#!/bin/bash
#set -x
###########################################################
#
## (C) Copyright IBM Corp. 2014, 2022 All Rights Reserved
#
#
###########################################################
#

testResult() {
 printf "`date` RESULT=$1 for $2 \n"
 if [ $1 -ne 0 ]; then
    printf "`date` FAILED in $2 !!!!!!!!! \n" 
    printf "`date` ************************ \n"
    printf "`date`  log file: ${SCRIPTLOG} \n"
    exit 1;
 fi
}

####### Create / check backup Directory ####
create_dir(){
  DIR=$1
  NEW=$2

  if [ -d  "$DIR" ];then    
    if [ "${NEW}" == "Y" ];then 
      printf "`date` $DIR already exist, removing it \n" 
      rm -rf $DIR
      testResult $? "rm -rf $DIR"
    fi
  fi 
  mkdir -p "$DIR"
  testResult $? "mkdir -p $DIR"
  if [ "$(stat -c '%u' $DIR)" == `id -u` ] || [ `id -nu` == "root"  ];then
    chmod -R 775 $DIR
    testResult $? "chmod -R 775 $DIR"
  elif [ -w $DIR  ];then
    printf "`date` Permissions for $DIR cannot be modified but it is writable. Ignoring\n"
  else
    printf "`date` $DIR cannot be used for backup, directory is not writable. FAILED!!!!\n"
    exit 1;
  fi
}


prepare(){
  NODETOOL="nodetool -Dcom.sun.jndi.rmiURLParsing=legacy"
  printf "`date` NODETOOL=$NODETOOL \n"
  if [ "x${CASSANDRA_CLIENT_ENCRYPTION_ENABLED}" = "xtrue" ]; then
    CQLSH="cqlsh --ssl -u $USER -p $PASS"
    CQLSH_NO_PASS="cqlsh --ssl -u $USER -p XXXX"
  else
    CQLSH="cqlsh -u $USER -p $PASS"
    CQLSH_NO_PASS="cqlsh -u $USER -p XXXX"
  fi
  printf "`date` CQLSH=$CQLSH_NO_PASS \n"
  CASSANDRA_SERVER=`$NODETOOL describecluster |grep Name |awk  '{print $2}'`
  printf "`date` CASSANDRA_SERVER=$CASSANDRA_SERVER \n"
  get_all_keyspaces 
}

##### SCHEMA BACKUP
schema_backup(){
  printf "`date` SCHEMA BACKUP \n"  
  
  for KS in $KEYSPACES;do
    printf "`date` Take SCHEMA Backup for KEYSPACE $KS \n" 
    ${CQLSH} -e "DESC KEYSPACE  ${KS}" > ${BACKUP_SCHEMA_DIR}/${KS}_schema-${DATE_TIME}.cql  
    testResult $? "${CQLSH_NO_PASS} -e \"DESC KEYSPACE  ${KS}\" > ${BACKUP_SCHEMA_DIR}/${KS}_schema-${DATE_TIME}.cql"
  done
}

create_snapshots(){
  printf "`date` Begin create_snapshots for keyspaces $KEYSPACES"
  for KS in $KEYSPACES; do	
    printf "`date` Creating snapshots for keyspace $KS \n" 
    printf "`date` $NODETOOL snapshot -t $SNAPSHOT_NAME $KS \n" 

    $NODETOOL snapshot -t $SNAPSHOT_NAME $KS 
	testResult $? "$NODETOOL snapshot -t $SNAPSHOT_NAME $KS "
	
    #cd $DATA_DIR
    #testResult $? "cd $DATA_DIR"
    #tar -cf $BACKUP_SNAPSHOT_DIR/${KS}_${HOSTNAME}_${SNAPSHOT_NAME}.tar $KS/*/snapshots/$SNAPSHOT_NAME
    #testResult $? "tar -cf $BACKUP_SNAPSHOT_DIR/${KS}_${HOSTNAME}_${SNAPSHOT_NAME}.tar $KS/\*/snapshots/$SNAPSHOT_NAME"
  
    printf "`date` Snapshot for keyspace $KS copied in $BACKUP_SNAPSHOT_DIR \n " 
  done 
  
  
}

