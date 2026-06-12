# Geo-Redundancy Sample Scripts

Scripts to support geo-redundancy for IBM Concert Operate.

## Prerequisites

Before using these scripts, ensure you have the following tools installed:
- `oc` CLI (OpenShift CLI)
- `curl`
- `jq` (JSON processor)
- `aiopsctl` (version 5.1.0 or later)
- Python 3.x (for policy replication scripts)

## Instructions

### Initial Setup
1. Fill out the `geo_config.env` file with the required information for both clusters (API endpoints, tokens, namespaces, etc.).
2. Run `./setupMultiCluster.sh` to enable multi-cluster support and perform the necessary token, secret, and encryption key exchanges.

### Optional: Replicate Policies
3. If policies need to be replicated, run `./exportPolicy.sh` to export policies from the Primary cluster.
4. Then run `./importPolicy.sh` to import the policies into the Backup cluster.

### Optional: Replicate Topology
5. If topology needs to be replicated, run `./exportTopology.sh` to export topology from the Primary cluster.
6. Then run `./importTopology.sh` to import the topology into the Backup cluster.

### Failover and Failback Operations

The state of the clusters can be changed using the scripts below:

**Failover** (Primary goes to Standby, Backup becomes Active):
```bash
./failover.sh
```

**Failback** (Primary becomes Active, Backup goes to Standby):
```bash
./failback.sh
```

## Important Notes

- **Hardcoded Tenant ID**: The topology export/import scripts use a hardcoded X-TenantID (`cfd95b7e-3bc7-4006-a4a8-a73a79c71255`). You may need to update this value in `exportTopology.sh` and `importTopology.sh` if your environment uses a different tenant ID.
- **Policy Script Dependencies**: The policy scripts depend on Python scripts located at `../../replicate-policies-scripts/v1/`. Ensure these scripts are available before running policy export/import operations.
- **Token Expiration**: The tokens configured in `geo_config.env` may expire. The `geo_config.env` needs to be updated with the new token. For example, calling `oc whoami -t` to get the new token.

