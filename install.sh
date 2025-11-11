#!/bin/bash
# UNA-AI Protection System - Universal Installer
# Installs on local machine or remote via SSH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║          UNA-AI PROTECTION SYSTEM v2.0 - UNIVERSAL INSTALLER            ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're installing locally or remotely
if [ "$#" -eq 0 ]; then
    echo "📍 Installing LOCALLY on this machine"
    REMOTE=""
else
    REMOTE="$1"
    echo "📍 Installing REMOTELY on: $REMOTE"
    echo ""
    echo "⚠️  Note: Remote install requires:"
    echo "   - SSH access configured"
    echo "   - External drive mounted on remote"
    echo ""
    read -p "Continue? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

echo ""
echo "🚀 Starting installation..."
echo ""

# Function to run command locally or remotely
run_cmd() {
    if [ -z "$REMOTE" ]; then
        eval "$1"
    else
        ssh "$REMOTE" "$1"
    fi
}

# Function to copy file locally or remotely
copy_file() {
    local src="$1"
    local dst="$2"
    
    if [ -z "$REMOTE" ]; then
        cp "$src" "$dst"
    else
        scp "$src" "${REMOTE}:${dst}"
    fi
}

# 1. Copy files
echo "📦 Copying protection system files..."
copy_file "$SCRIPT_DIR/protect_una_ai.sh" "~/protect_una_ai.sh"
copy_file "$SCRIPT_DIR/una_auto_backup.sh" "~/una_auto_backup.sh"
copy_file "$SCRIPT_DIR/una_drive_monitor.sh" "~/una_drive_monitor.sh"
copy_file "$SCRIPT_DIR/una_sync_to_cloud.sh" "~/una_sync_to_cloud.sh"

echo "📄 Copying documentation..."
copy_file "$SCRIPT_DIR/UNA_PROTECTION_GUIDE.md" "~/UNA_PROTECTION_GUIDE.md"
copy_file "$SCRIPT_DIR/UNA_PROTECTION_QUICK_START.md" "~/UNA_PROTECTION_QUICK_START.md"
copy_file "$SCRIPT_DIR/UNA_PROTECTION_V2_COMPLETE.txt" "~/UNA_PROTECTION_V2_COMPLETE.txt"

# 2. Make scripts executable
echo "🔧 Setting permissions..."
run_cmd "chmod +x ~/protect_una_ai.sh ~/una_auto_backup.sh ~/una_drive_monitor.sh ~/una_sync_to_cloud.sh"

# 3. Run setup
echo "⚙️  Running protection system setup..."
if [ -z "$REMOTE" ]; then
    bash ~/protect_una_ai.sh setup
else
    ssh -t "$REMOTE" "bash ~/protect_una_ai.sh setup"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║                    ✅ INSTALLATION COMPLETE!                            ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ -z "$REMOTE" ]; then
    echo "🎯 Next steps:"
    echo "   1. Reload your shell: source ~/.zshrc"
    echo "   2. Run health check: una-health"
    echo "   3. Check status: una-status"
else
    echo "🎯 Next steps on $REMOTE:"
    echo "   1. SSH into machine: ssh $REMOTE"
    echo "   2. Reload shell: source ~/.zshrc"
    echo "   3. Run health check: una-health"
fi

echo ""
echo "📚 Documentation:"
echo "   - Quick start: ~/UNA_PROTECTION_QUICK_START.md"
echo "   - Full guide: ~/UNA_PROTECTION_GUIDE.md"
echo "   - Summary: ~/UNA_PROTECTION_V2_COMPLETE.txt"
echo ""
echo "🎉 Protection system ready!"
