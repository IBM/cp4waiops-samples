IBM Confidential

5737-M96

(C) Copyright IBM Corporation 2021-2023 All Rights Reserved.

# Backing up  Cassandra database for IBM Cloud Pak for Watson AIOps

Follow the steps to back up Cassandra database for IBM Cloud Pak for Watson AIOps.


### Perform back up process for Cassandra

   We have automated the stpes for Cassandra backup. There is a main script `cassandra-backup.sh` at path `bcdr/backup/cassandra/scripts` which includes all the required steps for taking backup of Cassandra. 
   
   1. We need to run only script `cassandra-backup.sh` to take backup of Cassandra databse in IBM Cloud Pak for Watson AIOps.
      `./cassandra-backup.sh`
   2. `.cassandra-keyspace.json` has the information of the keysspaces of Cassandra, which will be cleaned and backup will run for those keyspaces. So `cassandra-backup.sh` scipt takes keyspaces information from this file.
   
   
   
   
   ### Following are the steps which are being performed and automated by this script, `cassandra-backup.sh`.
   
   1. Scale down the Agile Service Manager pods.
   2. Run a cleanup on all keyspaces mentioned in `.cassandra-keyspace.json` on Cassandra instances.
   3. Trigger Cassandra backup for keyspaces on Cassandra instances.
   4. Scale up the Agile Service Manager pod to the original level.
      


**Notes**:

- For more details on Cassandra backup, please check [Cassandra backup](https://www.ibm.com/docs/en/noi/1.6.3?topic=restore-backing-up-database-data-ocp#t_asm_ocp_backingupdbdata) document.
