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
1. Copy `geo_config.env.template` to `geo_config.env` and fill it out with the required information for both clusters (API endpoints, tokens, namespaces, etc.). This file can be saved outside of the repository.

**Note:** if the `cpadmin` user is unavailable, uncomment `PRIMARY_ACCESS_TOKEN` and `BACKUP_ACCESS_TOKEN` and follow the instructions https://www.ibm.com/docs/en/concert-operate/5.1.0?topic=apis-accessing#key__title__1 to get the access token for your username. This username requires administrative privelages in the cluster to write topology or policy changes. An example of getting the two access tokens can be found in [Example For Getting JWT Tokens](#example-for-getting-jwt-tokens)


1. Run `./setupMultiCluster.sh` to enable multi-cluster support and perform the necessary token, secret, and encryption key exchanges.

**Examples:**
```bash
./setupMultiCluster.sh                                    # Use default config. Looks for geo_config.env in the current directory
./setupMultiCluster.sh --config ~/clusters/geo_config.env # Example custom config path
```

### Optional: Replicate Policies

The export and import scripts support specifying which cluster to use and which config file to load using command-line flags.

3. **Export policies** from a cluster:
   ```bash
   ./exportPolicy.sh [OPTIONS]
   ```
   
   **Options:**
   - `--cluster CLUSTER` - Specify cluster: primary (default) or backup
   - `--config FILE` - Path to config file (default: ./geo_config.env)
   
   **Examples:**
   ```bash
   ./exportPolicy.sh                                                # Export from primary cluster
   ./exportPolicy.sh --cluster backup                               # Export from backup cluster
   ./exportPolicy.sh --config /path/to/config.env --cluster backup  # Use custom config
   ```

4. **Import policies** to a cluster:
   ```bash
   ./importPolicy.sh [OPTIONS]
   ```
   
   **Options:**
   - `--cluster CLUSTER` - Specify cluster: backup (default) or primary
   - `--config FILE` - Path to config file (default: ./geo_config.env)
   
   **Examples:**
   ```bash
   ./importPolicy.sh                                                 # Import to backup cluster
   ./importPolicy.sh --cluster primary                               # Import to primary cluster
   ./importPolicy.sh --config /path/to/config.env --cluster primary  # Use custom config
   ```

### Optional: Replicate Topology

The topology export and import scripts also support cluster and config file specification.

5. **Export topology** from a cluster:
   ```bash
   ./exportTopology.sh [OPTIONS]
   ```
   
   **Options:**
   - `--cluster CLUSTER` - Specify cluster: primary (default) or backup
   - `--config FILE` - Path to config file (default: ./geo_config.env)
   
   **Examples:**
   ```bash
   ./exportTopology.sh                                                # Export from primary cluster
   ./exportTopology.sh --cluster backup                               # Export from backup cluster
   ./exportTopology.sh --config /path/to/config.env --cluster backup  # Use custom config
   ```

6. **Import topology** to a cluster:
   ```bash
   ./importTopology.sh [OPTIONS] [FILE]
   ```
   
   **Options:**
   - `--cluster CLUSTER` - Specify cluster: backup (default) or primary
   - `--config FILE` - Path to config file (default: ./geo_config.env)
   
   **Arguments:**
   - `FILE` - Path to topology export file (default: topology-export.json)
   
   **Examples:**
   ```bash
   ./importTopology.sh                                                       # Import to backup from topology-export.json
   ./importTopology.sh my-topology.json                                      # Import to backup from my-topology.json
   ./importTopology.sh --cluster primary                                     # Import to primary from topology-export.json
   ./importTopology.sh --cluster primary my-topology.json                    # Import to primary from my-topology.json
   ./importTopology.sh --config ~/clusters/geo_config.env --cluster primary  # Use custom config
   ```

### Failover and Failback Operations

The state of the clusters can be changed using the scripts below. Both scripts support the `--config` flag for custom configuration files.

