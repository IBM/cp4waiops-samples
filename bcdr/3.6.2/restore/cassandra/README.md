# Restoring the Cassandra database for IBM Cloud Pak for Watson AIOps

Follow the steps to restore Cassandra database for IBM Cloud Pak for Watson AIOps

### Perform restore  process for Cassandra

   We have automated the stpes for Cassandra restore. There is a main script `cassandra-restore.sh` at path `bcdr/restore/cassandra/scripts` which includes all the required steps for restore of Cassandra.
 
   1. We need to run only script `cassandra-restore.sh` to perform restore of Cassandra databse in IBM Cloud Pak for Watson AIOps.
      `./cassandra-restore.sh`
   2. `cassandra-keyspace.json` has the information of the keysspaces of Cassandra and restore operation will run for those keyspaces. So `cassandra-restore.sh` scipt takes keyspaces information from this file.
   3. `backup-timestamp.json` has the information on backup timespamp. It means which backup as per timestamp needs to be restored.


   ### Following are the steps which are being performed and automated by this script, `cassandra-restore.sh`.
   
   1. Scale down the Agile Service Manager pods.
   2. Trigger restore for the Cassandra keyspaces mentioned in `cassandra-keyspace.json`.
   3. Scale up the Agile Service Manager pod to the original level.
      


**Notes**:

- For more details on Cassandra restore, please check [Cassandra restore](https://www.ibm.com/docs/en/noi/1.6.3?topic=restore-restoring-database-data-ocp#t_asm_ocp_restoringdbdata_procedure) document.
