# Backup and Restore Scripts

`backup.sh` exports the user configuration of an IBM Concert Operate cluster to a local directory as JSON files. `restore.sh` re-creates that configuration on a cluster from such a directory. Both scripts can work on a subset of resources, selected with `--include` and `--exclude`.

- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Resources](#resources)
- [Selecting resources](#selecting-resources)
- [backup.sh reference](#backupsh-reference)
- [restore.sh reference](#restoresh-reference)
- [What a backup directory contains](#what-a-backup-directory-contains)
- [Behavior and limitations](#behavior-and-limitations)
- [Security](#security)
- [Common recipes](#common-recipes)
- [Troubleshooting](#troubleshooting)
- [Adding a new resource](#adding-a-new-resource)

## Prerequisites

- `bash` 3.2 or later (the macOS default works)
- `oc`, `curl` and `jq` on the `PATH`
- A `geo_config.env` file created from [`geo_config.env.template`](geo_config.env.template). See [README.md](README.md#initial-setup) for how to fill it in and how to obtain tokens
- A user with administrative privileges on the cluster

`oc` is used to log in, and also for the connections export and restore and for reading HTTP action passwords. If `PRIMARY_ACCESS_TOKEN` or `BACKUP_ACCESS_TOKEN` is set in `geo_config.env`, the scripts skip `oc login` and use that token for the REST APIs. In that case `oc` must already be logged in to the right cluster and namespace for the `oc` based steps.

> **Encryption key:** connector secrets are encrypted with the `aiopsedge-config-encryption-key` secret. When you replicate to another cluster, both clusters must hold the same key (use `aiopsctl`'s `exchange-token`). On a clean install, restore the key secret from your own backup before running `restore.sh`.

## Quick start

```bash
# 1. Back up everything from the primary cluster
./backup.sh

# 2. Restore the known-working set into the backup cluster, from the newest ./backup-* directory
./restore.sh

# 3. Or be explicit
./backup.sh --cluster primary --output ./my-backup
./restore.sh --cluster backup ./my-backup

# See which resource IDs exist
./backup.sh --list-resources
```

Preview a restore without changing anything:

```bash
./restore.sh --dry-run ./my-backup
```

## Resources

Run `./backup.sh --list-resources` or `./restore.sh --list-resources` to print this table. Neither command logs in or calls an API.

| ID | Backup default | Restore default | What it covers |
|---|---|---|---|
| `algorithms` | yes | **no** | Algorithms. Only `SPARK` and `LUIGI` runtimes can be restored |
| `connections` | yes | yes | All connections as one group: external connections, log collector connections (internal v3) and runbook connections (SSH and Ansible AWX) |
| `filters` | yes | yes | Filters |
| `menus` | yes | yes | Menus |
| `policies` | yes | yes | Policies, all states (draft, enabled, disabled, archived) |
| `runbooks` | yes | yes | Runbooks, plus the encryption token needed to import them |
| `actions` | yes | yes | Runbook actions (called Tools in the v2 configuration API) |
| `topology` | yes | yes | Topology configuration |
| `training-definitions` | yes | **no** | Training definitions |
| `user-preferences` | yes | **no** | User preferences |
| `views` | yes | yes | Views |

**Why restore has a smaller default.** Algorithms, training definitions and user preferences are known to fail or to have limitations on restore in 5.4.0, so `restore.sh` leaves them out unless you ask for them with `--include`. `backup.sh` still captures them, so nothing is lost.

**Why `connections` is one ID.** It cannot be split. Log collector connections such as Splunk go through an internal connection manager that must run before the gRPC connection manager, otherwise the Kafka topics are generated incorrectly and the Flink job never starts. Selecting `connections` always processes all three connection files.

## Selecting resources

Three flags work the same way in both scripts.

| Flag | Meaning |
|---|---|
| `--include LIST` | Process **only** the listed resources |
| `--exclude LIST` | Process the default set **minus** the listed resources |
| `--list-resources` | Print the valid resource IDs and exit |

`LIST` is a comma-separated list of resource IDs with no spaces, for example `filters,views`.

The base set that `--exclude` subtracts from depends on the script:

| Command | Resources processed |
|---|---|
| `backup.sh` | all 11 resources |
| `backup.sh --include a,b` | `a` and `b` |
| `backup.sh --exclude a` | all 11 except `a` |
| `restore.sh` | the 8 restore-default resources |
| `restore.sh --include a,b` | `a` and `b`, even if they are not restore-default |
| `restore.sh --exclude a` | the 8 restore-default resources except `a` |

Rules:

- `--include` and `--exclude` cannot be used together. The script prints an error and exits with status 1.
- Unknown IDs are rejected **before** any login or API call. The error lists the valid IDs, and nothing is written or changed.
- A selection that ends up empty (for example excluding every default resource) is an error.
- The backup and restore selections are independent. You can back up everything and restore only a subset.
- Order on the command line does not matter. Resources are always processed in a fixed order: algorithms, connections, filters, menus, policies, runbooks, actions, topology, training definitions, user preferences, views.
- The selection works with `--cluster`, `--config`, `--output`, `--dry-run` and `--debug`.
- To restore something that is not in the restore default set (for example `algorithms`), name it with `--include`. `--exclude` can never add resources.

## backup.sh reference

```text
./backup.sh [OPTIONS]
```

| Option | Description |
|---|---|
| `--cluster CLUSTER` | `primary` (default) or `backup`. Which cluster to export from |
| `--config FILE` | Path to the config file. Default `./geo_config.env` |
| `--output DIR` | Output directory. Default `./backup-<YYYYMMDD-HHMMSS>` |
| `--include LIST` | Back up only these resources |
| `--exclude LIST` | Back up everything except these resources |
| `--list-resources` | Print the valid resource IDs and exit |
| `--debug` | Print the full URL and raw response of every API call |
| `-h`, `--help` | Show usage |

Examples:

```bash
./backup.sh                                       # everything, from the primary cluster
./backup.sh --cluster backup                      # everything, from the backup cluster
./backup.sh --include filters,views,policies      # only these three
./backup.sh --exclude policies                    # everything except policies (useful when policies are slow)
./backup.sh --include connections                 # all three connection files
./backup.sh --include runbooks                    # runbooks.json and runbooks-encryption-token.txt
./backup.sh --output ./nightly --exclude algorithms,training-definitions
./backup.sh --config ~/clusters/geo_config.env --cluster backup
```

What to expect:

- The script prints `Selected resources: ...` before it logs in, so you can confirm the selection.
- `oc` pod lookups used for connections are skipped when `connections` is not selected, which avoids unnecessary cluster access. HTTP action passwords are read from CouchDB through `oc` only when `actions` is selected and an action has a password.
- At the end it lists the files created and any resource that was skipped (for example an HTTP error that is not an authentication failure).
- HTTP 401 and 403 abort the backup immediately.

## restore.sh reference

```text
./restore.sh [OPTIONS] [BACKUP_DIR]
```

| Option / argument | Description |
|---|---|
| `--cluster CLUSTER` | `backup` (default) or `primary`. Which cluster to restore into |
| `--config FILE` | Path to the config file. Default `./geo_config.env` |
| `--include LIST` | Restore only these resources |
| `--exclude LIST` | Restore the default set except these resources |
| `--list-resources` | Print the valid resource IDs and exit |
| `--dry-run` | Show what would be sent without making any resource API calls |
| `-h`, `--help` | Show usage |
| `BACKUP_DIR` | Directory made by `backup.sh`. Default: the newest `./backup-*` directory |

The first argument that is not a flag is taken as `BACKUP_DIR`, so `./restore.sh --include filters ./dir` uses `./dir` as the backup directory.

Examples:

```bash
./restore.sh                                              # default set, newest ./backup-* directory, into the backup cluster
./restore.sh ./backup-20261027-101500                     # default set from a specific backup
./restore.sh --cluster primary ./backup-20261027-101500   # restore into the primary cluster
./restore.sh --include filters,views ./backup-20261027-101500
./restore.sh --exclude policies ./backup-20261027-101500
./restore.sh --include algorithms ./backup-20261027-101500          # restore a non-default resource
./restore.sh --include policies --dry-run ./backup-20261027-101500  # preview one resource
```

What to expect:

- Resources are checked against `backup-metadata.json`. A selected resource that is not in the backup is reported as `Skipping <name> — not in backup` and listed on the `Not in backup` line of the final summary. This is not an error, so restoring defaults from a partial backup works.
- A backup with no manifest, or one whose manifest has no `resources` list, is handled by checking whether the resource's files exist.
- Backups made before this feature have a manifest that lists every resource whether or not a file was written. For those, a selected resource with no file is reported as `Skipping ... — file not found` instead of `not in backup`. It is still skipped, not an error.
- With `--dry-run` the script still logs in and reads the cluster in a few places, but sends no create or update requests.
- The summary shows the resources that were processed, those not in the backup, and the attempted, succeeded and skipped counts.

## What a backup directory contains

| File | Resource ID | Notes |
|---|---|---|
| `algorithms.json` | `algorithms` | |
| `connections.json` | `connections` | External connections, with secrets decrypted |
| `connections-internal.json` | `connections` | Log collector connections (v3) |
| `connections-runbooks.json` | `connections` | SSH and Ansible AWX connections. Private keys are not stored |
| `filters.json` | `filters` | |
| `menus.json` | `menus` | |
| `policies.json` | `policies` | |
| `runbooks.json` | `runbooks` | |
| `runbooks-encryption-token.txt` | `runbooks` | Key needed to decrypt runbook secrets on import. Mode `600` |
| `actions.json` | `actions` | HTTP action passwords included |
| `topology.json` | `topology` | |
| `training-definitions.json` | `training-definitions` | |
| `user-preferences.json` | `user-preferences` | |
| `views.json` | `views` | |
| `backup-metadata.json` | | Manifest, see below |

All `*.json` resource files have the shape `{ "items": [ ... ] }`, except `topology.json`, which is the topology configuration object.

`backup-metadata.json` records when and where the backup was taken and which resources it really contains:

```json
{
  "backup_timestamp": "2026-10-27T10:15:00Z",
  "source_cluster": "primary",
  "cluster_endpoint": "https://cpd-katamari.example.com",
  "resources": ["filters", "views"]
}
```

`resources` lists only resources that were selected **and** written. A resource that failed with a non-authentication HTTP error is not listed, so `restore.sh` reports it as "not in backup" instead of failing later.

## Behavior and limitations

- **Restore creates, it does not update.** Only runbooks and actions are de-duplicated by name. Everything else is created again if you restore twice, so be careful with repeated partial runs. Prefer a freshly provisioned target, or clean up the target first.
- **Runbooks before actions.** The runbook import already creates the actions that runbooks embed. `restore.sh` then skips any action whose name already exists, so restore `runbooks` and `actions` together (the default does).
- **A failed restore step can stop the run.** For whole-file restores (runbooks, topology), an HTTP error prints the response body and exits with status 1, so the remaining selected resources are not processed. After fixing the cause you can re-run just that resource, for example `./restore.sh --include topology ./dir`.
- **Per item failures** (filters, menus, views, connections, and so on) print a warning and the restore continues. Check the counts in the summary.
- **Policies** are restored in batches with a 20 second pause between batches, because the policy engine indexes synchronously and the API is rate limited. Large policy sets take a while, so you can run policies separately: `--exclude policies` for the rest, then `--include policies`.
- **Algorithms:** only `SPARK` and `LUIGI` algorithms are posted. System-managed runtimes are skipped.
- **Actions:** predefined (system) actions are skipped.
- **SSH connectors:** the private key is never backed up. Restore creates the connector with a newly generated key pair and prints the new public key. Copy it to your SSH target hosts.
- **Log collector connections** (`logdna`, `humio`, `elk`, `custom`, `splunk`) are restored only through the internal v3 path, never through the external connections API.
- **User preferences** are applied to the authenticated user (`me`).
- **Not backed up:** alerts, events, incidents, metering, runbook executions, and policy IDs, status and timeline.
- **Tenant ID:** the scripts send the fixed `X-TenantID` header `cfd95b7e-3bc7-4006-a4a8-a73a79c71255`.

## Security

Backup directories contain **plaintext secrets**: decrypted connection credentials, HTTP action passwords and the runbook encryption token.

- Do not commit `backup-*` directories or any directory you pass to `--output`. The `Backup complete` message suggests `git add`, but only do that for a repository that is private and approved for secrets.
- Restrict access to the directory, for example `chmod 700 ./backup-20261027-101500`.
- Never commit `geo_config.env`. It holds cluster tokens and is already ignored by git.
- Do not paste backup files, hostnames, tenant IDs or tokens into tickets or pull requests. Paste the command line only.

## Common recipes

**Back up everything, restore only filters and views to a cluster that has its own connections**

```bash
./backup.sh --output ./snapshot
./restore.sh --include filters,views ./snapshot
```

**Restore the default set but skip policies, then restore policies separately**

```bash
./restore.sh --exclude policies ./snapshot
./restore.sh --include policies ./snapshot
```

**Restore a resource that is not restored by default**

```bash
./restore.sh --include algorithms,training-definitions ./snapshot
```

**Back up before a cluster shutdown, leaving out known problem resources**

```bash
./backup.sh --exclude algorithms,training-definitions,user-preferences
```

This replaces the old workaround of renaming files in the backup (for example `mv algorithms.json algorithms.json.skip`). Renaming still works, because a missing file is skipped, but it modifies the snapshot and is no longer needed.

**Replicate from primary to backup, then back after a failover**

```bash
./backup.sh --cluster primary --output ./snapshot
./restore.sh --cluster backup ./snapshot

# after failover, the other direction
./backup.sh --cluster backup --output ./snapshot-back
./restore.sh --cluster primary ./snapshot-back
```

**Check what a restore would do**

```bash
./restore.sh --dry-run --include policies,runbooks ./snapshot
```

**Run from CI or cron**

All flags are non-interactive, so the scripts work in `cron`, CI jobs and over SSH:

```bash
ssh host 'cd /opt/geo && ./restore.sh --config /etc/geo/geo_config.env --include filters,views ./snapshot'
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Error: unknown resource ID(s): ...` | A typo in `--include` or `--exclude`. Run `--list-resources` for the valid IDs. Nothing was changed |
| `Error: --include and --exclude cannot be used together` | Use one flag. To restore "default plus an extra", use `--include` and list everything you want |
| `Error: --include requires a comma-separated list...` | The flag was given with no value, or the next word starts with `--` |
| `Error: the selection leaves no resources to process` | The `--exclude` list removed every resource in the base set |
| `Configuration file not found` | Create `geo_config.env` from the template, or pass `--config FILE` |
| `Error: No backup directory found` | No `./backup-*` directory exists. Run `backup.sh` or pass the directory as an argument |
| A resource shows `not in backup` | It was not selected when the backup was taken, or its export failed. Check the `Skipped resources` section of that backup's output |
| `HTTP 401`/`403` during backup | The token has expired or lacks admin rights. Refresh it (`oc whoami -t`) in `geo_config.env` |
| `No aimanager-aio-controller pod found` | `oc` is not logged in to the right cluster or namespace. Internal connections are skipped |
| Restore stops with `Error: HTTP ...` for runbooks or topology | Read the printed response body, fix the cause, then re-run only that resource with `--include` |
| Policies restore reports HTTP 429, 504 or 413 | Handled automatically: the script waits for the rate limit, falls back to single posts, or splits the batch |

Use `--debug` with `backup.sh` to print every request URL and raw response.

## Adding a new resource

Selection is driven by one registry, so a new resource needs only a few small edits:

1. In [`common_functions.sh`](common_functions.sh), add the ID to `ALL_RESOURCES`, add it to `RESTORE_DEFAULT_RESOURCES` if it should restore by default, and add its description to `resource_description` and its file names to `resource_files` (the default is `<id>.json`).
2. In [`backup.sh`](backup.sh), add a `backup_<id>()` function. Hyphens in the ID become underscores, so `my-thing` calls `backup_my_thing`. The dispatch loop picks it up automatically.
3. In [`restore.sh`](restore.sh), add a function if needed and a line for the ID in the `case` of the dispatch loop.
4. Update the resource table in this file.

Keep the code compatible with bash 3.2: no associative arrays, no `mapfile`, and guard empty arrays with `${arr[@]+"${arr[@]}"}` because of `set -u`.
