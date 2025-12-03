# PostgreSQL Migration Issue Resolution (DT457312)

### this is to resolve the error shown here:
```
..."msg":"Could not create migration superuser","error":"failed to connect to PostgreSQL: cannot parse `host=.noi.svc port= user=postgres password=xxxxx dbname=postgres`: invalid port (strconv.ParseUint: parsing \"user=postgres\": invalid syntax)"...
```

### Root Cause
Older PostgreSQL versions lack certain parameters required for migration. Systems progressively upgraded from these versions retain outdated secrets without the necessary parameters, causing migration failures.

### Users impacted 
Any user who's initial install of the product was version 1.6.11 or earlier.

To resolve this we need to update the secret with the missing parameters and restart the migration.

## Update the postgres superuser secret with the missing values
These steps will vary slightly depending on the type of install, replace anything within `< >` with the appropriate values.



1. Update the postgres superuser secret with the missing values using the `update_superuser_secret.sh` script.

1. **Scale down the NOI operator**
   ```bash
   oc patch deployment noi-operator \
     -n <NOI_OPERATOR_NAMESPACE> \
     -p '{"spec":{"replicas":0}}'
     ```
1. Delete the postgres v17 cluster (⚠️ **WARNING**: ensure not to delete **non**-v17 cluster as it will cause loss of data)
    - Show the cluster names: 
    ```
    oc get clusters.postgresql.k8s.enterprisedb.io \
        -n <POSTGRE_CLUSTER_NAMESPACE> | grep "v17"
    ```
    - Use the cluster name in the below command:
    ```
    oc delete clusters.postgresql.k8s.enterprisedb.io \
        -n <POSTGRE_CLUSTER_NAMESPACE> <CLUSTER_NAME>
    ```
    - A finalizer will likely prevent its deletion, if this happens delete the finalizer and try again. You will need to exit the delete command (i.e ctrl^C) 
    ```
    oc edit clusters.postgresql.k8s.enterprisedb.io \
        -n <POSTGRE_CLUSTER_NAMESPACE> <CLUSTER_NAME>
    ```
    - Delete the line following `finalizers:` it should be similar to `- noi.postgres/finalizer`

1. Verify postgres v17 Cluster, Pods, PVCs are deleted

1. Update the NOI instance to increase the migration timeout, this may need to be quite long as the timer may not get reset so it will need to include all the time that has passed since upgrade started. The value provided here (i.e 10080) is equivalent to 1 week, if after these steps the migration fails with timeout errors, try increasing the value.
    ```
    oc patch <noi/noihybrid> <RELEASE_NAME> \
        -n <NOI_INSTANCE_NAMESPACE> --type=merge \
        -p '{"spec":{"helmValuesNOI":{"global.postgresql.migrationTimeoutMinutes":"10080"}}}'
    ```
1. Scale the operator back up 
    ```
    oc patch deployment noi-operator \
        -n <NOI_OPERATOR_NAMESPACE> -p '{"spec":{"replicas":1}}'
    ```


## Conclusion
At this point the migration should be running. You can tail the noi-operator logs to see the progress of the migration. Grepping for the `postgresMigrationStatusKeyV17` key will highlight the migration progress.