link_snapshots(){
  printf "`date` Begin link_snapshots for keyspaces $KEYSPACES"
  for KS in $KEYSPACES; do	
    printf "`date` Linking snapshots for keyspace $KS \n" 

    cd $DATA_DIR
    testResult $? "cd $DATA_DIR"
	
	for table in `ls $KS/` ; do 
	    if [ -d $DATA_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME ]; then
		mkdir -p $BACKUP_SNAPSHOT_DIR/$KS/$table/snapshots/
		testResult $? "mkdir -p $BACKUP_SNAPSHOT_DIR/$KS/$table/snapshots/"
		printf "`date` ln -s $DATA_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME $BACKUP_SNAPSHOT_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME" 
		ln -s $DATA_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME $BACKUP_SNAPSHOT_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME
		testResult $? "ln -s $DATA_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME $BACKUP_SNAPSHOT_DIR/$KS/$table/snapshots/$SNAPSHOT_NAME"
	    fi
	done
  
    printf "`date` Snapshot for keyspace $KS copied in $BACKUP_SNAPSHOT_DIR \n " 
  done 

}

#
##### Clear existing snapshots
clear_snapshots(){
 for KS in $KEYSPACES; do
  printf "`date` Remove old snapshots no longer needed for keyspace $KS \n"
  $NODETOOL clearsnapshot $KS
 done 
}

get_all_keyspaces(){
  ALL_KEYSPACES=$(${CQLSH} -e "DESC KEYSPACES" | sed '/^\s*$/d' | awk '{gsub("\r"," ");print}') 
  testResult $? "${CQLSH_NO_PASS} -e \"DESC KEYSPACES\" "
  count=0;
  if [ -z "${ALL_KEYSPACES}" ]; then
    printf "`date` #### No keyspace found !!! \n"
    return 1;
  else
     for KS in $ALL_KEYSPACES; do
     count=$((count+1));
     printf "`date`  KEYSPACE $count = $KS \n"
    done
  fi 
  printf "`date` ALL_KEYSPACES=${ALL_KEYSPACES} \n"
}

create_tar_file(){ 
 cd ${BACKUP_TEMP_DIR}
 testResult $? "cd ${BACKUP_TEMP_DIR}"
 local keyspace=`echo ${KEYSPACES}|sed 's/ /_KS_/g'`
 printf "`date` keyspace=$keyspace \n"
 local cass_prefix="cassandra_"
 TAR_FILE="${REMOTE_BACKUP_DIR}/${cass_prefix}${HOSTNAME}_KS_${keyspace}_date_${DATE_TIME}.tar"
 tar hcf - ${DATE_TIME} | pv -L ${TAR_SPEED_LIMIT} > ${TAR_FILE}
 testResult $? "tar hcf - ${DATE_TIME} | pv -L ${TAR_SPEED_LIMIT} > ${TAR_FILE}"
 
 
}

clean_backup_temp_dir(){
 rm -rf ${BACKUP_TEMP_DIR}
 testResult $? "rm -rf ${BACKUP_TEMP_DIR}"
} 

flush_keyspace(){
 $NODETOOL flush $1	
 testResult $? "$NODETOOL flush $1"
}

