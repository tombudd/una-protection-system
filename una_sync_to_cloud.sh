#!/bin/bash
# UNA-AI Cloud Sync Script
# Syncs backups to cloud storage (supports rclone, AWS S3, Google Drive)

set -euo pipefail

BACKUP_DIR="/Volumes/UNA-AI EXTENSION/UNA-AI-BACKUPS"
CLOUD_REMOTE="gdrive:UNA-AI-Backups"  # Configure for your cloud provider
LOG_FILE="$HOME/una-cloud-sync.log"

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" | tee -a "$LOG_FILE"
}

# Check if rclone is available
if ! command -v rclone &> /dev/null; then
    echo "❌ rclone not found. Install with: brew install rclone"
    echo "   Then configure with: rclone config"
    exit 1
fi

log "Starting cloud sync..."

# Sync backups to cloud
if rclone sync "$BACKUP_DIR" "$CLOUD_REMOTE" \
    --exclude ".DS_Store" \
    --exclude ".integrity.db" \
    --exclude ".last_backup_time" \
    --progress \
    --stats-one-line; then
    log "✅ Cloud sync completed successfully"
    
    # Verify sync
    local_count=$(find "$BACKUP_DIR" -name "UNA-AI-backup-*.tar.gz" | wc -l)
    remote_count=$(rclone ls "$CLOUD_REMOTE" | grep -c "UNA-AI-backup-" || echo 0)
    
    log "Local backups: $local_count, Remote backups: $remote_count"
    
    if [ "$local_count" -eq "$remote_count" ]; then
        log "✅ Verification passed"
        exit 0
    else
        log "⚠️  Backup count mismatch"
        exit 1
    fi
else
    log "❌ Cloud sync failed"
    exit 1
fi
