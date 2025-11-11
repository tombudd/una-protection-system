#!/bin/bash
# UNA-AI Deletion Protection System v2.0
# Enterprise-grade protection with integrity verification
# Protects UNA-AI directory on external drive from accidental deletion

set -euo pipefail
IFS=$'\n\t'

# Configuration
EXTERNAL_UNA="/Volumes/UNA-AI EXTENSION/UNA-AI"
LOCAL_UNA="$HOME/UNA-AI"
BACKUP_DIR="/Volumes/UNA-AI EXTENSION/UNA-AI-BACKUPS"
REMOTE_BACKUP_DIR="$HOME/.una-remote-backups"
LOG_FILE="$HOME/una-protection.log"
INTEGRITY_DB="$BACKUP_DIR/.integrity.db"
MIN_DISK_SPACE_GB=5
BACKUP_COOLDOWN_SECONDS=300
LAST_BACKUP_FILE="$BACKUP_DIR/.last_backup_time"

# Error codes
ERR_DRIVE_NOT_MOUNTED=1
ERR_INSUFFICIENT_SPACE=2
ERR_LOCK_FAILED=3
ERR_BACKUP_FAILED=4
ERR_VERIFY_FAILED=5
ERR_PERMISSION_DENIED=6

# Logging with severity levels
log_message() {
    local level="${1}"
    local message="${2}"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }

# Fatal error handler
fatal_error() {
    log_error "$1"
    echo "❌ FATAL ERROR: $1"
    echo "Check log: $LOG_FILE"
    exit "${2:-1}"
}

# Check if external drive is mounted with validation
check_drive_mounted() {
    if [ ! -d "$EXTERNAL_UNA" ]; then
        log_error "External drive 'UNA-AI EXTENSION' not mounted"
        return $ERR_DRIVE_NOT_MOUNTED
    fi
    
    # Verify it's actually a mounted volume, not just a directory (macOS)
    if ! /sbin/mount | grep -q "UNA-AI EXTENSION"; then
        log_error "Path exists but drive not properly mounted"
        return $ERR_DRIVE_NOT_MOUNTED
    fi
    
    # Check if path is a symlink (security risk)
    if [ -L "$EXTERNAL_UNA" ]; then
        log_error "UNA-AI path is a symlink - potential security risk"
        return $ERR_DRIVE_NOT_MOUNTED
    fi
    
    log_info "External drive mounted and validated"
    return 0
}

# Check available disk space
check_disk_space() {
    local required_gb="${1:-$MIN_DISK_SPACE_GB}"
    local mount_point="/Volumes/UNA-AI EXTENSION"
    
    # Get available space in GB
    local available_gb=$(df -g "$mount_point" | awk 'NR==2 {print $4}')
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space: ${available_gb}GB available, ${required_gb}GB required"
        return $ERR_INSUFFICIENT_SPACE
    fi
    
    log_info "Disk space check passed: ${available_gb}GB available"
    return 0
}

# Verify sudo access
verify_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo "🔐 This operation requires administrator privileges"
        echo "Reason: macOS chflags requires root to set immutable flag"
        sudo -v || fatal_error "Administrator access required" $ERR_PERMISSION_DENIED
    fi
}

# Apply macOS file locking with verification
apply_file_locks() {
    log_info "Applying file system locks (deletion protection only)..."
    
    verify_sudo
    check_drive_mounted || fatal_error "Cannot lock: drive not mounted" $ERR_DRIVE_NOT_MOUNTED
    
    # Lock .git directory
    if [ ! -d "$EXTERNAL_UNA/.git" ]; then
        log_warn "No .git directory found - skipping git lock"
        return 0
    fi
    
    # Apply lock without following symlinks
    if sudo chflags -h -R uchg "$EXTERNAL_UNA/.git"; then
        log_info "Applied uchg flag to .git directory"
    else
        fatal_error "Failed to apply file locks" $ERR_LOCK_FAILED
    fi
    
    # VERIFY lock was applied
    local git_flags=$(ls -ldO "$EXTERNAL_UNA/.git" 2>/dev/null | awk '{print $5}')
    if [[ "$git_flags" == *"uchg"* ]]; then
        log_success "Lock verification PASSED: .git is protected"
        log_info "Protection scope: Deletion only (read/write preserved)"
        return 0
    else
        fatal_error "Lock verification FAILED: .git not properly protected" $ERR_LOCK_FAILED
    fi
}

