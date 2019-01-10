# Openshift Pod Backup

This repo describes a docker image that will back up openshift pods.

The docker image is based on Alpine and has the openshift origin cli baked in.

Currently supported:

- etcd
- mysql
- local content (via rsync)
- mongodb

Prerequisites:

You can use the backup.yaml file to create the required openshift resources:

oc new-project infra-backups
oc process -f backup.yaml | oc create -n infra-backups -f -

Ensure that the newly created serviceaccount has the cluster-reader cluster-role and the system:image-puller role

oc policy add-role-to-user system:image-puller system:serviceaccount:infra-backups:backup
oc policy add-cluster-role-to-user cluster-reader system:serviceaccount:infra-backups:backup

To rebuild the docker image:

docker login docker-registry.fhpaas.fasthosts.co.uk:443
./build_and_push.sh

## Cleanup

backups older than 30 days (default) are automatically deleted. This schedule runs on a daily basis. see `files/etc/periodic/daily/backup`

## Off Cluster Backups

The service provides a means of moving backups off cluster. For maximum protocol compatability the off cluster backups are made with [Duplicity](https://www.nongnu.org/duplicity/). The default method uses `nfs` and assumes that nfs is mounted at the `OFF_CLUSTER_BACKUP_TARGET_DIRECTORY` location. Off cluster backups run on a daily schedule see `files/etc/periodic/daily/backup`.

Backup default environment variables

```bash
OFF_CLUSTER_BACKUP_PASSWORD="insecure"
OFF_CLUSTER_BACKUP_SOURCE_DIRECTORY="/backup-data"
OFF_CLUSTER_BACKUP_TARGET_DIRECTORY="file:///nfs-storage/backups"
OFF_CLUSTER_BACKUP_NAME="my-backup"
OFF_CLUSTER_BACKUP_NUMBER_OF_FULL_BACKUPS_TO_KEEP="7"
```

### Manual backups

You can run a manual backup at any time by running `/off-cluster-backup.sh`. The result will be duplicity backups at `nfs-storage/backups`

### Backup restores

To restore backups run the duplicity command with the source and target reversed eg. Duplicity will understand that a restore is required

```bash
duplicity --allow-source-mismatch \
          --name="$OFF_CLUSTER_BACKUP_NAME" \
          --log-file /var/log/duplicity.log \
          "$OFF_CLUSTER_BACKUP_TARGET_DIRECTORY" "$OFF_CLUSTER_BACKUP_SOURCE_DIRECTORY"
```

A single file can be restored from the backup. List available files by running `duplicity list-current-files file:///nfs-storage/backups"`

Restore a single file by running the command below

```bash
duplicity restore --allow-source-mismatch \
          --name="$OFF_CLUSTER_BACKUP_NAME" \
          --log-file /var/log/duplicity.log \
          --file-to-restore /backup-data/my-database-backup.sql \
          "$OFF_CLUSTER_BACKUP_TARGET_DIRECTORY" "$OFF_CLUSTER_BACKUP_SOURCE_DIRECTORY"
```

### Verify backups

To verify the backup entegrity you can run the backup command with the verify arg eg.

```bash
./off-cluster-backup.sh verify
Verifying backups on file:///nfs-storage/backups .....
Local and Remote metadata are synchronized, no sync needed.
Last full backup date: Thu Dec 20 12:49:51 2018
```

### Delete old backups

The backup sript will automatically delete backups older than the `OFF_CLUSTER_BACKUP_RETENTION` variable.

You can manually do this by running

```bash
duplicity --allow-source-mismatch remove-older-than "1D" --force "$OFF_CLUSTER_BACKUP_TARGET_DIRECTORY"
```

### Backup collection status

The collection status of a backup can be found by running the off cluster command with the `collection-status` argument

```bash
/off-cluster-backup.sh collection-status
Getting collection status for backups on file:///nfs-storage/backups .....
Local and Remote metadata are synchronized, no sync needed.
Last full backup date: Thu Jan 10 09:49:20 2019
Collection Status
-----------------
Connecting with backend: BackendWrapper
Archive dir: /root/.cache/duplicity/fc682b7c8a64a29bcd24c8e05a9bba21

Found 1 secondary backup chain.
Secondary chain 1 of 1:
-------------------------
Chain start time: Wed Jan  9 12:27:39 2019
Chain end time: Thu Jan 10 02:16:28 2019
Number of contained backup sets: 1
Total number of contained volumes: 101
 Type of backup set:                            Time:      Num volumes:
                Full         Wed Jan  9 12:27:39 2019                101
-------------------------

Found primary backup chain with matching signature chain:
-------------------------
Chain start time: Thu Jan 10 09:49:20 2019
Chain end time: Thu Jan 10 09:49:20 2019
Number of contained backup sets: 1
Total number of contained volumes: 101
 Type of backup set:                            Time:      Num volumes:
                Full         Thu Jan 10 09:49:20 2019               101
-------------------------
No orphaned or incomplete backup sets found.
```