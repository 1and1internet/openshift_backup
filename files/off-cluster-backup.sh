#! /bin/sh

# Creates backups of backups and stores them a given location using duplicity http://duplicity.nongnu.org
# The backup location should be a mount somewhere off cluster or server.

set -e

SOURCE_DIRECTORY=${OFF_CLUSTER_BACKUP_SOURCE_DIRECTORY:-"/backup-data"}
TARGET_DIRECTORY=${OFF_CLUSTER_BACKUP_TARGET_DIRECTORY:-"file:///nfs-storage/backups"}
BACKUP_NAME=${OFF_CLUSTER_BACKUP_NAME:-"towp-backup"}
BACKUP_RETENTION=${OFF_CLUSTER_BACKUP_RETENTION:-"10D"}

if ! [ -x "$(command -v duplicity)" ]; then
  echo "Error: `duplicity` is not available please install duplicity (http://duplicity.nongnu.org/)"
  exit 1
fi

if [ -z "${OFF_CLUSTER_BACKUP_PASSWORD}" ]; then
  echo "OFF_CLUSTER_BACKUP_PASSWORD environment variable is required for off cluster backups"
  exit 1
fi

# Setting the pass phrase to encrypt the backup files.
export PASSPHRASE=$OFF_CLUSTER_BACKUP_PASSWORD

if [ "$1" == "status" ]; then
  echo "Verifying backups on $TARGET_DIRECTORY ....."
  duplicity verify --allow-source-mismatch "$TARGET_DIRECTORY" "$SOURCE_DIRECTORY"
  exit 0
fi

# Backup to nfs mount
echo "Starting backup from $SOURCE_DIRECTORY to $TARGET_DIRECTORY"
duplicity --allow-source-mismatch \
          --name="$BACKUP_NAME" \
          --log-file /var/log/duplicity.log \
          "$SOURCE_DIRECTORY" "$TARGET_DIRECTORY"

# Deleting old backups
echo "Removing Old backups on $TARGET_DIRECTORY"
duplicity --allow-source-mismatch remove-older-than "$BACKUP_RETENTION" --force "$TARGET_DIRECTORY"