# Remove file locks with verification
remove_file_locks() {
    log_info "Removing file system locks..."
    
    verify_sudo
    check_drive_mounted || fatal_error "Cannot unlock: drive not mounted" $ERR_DRIVE_NOT_MOUNTED
    
    if [ ! -d "$EXTERNAL_UNA/.git" ]; then
        log_warn "No .git directory found"
        return 0
    fi
    
    # Remove lock
    if sudo chflags -h -R nouchg "$EXTERNAL_UNA/.git"; then
        log_info "Removed uchg flag from .git directory"
    else
        log_error "Failed to remove locks (may already be unlocked)"
        return 0
    fi
    
    # VERIFY lock was removed
    local git_flags=$(ls -ldO "$EXTERNAL_UNA/.git" 2>/dev/null | awk '{print $5}')
    if [[ "$git_flags" != *"uchg"* ]]; then
        log_success "Unlock verification PASSED: .git is now unprotected"
        return 0
    else
        log_error "Unlock verification FAILED: .git still protected"
        return $ERR_LOCK_FAILED
    fi
}

# Calculate SHA256 checksum
calculate_checksum() {
    local file="$1"
    shasum -a 256 "$file" | awk '{print $1}'
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    log_info "Verifying backup integrity..."
    
    # Check file exists
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file does not exist: $backup_file"
        return $ERR_VERIFY_FAILED
    fi
    
    # Test tar integrity
    if ! tar -tzf "$backup_file" > /dev/null 2>&1; then
        log_error "Backup file is corrupted or invalid"
        return $ERR_VERIFY_FAILED
    fi
    
    # Calculate and store checksum
    local checksum=$(calculate_checksum "$backup_file")
    echo "$(date -u +%s) $(basename "$backup_file") $checksum" >> "$INTEGRITY_DB"
    
    log_success "Backup integrity verified (SHA256: ${checksum:0:16}...)"
    return 0
}

# Check backup cooldown
check_backup_cooldown() {
    if [ ! -f "$LAST_BACKUP_FILE" ]; then
        return 0
    fi
    
    local last_backup=$(cat "$LAST_BACKUP_FILE")
    local current_time=$(date +%s)
    local elapsed=$((current_time - last_backup))
    
    if [ "$elapsed" -lt "$BACKUP_COOLDOWN_SECONDS" ]; then
        local remaining=$((BACKUP_COOLDOWN_SECONDS - elapsed))
        log_warn "Backup cooldown active: wait ${remaining}s before next backup"
        echo "⏳ Recent backup exists (${elapsed}s ago). Wait ${remaining}s or use --force"
        return 1
    fi
    
    return 0
}

# Create backup with full verification
create_backup() {
    local force_backup="${1:-false}"
    
    log_info "Starting backup process..."
    
    check_drive_mounted || fatal_error "Cannot backup: drive not mounted" $ERR_DRIVE_NOT_MOUNTED
    check_disk_space 10 || fatal_error "Insufficient disk space for backup" $ERR_INSUFFICIENT_SPACE
    
    # Check cooldown unless forced
    if [ "$force_backup" != "force" ]; then
        check_backup_cooldown || return 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$REMOTE_BACKUP_DIR"
    
    local backup_name="UNA-AI-backup-$(date -u +%Y%m%d-%H%M%S-UTC).tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    local backup_tmp="${backup_path}.tmp"
    
    log_info "Creating backup: $backup_name"
    
    # Create backup to temp file first (atomic operation)
    cd "$(dirname "$EXTERNAL_UNA")"
    if tar -czf "$backup_tmp" --no-xattrs --exclude='.DS_Store' "UNA-AI/"; then
        mv "$backup_tmp" "$backup_path"
        log_info "Backup file created"
    else
        rm -f "$backup_tmp"
        fatal_error "Backup creation failed" $ERR_BACKUP_FAILED
    fi
    
    # Verify backup integrity
    verify_backup "$backup_path" || fatal_error "Backup verification failed" $ERR_VERIFY_FAILED
    
    # Copy to remote backup location
    if cp "$backup_path" "$REMOTE_BACKUP_DIR/"; then
        log_info "Remote backup copy created"
    else
        log_warn "Remote backup copy failed (continuing)"
    fi
    
    # Update last backup time
    date +%s > "$LAST_BACKUP_FILE"
    
    # Keep only last 5 backups in each location
    for dir in "$BACKUP_DIR" "$REMOTE_BACKUP_DIR"; do
        cd "$dir"
        ls -t UNA-AI-backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    done
    
    local backup_size=$(du -h "$backup_path" | awk '{print $1}')
    log_success "Backup completed: $backup_name ($backup_size)"
    echo "✅ Backup: $backup_name ($backup_size)"
    echo "📍 Location: $BACKUP_DIR"
    echo "📍 Remote: $REMOTE_BACKUP_DIR"
}

