#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

#set -x

print_help() {
    echo Missing argumentablespace. Should be like:
    echo $0 \$type \$database_name 
    echo The type is either backup or restore
    echo Exit ...
    exit -1
}

initialize_backup_folder() {
    mkdir -p /backup/$1 2>/dev/null && echo /backup/$1 && return 0
    mkdir -p $HOME/backup/$1 2>/dev/null && echo $HOME/backup/$1 && return 0
    return -1
}

backup_data() {
    host=$POSTGRES_HOST
    port=$POSTGRES_PORT
    dbname=$1
    user=$POSTGRES_USERNAME
    passfile=$HOME/passfile
    export PGPASSFILE=$passfile
    echo $host:$port:$dbname:$user:$POSTGRES_PASSWORD > $passfile
    chmod go-rwx $HOME/passfile
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    pg_dump -F c -f $backup_folder/${dbname}_$TIMESTAMP.dmp  -C -h $host -p $port -U $user $dbname
    cp $backup_folder/${dbname}_$TIMESTAMP.dmp $backup_folder/$dbname.dmp
    return $?
}

delete_old_files() {
    dir=$1
    reservednum=$2
    date=$(date "+%Y%m%d-%H%M%S")
    filenum=$(ls -l $dir|grep ^- |wc -l)
    while(( $filenum > $reservednum))
    do
        oldfile=$(ls -rt $dir | head -1)
        echo  $date "Delete File:"$oldfile
        rm -rf $dir/$oldfile
        let "filenum--"
    done 
}

restore_data() {
    host=$POSTGRES_HOST
    port=$POSTGRES_PORT
    dbname=$1
    user=$POSTGRES_USERNAME
    passfile=$HOME/passfile
    export PGPASSFILE=$passfile
    echo $host:$port:$dbname:$user:$POSTGRES_PASSWORD > $passfile
    chmod go-rwx $HOME/passfile
    pg_restore -F c -h $host -p $port -U $user -d $dbname -c -O $backup_folder/$dbname.dmp
    return $?
}

[ -z "$1" ] && print_help
[ -z "$2" ] && print_help

type=$1
dbname=$2
backup_folder=$(initialize_backup_folder $dbname)
[ -z "$backup_folder" ] && echo Failed to initialize the backup folder for database $dbname, exit ... && exit -1

if [ "$type" == "backup" ]; then
    delete_old_files $backup_folder 5
    backup_data $dbname
    result=$?
    if  [ "$result" == "0" ]; then
      echo "Backup database success"
    else
      echo "Backup database failed"
    fi
    exit $result
elif [ "$type" == "restore" ]; then
    restore_data $dbname
    result=$?
    if  [ "$result" == "0" ]; then
      echo "Restore database success."
    else
      echo "Restore database failed."
    fi
    exit $result
else
  print_help
  exit -1
fi
