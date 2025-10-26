#!/bin/bash
# Pre-backup script - saves package lists and system info

BACKUP_INFO_DIR="/var/lib/backup-info"
mkdir -p "$BACKUP_INFO_DIR"

# Save package lists
dpkg --get-selections > "$BACKUP_INFO_DIR/dpkg-selections.txt" 2>/dev/null
apt-mark showmanual > "$BACKUP_INFO_DIR/manual-packages.txt" 2>/dev/null

# Save enabled services
systemctl list-unit-files --state=enabled --no-pager > "$BACKUP_INFO_DIR/enabled-services.txt" 2>/dev/null

# Save system info
{
  echo "Backup Date: $(date)"
  uname -a
  cat /etc/os-release
} > "$BACKUP_INFO_DIR/system-info.txt"

exit 0
