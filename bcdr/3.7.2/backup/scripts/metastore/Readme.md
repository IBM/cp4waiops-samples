© Copyright IBM Corp. 2020, 2022

# Metastore backup

- Backup is delivered using backup approach explained in following git [issue](https://github.ibm.com/PrivateCloud-analytics/zen-dev-test-utils/blob/gh-pages/docs/zen-metastoredb.md#5-metastoredb--backup--restore-options-for-cloudpaks) 
  
- `zen_backup.sql` file will be generated using steps described above
  
- This sql file will be moved to a different POD with mounted volumes
  ```    
    Using single command, but requires tar to be installed in both the container
    oc exec zen-metastoredb-0 -- tar cf - /user-home/zen-metastoredb-backup | oc exec -i backup-metastore -- tar xvf - -C /usr/share/backup/
  ```
- Data will be moved outside the cluster using velero and restic plugin
