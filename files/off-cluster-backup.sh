#! /bin/sh

# Creates backups of backups and stores them a given location using duplicity http://duplicity.nongnu.org
# The backup location should be a mount somewhere off cluster or server.

set -e

SOURCE_DIRECTORY=${OFF_CLUSTER_BACKUP_SOURCE_DIRECTORY:-"/home/leroy/Development/github.com/1and1internet/openshift_backup/backup-data"}
TARGET_DIRECTORY=${OFF_CLUSTER_BACKUP_TARGET_DIRECTORY:-"file:///home/leroy/Development/github.com/1and1internet/openshift_backup/nfs-storage/backups"}
BACKUP_NAME=${OFF_CLUSTER_BACKUP_NAME:-"towp-backup"}
NUMBER_OF_FULL_BACKUPS_TO_KEEP=${OFF_CLUSTER_BACKUP_NUMBER_OF_FULL_BACKUPS_TO_KEEP:-"7"}

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

if [ "$1" == "verify" ]; then
  echo "Verifying backups on $TARGET_DIRECTORY ....."
  duplicity verify --allow-source-mismatch "$TARGET_DIRECTORY" "$SOURCE_DIRECTORY"
  exit 0
elif [ "$1" == "collection-status" ]; then
  echo "Getting collection status for backups on $TARGET_DIRECTORY ....."
  duplicity collection-status "$TARGET_DIRECTORY"
  exit 0
fi

# Backup to nfs mount
echo "Starting backup from $SOURCE_DIRECTORY to $TARGET_DIRECTORY"
duplicity full \
          --allow-source-mismatch \
          --name="$BACKUP_NAME" \
          --log-file /var/log/duplicity.log \
          "$SOURCE_DIRECTORY" "$TARGET_DIRECTORY"

# Deleting old backups
echo "Removing Old backups on $TARGET_DIRECTORY"
duplicity remove-all-but-n-full \
          --allow-source-mismatch "$NUMBER_OF_FULL_BACKUPS_TO_KEEP" \
          --force \
          "$TARGET_DIRECTORY"
