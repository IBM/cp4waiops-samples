# Policy Replication Tool for IBM AIOps

A Python-based tool for migrating policies between IBM AIOps clusters using the IR Core API.

## Requirements

- **Python**: 3.7 or higher
- **Dependencies**: None (standard library only)
- **Network**: HTTPS access to source and target IBM AIOps clusters
- **Authentication**: Valid bearer tokens for both clusters

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd replicate-policies
```

2. Make scripts executable:
```bash
chmod +x export_policies.py import_policies.py
```

## Usage

### Archive Mode (Two-Step Process)

#### Step 1: Export Policies from Source Cluster

```bash
./export_policies.py \
  --source-url https://source-cluster.example.com \
  --source-token YOUR_SOURCE_TOKEN \
  --timeout 180 \
  --output policies-export.tar.gz
```

#### Step 2: Import Policies to Target Cluster

```bash
./import_policies.py \
  --archive policies-export.tar.gz \
  --target-url https://target-cluster.example.com \
  --target-token YOUR_TARGET_TOKEN \
  --timeout 180
```

### Immediate Mode (Single Command)

For direct cluster-to-cluster transfers without creating an archive:

```bash
./export_policies.py \
  --source-url https://source-cluster.example.com \
  --source-token YOUR_SOURCE_TOKEN \
  --import-now \
  --target-url https://target-cluster.example.com \
  --target-token YOUR_TARGET_TOKEN \
  --timeout 180
```

## Scripts

### export_policies.py

**Purpose:** Exports policies from the source cluster and prepares them for import.

**Key Responsibilities:**
- Retrieves all policies using cursor-based pagination
- Creates payload-size-limited batches (max 2 MiB per batch)
- Generates metadata and manifest files
- Creates tar.gz archive (archive mode) or chains to import script (immediate mode)

**Options:**
- `--source-url`: Source cluster URL (required)
- `--source-token`: Source cluster bearer token (required)
- `--output`: Output archive filename (required in archive mode)
- `--import-now`: Enable immediate import mode (no archive created)
- `--target-url`: Target cluster URL (required with --import-now)
- `--target-token`: Target cluster bearer token (required with --import-now)
- `--page-size`: Initial page size for pagination (default: 10000, range: 1000-10000)
- `--max-payload-bytes`: Maximum JSON payload size per batch in bytes (default: 2097052 = ~2 MiB)
- `--timeout`: HTTP request timeout in seconds (default: 120)
- `--verbose`: Enable detailed debug logging

### import_policies.py

**Purpose:** Imports policy batches to the target cluster.

**Key Responsibilities:**
- Extracts and validates archives (archive mode)
- Verifies batch file checksums
- Imports batches sequentially to target cluster
- Handles import failures with adaptive batch splitting

**Options:**
- `--target-url`: Target cluster URL (required)
- `--target-token`: Target cluster bearer token (required)
- `--archive`: Input archive file (for archive mode)
- `--batches-dir`: Directory containing batch files (for immediate mode)
- `--metadata-file`: Metadata JSON file (required with --batches-dir)
- `--timeout`: HTTP request timeout in seconds (default: 120)
- `--dry-run`: Validate archive and batches without uploading
- `--verbose`: Enable detailed debug logging

### policy_replication_common.py

**Purpose:** Shared utilities and constants used by both scripts.

**Provides:**
- HTTP client with retry logic
- Data classes for batch info and statistics
- Formatting utilities (bytes, duration)
- Checksum calculation
- Logging configuration

## Examples

### Basic Archive Workflow
```bash
# Export policies
./export_policies.py \
  --source-url https://prod-cluster \
  --source-token $PROD_TOKEN \
  --timeout 180 \
  --output prod-policies.tar.gz

# Import to staging
./import_policies.py \
  --archive prod-policies.tar.gz \
  --target-url https://staging-cluster \
  --target-token $STAGING_TOKEN \
  --timeout 180
```

### Immediate Transfer with Custom Settings
```bash
./export_policies.py \
  --source-url https://source \
  --source-token $SOURCE_TOKEN \
  --page-size 5000 \
  --max-payload-bytes 5242880 \
  --import-now \
  --target-url https://target \
  --target-token $TARGET_TOKEN \
  --timeout 180 \
  --verbose
```

### Dry Run Validation
```bash
./import_policies.py \
  --archive policies-export.tar.gz \
  --target-url https://target \
  --target-token $TARGET_TOKEN \
  --timeout 180 \
  --dry-run
```

## Troubleshooting

### Common Issues

**Issue**: Export fails with HTTP 500 errors
- **Solution**: Use `--page-size` to reduce page size, or let adaptive fallback handle it automatically

**Issue**: Import fails with payload too large errors
- **Solution**: The tool automatically splits failed batches; check logs for split operations

**Issue**: Checksum verification fails
- **Solution**: Re-export policies from source cluster; archive may be corrupted

**Issue**: Connection timeouts
- **Solution**: Check network connectivity and increase `--timeout` as needed; default timeout is 120 seconds with automatic retries
