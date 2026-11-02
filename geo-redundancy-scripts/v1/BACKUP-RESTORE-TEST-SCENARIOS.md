# Backup and Restore Execution Test Scenarios & Flag Reference

This document records the execution results for multiple backup and restore scenarios and flags tested using [`backup.sh`](backup.sh) and [`restore.sh`](restore.sh).

---

## Environment & Configuration

- **Configuration File**: `/path/to/geo_config.env`
- **Primary Cluster**: `primary-cluster` (`https://api.primary-cluster.example.com:6443`) / Namespace: `cp4waiops`
- **Backup Cluster**: `backup-cluster` (`https://api.backup-cluster.example.com:6443`) / Namespace: `cp4waiops`
- **Execution Date**: 2026-11-02

---

## Table of Contents

- [Backup Flags Matrix & Scenarios](#backup-flags-matrix--scenarios)
  - [Flag 1: `--help` / `-h` (Display Usage)](#flag-1---help---h-display-usage)
  - [Flag 2: `--list-resources` (List Resource IDs)](#flag-2---list-resources-list-resource-ids)
  - [Flag 3: `--cluster` (`primary` vs `backup` vs Invalid Argument)](#flag-3---cluster-primary-vs-backup-vs-invalid-argument)
  - [Flag 4: `--config` (Custom Path vs Missing Path)](#flag-4---config-custom-path-vs-missing-path)
  - [Flag 5: `--output` (Custom Directory vs Default Timestamped vs Missing Path)](#flag-5---output-custom-directory-vs-default-timestamped-vs-missing-path)
  - [Flag 6: `--include` (Single Resource vs Multi-Resource vs Missing Argument)](#flag-6---include-single-resource-vs-multi-resource-vs-missing-argument)
  - [Flag 7: `--exclude` (Single / Multi Exclusion vs Empty Set Error)](#flag-7---exclude-single--multi-exclusion-vs-empty-set-error)
  - [Flag 8: Mutual Exclusion Conflict (`--include` with `--exclude`)](#flag-8-mutual-exclusion-conflict---include-with---exclude)
  - [Flag 9: `--debug` (Verbose Diagnostics)](#flag-9---debug-verbose-diagnostics)
- [Standalone Single-Flag Backup Scenarios](#standalone-single-flag-backup-scenarios)
  - [Scenario A1: Only `--cluster` Flag Provided (`--cluster backup`)](#scenario-a1-only---cluster-flag-provided---cluster-backup)
  - [Scenario A2: Only `--cluster` Flag Provided (`--cluster primary`)](#scenario-a2-only---cluster-flag-provided---cluster-primary)
  - [Scenario A3: Only `--output` Flag Provided](#scenario-a3-only---output-flag-provided)
  - [Scenario A4: Only `--config` Flag Provided](#scenario-a4-only---config-flag-provided)
- [Comprehensive Multi-Flag Backup Scenarios](#comprehensive-multi-flag-backup-scenarios)
  - [Scenario A: Full Backup (Primary Cluster, Explicit Flags)](#scenario-a-full-backup-primary-cluster-explicit-flags)
  - [Scenario B: Selective Backup with `--include` (Primary Cluster)](#scenario-b-selective-backup-with---include-primary-cluster)
  - [Scenario C: Selective Backup with `--exclude` (Primary Cluster)](#scenario-c-selective-backup-with---exclude-primary-cluster)
  - [Scenario D: Backup from Backup Cluster with Selection](#scenario-d-backup-from-backup-cluster-with-selection)
- [Restore Flags Matrix & Scenarios](#restore-flags-matrix--scenarios)
  - [Flag R1: `--help` / `-h` (Display Usage)](#flag-r1---help---h-display-usage)
  - [Flag R2: `--list-resources` (List Resource IDs)](#flag-r2---list-resources-list-resource-ids)
  - [Flag R3: `--cluster` (`backup` vs `primary` vs Invalid Argument)](#flag-r3---cluster-backup-vs-primary-vs-invalid-argument)
  - [Flag R4: `--config` (Custom Path vs Missing Path)](#flag-r4---config-custom-path-vs-missing-path)
  - [Flag R5: `BACKUP_DIR` (Explicit Path vs Default Newest vs Non-existent Dir Error)](#flag-r5-backup_dir-explicit-path-vs-default-newest-vs-non-existent-dir-error)
  - [Flag R6: `--include` (Single Resource vs Non-Default Resource vs Missing Argument)](#flag-r6---include-single-resource-vs-non-default-resource-vs-missing-argument)
  - [Flag R7: `--exclude` (Single / Multi Exclusion vs Empty Set Error)](#flag-r7---exclude-single--multi-exclusion-vs-empty-set-error)
  - [Flag R8: Mutual Exclusion Conflict (`--include` with `--exclude`)](#flag-r8-mutual-exclusion-conflict---include-with---exclude)
- [Standalone Single-Flag Restore Scenarios](#standalone-single-flag-restore-scenarios)
  - [Scenario R1: Default Restore (Only `--dry-run` or No Flags)](#scenario-r1-default-restore-only---dry-run-or-no-flags)
  - [Scenario R2: Only `--cluster primary` Flag Provided](#scenario-r2-only---cluster-primary-flag-provided)
  - [Scenario R3: Only `--cluster backup` Flag Provided](#scenario-r3-only---cluster-backup-flag-provided)
  - [Scenario R4: Only `BACKUP_DIR` Argument Provided](#scenario-r4-only-backup_dir-argument-provided)
  - [Scenario R5: Only `--config` Flag Provided](#scenario-r5-only---config-flag-provided)
- [Comprehensive Multi-Flag Restore Scenarios](#comprehensive-multi-flag-restore-scenarios)
  - [Scenario E: Dry-Run Restore with Default Set (`--dry-run`)](#scenario-e-dry-run-restore-with-default-set---dry-run)
  - [Scenario F: Dry-Run Restore with `--include filters,views`](#scenario-f-dry-run-restore-with---include-filtersviews)
  - [Scenario G: Dry-Run Restore with `--exclude policies`](#scenario-g-dry-run-restore-with---exclude-policies)
  - [Scenario H: Dry-Run Restore with Partial Backup Manifest (Graceful Skip)](#scenario-h-dry-run-restore-with-partial-backup-manifest-graceful-skip)
  - [Scenario I: Live Selective Restore (`--include menus`)](#scenario-i-live-selective-restore---include-menus)

---

## Backup Flags Matrix & Scenarios

| Flag | Argument | Description | Default |
|---|---|---|---|
| `-h`, `--help` | None | Displays usage help message and exits | — |
| `--list-resources` | None | Lists all supported resource IDs and restore defaults | — |
| `--cluster` | `primary` \| `backup` | Selects target cluster to connect to | `primary` |
| `--config` | `<file_path>` | Specifies custom path to `geo_config.env` | `./geo_config.env` |
| `--output` | `<dir_path>` | Specifies custom directory to store backup files | `./backup-<YYYYMMDD-HHMMSS>` |
| `--include` | `<id1,id2,...>` | Selects only specified resource IDs for backup | All resources |
| `--exclude` | `<id1,id2,...>` | Excludes specified resource IDs from backup | None |
| `--debug` | None | Enables verbose output (request URLs & raw bodies) | `false` |

---

### Flag 1: `--help` / `-h` (Display Usage)

**Command:**
```bash
./backup.sh --help
```

**Output:**
```text
Usage: ./backup.sh [OPTIONS]

Export restorable configuration data from the specified cluster.
Output is written to a timestamped directory that can be committed to git.
By default every resource is exported.

Options:
  --cluster CLUSTER    Specify cluster: primary (default) or backup
  --config FILE        Path to config file (default: ./geo_config.env)
  --output DIR         Output directory (default: ./backup-<timestamp>)
  --include LIST       Comma-separated resource IDs to back up (only these)
  --exclude LIST       Comma-separated resource IDs to leave out (all others)
                       --include and --exclude cannot be used together
  --list-resources     Print the valid resource IDs and exit
  --debug              Print the full URL and raw response for every API call
  -h, --help           Show this help message

Examples:
  ./backup.sh                                           # Backup from primary cluster
  ./backup.sh --cluster backup                          # Backup from backup cluster
  ./backup.sh --output ./my-backup                      # Use custom output directory
  ./backup.sh --include filters,views,policies          # Back up only these resources
  ./backup.sh --exclude policies                        # Back up everything except policies
  ./backup.sh --list-resources                          # Show valid resource IDs
  ./backup.sh --debug                                   # Show full API request/response detail
  ./backup.sh --config /path/to/config.env --cluster backup
```

---

### Flag 2: `--list-resources` (List Resource IDs)

Prints all registered resource identifiers and indicates whether each is restored by default.

**Command:**
```bash
./backup.sh --list-resources
```

**Output:**
```text
Valid resource IDs:

  ID                     RESTORE DEFAULT  DESCRIPTION
  algorithms             no               Algorithms
  connections            yes              Connections
  filters                yes              Filters
  menus                  yes              Menus
  policies               yes              Policies
  runbooks               yes              Runbooks
  actions                yes              Runbook actions
  topology               yes              Topology configuration
  training-definitions   no               Training definitions
  user-preferences       no               User preferences
  views                  yes              Views

backup.sh : with no flags every resource is backed up.
restore.sh: with no flags only the resources marked 'yes' are restored.
```

---

### Flag 3: `--cluster` (`primary` vs `backup` vs Invalid Argument)

#### 3.1 Valid: `--cluster primary` (or omitted default)
Logs into the primary API endpoint (`PRIMARY_CLUSTER_API_ENDPOINT`) and exports configuration using `./geo_config.env` and timestamped output `./backup-<timestamp>`.

#### 3.2 Valid: `--cluster backup`
Logs into the backup API endpoint (`BACKUP_CLUSTER_API_ENDPOINT`) and exports configuration using `./geo_config.env` and timestamped output `./backup-<timestamp>`.

#### 3.3 Invalid Value Error Handling
**Command:**
```bash
./backup.sh --cluster invalid_cluster_name
```
**Output:**
```text
Error: Invalid cluster specified: invalid_cluster_name
Must be either 'primary' or 'backup'
```

#### 3.4 Missing Argument Error Handling
**Command:**
```bash
./backup.sh --cluster
```
**Output:**
```text
Error: --cluster requires a value (primary or backup)
```

---

### Flag 4: `--config` (Custom Path vs Missing Path)

#### 4.1 Valid Custom Config
Passes an external configuration file location to avoid storing credentials inside the repo.
```bash
./backup.sh --config /path/to/geo_config.env
```

#### 4.2 Missing Argument Error Handling
**Command:**
```bash
./backup.sh --config
```
**Output:**
```text
Error: --config requires a file path
```

#### 4.3 Missing File Error Handling
**Command:**
```bash
./backup.sh --config /nonexistent/path/geo_config.env
```
**Output:**
```text
Error: Configuration file not found at: /nonexistent/path/geo_config.env
Please create geo_config.env from geo_config.env.template
Or use --config option to specify a different config file
```

---

### Flag 5: `--output` (Custom Directory vs Default Timestamped vs Missing Path)

#### 5.1 Valid Custom Output Directory
**Command:**
```bash
./backup.sh --config /path/to/geo_config.env \
  --output ./my-custom-backup-dir --include filters
```
Creates `./my-custom-backup-dir/filters.json` and `./my-custom-backup-dir/backup-metadata.json`.

#### 5.2 Default Timestamped Directory
When `--output` is omitted, output directory defaults to `./backup-<YYYYMMDD-HHMMSS>`.

#### 5.3 Missing Argument Error Handling
**Command:**
```bash
./backup.sh --output
```
**Output:**
```text
Error: --output requires a directory path
```

---

### Flag 6: `--include` (Single Resource vs Multi-Resource vs Missing Argument)

#### 6.1 Single Resource: `--include connections`
Backs up all 3 connection files (`connections.json`, `connections-internal.json`, `connections-runbooks.json`).

**Command:**
```bash
./backup.sh --config /path/to/geo_config.env \
  --cluster primary \
  --include connections \
  --output ./backup-flag-connections
```

**Output:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: connections
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-flag-connections

Exporting Connections...
  OK — 16 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-flag-connections
 Files created:
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
```

#### 6.2 Single Resource: `--include runbooks`
Exports `runbooks.json` and writes `runbooks-encryption-token.txt` with permissions `600`.

**Command:**
```bash
./backup.sh --config /path/to/geo_config.env \
  --cluster primary \
  --include runbooks \
  --output ./backup-flag-runbooks
```

**Output:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: runbooks
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-flag-runbooks

Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 4 item(s) → runbooks.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-flag-runbooks
 Files created:
   backup-metadata.json
   runbooks.json
```

#### 6.3 Missing Argument Error Handling
**Command:**
```bash
./backup.sh --include
```
**Output:**
```text
Error: --include requires a comma-separated list of resource IDs (see --list-resources)
```

#### 6.4 Unknown Resource Identifier Error Handling
**Command:**
```bash
./backup.sh --include foo,bar
```
**Output:**
```text
Error: unknown resource ID(s): foo bar
Valid resource IDs: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Run with --list-resources for details.
```

---

### Flag 7: `--exclude` (Single / Multi Exclusion vs Empty Set Error)

#### 7.1 Multi-Resource Exclusion: `--exclude policies,training-definitions`
Exports all resources in the registry except `policies` and `training-definitions`. (See Scenario C for full execution trace).

#### 7.2 Empty Selection Error Handling
**Command:**
```bash
./backup.sh --exclude algorithms,connections,filters,menus,policies,runbooks,actions,topology,training-definitions,user-preferences,views
```
**Output:**
```text
Error: the selection leaves no resources to process
```

---

### Flag 8: Mutual Exclusion Conflict (`--include` with `--exclude`)

`--include` and `--exclude` cannot be used together in the same command.

**Command:**
```bash
./backup.sh --include filters --exclude views
```

**Output:**
```text
Error: --include and --exclude cannot be used together
```

---

### Flag 9: `--debug` (Verbose Diagnostics)

Enables full URL printing and verbose HTTP responses for all API calls.

**Command:**
```bash
./backup.sh --config /path/to/geo_config.env \
  --cluster primary \
  --include menus \
  --output ./backup-flag-debug \
  --debug
```

**Output snippet:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: menus
Performing oc login into cluster: primary
...
Exporting Menus...
  [debug] GET https://cpd-primary.apps.example.com/aiops/api/v2/configuration/menus?all=true
...
```

---

## Standalone Single-Flag Backup Scenarios

### Scenario A1: Only `--cluster` Flag Provided (`--cluster backup`)

Only the `--cluster backup` flag is specified. The script automatically uses `./geo_config.env` for configuration and defaults to a timestamped output directory (`./backup-<YYYYMMDD-HHMMSS>`).

**Command:**
```bash
./backup.sh --cluster backup
```

**Execution Output:**
```text
NOTE:
    If you are using these scripts to replicate data, use aiopsctl’s exchange-token (https://github.com/IBM/aiopsctl) to ensure the connector’s encryption key
    gets copied over to the other cluster.
    Both clusters must have the same key to decrypt all the connectors' encrypted data. If the system is clean installed you must have a backup of the
    aiopsedge-config-encryption-key secret and restore it prior to running the restore script.

Backing up configuration from BACKUP cluster...
Selected resources: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-20261102-114731

Exporting Algorithms...
  OK — 14 item(s) → algorithms.json
Exporting Connections...
  OK — 14 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json
Exporting Filters...
  OK — 23 item(s) → filters.json
Exporting Menus...
  OK — 2 item(s) → menus.json
Exporting Policies...
  state=draft: 0 item(s)
  state=enabled: 1266 item(s)
  state=disabled: 35 item(s)
  state=archived: 0 item(s)
  OK — 1301 item(s) → policies.json
Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 0 item(s) → runbooks.json
Exporting Actions...
  OK — 7 item(s) → actions.json
Exporting Topology configuration...
  Warning: HTTP 404 while exporting Topology — skipping
  Response body: {"message":"Cannot GET /aiops/api/v2/configuration/topology/config/backup","error":"Not Found","statusCode":404}
Exporting Training definitions...
  OK — 1 item(s) → training-definitions.json
Exporting User preferences...
  OK — 0 item(s) → user-preferences.json
Exporting Views...
  OK — 10 item(s) → views.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : backup
 Output directory: ./backup-20261102-114731
 Files created:
   actions.json
   algorithms.json
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
   filters.json
   menus.json
   policies.json
   runbooks.json
   training-definitions.json
   user-preferences.json
   views.json

 Skipped resources (not available on this cluster):
   - Topology (HTTP 404)

To commit to git:
  git add ./backup-20261102-114731
  git commit -m "chore: config backup from backup 2026-11-02T19:47:48Z"
```

---

### Scenario A2: Only `--cluster` Flag Provided (`--cluster primary`)

Only the `--cluster primary` flag is specified. The script uses `./geo_config.env` and creates a timestamped output directory.

**Command:**
```bash
./backup.sh --cluster primary
```

**Execution Output:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-20261102-114833

Exporting Algorithms...
  OK — 14 item(s) → algorithms.json
Exporting Connections...
  OK — 16 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json
Exporting Filters...
  OK — 23 item(s) → filters.json
Exporting Menus...
  OK — 2 item(s) → menus.json
Exporting Policies...
  state=draft: 0 item(s)
  state=enabled: 1266 item(s)
  state=disabled: 35 item(s)
  state=archived: 0 item(s)
  OK — 1301 item(s) → policies.json
Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 4 item(s) → runbooks.json
Exporting Actions...
  Enriching HTTP action passwords from CouchDB...
    Added password for action: action-id-example-1
    Added password for action: action-id-example-2
  OK — 12 item(s) → actions.json
Exporting Topology configuration...
  Warning: HTTP 404 while exporting Topology — skipping
  Response body: {"message":"Cannot GET /aiops/api/v2/configuration/topology/config/backup","error":"Not Found","statusCode":404}
Exporting Training definitions...
  OK — 2 item(s) → training-definitions.json
Exporting User preferences...
  OK — 1 item(s) → user-preferences.json
Exporting Views...
  OK — 10 item(s) → views.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-20261102-114833
 Files created:
   actions.json
   algorithms.json
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
   filters.json
   menus.json
   policies.json
   runbooks.json
   training-definitions.json
   user-preferences.json
   views.json

 Skipped resources (not available on this cluster):
   - Topology (HTTP 404)

To commit to git:
  git add ./backup-20261102-114833
  git commit -m "chore: config backup from primary 2026-11-02T19:48:56Z"
```

---

### Scenario A3: Only `--output` Flag Provided

Only the `--output` flag is provided. The script defaults to the `primary` cluster, uses configuration from `./geo_config.env`, and writes all exported resource files directly to the designated directory.

**Command:**
```bash
./backup.sh --output ./backup-standalone-output-only
```

**Execution Output:**
```text
NOTE:
    If you are using these scripts to replicate data, use aiopsctl’s exchange-token (https://github.com/IBM/aiopsctl) to ensure the connector’s encryption key
    gets copied over to the other cluster.
    Both clusters must have the same key to decrypt all the connectors' encrypted data. If the system is clean installed you must have a backup of the
    aiopsedge-config-encryption-key secret and restore it prior to running the restore script.

Backing up configuration from PRIMARY cluster...
Selected resources: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-standalone-output-only

Exporting Algorithms...
  OK — 14 item(s) → algorithms.json
Exporting Connections...
  OK — 16 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json
Exporting Filters...
  OK — 23 item(s) → filters.json
Exporting Menus...
  OK — 2 item(s) → menus.json
Exporting Policies...
  state=draft: 0 item(s)
  state=enabled: 1266 item(s)
  state=disabled: 35 item(s)
  state=archived: 0 item(s)
  OK — 1301 item(s) → policies.json
Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 4 item(s) → runbooks.json
Exporting Actions...
  Enriching HTTP action passwords from CouchDB...
    Added password for action: action-id-example-1
    Added password for action: action-id-example-2
  OK — 12 item(s) → actions.json
Exporting Topology configuration...
  Warning: HTTP 404 while exporting Topology — skipping
  Response body: {"message":"Cannot GET /aiops/api/v2/configuration/topology/config/backup","error":"Not Found","statusCode":404}
Exporting Training definitions...
  OK — 2 item(s) → training-definitions.json
Exporting User preferences...
  OK — 1 item(s) → user-preferences.json
Exporting Views...
  OK — 10 item(s) → views.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-standalone-output-only
 Files created:
   actions.json
   algorithms.json
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
   filters.json
   menus.json
   policies.json
   runbooks.json
   training-definitions.json
   user-preferences.json
   views.json

 Skipped resources (not available on this cluster):
   - Topology (HTTP 404)

To commit to git:
  git add ./backup-standalone-output-only
  git commit -m "chore: config backup from primary 2026-11-02T19:47:01Z"
```

---

### Scenario A4: Only `--config` Flag Provided

Only the `--config` flag is passed. The script defaults to the `primary` cluster, reads the specified configuration file, and writes all exported resources into a newly generated timestamped directory.

**Command:**
```bash
./backup.sh --config /path/to/geo_config.env
```

**Execution Output:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-20261102-114804

Exporting Algorithms...
  OK — 14 item(s) → algorithms.json
Exporting Connections...
  OK — 16 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json
Exporting Filters...
  OK — 23 item(s) → filters.json
Exporting Menus...
  OK — 2 item(s) → menus.json
Exporting Policies...
  state=draft: 0 item(s)
  state=enabled: 1266 item(s)
  state=disabled: 35 item(s)
  state=archived: 0 item(s)
  OK — 1301 item(s) → policies.json
Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 4 item(s) → runbooks.json
Exporting Actions...
  Enriching HTTP action passwords from CouchDB...
    Added password for action: action-id-example-1
    Added password for action: action-id-example-2
  OK — 12 item(s) → actions.json
Exporting Topology configuration...
  Warning: HTTP 404 while exporting Topology — skipping
  Response body: {"message":"Cannot GET /aiops/api/v2/configuration/topology/config/backup","error":"Not Found","statusCode":404}
Exporting Training definitions...
  OK — 2 item(s) → training-definitions.json
Exporting User preferences...
  OK — 1 item(s) → user-preferences.json
Exporting Views...
  OK — 10 item(s) → views.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-20261102-114804
 Files created:
   actions.json
   algorithms.json
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
   filters.json
   menus.json
   policies.json
   runbooks.json
   training-definitions.json
   user-preferences.json
   views.json

 Skipped resources (not available on this cluster):
   - Topology (HTTP 404)

To commit to git:
  git add ./backup-20261102-114804
  git commit -m "chore: config backup from primary 2026-11-02T19:48:27Z"
```

---

## Comprehensive Multi-Flag Backup Scenarios

### Scenario A: Full Backup (Primary Cluster, Explicit Flags)

Executes complete backup across all 11 supported resources.

**Command:**
```bash
./backup.sh \
  --config /path/to/geo_config.env \
  --cluster primary \
  --output ./backup-scenario4-full-primary
```

**Execution Output:**
```text
Backing up configuration from PRIMARY cluster...
Selected resources: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully
Output directory: ./backup-scenario4-full-primary

Exporting Algorithms...
  OK — 14 item(s) → algorithms.json
Exporting Connections...
  OK — 16 item(s) → connections.json
Using pod for internal connections: aimanager-aio-controller-xxxx-yyyy
Exporting Internal Connections (v3)...
  OK — 0 item(s) → connections-internal.json
Exporting Internal Connections (runbooks)...
  OK — 1 item(s) → connections-runbooks.json
Exporting Filters...
  OK — 23 item(s) → filters.json
Exporting Menus...
  OK — 2 item(s) → menus.json
Exporting Policies...
  state=draft: 0 item(s)
  state=enabled: 1266 item(s)
  state=disabled: 35 item(s)
  state=archived: 0 item(s)
  OK — 1301 item(s) → policies.json
Exporting Runbooks...
  Encryption token saved → runbooks-encryption-token.txt
  OK — 4 item(s) → runbooks.json
Exporting Actions...
  Enriching HTTP action passwords from CouchDB...
    Added password for action: action-id-example-1
    Added password for action: action-id-example-2
  OK — 12 item(s) → actions.json
Exporting Topology configuration...
  Warning: HTTP 404 while exporting Topology — skipping
  Response body: {"message":"Cannot GET /aiops/api/v2/configuration/topology/config/backup","error":"Not Found","statusCode":404}
Exporting Training definitions...
  OK — 2 item(s) → training-definitions.json
Exporting User preferences...
  OK — 1 item(s) → user-preferences.json
Exporting Views...
  OK — 10 item(s) → views.json

Metadata written → backup-metadata.json

============================================
 Backup complete
============================================
 Source cluster  : primary
 Output directory: ./backup-scenario4-full-primary
 Files created:
   actions.json
   algorithms.json
   backup-metadata.json
   connections-internal.json
   connections-runbooks.json
   connections.json
   filters.json
   menus.json
   policies.json
   runbooks.json
   training-definitions.json
   user-preferences.json
   views.json

 Skipped resources (not available on this cluster):
   - Topology (HTTP 404)
```

---

### Scenario B: Selective Backup with `--include` (Primary Cluster)

Exports only `filters`, `views`, `menus`, `actions`.

**Command:**
```bash
./backup.sh \
  --config /path/to/geo_config.env \
  --cluster primary \
  --include filters,views,menus,actions \
  --output ./backup-scenario2-selective-include
```

**Generated `backup-metadata.json`:**
```json
{
  "backup_timestamp": "2026-11-02T19:21:15Z",
  "source_cluster": "primary",
  "cluster_endpoint": "https://cpd-primary.apps.example.com",
  "resources": [
    "filters",
    "menus",
    "actions",
    "views"
  ]
}
```

---

### Scenario C: Selective Backup with `--exclude` (Primary Cluster)

Exports all resources except `policies` and `training-definitions`.

**Command:**
```bash
./backup.sh \
  --config /path/to/geo_config.env \
  --cluster primary \
  --exclude policies,training-definitions \
  --output ./backup-scenario3-selective-exclude
```

---

### Scenario D: Backup from Backup Cluster (`--cluster backup`)

Exports from secondary/backup cluster.

**Command:**
```bash
./backup.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --include filters,views,menus,runbooks \
  --output ./backup-scenario5-from-backup-cluster
```

---

## Restore Flags Matrix & Scenarios

| Flag / Option | Argument | Description | Default |
|---|---|---|---|
| `-h`, `--help` | None | Displays usage help message and exits | — |
| `--list-resources` | None | Lists all supported resource IDs and restore defaults | — |
| `--cluster` | `backup` \| `primary` | Selects target cluster to restore into | `backup` |
| `--config` | `<file_path>` | Specifies custom path to `geo_config.env` | `./geo_config.env` |
| `BACKUP_DIR` | `<dir_path>` | Positional argument specifying backup folder path | Newest `./backup-*` |
| `--include` | `<id1,id2,...>` | Restores only specified resource IDs | Restore defaults (8 resources) |
| `--exclude` | `<id1,id2,...>` | Excludes specified resource IDs from restore | None |
| `--dry-run` | None | Simulates execution without making any REST API calls | `false` |

---

### Flag R1: `--help` / `-h` (Display Usage)

**Command:**
```bash
./restore.sh --help
```

**Output:**
```text
Usage: ./restore.sh [OPTIONS] [BACKUP_DIR]

Restore configuration data from a backup directory to the specified cluster.
By default only the resources known to restore reliably are restored
(run --list-resources to see them).

Options:
  --cluster CLUSTER    Specify cluster: backup (default) or primary
  --config FILE        Path to config file (default: ./geo_config.env)
  --include LIST       Comma-separated resource IDs to restore (only these)
  --exclude LIST       Comma-separated resource IDs to leave out of the default set
                       --include and --exclude cannot be used together
  --list-resources     Print the valid resource IDs and exit
  --dry-run            Print what would be sent without making any API calls
  -h, --help           Show this help message

Arguments:
  BACKUP_DIR           Path to the backup directory (default: most recent ./backup-* directory)

Examples:
  ./restore.sh                                           # Restore to backup cluster from latest backup
  ./restore.sh ./backup-20250101-120000                  # Restore from specific backup directory
  ./restore.sh --cluster primary ./backup-20250101-120000
  ./restore.sh --dry-run ./backup-20250101-120000        # Preview without making changes
  ./restore.sh --include filters,views ./backup-20250101-120000
  ./restore.sh --exclude policies ./backup-20250101-120000
  ./restore.sh --list-resources                          # Show valid resource IDs
```

---

### Flag R2: `--list-resources` (List Resource IDs)

**Command:**
```bash
./restore.sh --list-resources
```

**Output:**
```text
Valid resource IDs:

  ID                     RESTORE DEFAULT  DESCRIPTION
  algorithms             no               Algorithms
  connections            yes              Connections
  filters                yes              Filters
  menus                  yes              Menus
  policies               yes              Policies
  runbooks               yes              Runbooks
  actions                yes              Runbook actions
  topology               yes              Topology configuration
  training-definitions   no               Training definitions
  user-preferences       no               User preferences
  views                  yes              Views

backup.sh : with no flags every resource is backed up.
restore.sh: with no flags only the resources marked 'yes' are restored.
```

---

### Flag R3: `--cluster` (`backup` vs `primary` vs Invalid Argument)

#### R3.1 Valid: `--cluster backup` (Default)
Targets the backup cluster (`BACKUP_CLUSTER_API_ENDPOINT`).

#### R3.2 Valid: `--cluster primary`
Targets the primary cluster (`PRIMARY_CLUSTER_API_ENDPOINT`).

#### R3.3 Invalid Value Error Handling
**Command:**
```bash
./restore.sh --cluster invalid_name --dry-run
```
**Output:**
```text
Error: Invalid cluster specified: invalid_name
Must be either 'primary' or 'backup'
```

---

### Flag R4: `--config` (Custom Path vs Missing Path)

#### R4.1 Valid Custom Config
Passes an external configuration file location.
```bash
./restore.sh --config /path/to/geo_config.env --dry-run
```

#### R4.2 Missing File Error Handling
**Command:**
```bash
./restore.sh --config /nonexistent/geo_config.env --dry-run
```
**Output:**
```text
Error: Configuration file not found at: /nonexistent/geo_config.env
Please create geo_config.env from geo_config.env.template
Or use --config option to specify a different config file
```

---

### Flag R5: `BACKUP_DIR` (Explicit Path vs Default Newest vs Non-existent Dir Error)

#### R5.1 Explicit Backup Directory Positional Argument
```bash
./restore.sh --dry-run ./backup-scenario4-full-primary
```

#### R5.2 Non-Existent Directory Error Handling
**Command:**
```bash
./restore.sh /nonexistent/backup/dir --dry-run
```
**Output:**
```text
Error: Backup directory not found: /nonexistent/backup/dir
```

---

### Flag R6: `--include` (Single Resource vs Non-Default Resource vs Missing Argument)

#### R6.1 Restoring Non-Default Resource: `--include algorithms`
Algorithms are not in the restore default set (marked `no` in `--list-resources`). They are restored when explicitly requested with `--include algorithms`.

**Command:**
```bash
./restore.sh --include algorithms --dry-run ./backup-scenario4-full-primary
```

**Output:**
```text
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-scenario4-full-primary
Selected resources: algorithms

*** DRY RUN MODE — no API calls will be made ***

Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:22:15Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Restoring Algorithms (14 item(s))...
  [dry-run] Would POST 9 SPARK/LUIGI item(s) to /aiops/api/v2/configuration/algorithms
  [dry-run] Would skip 5 system-managed item(s) (K8s/GENAI/LADGS/…)

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario4-full-primary
 Resources       : algorithms
 Mode            : DRY RUN (no changes made)
```

#### R6.2 Unknown Resource ID Error Handling
**Command:**
```bash
./restore.sh --include invalid_res --dry-run
```
**Output:**
```text
Error: unknown resource ID(s): invalid_res
Valid resource IDs: algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views
Run with --list-resources for details.
```

---

### Flag R7: `--exclude` (Single / Multi Exclusion vs Empty Set Error)

Excludes specific resources from the restore default set (e.g. `--exclude policies`).

---

### Flag R8: Mutual Exclusion Conflict (`--include` with `--exclude`)

**Command:**
```bash
./restore.sh --include filters --exclude views --dry-run
```
**Output:**
```text
Error: --include and --exclude cannot be used together
```

---

## Standalone Single-Flag Restore Scenarios

### Scenario R1: Default Restore (Only `--dry-run` or No Flags)

When no flags (or only `--dry-run`) are supplied:
- Uses default cluster: `backup`
- Uses configuration file: `./geo_config.env`
- Automatically discovers and uses the most recent backup folder (`./backup-*`)
- Restores all 8 default resources

**Command:**
```bash
./restore.sh --dry-run
```

**Execution Output:**
```text
Using most recent backup directory: ./backup-standalone-output-only
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-standalone-output-only
Selected resources: connections filters menus policies runbooks actions topology views

*** DRY RUN MODE — no API calls will be made ***

Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:47:01Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Skipping Connections — 0 items in backup
Using pod for internal connections restore: aimanager-aio-controller-xxxx-yyyy
Skipping Internal Connections (v3) — 0 items in backup
Restoring Internal Connections (runbooks) (1 item(s))...
  Note: private keys are not restored — SSH connectors get a newly generated key pair
  [dry-run] Would POST 1 item(s) via oc exec to /v1/runbooks/connections/{type}
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Menus (2 item(s))...
  [dry-run] Would POST 2 item(s) to /aiops/api/v2/configuration/menus
Restoring Policies (1301 item(s), max 50/batch, 27 batch(es))...
  [dry-run] Would POST 1301 policy/policies in 27 batch(es) to /aiops/api/v2/configuration/policy-batches
Restoring Runbooks...
  [dry-run] Would POST to /aiops/api/story-manager/rba/v1/runbooks/import
Restoring Actions (12 item(s))...
  [dry-run] Would POST 12 item(s) to /aiops/api/story-manager/rba/v1/actions
Skipping Topology configuration — not in backup
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-standalone-output-only
 Resources       : connections filters menus policies runbooks actions topology views
 Not in backup   : topology
 Mode            : DRY RUN (no changes made)
```

---

### Scenario R2: Only `--cluster primary` Flag Provided

Targets the `primary` cluster for restore. Automatically uses `./geo_config.env` and the newest `./backup-*` directory.

**Command:**
```bash
./restore.sh --cluster primary --dry-run
```

**Execution Output:**
```text
Using most recent backup directory: ./backup-standalone-output-only
Restoring configuration to PRIMARY cluster...
Backup directory: ./backup-standalone-output-only
Selected resources: connections filters menus policies runbooks actions topology views

*** DRY RUN MODE — no API calls will be made ***

Performing oc login into cluster: primary
Logged into "https://api.primary-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:47:01Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Skipping Connections — 0 items in backup
Using pod for internal connections restore: aimanager-aio-controller-xxxx-yyyy
Skipping Internal Connections (v3) — 0 items in backup
Restoring Internal Connections (runbooks) (1 item(s))...
  Note: private keys are not restored — SSH connectors get a newly generated key pair
  [dry-run] Would POST 1 item(s) via oc exec to /v1/runbooks/connections/{type}
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Menus (2 item(s))...
  [dry-run] Would POST 2 item(s) to /aiops/api/v2/configuration/menus
Restoring Policies (1301 item(s), max 50/batch, 27 batch(es))...
  [dry-run] Would POST 1301 policy/policies in 27 batch(es) to /aiops/api/v2/configuration/policy-batches
Restoring Runbooks...
  [dry-run] Would POST to /aiops/api/story-manager/rba/v1/runbooks/import
Restoring Actions (12 item(s))...
  [dry-run] Would POST 12 item(s) to /aiops/api/story-manager/rba/v1/actions
Skipping Topology configuration — not in backup
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : primary
 Backup directory: ./backup-standalone-output-only
 Resources       : connections filters menus policies runbooks actions topology views
 Not in backup   : topology
 Mode            : DRY RUN (no changes made)
```

---

### Scenario R3: Only `--cluster backup` Flag Provided

Explicitly targets the `backup` cluster. Automatically uses `./geo_config.env` and the newest `./backup-*` directory.

**Command:**
```bash
./restore.sh --cluster backup --dry-run
```

---

### Scenario R4: Only `BACKUP_DIR` Argument Provided

Specifies a specific backup directory to restore from while using default cluster (`backup`) and default config (`./geo_config.env`).

**Command:**
```bash
./restore.sh --dry-run ./backup-scenario4-full-primary
```

---

### Scenario R5: Only `--config` Flag Provided

Specifies an external configuration file path. Automatically detects the most recent `./backup-*` directory and targets the default `backup` cluster.

**Command:**
```bash
./restore.sh --config /path/to/geo_config.env --dry-run
```

**Execution Output:**
```text
Using most recent backup directory: ./backup-standalone-output-only
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-standalone-output-only
Selected resources: connections filters menus policies runbooks actions topology views

*** DRY RUN MODE — no API calls will be made ***

Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:47:01Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Skipping Connections — 0 items in backup
Using pod for internal connections restore: aimanager-aio-controller-xxxx-yyyy
Skipping Internal Connections (v3) — 0 items in backup
Restoring Internal Connections (runbooks) (1 item(s))...
  Note: private keys are not restored — SSH connectors get a newly generated key pair
  [dry-run] Would POST 1 item(s) via oc exec to /v1/runbooks/connections/{type}
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Menus (2 item(s))...
  [dry-run] Would POST 2 item(s) to /aiops/api/v2/configuration/menus
Restoring Policies (1301 item(s), max 50/batch, 27 batch(es))...
  [dry-run] Would POST 1301 policy/policies in 27 batch(es) to /aiops/api/v2/configuration/policy-batches
Restoring Runbooks...
  [dry-run] Would POST to /aiops/api/story-manager/rba/v1/runbooks/import
Restoring Actions (12 item(s))...
  [dry-run] Would POST 12 item(s) to /aiops/api/story-manager/rba/v1/actions
Skipping Topology configuration — not in backup
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-standalone-output-only
 Resources       : connections filters menus policies runbooks actions topology views
 Not in backup   : topology
 Mode            : DRY RUN (no changes made)
```

---

## Comprehensive Multi-Flag Restore Scenarios

### Scenario E: Dry-Run Restore with Default Set (`--dry-run`)

Simulates restoring default resources from a full backup without applying any changes.

**Command:**
```bash
./restore.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --dry-run ./backup-scenario4-full-primary
```

**Output:**
```text
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-scenario4-full-primary
Selected resources: connections filters menus policies runbooks actions topology views

*** DRY RUN MODE — no API calls will be made ***

Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:22:15Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Skipping Connections — 0 items in backup
Using pod for internal connections restore: aimanager-aio-controller-xxxx-yyyy
Skipping Internal Connections (v3) — 0 items in backup
Restoring Internal Connections (runbooks) (1 item(s))...
  Note: private keys are not restored — SSH connectors get a newly generated key pair
  [dry-run] Would POST 1 item(s) via oc exec to /v1/runbooks/connections/{type}
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Menus (2 item(s))...
  [dry-run] Would POST 2 item(s) to /aiops/api/v2/configuration/menus
Restoring Policies (1301 item(s), max 50/batch, 27 batch(es))...
  [dry-run] Would POST 1301 policy/policies in 27 batch(es) to /aiops/api/v2/configuration/policy-batches
Restoring Runbooks...
  [dry-run] Would POST to /aiops/api/story-manager/rba/v1/runbooks/import
Restoring Actions (12 item(s))...
  [dry-run] Would POST 12 item(s) to /aiops/api/story-manager/rba/v1/actions
Skipping Topology configuration — not in backup
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario4-full-primary
 Resources       : connections filters menus policies runbooks actions topology views
 Not in backup   : topology
 Mode            : DRY RUN (no changes made)
```

---

### Scenario F: Dry-Run Restore with `--include filters,views`

**Command:**
```bash
./restore.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --include filters,views \
  --dry-run ./backup-scenario4-full-primary
```

**Output:**
```text
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario4-full-primary
 Resources       : filters views
 Mode            : DRY RUN (no changes made)
```

---

### Scenario G: Dry-Run Restore with `--exclude policies`

**Command:**
```bash
./restore.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --exclude policies \
  --dry-run ./backup-scenario4-full-primary
```

**Output:**
```text
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-scenario4-full-primary
Selected resources: connections filters menus runbooks actions topology views

*** DRY RUN MODE — no API calls will be made ***
...
============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario4-full-primary
 Resources       : connections filters menus runbooks actions topology views
 Not in backup   : topology
 Mode            : DRY RUN (no changes made)
```

---

### Scenario H: Dry-Run Restore with Partial Backup Manifest (Graceful Skip)

Demonstrates how restore inspects `backup-metadata.json` and skips missing resources gracefully without errors.

**Command:**
```bash
./restore.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --dry-run ./backup-scenario2-selective-include
```

**Output:**
```text
Skipping Connections — not in backup
Restoring Filters (23 item(s))...
  [dry-run] Would POST 23 item(s) to /aiops/api/v2/configuration/filters
Restoring Menus (2 item(s))...
  [dry-run] Would POST 2 item(s) to /aiops/api/v2/configuration/menus
Skipping Policies — not in backup
Skipping Runbooks — not in backup
Restoring Actions (12 item(s))...
  [dry-run] Would POST 12 item(s) to /aiops/api/story-manager/rba/v1/actions
Skipping Topology configuration — not in backup
Restoring Views (10 item(s))...
  [dry-run] Would POST 10 item(s) to /aiops/api/v2/configuration/views

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario2-selective-include
 Resources       : connections filters menus policies runbooks actions topology views
 Not in backup   : connections policies runbooks topology
 Mode            : DRY RUN (no changes made)
```

---

### Scenario I: Live Selective Restore (`--include menus`)

Restores menu configuration from the primary backup into the backup cluster.

**Command:**
```bash
./restore.sh \
  --config /path/to/geo_config.env \
  --cluster backup \
  --include menus \
  ./backup-scenario2-selective-include
```

**Output:**
```text
Restoring configuration to BACKUP cluster...
Backup directory: ./backup-scenario2-selective-include
Selected resources: menus
Performing oc login into cluster: backup
Logged into "https://api.backup-cluster.example.com:6443" as "kube:admin" using the token provided.
Using project "cp4waiops".
Getting JWT token...
Retrieving credentials from platform-auth-idp-credentials secret...
JWT token obtained successfully

Backup metadata:
  Backup timestamp : 2026-11-02T19:21:15Z
  Source cluster   : primary
  Cluster endpoint : https://cpd-primary.apps.example.com

Restoring Menus (2 item(s))...
  2/2 item(s) restored successfully (0 skipped)

============================================
 Restore complete
============================================
 Target cluster  : backup
 Backup directory: ./backup-scenario2-selective-include
 Resources       : menus
 Attempted       : 2
 Succeeded       : 2
 Skipped         : 0
```
