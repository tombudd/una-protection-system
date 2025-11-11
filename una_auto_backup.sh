#!/bin/bash
# UNA-AI Automated Backup Daemon
# Runs in background and creates backups on schedule

set -euo pipefail

BACKUP_INTERVAL_HOURS=6
PID_FILE="$HOME/.una_auto_backup.pid"
LOG_FILE="$HOME/una-auto-backup.log"

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" | tee -a "$LOG_FILE"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    if ps -p "$old_pid" > /dev/null 2>&1; then
        echo "Auto-backup daemon already running (PID: $old_pid)"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Save PID
echo $$ > "$PID_FILE"

log "Auto-backup daemon started (PID: $$, interval: ${BACKUP_INTERVAL_HOURS}h)"

# Cleanup on exit
cleanup() {
    log "Auto-backup daemon stopped"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Main loop
while true; do
    # Check if drive is mounted
    if [ -d "/Volumes/UNA-AI EXTENSION/UNA-AI" ]; then
        log "Creating scheduled backup..."
        
        if bash ~/protect_una_ai.sh backup force; then
            log "Scheduled backup completed successfully"
        else
            log "ERROR: Scheduled backup failed"
        fi
    else
        log "WARNING: External drive not mounted, skipping backup"
    fi
    
    # Sleep until next backup
    sleep $((BACKUP_INTERVAL_HOURS * 3600))
done
