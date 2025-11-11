#!/bin/bash
# UNA-AI Drive Monitor
# Watches for drive disconnection and sends alerts

set -euo pipefail

LOG_FILE="$HOME/una-drive-monitor.log"
CHECK_INTERVAL=30
ALERT_FILE="$HOME/.una_drive_alert_sent"

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    
    # Log alert
    log "ALERT: $message"
    
    # Display system notification (macOS)
    osascript -e "display notification \"$message\" with title \"UNA-AI Protection\" sound name \"Basso\""
    
    # Mark alert as sent
    touch "$ALERT_FILE"
}

clear_alert() {
    rm -f "$ALERT_FILE"
}

log "Drive monitor started (check interval: ${CHECK_INTERVAL}s)"

was_mounted=false

while true; do
    if [ -d "/Volumes/UNA-AI EXTENSION/UNA-AI" ]; then
        # Drive is mounted
        if [ "$was_mounted" = false ]; then
            log "Drive mounted - protection active"
            clear_alert
            was_mounted=true
        fi
    else
        # Drive not mounted
        if [ "$was_mounted" = true ]; then
            send_alert "⚠️ UNA-AI drive disconnected! Data at risk."
            was_mounted=false
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
