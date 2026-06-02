# Geo-Redundancy Sample Scripts

Scripts to support geo-reundancy

## Instructions
1. Fill out the config.env file with the required information for both clusters.
2. Run setupMultiCluster.sh to enable multi-cluster support and perform the necessary token, secret, and encryption key exchanges.
3. If policies need to be replicated, run exportPolicy.sh. Then run importPolicy.sh to import the policies into the backup cluster.
4. If topology needs to be replicated, run exportTopology.sh. Then run importTopology.sh to import the topology into the backup cluster.

For a failover scenario, where the Primary goes into Standby and the Backup clsuter becomes Active, run the following commands:
failover.sh

For a failback secnario, where the Primary goes back to being Active and the Backup cluster becomes Standby, run the following commands:
failback.sh