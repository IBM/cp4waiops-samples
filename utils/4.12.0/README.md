# Policies Cleanup Tool

This tool manages AIOps policy cleanup operations by exporting, truncating, and reloading policies while preserving user-defined policies and modified default policies.
This is necessary to avoid Cassandra tombstones when there are more than 100k policies present.

## Overview

The tool performs the following operations:
1. Exports default policies (with `isDefault=true` label)
2. Exports user-defined policies (with `isDefault=false` and `managed-by-analytics=false`)
3. Truncates Cassandra policy tables
4. Runs policy registry upgrade
5. Reloads policies via appropriate APIs

## System Requirements

1. **Authentication**: Script must be executed with access to `cpadmin` credentials (via secrets)
2. **Kubernetes Access**: User must be logged into the AIOps namespace
3. **CLI Tools**: `curl`, `kubectl`, and `jq` must be installed
4. **API Access**: Policy registry service must be functioning correctly
5. **Pod Access**: Ability to exec into pods using kubectl
6. **Bash Version**: Bash 3.2 or higher

## Usage

### Full Mode (Export, Truncate, Reload)

```bash
chmod +x clearAnalyticsPolicies.sh
./clearAnalyticsPolicies.sh -n <namespace>
```

This mode:
- Exports all policies to JSONL files
- Prompts for user confirmation
- Truncates Cassandra tables
- Runs upgrade command
- Reloads policies from JSONL files

### Download Mode

During the invocation of full mode, you will be given an option to proceed to truncation and reload, you can select no at this stage to simply download the policies.
This would be useful in a situation where you would rather manually truncate the policy tables, then later reload the policies to the system using the reload option.

```bash
chmod +x clearAnalyticsPolicies.sh
./clearAnalyticsPolicies.sh -n <namespace>
```

### Reload-Only Mode

```bash
chmod +x clearAnalyticsPolicies.sh
./clearAnalyticsPolicies.sh -n <namespace> -r
```

This mode:
- Skips export, truncation, and upgrade steps
- Only reloads policies from existing JSONL files
- Useful for retrying after a failed reload

## Command-Line Options

- `-n <namespace>`: **(Required)** Kubernetes namespace where AIOps is installed
- `-r`: **(Optional)** Reload-only mode - skips export and truncation

## Risks and Warnings

⚠️ **IMPORTANT**: This tool performs destructive operations:

1. **Data Loss Risk**: In exceptional circumstances, policy data may be lost
2. **User Policies**: Cannot be restored if lost/capture file is deleted
3. **Default Policies**: Customizations to default policies cannot be restored
4. **Analytics Policies**: Can be regenerated from latest data set