create_schema(){
 # Search if keyspace exist already 
 KEYSPACE_FOUND=1
 for ks in $ALL_KEYSPACES; do
    if [ "$ks" == ${KEYSPACE_TO_RESTORE} ]; then
       KEYSPACE_FOUND=0
    fi
 done    
 if [ $KEYSPACE_FOUND -eq 1 ]; then
   printf "`date` keyspace ${KEYSPACE_TO_RESTORE} does not exist, need to create it \n"
   printf "`date` find ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SCHEMA -type f -name \"${KEYSPACE_TO_RESTORE}_schema-${SNAPSHOT_DATE_TO_RESTORE}.cql\" | wc -l \n"
   COUNT=$(find ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SCHEMA -type f -name "${KEYSPACE_TO_RESTORE}_schema-${SNAPSHOT_DATE_TO_RESTORE}.cql" | wc -l)
   if [ $COUNT -eq 0 ]; then
     printf "`date` There is no schema file for keyspace ${KEYSPACE_TO_RESTORE} \n"
     exit 1;
   else  
     printf "`date` find ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SCHEMA -type f -name \"${KEYSPACE_TO_RESTORE}_schema-${SNAPSHOT_DATE_TO_RESTORE}.cql\" \n"	   
     SCHEMA_CQL_FILE=$(find ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SCHEMA -type f -name "${KEYSPACE_TO_RESTORE}_schema-${SNAPSHOT_DATE_TO_RESTORE}.cql")
     
     create_dir $CQL_PATH
     testResult $? "create_dir $CQL_PATH"
     cp $SCHEMA_CQL_FILE  $CQL_PATH 
     testResult $? " cp $SCHEMA_CQL_FILE  $CQL_PATH "
     BASENAME_SCHEMA_CQL_FILE=`ls $SCHEMA_CQL_FILE|awk -F '/' '{print $(NF)}'`
     printf "`date` Schema for keyspace ${KEYSPACE_TO_RESTORE} must be created using cqlsh and file $BASENAME_SCHEMA_CQL_FILE located in $CQL_PATH \n"
     $CQLSH -f  ${CQL_PATH}/${BASENAME_SCHEMA_CQL_FILE}
     testResult $? "$CQLSH_NO_PASS -f ${CQL_PATH}/${BASENAME_SCHEMA_CQL_FILE}"     
   fi  
 else
   printf "`date` Schema exits ... continue... \n"       
 fi
}

get_cfstats(){
 PREFIX=$1
 TARGET_DIR=$2
 KEYSPACE=$3
 OUTPUT_FILE1=${TARGET_DIR}/${PREFIX}_${HOSTNAME}_stats_${DATE_TIME}.log
 
 if [ -z $KEYSPACE ]; then
   printf "`date` Taking statistics of Cassandra node \n"     
 else
   printf "`date` Taking statistics of Cassandra keyspace $KEYSPACE \n" 
   OUTPUT_FILE2=${TARGET_DIR}/${KEYSPACE}_keys.txt 
 fi	 

 $NODETOOL cfstats $KEYSPACE > ${OUTPUT_FILE1}
 testResult $? "$NODETOOL cfstats $KEYSPACE >  ${OUTPUT_FILE1}"

 if [ -z $OUTPUT_FILE1 ] ;then
   printf "`date` statistics on entire node ... nothing to do \n"	 
 else
   create_key_result_file $OUTPUT_FILE1 $OUTPUT_FILE2 
   testResult $? "create_key_result_file ${OUTPUT_FILE1} ${OUTPUT_FILE2}"
 fi
}

cleanup(){
 clean_backup_temp_dir 
}

create_key_result_file(){
 input_filename=$1
 output_filename=$2

 touch $output_filename
 testResult $? "touch $output_filename"
 printf "CASSANDRA DATA \n" > $output_filename
 if [ -f $input_filename ]; then
   while read -r line_w1 line_w2 line_w3 line_w4 line_end
   do
     if [ "$line_w1" == "Table:" ]; then
       printf "$line_w1 $line_w2 ; " >> $output_filename
     fi
     if [ "$line_w1" == "Number" ] && [ "$line_w3" == "keys" ]; then
       printf "keys=$line_end \n" >> $output_filename
     fi
   done  < "$input_filename"
 else
   printf "`date` File $input_filename does not exist \n"
 fi
}