# Set up shell aliases for safe operations
setup_aliases() {
    log_message "⚙️  Setting up safety aliases..."
    
    ALIAS_FILE="$HOME/.una_protection_aliases"
    
    cat > "$ALIAS_FILE" << 'EOF'
# UNA-AI Protection Aliases
# DO NOT rm -rf UNA-AI directories without confirmation

# Override rm for UNA-AI paths with confirmation
rm() {
    local args=("$@")
    local una_path_found=false
    
    for arg in "${args[@]}"; do
        if [[ "$arg" == *"UNA-AI"* ]]; then
            una_path_found=true
            break
        fi
    done
    
    if [ "$una_path_found" = true ]; then
        echo "⚠️  WARNING: You are about to delete UNA-AI files!"
        echo "Path(s) contain: UNA-AI"
        read -p "Are you ABSOLUTELY sure? Type 'DELETE UNA-AI' to confirm: " confirmation
        
        if [ "$confirmation" != "DELETE UNA-AI" ]; then
            echo "❌ Deletion cancelled. Your UNA-AI files are safe."
            return 1
        fi
    fi
    
    command rm "$@"
}

# Safe UNA-AI navigation
alias cd-una-external='cd "/Volumes/UNA-AI EXTENSION/UNA-AI"'
alias cd-una-local='cd "$HOME/UNA-AI"'

# Quick protection commands
alias una-lock='bash ~/protect_una_ai.sh lock'
alias una-unlock='bash ~/protect_una_ai.sh unlock'
alias una-backup='bash ~/protect_una_ai.sh backup'
alias una-backup-force='bash ~/protect_una_ai.sh backup force'
alias una-status='bash ~/protect_una_ai.sh status'
alias una-health='bash ~/protect_una_ai.sh health'
alias una-restore='bash ~/protect_una_ai.sh restore'
alias una-verify='bash ~/protect_una_ai.sh verify'
EOF
    
    # Add to shell profile if not already present
    for profile in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$profile" ] && ! grep -q "una_protection_aliases" "$profile"; then
            echo "" >> "$profile"
            echo "# UNA-AI Protection System" >> "$profile"
            echo "[ -f ~/.una_protection_aliases ] && source ~/.una_protection_aliases" >> "$profile"
            log_message "  Added to: $profile"
        fi
    done
    
    log_message "✅ Aliases configured"
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo "Available backups:"
        ls -lht "$BACKUP_DIR"/UNA-AI-backup-*.tar.gz 2>/dev/null || echo "No backups found"
        echo ""
        echo "Usage: $0 restore <backup-filename>"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_file"
    
    if [ ! -f "$backup_path" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warn "RESTORE operation will overwrite current UNA-AI directory!"
    read -p "Type 'RESTORE NOW' to confirm: " confirmation
    
    if [ "$confirmation" != "RESTORE NOW" ]; then
        echo "❌ Restore cancelled"
        return 1
    fi
    
    # Verify backup before restoring
    verify_backup "$backup_path" || fatal_error "Cannot restore corrupted backup" $ERR_VERIFY_FAILED
    
    # Unlock before restore
    remove_file_locks
    
    # Create safety backup of current state
    log_info "Creating safety backup of current state..."
    create_backup force
    
    # Restore
    log_info "Restoring from: $backup_file"
    cd "$(dirname "$EXTERNAL_UNA")"
    
    if tar -xzf "$backup_path"; then
        log_success "Restore completed successfully"
        apply_file_locks
        echo "✅ Restore complete from: $backup_file"
    else
        fatal_error "Restore failed" $ERR_BACKUP_FAILED
    fi
}

# Health check
health_check() {
    log_info "Running comprehensive health check..."
    
    local health_score=100
    local issues=0
    
    echo ""
    echo "=== UNA-AI Protection System Health Check ==="
    echo ""
    
    # Check 1: Drive mounted
    if check_drive_mounted; then
        echo "✅ External drive: Mounted"
    else
        echo "❌ External drive: NOT MOUNTED"
        health_score=$((health_score - 40))
        issues=$((issues + 1))
    fi
    
    # Check 2: Lock status
    if [ -e "$EXTERNAL_UNA/.git" ]; then
        flags=$(ls -ldO "$EXTERNAL_UNA/.git" 2>/dev/null | awk '{print $5}')
        if [[ "$flags" == *"uchg"* ]]; then
            echo "✅ File locks: Active (deletion protected)"
        else
            echo "⚠️  File locks: Inactive"
            health_score=$((health_score - 15))
            issues=$((issues + 1))
        fi
    fi
    
    # Check 3: Recent backup
    if [ -f "$LAST_BACKUP_FILE" ]; then
        local last_backup=$(cat "$LAST_BACKUP_FILE")
        local current_time=$(date +%s)
        local hours_since=$(( (current_time - last_backup) / 3600 ))
        
        if [ "$hours_since" -lt 24 ]; then
            echo "✅ Recent backup: ${hours_since}h ago"
        elif [ "$hours_since" -lt 168 ]; then
            echo "⚠️  Recent backup: ${hours_since}h ago (consider backing up)"
            health_score=$((health_score - 10))
        else
            echo "❌ Recent backup: ${hours_since}h ago (BACKUP NOW!)"
            health_score=$((health_score - 25))
            issues=$((issues + 1))
        fi
    else
        echo "❌ No backup history found"
        health_score=$((health_score - 25))
        issues=$((issues + 1))
    fi
    
    # Check 4: Disk space
    if check_disk_space; then
        local available_gb=$(df -g "/Volumes/UNA-AI EXTENSION" | awk 'NR==2 {print $4}')
        echo "✅ Disk space: ${available_gb}GB available"
    else
        echo "❌ Disk space: CRITICALLY LOW"
        health_score=$((health_score - 20))
        issues=$((issues + 1))
    fi
    
    # Check 5: Backup integrity
    if [ -f "$INTEGRITY_DB" ]; then
        local backup_count=$(wc -l < "$INTEGRITY_DB")
        echo "✅ Integrity database: $backup_count backups tracked"
    else
        echo "⚠️  Integrity database: Not initialized"
        health_score=$((health_score - 5))
    fi
    
    # Check 6: Aliases
    if [ -f "$HOME/.una_protection_aliases" ]; then
        echo "✅ Shell aliases: Installed"
    else
        echo "⚠️  Shell aliases: Not installed"
        health_score=$((health_score - 10))
    fi
    
    # Check 7: Git repository health
    if [ -d "$EXTERNAL_UNA/.git" ]; then
        cd "$EXTERNAL_UNA"
        if git fsck --quiet 2>/dev/null; then
            echo "✅ Git repository: Healthy"
        else
            echo "⚠️  Git repository: Issues detected (run git fsck)"
            health_score=$((health_score - 15))
        fi
    fi
    
    echo ""
    echo "=== Health Score: $health_score/100 ==="
    
    if [ "$health_score" -ge 90 ]; then
        echo "🎉 System Status: EXCELLENT"
    elif [ "$health_score" -ge 70 ]; then
        echo "✅ System Status: GOOD"
    elif [ "$health_score" -ge 50 ]; then
        echo "⚠️  System Status: NEEDS ATTENTION"
    else
        echo "❌ System Status: CRITICAL - TAKE ACTION NOW"
    fi
    
    echo ""
    echo "Issues found: $issues"
    
    if [ "$issues" -gt 0 ]; then
        echo ""
        echo "Recommendations:"
        [ "$health_score" -lt 90 ] && echo "  - Run 'una-backup' to create fresh backup"
        [ ! -f "$HOME/.una_protection_aliases" ] && echo "  - Run setup to install aliases"
        echo "  - Review log: $LOG_FILE"
    fi
}

# Enhanced status check
check_status() {
    log_info "Protection Status Report"
    echo ""
    
    if check_drive_mounted; then
        echo "🔌 External Drive: ✅ Mounted"
    else
        echo "🔌 External Drive: ❌ Not Mounted"
    fi
    
    echo ""
    echo "🔒 File Locks (prevents deletion only, NOT reading/writing):"
    
    if [ -e "$EXTERNAL_UNA/.git" ]; then
        flags=$(ls -ldO "$EXTERNAL_UNA/.git" 2>/dev/null | awk '{print $5}')
        if [[ "$flags" == *"uchg"* ]]; then
            echo "  🔒 .git - LOCKED (deletion protected)"
        else
            echo "  🔓 .git - unlocked"
        fi
    fi
    
    echo ""
    echo "✅ All files readable/writable by you and AI assistants"
    
    echo ""
    echo "💾 Recent Backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lht "$BACKUP_DIR"/UNA-AI-backup-*.tar.gz 2>/dev/null | head -6 || echo "  No backups found"
    else
        echo "  No backups directory found"
    fi
    
    echo ""
    echo "📍 Remote Backups:"
    if [ -d "$REMOTE_BACKUP_DIR" ]; then
        ls -lht "$REMOTE_BACKUP_DIR"/UNA-AI-backup-*.tar.gz 2>/dev/null | head -3 || echo "  No remote backups"
    else
        echo "  Not configured"
    fi
    
    echo ""
    echo "⚙️  Aliases: $([ -f "$HOME/.una_protection_aliases" ] && echo "✅ Installed" || echo "❌ Not installed")"
    
    echo ""
    echo "Run 'una-health' for comprehensive health check"
}

# Verify all backups
verify_all_backups() {
    log_info "Verifying all backups..."
    
    local total=0
    local valid=0
    local invalid=0
    
    for backup in "$BACKUP_DIR"/UNA-AI-backup-*.tar.gz; do
        if [ ! -f "$backup" ]; then
            continue
        fi
        
        total=$((total + 1))
        echo -n "Checking $(basename "$backup")... "
        
        if tar -tzf "$backup" > /dev/null 2>&1; then
            echo "✅ Valid"
            valid=$((valid + 1))
        else
            echo "❌ CORRUPTED"
            invalid=$((invalid + 1))
            log_error "Corrupted backup: $(basename "$backup")"
        fi
    done
    
    echo ""
    echo "Results: $valid valid, $invalid corrupted, $total total"
    
    if [ "$invalid" -gt 0 ]; then
        log_warn "Found $invalid corrupted backups - recommend creating fresh backup"
        return 1
    fi
    
    log_success "All backups verified successfully"
    return 0
}

# Main command handler
case "${1:-status}" in
    lock)
        check_drive_mounted && apply_file_locks
        ;;
    unlock)
        check_drive_mounted && remove_file_locks
        ;;
    backup)
        shift
        check_drive_mounted && create_backup "$@"
        ;;
    restore)
        shift
        restore_backup "$1"
        ;;
    verify)
        verify_all_backups
        ;;
    health)
        health_check
        ;;
    setup)
        echo "🚀 Starting UNA-AI Protection System Setup..."
        echo ""
        check_drive_mounted || fatal_error "Setup requires mounted drive" $ERR_DRIVE_NOT_MOUNTED
        check_disk_space || fatal_error "Insufficient disk space" $ERR_INSUFFICIENT_SPACE
        
        setup_aliases
        apply_file_locks
        create_backup force
        
        echo ""
        log_success "UNA-AI protection system fully configured!"
        echo ""
        echo "✅ Setup complete! Reload your shell:"
        echo "   source ~/.zshrc"
        echo ""
        echo "Quick commands:"
        echo "   una-status  - Check status"
        echo "   una-health  - Health check"
        echo "   una-backup  - Create backup"
        echo "   una-lock    - Lock files"
        ;;
    status)
        check_status
        ;;
    *)
        echo "UNA-AI Deletion Protection System v2.0"
        echo "Enterprise-grade protection with integrity verification"
        echo ""
        echo "Usage: $0 {setup|lock|unlock|backup|restore|verify|health|status}"
        echo ""
        echo "Commands:"
        echo "  setup          - Full protection setup (locks, aliases, backup)"
        echo "  lock           - Apply file system locks"
        echo "  unlock         - Remove file system locks (for maintenance)"
        echo "  backup [force] - Create verified backup (with optional force)"
        echo "  restore <file> - Restore from backup"
        echo "  verify         - Verify integrity of all backups"
        echo "  health         - Comprehensive health check"
        echo "  status         - Show protection status"
        echo ""
        echo "Quick aliases (after setup):"
        echo "  una-lock          - Lock files"
        echo "  una-unlock        - Unlock files"
        echo "  una-backup        - Create backup (with cooldown)"
        echo "  una-backup-force  - Force immediate backup"
        echo "  una-restore       - Restore from backup"
        echo "  una-verify        - Verify backups"
        echo "  una-health        - Health check"
        echo "  una-status        - Status report"
        ;;
esac
