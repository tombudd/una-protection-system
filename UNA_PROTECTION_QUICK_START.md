# UNA-AI Protection System - Quick Start Guide

## 🚀 5-Minute Setup

### Step 1: Run Setup (2 minutes)
```bash
bash ~/protect_una_ai.sh setup
```

This will:
- ✅ Verify external drive is connected
- ✅ Check disk space
- ✅ Install shell aliases
- ✅ Apply deletion protection locks
- ✅ Create initial verified backup

### Step 2: Reload Shell (30 seconds)
```bash
source ~/.zshrc   # or source ~/.bashrc
```

### Step 3: Verify System (1 minute)
```bash
una-health
```

### Step 4: Test Commands (1 minute)
```bash
# Check status
una-status

# View backups
ls -lh "/Volumes/UNA-AI EXTENSION/UNA-AI-BACKUPS/"

# Navigate to UNA-AI
cd-una-external
```

## ✅ You're Protected!

Your UNA-AI files now have:
- 🔒 **Deletion protection** on .git directory
- 💾 **Verified backups** with integrity checks
- 📍 **Dual-location** backup storage
- ⚠️  **Confirmation prompts** for rm commands
- 📊 **Health monitoring** system

## 🎯 Daily Commands

```bash
# Check everything is OK
una-health

# Create backup before major changes
una-backup

# Check protection status
una-status
```

## 🆘 Emergency Commands

```bash
# If something gets deleted:
una-restore

# If backup seems corrupted:
una-verify

# Force fresh backup:
una-backup-force
```

## 🔧 Optional: Automation

### Auto-Backup Every 6 Hours
```bash
# Start in background
nohup bash ~/una_auto_backup.sh > /dev/null 2>&1 &

# Check it's running
ps aux | grep una_auto_backup
```

### Drive Disconnection Monitor
```bash
# Start in background
nohup bash ~/una_drive_monitor.sh > /dev/null 2>&1 &

# You'll get notifications if drive disconnects
```

### Cloud Sync (requires rclone)
```bash
# Install rclone
brew install rclone

# Configure cloud storage
rclone config

# Run sync
bash ~/una_sync_to_cloud.sh
```

## 📊 Understanding Health Scores

| Score | Status | Action |
|-------|--------|--------|
| 90-100 | 🎉 Excellent | No action needed |
| 70-89 | ✅ Good | Consider creating backup |
| 50-69 | ⚠️ Needs Attention | Run `una-backup` and review issues |
| < 50 | ❌ Critical | **Take action immediately** |

## 🎓 What You're Protected Against

✅ **Accidental `rm -rf` commands**  
✅ **Git history deletion**  
✅ **Silent backup failures**  
✅ **Corrupted backups**  
✅ **Single point of failure**  
✅ **Drive disconnection data loss**  
✅ **Unverified operations**  

## ❌ What You're NOT Protected Against

⚠️ **Physical drive failure** - Use cloud sync  
⚠️ **Malicious intentional deletion** - This is accidental deletion protection  
⚠️ **Ransomware encryption** - Keep offline backups  
⚠️ **File corruption** - Git provides version control  

## 🆘 If Something Goes Wrong

1. **Stay calm** - Your files are probably safe
2. **Check status**: `una-status`
3. **Check health**: `una-health`
4. **Check backups**: `una-restore` (lists available backups)
5. **Review logs**: `tail -50 ~/una-protection.log`

## 📞 Emergency Recovery

```bash
# List available backups
una-restore

# Restore specific backup (it will ask for confirmation)
una-restore UNA-AI-backup-YYYYMMDD-HHMMSS-UTC.tar.gz

# Check git history
cd-una-external
git reflog
git fsck --lost-found
```

## 🎯 Best Practices

1. ✅ Run `una-health` weekly
2. ✅ Create backup before major changes
3. ✅ Keep external drive safely stored
4. ✅ Enable auto-backup daemon
5. ✅ Test restore process monthly
6. ✅ Set up cloud sync for redundancy

## 📝 Files Created

```
~/protect_una_ai.sh              - Main protection script
~/una_auto_backup.sh             - Auto-backup daemon
~/una_drive_monitor.sh           - Drive monitor
~/una_sync_to_cloud.sh           - Cloud sync
~/.una_protection_aliases        - Shell aliases
~/una-protection.log             - Main log
~/una-auto-backup.log            - Auto-backup log
~/una-drive-monitor.log          - Monitor log
~/.una-remote-backups/           - Local remote backups
/Volumes/.../UNA-AI-BACKUPS/     - Primary backups
```

## ✨ Key Features

### Verified Operations
Every operation is verified:
- Lock application ✅ Verified
- Lock removal ✅ Verified  
- Backup creation ✅ Verified with SHA256
- Backup integrity ✅ Tested before accepting
- Drive mounting ✅ Validated

### No Silent Failures
v2.0 eliminates all silent failures:
- Operations succeed ✅ or fail loudly ❌
- Clear error messages
- Detailed logging
- Exit codes for scripts

### Dual-Location Backups
Never lose data:
- Primary: External drive
- Secondary: Local remote location
- Optional: Cloud storage

### AI-Friendly Protection
- All files remain readable ✅
- All files remain writable ✅
- Only deletion is prevented 🔒
- UNA-AI and assistants have full access ✅

---

**Setup Time:** 5 minutes  
**Daily Time:** 0 minutes (automated)  
**Peace of Mind:** Priceless 😌

**Questions?** Check the full guide: `UNA_PROTECTION_GUIDE.md`