**Failover** (Primary goes to Standby, Backup becomes Active):
```bash
./failover.sh                                    # Use default config
./failover.sh --config ~/clusters/geo_config.env # Use custom config
```

**Failback** (Primary becomes Active, Backup goes to Standby):
```bash
./failback.sh                                    # Use default config
./failback.sh --config ~/clusters/geo_config.env # Use custom config
```

### Common Disaster Recovery Scenarios

**Scenario 1: Normal replication from Primary to Backup**
```bash
# Export from primary (default), import to backup (default)
./exportPolicy.sh
./importPolicy.sh

./exportTopology.sh
./importTopology.sh
```

**Scenario 2: After failover, replicate changes back to Primary**

When the backup cluster has been promoted to active and you need to replicate data back to the restored primary cluster:

```bash
# Export from backup (now active), import to primary
./exportPolicy.sh --cluster backup
./importPolicy.sh --cluster primary

./exportTopology.sh --cluster backup
./importTopology.sh --cluster primary
```

**Scenario 3: Using custom config files**

If you have multiple environment configurations:

```bash
# Export from production backup cluster
./exportPolicy.sh --config ~/clusters/geo_config.env --cluster backup

# Import to staging primary cluster
./importPolicy.sh --config ~/clusters/geo_config.env --cluster primary
```

## Important Notes

- **Configuration File Location**: By default, scripts look for `geo_config.env` in the current directory. To use a config file in a different location (e.g., stored outside this repository for security), set the `GEO_CONFIG_FILE` environment variable:
  ```bash
  export GEO_CONFIG_FILE=~/clusters/geo_config.env
  ./setupMultiCluster.sh
  ```
- **Hardcoded Tenant ID**: The topology export/import scripts use a hardcoded X-TenantID (`cfd95b7e-3bc7-4006-a4a8-a73a79c71255`). You may need to update this value in `exportTopology.sh` and `importTopology.sh` if your environment uses a different tenant ID.
- **Policy Script Dependencies**: The policy scripts depend on Python scripts located at `../../replicate-policies-scripts/v1/`. Ensure these scripts are available before running policy export/import operations.
- **Token Expiration**: The tokens configured in `geo_config.env` may expire. The `geo_config.env` needs to be updated with the new token. For example, calling `oc whoami -t` to get the new token.

## Example For Getting JWT Tokens
Follow the instructions: https://www.ibm.com/docs/en/concert-operate/5.1.0?topic=apis-accessing#key__title__1 to get the API key:

```bash
PRIMARY_CLUSTER_CPD_ENDPOINT=https://cpd-katamari.concert-op-west.cp.acme.ibm.com
PRIMARY_API_KEY=API_KEY
PRIMARY_ADMIN_USER=admin@example.ibm.com

PRIMARY_CLUSTER_TOKEN=$(curl -k -X POST "${PRIMARY_CLUSTER_CPD_ENDPOINT}/icp4d-api/v1/authorize" \
  -H 'Content-Type: application/json' \
  -d "{\"username\": \"${PRIMARY_ADMIN_USER}\", \"api_key\": \"${PRIMARY_API_KEY}\"}" | jq -r '.token')
```

Put `PRIMARY_CLUSTER_TOKEN` into `geo_config.env` file.


```bash
BACKUP_CLUSTER_CPD_ENDPOINT=https://cpd-katamari.concert-op-west.cp.acme.ibm.com
BACKUP_API_KEY=API_KEY
BACKUP_ADMIN_USER=admin@example.ibm.com

BACKUP_CLUSTER_TOKEN=$(curl -k -X POST "${BACKUP_CLUSTER_CPD_ENDPOINT}/icp4d-api/v1/authorize" \
  -H 'Content-Type: application/json' \
  -d "{\"username\": \"${BACKUP_ADMIN_USER}\", \"api_key\": \"${BACKUP_API_KEY}\"}" | jq -r '.token')
```

Put `BACKUP_CLUSTER_TOKEN` into `geo_config.env` file.

