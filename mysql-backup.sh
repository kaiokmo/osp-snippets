#!/usr/bin/env bash

BACKUP_DIR="/scratch/backups"
BACKUP_SUFFIX="mysql.dump"

BACKUP_NUM=10
USER_REMOTE=root
HOSTNAME=<HOSTNAME FQDN>

exec 1> >(logger -t $(basename $0)) 2>&1

hostGetList() {
    FULLDOMAIN=$(ssh $USER_REMOTE@$HOSTNAME "hostname -d")
    while IFS="" read -r LINE || [ -n "$LINE" ]; do
        echo $LINE.$FULLDOMAIN
    done <<< $(ssh $USER_REMOTE@$HOSTNAME "pcs status |grep -E 'heartbeat:galera.*Master'|awk '{print \$NF}'")
}

hostGetListAnsible() {
    while IFS="" read -r LINE || [ -n "$LINE" ]; do
        echo $LINE |xargs
    done <<< $(ansible --list-hosts $SECTION_HOSTS 2>/dev/null | tail -n +2)
}

dbActiveMasterGet() {
    while IFS="" read -r HOST_REMOTE || [ -n "$HOST_REMOTE" ]; do
        PODNAME=$(ssh $USER_REMOTE@$HOST_REMOTE "(podman ps --filter 'name=galera' --format '{{.Names}}')")
        OUTPUT=$(ssh  $USER_REMOTE@$HOST_REMOTE "(podman exec -it $PODNAME bash -c \"mysql -e \\\"show variables like 'wsrep_node_name'\\\" --batch --disable-column-names\")" 2>/dev/null)
        OUTPUT=${OUTPUT//$'\r'/}                 # Removing excess chars '\r' from output
        if [ "$OUTPUT" != "" ]; then
            echo $(echo $OUTPUT | awk '{ print $2 }')
            return
        fi
    done <<< "$1"
}
 
dbSelectAvailable() {
    MASTER=$1
    LIST=$2

    while IFS="" read -r HOST_NAME || [ -n "$HOST_NAME" ]; do
        if [ "$HOST_NAME" != "$MASTER" ]; then
            echo $HOST_NAME
            return
        fi 
    done <<< "$LIST"
}

dbDumpDatabase() {
    HOST_NAME=$1
    FILE_DEST=$BACKUP_DIR/$BACKUP_SUFFIX.$(date "+%Y-%m-%d.%H-%M").gz
    PODNAME=$(ssh $USER_REMOTE@$HOST_NAME "(podman ps --filter 'name=galera' --format '{{.Names}}')")
    ssh $USER_REMOTE@$HOST_NAME "(podman exec -it $PODNAME bash -c \"mysqldump --all-databases | gzip -9 | base64 -w 0\")" | base64 -w 0 -d > $FILE_DEST
    echo "- Dump created      $FILE_DEST"
}

cleanOldBackups() {
    echo "- Cleaning old backups (more than $BACKUP_NUM backups ago)"
    while IFS="" read -r BACKUP_NAME || [ -n "$BACKUP_NAME" ]; do
        if [ "$BACKUP_NAME" != "" ]; then
            echo "    . $BACKUP_NAME"
            rm -f $BACKUP_NAME
        fi
    done <<< "$(ls -1r $BACKUP_DIR/$BACKUP_SUFFIX.* | tail -n +$(($BACKUP_NUM+1)))"
}

printHelp() {
    echo "Usage: $0 [OPTION...]"
    echo -e "    Backup MySQL database on first available (but non active) host\n"
    echo "    -H HOST        Controlplane where <pcs> utility is  [default: $HOSTNAME]"
    echo "    -B BACKUP_DIR  Backup directory  [default: $BACKUP_DIR]"
    echo "    -U USER        Used account for backup operations  [default: $USER_REMOTE]"
    echo "    -N Number      Number of backups to keep, older files will be deleted  [default: $BACKUP_NUM]"
    echo ""
    exit 0
}

while getopts ":hH:B:U:N:" option; do
    case $option in
        H)  HOSTNAME=$OPTARG;;
        B)  BACKUP_DIR=$OPTARG;;
        U)  USER_REMOTE=$OPTARG;;
        N)  BACKUP_NUM=$OPTARG;;
        h)  printHelp;;
        \?) printHelp;;
        :)  "Option -$OPTARG requires an argument"
            exit 1;;
    esac
done

echo "- Getting host list"
HOST_LIST=$(hostGetList)
if [ "$HOST_LIST" == "" ]; then
    echo "host list is empty"
    exit 1
fi

HOST_MASTER=$(dbActiveMasterGet "$HOST_LIST")
echo "- Current master    $HOST_MASTER"
if [ "$HOST_MASTER" == "" ]; then
    echo "cannot detect master db"
    exit 1
fi

HOST_AVAILABLE=$(dbSelectAvailable "$HOST_MASTER" "$HOST_LIST")
echo "- Selected host     $HOST_AVAILABLE"
if [ "$HOST_AVAILABLE" == "" ]; then
    echo "cannot get an available host from list"
    exit 1
fi

dbDumpDatabase "$HOST_AVAILABLE"
echo "- Operation completed"
cleanOldBackups