backup(){
 printf "`date` \n Starting Backup \n"
    cleanup
    testResult $? "cleanup"

    prepare 
    
    if [ "$KEYSPACE_TO_BACKUP" == "ALL" ]; then
      KEYSPACES=${ALL_KEYSPACES}   
    else
      KEYSPACES=${KEYSPACE_TO_BACKUP}	  
    fi
    printf "`date` KEYSPACES=${KEYSPACES} \n"

    create_dir $BACKUP_STATS_DIR 
    testResult $? "create_dir $BACKUP_STATS_DIR" 

    for KS in ${KEYSPACES} ;do
      printf "`date` KS=$KS \n"
      flush_keyspace $KS
      get_cfstats $KS $BACKUP_STATS_DIR $KS
    done 

    create_dir $BACKUP_SCHEMA_DIR 
    testResult $? "create_dir $BACKUP_SCHEMA_DIR"
    create_dir $BACKUP_SNAPSHOT_DIR 
    testResult $? "create_dir $BACKUP_SNAPSHOT_DIR" 
    create_dir $BACKUP_TEMP_DIR 
    testResult $? "create_dir $BACKUP_TEMP_DIR"
    create_dir $BACKUP_DIR 
    testResult $? "create_dir $BACKUP_DIR"
     
    
    schema_backup 
    testResult $? "schema_backup"
    
    clear_snapshots 
    create_snapshots 
    testResult $? "create_snapshots"
    
	link_snapshots
	
    create_tar_file 
    testResult $? "create_tar_file"

    printf "`date` BACKUP DONE SUCCESSFULLY !!! \n\n"
    cleanup
    testResult $? "cleanup"
}

find_backup(){
  printf "`date` SNAPSHOT_DATE_TO_RESTORE=$SNAPSHOT_DATE_TO_RESTORE \n"
   
  local cassandra_prefix="cassandra_"
  # Find the tar file for that cassandra server and that date
  if [ "${SNAPSHOT_DATE_TO_RESTORE}" == "latest" ];then
     printf "`date` Find latest snapshot for Keyspace: \"${KEYSPACE_TO_RESTORE}\" in  \"${REMOTE_BACKUP_DIR}\"\n"
     COUNT=$(find ${REMOTE_BACKUP_DIR} -type f -name "${cassandra_prefix}${BACKUP_HOSTNAME}_KS_*${KEYSPACE_TO_RESTORE}*" |wc -l)
     if [ $COUNT -eq 0 ]; then
       printf "`date` Backup File not found \n"
       exit 1;
     else      
       printf "`date` find ${REMOTE_BACKUP_DIR} -type f -name "${cassandra_prefix}${BACKUP_HOSTNAME}_KS_*${KEYSPACE_TO_RESTORE}*" -print0 |xargs -0 ls -ltr |tail -n 1 |awk -F '/' '{print \$(NF)}}' \n"	     
       local file=$(find ${REMOTE_BACKUP_DIR} -type f -name "${cassandra_prefix}${BACKUP_HOSTNAME}_KS_*${KEYSPACE_TO_RESTORE}*" -print0 |xargs -0 ls -ltr |tail -n 1 |awk -F '/' '{print $(NF)}')
       TAR_FILE=${REMOTE_BACKUP_DIR}/${file}
     fi
     
     SNAPSHOT_DATE_TO_RESTORE=`echo $TAR_FILE|sed 's/.*_date_//'|sed 's/\.tar//'`          
  else
     local tar_file_search=${cassandra_prefix}${BACKUP_HOSTNAME}_*KS_${KEYSPACE_TO_RESTORE}*_date_${SNAPSHOT_DATE_TO_RESTORE}.tar
     COUNT=$(find ${REMOTE_BACKUP_DIR} -type f -name "$tar_file_search" |wc -l)
     if [ $COUNT -eq 1 ]; then
       TAR_FILE=$(find ${REMOTE_BACKUP_DIR} -type f -name "$tar_file_search")
     else
       printf "`date` Backup file for Keyspace: \"${KEYSPACE_TO_RESTORE}\" for node \"${BACKUP_HOSTNAME}\" 
               for date \"${SNAPSHOT_DATE_TO_RESTORE}\" in \"${REMOTE_BACKUP_DIR}\" NOT FOUND ! \n"
       exit 1;
     fi  
  fi 
  printf "`date` SNAPSHOT_DATE_TO_RESTORE=$SNAPSHOT_DATE_TO_RESTORE \n"
  printf "`date` TAR_FILE=$TAR_FILE \n"
}

truncate_all_tables(){
 $CQLSH -e "SELECT table_name FROM system_schema.tables WHERE keyspace_name = '$KEYSPACE_TO_RESTORE'" \
  | sed -e '1,/^-/d' -e '/^(/d' -e '/^$/d' \
  | while read TAB; do
    printf "`date` Truncate table $TAB \n"
    $CQLSH -e "TRUNCATE $KEYSPACE_TO_RESTORE.$TAB"
    testResult $? "$CQLSH_NO_PASS -e \"TRUNCATE $KEYSPACE_TO_RESTORE.$TAB\""
 done
}

