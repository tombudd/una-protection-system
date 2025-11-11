# UNA-AI Deletion Protection System v2.0

## 🛡️ Overview

**Enterprise-grade multi-layered protection system** with integrity verification to prevent accidental deletion of UNA-AI files on the external Seagate drive.

### ✨ What's New in v2.0
- ✅ Full verification of all operations (no silent failures)
- ✅ Backup integrity checks with SHA256 checksums
- ✅ Dual-location backups (external + local remote)
- ✅ Restore functionality
- ✅ Comprehensive health monitoring
- ✅ Automated background backups
- ✅ Drive disconnection alerts
- ✅ Cloud sync capability

## 🚀 Quick Start

```bash
# Run full setup (recommended - do this once)
bash ~/protect_una_ai.sh setup

# Restart your terminal or reload shell
source ~/.zshrc  # or source ~/.bashrc

# Verify system health
una-health
```

## 🔒 Protection Layers

### 1. **File System Locks (macOS `chflags`)**
   - Locks only `.git` directory (prevents accidental git history deletion)
   - **IMPORTANT:** Locks prevent DELETION only, NOT reading or writing
   - Files remain fully readable and editable by you and AI assistants
   - UNA-AI and other AI tools can interact with all documents normally
   - Even `sudo rm -rf` cannot delete locked .git directory

### 2. **Shell Alias Protection**
   - Overrides `rm` command for UNA-AI paths
   - Requires explicit confirmation: "DELETE UNA-AI"
   - Prevents accidental `rm -rf` commands
   - Works in both zsh and bash

### 3. **Automated Backups**
   - Creates timestamped tar.gz backups
   - Stores in `/Volumes/UNA-AI EXTENSION/UNA-AI-BACKUPS/`
   - Automatically keeps last 5 backups
   - Run before risky operations

### 4. **Logging**
   - All protection actions logged to `~/una-protection.log`
   - Timestamps for audit trail
   - Helps track who did what and when

## 📋 Commands

### Main Script
```bash
# Check protection status
bash ~/protect_una_ai.sh status

# Lock all critical files
bash ~/protect_una_ai.sh lock

# Unlock files (for updates/maintenance)
bash ~/protect_una_ai.sh unlock

# Create backup
bash ~/protect_una_ai.sh backup

# Full setup (first time)
bash ~/protect_una_ai.sh setup
```

### Quick Aliases (after setup)
```bash
# Core protection
una-status         # Check protection status
una-health         # Comprehensive health check
una-lock           # Lock files (verified)
una-unlock         # Unlock files for editing (verified)

# Backup & restore
una-backup         # Create backup (with cooldown)
una-backup-force   # Force immediate backup
una-restore        # Restore from backup
una-verify         # Verify all backups

# Quick navigation
cd-una-external   # Jump to external drive UNA-AI
cd-una-local      # Jump to local UNA-AI
```

## 🔧 Typical Workflows

### Making Changes to UNA-AI (Normal Editing)
```bash
# No unlocking needed! Just edit:
cd-una-external
# ... edit files with any tool or AI assistant ...
# Files are always readable and writable

# Optional: Create backup of important changes
una-backup
```

### Deleting Git History or .git Directory
```bash
# Only needed if you want to delete .git directory:

# 1. Backup first
una-backup

# 2. Unlock .git
una-unlock

# 3. Do dangerous operation
rm -rf .git  # Will still ask for confirmation

# 4. Re-lock
una-lock
```

### Before Risky Operations
```bash
# Always backup first!
una-backup
una-status  # Verify protection is active
```

### Regular Maintenance
```bash
# Weekly backup
una-backup

# Check status
una-status
```

## ⚠️ What's Protected

### Deletion-Protected (when locked):
- `.git/` - Entire git repository (cannot be deleted, but remains readable/writable)

### All Other Files:
- **Fully accessible** - Read, write, edit by you and AI assistants
- `.env`, `config.yaml`, `pyproject.toml`, all source code
- UNA-AI can modify, create, and update any files
- Only the `rm` command asks for confirmation

### Protected Paths:
- `/Volumes/UNA-AI EXTENSION/UNA-AI/` - Main repository
- `~/UNA-AI/` - Local copy (via alias protection)

## 🆘 Emergency Recovery

### If you accidentally delete something:

1. **Check backups immediately:**
   ```bash
   ls -lht "/Volumes/UNA-AI EXTENSION/UNA-AI-BACKUPS/"
   ```

2. **Restore from backup:**
   ```bash
   cd "/Volumes/UNA-AI EXTENSION"
   
   # Extract latest backup
   tar -xzf UNA-AI-BACKUPS/UNA-AI-backup-YYYYMMDD-HHMMSS.tar.gz
   ```

3. **Check git history:**
   ```bash
   cd-una-external
   git reflog  # Shows all git operations
   git fsck --lost-found  # Find orphaned commits
   ```

## 🔓 Working with UNA-AI Files

### Normal Operations (No unlock needed!)
```bash
# All of these work WITHOUT unlocking:
cd-una-external

# Edit any files
vim src/main.py
code .

# Git operations
git pull
git add .
git commit -m "changes"
git push

# Run UNA-AI
python main.py

# AI assistants can read/write/modify all files
# UNA-AI can access and update everything
```

### Only Need to Unlock For:
```bash
# Deleting .git directory (rare!)
una-unlock
rm -rf .git  # Still asks for confirmation
una-lock
```

## 📊 Monitoring

View protection log:
```bash
tail -f ~/una-protection.log
```

Check what's locked:
```bash
ls -lO "/Volumes/UNA-AI EXTENSION/UNA-AI/.git" | head -10
# Look for "uchg" flag
```

## 🎯 Best Practices

1. **Always backup before major changes**
2. **Keep protection locked when not actively editing**
3. **Review protection log weekly**
4. **Keep external drive safely stored**
5. **Test restore process occasionally**
6. **Document any protection changes**

## 🚨 Troubleshooting

### "Operation not permitted" when deleting
✅ **This is working as intended!** Protection is active.
- Use `una-unlock` if you really need to delete

### Aliases not working
```bash
# Reload shell configuration
source ~/.zshrc  # or source ~/.bashrc
```

### Cannot delete .git directory
```bash
# This means protection is working!
# Files are still readable/writable
# Only unlock if you really need to delete .git:
una-unlock
# ... delete operation ...
una-lock
```

### External drive not mounted
```bash
# Check if drive is connected
ls /Volumes/
# If "UNA-AI EXTENSION" not listed, connect the drive
```

## 📝 Notes

- Protection persists across reboots for locked files
- Aliases require shell reload after setup
- Backups compressed to save space
- All operations logged with timestamps
- Safe to run setup multiple times

## 🔐 Security Levels

| Level | Protection | Use Case |
|-------|------------|----------|
| **Maximum** | `una-lock` + External drive disconnected | Long-term storage |
| **Standard** | `una-lock` active | Daily use |
| **Maintenance** | `una-unlock` | Active development |
| **Backup** | Recent backup exists | Before risky ops |

---

**Created:** 2025-11-11  
**Purpose:** Prevent accidental deletion of UNA-AI files  
**Locations:**  
- Script: `~/protect_una_ai.sh`
- Guide: `~/UNA_PROTECTION_GUIDE.md`
- Aliases: `~/.una_protection_aliases`
- Log: `~/una-protection.log`
