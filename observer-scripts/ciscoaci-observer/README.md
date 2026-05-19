# Cisco ACI Observer Job Management Script - User Guide

This file provides instructions for managing Cisco ACI observer jobs using the REST APIs.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [Script Usage](#script-usage)
6. [Actions Reference](#actions-reference)
   - [Create Jobs](#create-jobs)
   - [Update Jobs](#update-jobs)
   - [Stop Jobs](#stop-jobs)
   - [Delete Jobs](#delete-jobs)
   - [Query Job Status](#query-job-status)
   - [Export Jobs](#export-jobs)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The `manage-ciscoaci-jobs.sh` script provides automated management of Cisco ACI observer jobs through REST APIs:

- **Create Jobs**: Create new observer jobs
- **Update Jobs**: Update existing observer jobs (with validation checks)
- **Stop Jobs**: Stop running observer jobs
- **Delete Jobs**: Delete observer jobs from topology (non-running jobs only)
- **Query Jobs**: Query the status of observer jobs
- **Export Jobs**: Export existing job definitions

---

## Prerequisites

### 1. Required Tools

Ensure the following tools are installed on your system:

- **OpenShift CLI (oc)** - For cluster access
- **jq** - For JSON processing

### 2. Cluster Access

Login to your OpenShift cluster and switch to the project where ASM topology is installed.

```bash
# Verify you're in the correct project
oc project

# Verify secret exists
oc get secret aiops-topology-asm-credentials

# Verify routes exist (if enabled)
oc get routes | grep -E 'ciscoaci|topology'
```

If routes are not found, follow the steps below to enable them.

### 3. Enable Observer Routes

To access the URL routes for the topology Swagger documentation, you need to update the IBM ASM Operator configuration.

Complete the following configuration to expose all observers for both full and listen jobs.

```bash
# Edit the ASM operator configuration
oc edit asm aiops-topology

# Search for the string helmValuesASM: within the spec section of the operator custom resource. Add global.enableAllRoutes: true to the list of values to enable the routes. The following example, shows this setting:
spec:
  helmValuesASM:
    global.enableAllRoutes: true

#Save your changes and wait for the ASM operator to reload.

# Verify routes exist (once enabled)
oc get route | grep -E 'ciscoaci|topology'

#Output example
aiops-topology-ciscoaci-observer aiops-topology-ciscoaci-observer-cp4aiops.apps.kubernetes-fvt-test.cp.fyre.ibm.com  /1.0/ciscoaci-observer aiops-topology-ciscoaci-observer 9112 reencrypt/Redirect None
```

### 4. Make Script Executable

```bash

# Make the script executable
chmod +x manage-ciscoaci-jobs.sh
```

---

## Quick Start

### Basic Syntax

```bash
./manage-ciscoaci-jobs.sh <action> [input-file] [log-file-path] [options]
```

### Parameters

| Parameter | Required | Description | Valid Values |
|-----------|----------|-------------|--------------|
| `action` | Yes | Operation to perform (case-insensitive) | create, update, stop, delete, status, export |
| `input-file` | Conditional | JSON/TXT file or directory with job data | Path to file or directory (not required for export) |
| `log-file-path` | No | Directory for log file output | Valid directory path (default: current directory) |

### Quick Examples

```bash
# Create new jobs from a single file
./manage-ciscoaci-jobs.sh create cisco-jobs-sample.json

# Create jobs from a directory (all .json files merged)
./manage-ciscoaci-jobs.sh create /path/to/jobs-directory/

# Create jobs with automatic password encryption
./manage-ciscoaci-jobs.sh create cisco-jobs.json --apic-password 'MyPassword'

# Stop running jobs
./manage-ciscoaci-jobs.sh stop jobs-to-stop.txt

./manage-ciscoaci-jobs.sh stop jobs-to-stop.json

# Delete jobs from topology
./manage-ciscoaci-jobs.sh delete jobs-to-delete.txt

# Export all jobs (single file in current directory)
./manage-ciscoaci-jobs.sh export

# Export all jobs with encrypted passwords included
./manage-ciscoaci-jobs.sh export --include-secrets

# Export to specific directory (creates per-job files)
./manage-ciscoaci-jobs.sh export /path/to/output/ --include-secrets

# Specify custom log directory
./manage-ciscoaci-jobs.sh create cisco-jobs-sample.json /var/logs/
```

---

## Configuration

### Failure Handling Mode

The script includes a configurable failure handling behavior for create and update operations.

```bash
CONTINUE_ON_FAILURE=false
```

**Options:**

- **`false` (default)**: Stop script execution on first failure
  - Recommended for production environments
  - Ensures no partial deployments
  - Provides immediate feedback on errors

- **`true`**: Continue processing remaining jobs even if some fail
  - Useful for bulk operations
  - Processes all jobs and provides complete failure report
  - Allows maximum job creation despite individual failures

**To Change:**
Edit the script and modify line:
```bash
CONTINUE_ON_FAILURE=true  # Continue on failure
```

---

## Script Usage

### Input File Formats

#### For CREATE and UPDATE Actions

**Format:** JSON array with complete job definitions

**Single File:** `cisco-jobs-sample.json`

```json
[
  {
    "unique_id": "ciscoaci_load_job_1",
    "type": "restapi",
    "description": "Example load job",
    "parameters": {
      "ciscoapic_username": "admin",
      "tenant_name": "cvt",
      "ciscoapic_password": "CISCOAPIC_PASS",
      "ciscoapic_api_url": "https://test-host:port/api",
      "ciscoapic_certificate": "ciscoaci.crt",
      "ssl_truststore_file": "localhost.jks",
      "password_ssl_truststore_file": "TRUSTSTORE_PASS",
      "proxy_host": "example-host.com",
      "proxy_port": 3128,
      "proxy_username": "PROXY_USERNAME",
      "proxy_password": "PROXY_PASSWORD"
    }
  },
  {
    "unique_id": "ciscoaci_listen_job_1",
    "type": "websocket",
    "description": "Example listen job",
    "parameters": {
      "ciscoapic_username": "admin",
      "tenant_name": "cvt",
      "ciscoapic_password": "CISCOAPIC_PASS",
      "ciscoapic_api_url": "https://test-host:port/api",
      "ciscoapic_certificate": "ciscoaci.crt",
      "ssl_truststore_file": "localhost.jks",
      "password_ssl_truststore_file": "TRUSTSTORE_PASS"
    }
  }
]
```

**Directory Input:** You can also provide a directory path containing multiple `.json` files. The script will automatically discover, validate, and merge all JSON files in the directory.

```bash
# Directory structure example
jobs-directory/
  ├── load-jobs.json
  ├── listen-jobs.json
  └── fabric-jobs.json

# Usage
./manage-ciscoaci-jobs.sh create jobs-directory/
```

**Password Encryption:** Use `--apic-password` and `--truststore-password` flags to automatically encrypt cleartext passwords:

```bash
./manage-ciscoaci-jobs.sh create cisco-jobs.json \
  --apic-password 'MyCleartextPassword' \
  --truststore-password 'MyTruststorePassword'
```

#### For STOP, DELETE, and STATUS Actions

**Option 1: JSON File** (complete job definitions - unique_id will be extracted)

```json
[
  {
    "unique_id": "ciscoaci_load_job_1",
    "type": "restapi",
    "parameters": {...}
  }
]
```

**Option 2: Text File** (one job ID per line)

**File:** `jobs-to-stop.txt`

```
# Sample file for stopping Cisco ACI observer jobs
# One job unique_id per line
# Lines starting with # are ignored

ciscoaci_load_job_1
ciscoaci_listen_job_1
ciscoaci_fabric_prod_1
```

**Option 3: JSON File** (array of objects with unique_id)

**File:** `jobs-to-stop.json`

```json
[
  {"unique_id": "ciscoaci_load_job_1"},
  {"unique_id": "ciscoaci_listen_job_1"}
]
```
---

## Actions Reference

### Create Jobs

Creates new Cisco ACI observer jobs via REST API.

#### Usage

```bash
./manage-ciscoaci-jobs.sh create <jobs-file-or-directory> [log-path] [options]
```

#### Input Requirements

- **File Format**: JSON array with complete job definitions OR directory containing JSON files
- **Required Fields**:
  - `unique_id`: Unique identifier for the job
  - `type`: Job type (`restapi` for load jobs, `websocket` for listen jobs) - required
  - `parameters`: Job-specific configuration

#### Options

- `--apic-password <password>`: Cleartext APIC password to encrypt and inject into all jobs
- `--truststore-password <password>`: Cleartext SSL truststore password to encrypt and inject into all jobs

#### Example

```bash
# Create jobs from a single file
./manage-ciscoaci-jobs.sh create cisco-jobs-sample.json

# Create jobs from a directory (all .json files merged)
./manage-ciscoaci-jobs.sh create /path/to/jobs-directory/

# Create jobs with automatic password encryption
./manage-ciscoaci-jobs.sh create cisco-jobs.json --apic-password 'MyPassword'

# Create jobs with both passwords encrypted
./manage-ciscoaci-jobs.sh create cisco-jobs.json \
  --apic-password 'MyApicPass' \
  --truststore-password 'MyTruststorePass'

# Create with custom log location
./manage-ciscoaci-jobs.sh create cisco-jobs-sample.json /var/logs/

# Directory input with password encryption
./manage-ciscoaci-jobs.sh create /jobs-dir/ --apic-password 'MyPassword'
```

#### Output

**Console Output:**
```
==========================================
Cisco ACI Observer Job Management Script
==========================================

[INFO] Checking prerequisites...
[SUCCESS] All prerequisites met
[INFO] Log file: ciscoaci-job-create-20260225_113045.log
[SUCCESS] Found 2 job(s) to create
[INFO] Starting job create process...
[STEP] [1/2] Creating job: ciscoaci_load_job_1 (type: restapi)
[SUCCESS] Job created successfully: ciscoaci_load_job_1
[STEP] [2/2] Creating job: ciscoaci_listen_job_1 (type: websocket)
[SUCCESS] Job created successfully: ciscoaci_listen_job_1

==========================================
Job Create Summary
==========================================
Total Jobs: 2
Successful: 2
Failed: 0
Timeout (likely accepted): 0
Skipped: 0
==========================================
```

**Log File:** `ciscoaci-job-create-YYYYMMDD_HHMMSS.log`

```
==========================================
Cisco ACI Observer Job Create Log
==========================================
Timestamp: Mon Feb 25 11:30:45 IST 2026
Jobs File: cisco-jobs-sample.json
Total Jobs: 2
==========================================

Summary:
  Total Jobs: 2
  Successful: 2
  Failed: 0
  Timeout (likely accepted): 0
  Skipped: 0

==========================================
Detailed Job Results
==========================================

Job: ciscoaci_load_job_1
  HTTP Code: 201
  Status: SUCCESS

Job: ciscoaci_listen_job_1
  HTTP Code: 201
  Status: SUCCESS
```

---

### Update Jobs

Updates existing Cisco ACI observer jobs via REST API with validation checks.

#### Usage

```bash
./manage-ciscoaci-jobs.sh update <jobs-file-or-directory> [log-path] [options]
```

#### Input Requirements

- **File Format**: JSON array with complete job definitions OR directory containing JSON files
- **Same unique_id**: Must match the existing job you want to update
- **Complete definition**: Include ALL job parameters, not just changed fields
- **Job must exist**: The job must already exist in the topology
- **Job not running**: The job must not be in RUNNING state (stop it first)
- **Job type cannot change**: Cannot change between `restapi` and `websocket` types

#### Options

- `--apic-password <password>`: Cleartext APIC password to encrypt and inject into all jobs
- `--truststore-password <password>`: Cleartext SSL truststore password to encrypt and inject into all jobs

#### Validation Checks

Before updating, the script validates:
1. **Job Exists**: Queries topology to verify the job exists
2. **Job State**: Ensures the job is not currently RUNNING
3. **Job Type Match**: Verifies the requested type matches the existing job type

If any validation fails, the update is skipped with an appropriate error message.

#### Example

```bash
# Update jobs from a single file
./manage-ciscoaci-jobs.sh update cisco-jobs-update.json

# Update jobs from a directory
./manage-ciscoaci-jobs.sh update /path/to/jobs-directory/

# Update with automatic password encryption
./manage-ciscoaci-jobs.sh update cisco-jobs.json --apic-password 'NewPassword'

# Update with both passwords
./manage-ciscoaci-jobs.sh update cisco-jobs.json \
  --apic-password 'NewApicPass' \
  --truststore-password 'NewTruststorePass'

# Update with case-insensitive action
./manage-ciscoaci-jobs.sh Update cisco-jobs-update.json
```

#### Output

**Log File:** `ciscoaci-job-update-YYYYMMDD_HHMMSS.log`

```
==========================================
Cisco ACI Observer Job Update Log
==========================================
Timestamp: Mon Feb 25 13:30:48 IST 2026
Jobs File: cisco-jobs-update.json
Total Jobs: 2
==========================================

Summary:
  Total Jobs: 2
  Successful: 2
  Failed: 0
  Timeout (likely accepted): 0
  Skipped: 0

==========================================
Detailed Job Results
==========================================

Job: ciscoaci_load_job_1
  HTTP Code: 201
  Status: SUCCESS

Job: ciscoaci_listen_job_1
  HTTP Code: 201
  Status: SUCCESS
```

---

### Stop Jobs

Stops running Cisco ACI observer jobs via REST API.

#### Usage

```bash
./manage-ciscoaci-jobs.sh stop <jobs-file> [log-path]
```

#### Input Requirements

- **File Format**: Text file (one job ID per line) OR JSON file
- **Job State**: Only running jobs can be stopped

#### Example

```bash
# Stop jobs using text file
./manage-ciscoaci-jobs.sh stop jobs-to-stop.txt

# Stop jobs using JSON file
./manage-ciscoaci-jobs.sh STOP jobs-to-stop.json
```

#### Output

**Log File:** `ciscoaci-job-stop-YYYYMMDD_HHMMSS.log`

```
==========================================
Cisco ACI Observer Job Stop Log
==========================================
Timestamp: Mon Feb 25 11:45:30 IST 2026
Jobs File: jobs-to-stop.txt
Total Jobs: 3
==========================================

Summary:
  Total Jobs: 3
  Successfully Stopped: 2
  Not Found: 1

==========================================
Detailed Job Results
==========================================

Job: ciscoaci_load_job_1
  Status: STOPPED
  HTTP Code: 200

Job: ciscoaci_listen_job_1
  Status: STOPPED
  HTTP Code: 200

Job: ciscoaci_fabric_prod_1
  HTTP Code: 404
  Status: NOT FOUND
  Reason: Job does not exist or is not currently running
```

---

### Delete Jobs

Deletes Cisco ACI observer jobs from topology via REST API. This is a two-step process:
1. Query topology to get management artifact IDs
2. Delete the artifacts

**Important:** Only non-running jobs can be deleted. Running jobs must be stopped first.

#### Usage

```bash
./manage-ciscoaci-jobs.sh delete <jobs-file> [log-path]
```

#### Input Requirements

- **File Format**: Text file (one job ID per line) OR JSON file (with unique_id fields)
- **Job State**: Jobs must be stopped before deletion

#### Example

```bash
# Delete jobs using text file
./manage-ciscoaci-jobs.sh delete jobs-to-delete.txt

# Delete jobs using JSON file
./manage-ciscoaci-jobs.sh Delete jobs-to-delete.json
```

#### Output

**Log File:** `ciscoaci-job-delete-YYYYMMDD_HHMMSS.log`

```
==========================================
Cisco ACI Observer Job Delete Log
==========================================
Timestamp: Mon Feb 25 11:50:45 IST 2026
Jobs File: jobs-to-delete.txt
Total Jobs Requested: 3
==========================================

Summary:
  Total Jobs Requested: 3
  Successfully Deleted: 2
  Cannot Delete: 1

==========================================
Detailed Job Results
==========================================

Job: ciscoaci_load_job_1
  HTTP Code: 200
  Status: DELETED

Job: ciscoaci_listen_job_1
  Status: NOT_FOUND
  Reason: Job not found in topology

Job: ciscoaci_fabric_prod_1
  HTTP Code: 200
  Status: DELETED
```

---

### Query Job Status

Queries the status of Cisco ACI observer jobs from topology.

#### Usage

```bash
./manage-ciscoaci-jobs.sh status <jobs-file> [log-path]
```

#### Input Requirements

- **File Format**: Text file (one job ID per line) OR JSON file.

#### Example

```bash
# Query status using text file
./manage-ciscoaci-jobs.sh status jobs-to-check.txt

# Query status using JSON file
./manage-ciscoaci-jobs.sh STATUS jobs-to-check.json
```

#### Output

**Log File:** `ciscoaci-job-status-YYYYMMDD_HHMMSS.log`

```
==========================================
Cisco ACI Observer Job Status Log
==========================================
Timestamp: Mon Feb 25 12:00:00 IST 2026
Jobs File: jobs-to-check.txt
Total Jobs: 3
==========================================

Summary:
  Total Jobs Queried: 3
  Found: 2
  Not Found: 1

==========================================
Detailed Job Status
==========================================

Job: ciscoaci_load_job_1
  Status: RUNNING
  Type: restapi
  Last Updated: 2026-02-25T06:30:00Z

Job: ciscoaci_listen_job_1
  Status: STOPPED
  Type: websocket
  Last Updated: 2026-02-25T06:25:00Z

Job: ciscoaci_fabric_prod_1
  Status: NOT_FOUND
  Message: Job not found in topology
```

---

### Export Jobs

Exports all existing Cisco ACI observer job definitions from topology to JSON file(s).

#### Usage

```bash
./manage-ciscoaci-jobs.sh export [output-directory] [--include-secrets]
```

#### Parameters

- **output-directory** (optional): Directory for export files
  - If not specified: Creates single file `exported-ciscoaci-jobs-YYYYMMDD_HHMMSS.json` in current directory
  - If specified: Creates subdirectory with per-job files plus combined file

- **--include-secrets** (optional): Include encrypted password fields in export
  - Without flag: Password fields (`ciscoapic_password`, `password_ssl_truststore_file`) are blanked to `""`
  - With flag: Encrypted password values are preserved

#### Example

```bash
# Export to current directory (single file)
./manage-ciscoaci-jobs.sh export

# Export to specific directory (per-job files + combined)
./manage-ciscoaci-jobs.sh export /backup/ciscoaci-jobs/

# Export with encrypted passwords included
./manage-ciscoaci-jobs.sh export --include-secrets

# Export to directory with passwords
./manage-ciscoaci-jobs.sh export /backup/ciscoaci-jobs/ --include-secrets
```

#### Output

**Single File Mode** (no output directory specified):
```
exported-ciscoaci-jobs-20260225_143000.json
```

**Directory Mode** (output directory specified):
```
/backup/ciscoaci-jobs/export-20260225_143000/
  ├── ciscoaci_load_job_1.json
  ├── ciscoaci_listen_job_1.json
  ├── ciscoaci_fabric_prod_1.json
  └── all-jobs-20260225_143000.json
```

**Console Output (Single File Mode):**
```
==========================================
Cisco ACI Observer Job Management Script
==========================================

[INFO] Action: export
[INFO] Checking prerequisites...
[SUCCESS] All prerequisites met
[INFO] Starting job export process...
[INFO] Querying topology for all observer jobs...
[SUCCESS] Found 3 job(s) in topology  - fetching full definitions...
[INFO] Export mode: Single combined file
[INFO] Fetching full job definitions...
[STEP] [1/3] Fetched: ciscoaci_load_job_1
[STEP] [2/3] Fetched: ciscoaci_listen_job_1
[STEP] [3/3] Fetched: ciscoaci_fabric_prod_1
[SUCCESS] Exported 3 job(s) to file: ./exported-ciscoaci-jobs-20260225_143000.json

==========================================
Job Export Summary
==========================================
Total Jobs Found: 3
Exported: 3
Output File: ./exported-ciscoaci-jobs-20260225_143000.json
==========================================
[SUCCESS] Export completed: ./exported-ciscoaci-jobs-20260225_143000.json
```

**Console Output (Directory Mode):**
```
==========================================
Cisco ACI Observer Job Management Script
==========================================

[INFO] Action: export
[INFO] Output directory: /backup/ciscoaci-jobs/
[INFO] Checking prerequisites...
[SUCCESS] All prerequisites met
[INFO] Starting job export process...
[INFO] Querying topology for all observer jobs...
[SUCCESS] Found 3 job(s) in topology  - fetching full definitions...
[INFO] Per-job export mode: writing individual files to /backup/ciscoaci-jobs/export-20260225_143000
[INFO] Fetching full job definitions...
[STEP] [1/3] Exported: ciscoaci_load_job_1.json
[STEP] [2/3] Exported: ciscoaci_listen_job_1.json
[STEP] [3/3] Exported: ciscoaci_fabric_prod_1.json
[SUCCESS] Exported 3 job(s) to directory: /backup/ciscoaci-jobs/export-20260225_143000
[INFO]   - Per-job files: <job_name>.json
[INFO]   - Combined file: all-jobs-20260225_143000.json

==========================================
Job Export Summary
==========================================
Total Jobs Found: 3
Exported: 3
Output Directory: /backup/ciscoaci-jobs/export-20260225_143000
  Per-job files: <job_name>.json
  Combined file: all-jobs-20260225_143000.json
==========================================
[SUCCESS] Export completed: /backup/ciscoaci-jobs/export-20260225_143000
```

#### Export Format

Exported jobs are in the same format as input for create/update actions:

```json
[
  {
    "unique_id": "ciscoaci_load_job_1",
    "type": "restapi",
    "description": "Production load job",
    "parameters": {
      "ciscoapic_username": "admin",
      "tenant_name": "production",
      "ciscoapic_password": "",
      "ciscoapic_api_url": "https://apic.example.com/api",
      "ciscoapic_certificate": "ciscoaci.crt",
      "ssl_truststore_file": "truststore.jks",
      "password_ssl_truststore_file": ""
    }
  }
]
```

**Note:** Exported files can be directly used with create/update actions after updating password fields.

---

## Troubleshooting

### Common Issues and Solutions

#### 1. "oc CLI is not installed"

**Solution:** Install OpenShift CLI.

#### 2. "Not logged into OpenShift cluster"

**Solution:** Login to your OpenShift cluster.

#### 3. "Failed to retrieve credentials from secret"

**Solution:**
```bash
# Verify you're in the correct project
oc project

# Check if secret exists
oc get secret aiops-topology-asm-credentials

# If not in correct project, switch
oc project <correct-project-name>
```

#### 4. "Observer route not found"

**Solution:**
- Follow the [Enable Observer Routes](#3-enable-observer-routes) section
- Ensure routes are enabled
- Wait a few minutes for routes to be enabled

#### 5. "Job creation failed with HTTP 400"

**Solution:**
- Verify JSON syntax is correct
- Ensure all required fields are present
- Check connection parameters (URL, credentials)
- Review the log file for detailed error messages

#### 6. "Permission denied" when running script

**Solution:**
```bash
# Make script executable
chmod +x scripts/manage-ciscoaci-jobs.sh
```

#### 7. "Invalid action specified"

**Solution:**
- Check action spelling (valid: create, update, stop, delete, status)
- Action is case-insensitive, so CREATE, create, Create all work

#### 8. "Input file validation failed"

**Solution:**
- For create/update: Ensure JSON file contains complete job definitions
- For stop/delete/status: Ensure file contains job IDs (TXT or JSON format)
- Check file exists and is readable

#### 9. "Job schema validation failed"

**Solution:**
- Check that all required fields are present: `unique_id`, `type`, `parameters`
- Verify `type` is either `restapi` or `websocket`
- Ensure `unique_id` is not empty or null
- Verify `parameters` is a valid JSON object
- Review error messages for specific job index and field

---

### Generated Log Files

The script generates timestamped log files for each operation:

- `ciscoaci-job-create-YYYYMMDD_HHMMSS.log` - Create operation logs
- `ciscoaci-job-update-YYYYMMDD_HHMMSS.log` - Update operation logs
- `ciscoaci-job-stop-YYYYMMDD_HHMMSS.log` - Stop operation logs
- `ciscoaci-job-delete-YYYYMMDD_HHMMSS.log` - Delete operation logs
- `ciscoaci-job-status-YYYYMMDD_HHMMSS.log` - Status query logs

**Note:** Export action creates JSON output files instead of log files.

---