repair_keyspace(){
 $NODETOOL repair ${KEYSPACE_TO_RESTORE} 
}

clear_commit_log() {
  printf "`date` Clear Commit Logs \n"
  rm -rf ${DATA_DIR}/../commitlog/*
  testResult $? "rm -rf ${DATA_DIR}/../commitlog/*"    
}

extract_tarfile(){  
  cd ${BACKUP_TEMP_DIR}
  testResult $? "cd ${BACKUP_TEMP_DIR}"
    
  #--no-same-owner --no-same-permissions needed for if you're extracting onto a mounted dir without root permissions
  printf "`date` untar file ${TAR_FILE} \n"
  tar -xf ${TAR_FILE} --no-same-owner --no-same-permissions
  testResult $? "tar -xf ${TAR_FILE} --no-same-owner --no-same-permissions"
}

sstableloader_tables(){
  printf "`date`  Now trying to load snapshot tar file ${snasphot_tarfile} \n"
  SNAPSHOT_NAME="snp-${SNAPSHOT_DATE_TO_RESTORE}" 
  
  TABLES=`nodetool -Dcom.sun.jndi.rmiURLParsing=legacy cfstats ${KEYSPACE_TO_RESTORE} | grep "Table: " | sed -e 's+^.*: ++'`
  for TABLE in $TABLES; do
    echo "Loading table ${TABLE}"
    cd ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/${TABLE}-*
    testResult $? "cd ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/${TABLE}-*"
	printf "ls -ltr ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/\n"
	ls -ltr ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/
    if [ "`ls ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/ | wc -l`" -gt '0' ]; then
		mv ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/* ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/
		testResult $? "mv ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/* ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/"
		
		sstableloader -u $USER -pw $PASS -d $CASSANDRA_IP ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/
		testResult $? "sstableloader -d $CASSANDRA_IP ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/"
		
        echo "    Table ${TABLE} loaded."
    else
        echo "    >>> Nothing to loaded."
    fi   
    cd ${DATA_DIR}
    testResult $? "cd ${DATA_DIR}"
  done
  
}
 
restore_and_refresh_tables(){ 
  SNAPSHOT_NAME="snp-${SNAPSHOT_DATE_TO_RESTORE}" 

  TABLES=`nodetool -Dcom.sun.jndi.rmiURLParsing=legacy cfstats ${KEYSPACE_TO_RESTORE} | grep "Table: " | sed -e 's+^.*: ++'`
  for TABLE in $TABLES; do
    echo "Restore table ${TABLE}"
    ID=$(${CQLSH} -e "select id from system_schema.tables WHERE keyspace_name='${KEYSPACE_TO_RESTORE}' and table_name='$TABLE'"|egrep -vw "id|rows"|grep -v "\-\-\-"|grep .|sed s/" "*//g|sed s/"-"//g)
    testResult $? "${CQLSH_NO_PASS} -e \"select id from system_schema.tables WHERE keyspace_name='${KEYSPACE_TO_RESTORE}' and table_name='$TABLE'\""
    TABLEDIR="${TABLE}-${ID}"
    if [ ! -d "${DATA_DIR}/${KEYSPACE_TO_RESTORE}/$TABLEDIR" ]; then
      echo "Directory $TABLEDIR not found for ${TABLE} in ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/"
      echo "ls ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/"
      ls ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/
      echo
    else
      cd "${DATA_DIR}/${KEYSPACE_TO_RESTORE}/$TABLEDIR"
      testResult $? "cd ${DATA_DIR}/${KEYSPACE_TO_RESTORE}/$TABLEDIR"
      printf "ls -ltr ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/\n"
	ls -ltr ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/
      if [ "`ls ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/ | wc -l`" -gt '0' ]; then
        mv ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/* .
		testResult $? "mv ${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/SNAPSHOTS/${KEYSPACE_TO_RESTORE}/${TABLE}-*/snapshots/${SNAPSHOT_NAME}/* ."
		
		nodetool -Dcom.sun.jndi.rmiURLParsing=legacy refresh ${KEYSPACE_TO_RESTORE} ${TABLE}
		testResult $? "nodetool -Dcom.sun.jndi.rmiURLParsing=legacy  refresh ${KEYSPACE_TO_RESTORE} ${TABLE}"
        echo "    Table ${TABLE} restored."
      else
        echo "    >>> Nothing to restore."
      fi
    fi
    cd ${DATA_DIR}
    testResult $? "cd ${DATA_DIR}"
  done
}

check_restore(){
RESTORED_FILE=${BACKUP_STATS_DIR}/${KEYSPACE_TO_RESTORE}_keys.txt # after_restore
EXPECTED_FILE=${BACKUP_TEMP_DIR}/${SNAPSHOT_DATE_TO_RESTORE}/STATS/${KEYSPACE_TO_RESTORE}_keys.txt # in restore tar file, expected

printf "`date` Comparing $RESTORED_FILE to $EXPECTED_FILE\n"
DIFF_RESULT=$(diff -s $RESTORED_FILE $EXPECTED_FILE|grep -c "identical")


printf "`date` \nEXPECTING: \n"
cat $EXPECTED_FILE
printf "`date` \nRESTORED: \n"
cat $RESTORED_FILE 

if [ $DIFF_RESULT -ne 1 ]; then
  printf "`date` \nKeyspace not containing the number of keys expected \n"
  exit 1;
else
  printf "`date` \nFiles are identical. Restore successful!!! \n"
fi
}

restore(){

  cleanup
  prepare

  create_dir $BACKUP_TEMP_DIR 
  testResult $? "create_dir $BACKUP_TEMP_DIR"

  find_backup 
  testResult $? "find backup"

  extract_tarfile 
  testResult $? "extract_tarfile"

  create_schema
  testResult $? "create Schema"

  create_dir $BACKUP_STATS_DIR 
  testResult $? "create_dir $BACKUP_STATS_DIR" 
  get_cfstats "before_restore" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}
  testResult $? "get_cfstats \"before_restore\" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}"  

  printf "`date` Starting Restore \n"  

  truncate_all_tables
  testResult $? "truncate tables"  

  repair_keyspace
  testResult $? "repair keyspace"

  clear_commit_log 
  testResult $? "clear_commit_log"

  restore_and_refresh_tables
  testResult $? "restore_and_refresh_tables"

  get_cfstats "after_restore" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}
  testResult $? "get_cfstats \"after_restore\" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}"

  check_restore

  cleanup
  testResult $? "cleanup"

  printf "`date` RESTORE DONE !!!\n\n"
}

restore_sstableloader(){
  printf "`date` RESTORING WITH SSTABLELOADER"
  
  cleanup
  prepare

  create_dir $BACKUP_TEMP_DIR 
  testResult $? "create_dir $BACKUP_TEMP_DIR"

  find_backup 
  testResult $? "find backup"

  extract_tarfile 
  testResult $? "extract_tarfile"  
  
  create_schema
  testResult $? "create Schema"
  
  create_dir $BACKUP_STATS_DIR 
  testResult $? "create_dir $BACKUP_STATS_DIR" 
  get_cfstats "before_restore" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}
  testResult $? "get_cfstats \"before_restore\" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}"  
  
  printf "`date` Starting Restore \n"  
  sstableloader_tables
  testResult $? "sstableloader_tables" 
  
  get_cfstats "after_restore" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}
  testResult $? "get_cfstats \"after_restore\" ${BACKUP_STATS_DIR} ${KEYSPACE_TO_RESTORE}"

  check_restore

  cleanup
  testResult $? "cleanup"

  printf "`date` RESTORE DONE !!!\n\n"
  
}

test_force(){
 if [ "${FORCE}" == "Y" ]; then
   ok=0
 else
   printf "`date` ************************************ \n"
   printf "`date`  Do you want to continue (y/n) ? \n"
   read ans

   #ans=$(tr '[:upper:]' '[:lower:]'<<<$ans)
   ok=1

   if [[ "$ans" == "y"  ||  "$ans" == "yes"  ]]; then
     ok=0
   fi
 fi

 testResult $ok "Read answer" 
}
