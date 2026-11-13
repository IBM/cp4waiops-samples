#!/usr/bin/env bash

set -euo pipefail

OC="oc"

NAMESPACE=""
FORCE=0
DRY_RUN=0
# getopts does not support long options; strip --force (undocumented) and --dry-run first.
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then
    FORCE=1
  elif [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=1
  else
    ARGS+=("$arg")
  fi
done
set -- ${ARGS[@]+"${ARGS[@]}"}

while getopts "n:" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    *) echo "Usage: $0 -n <namespace> [--dry-run]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "$NAMESPACE" ]]; then
  echo "ERROR: Provide the Concert Operate project/namespace with the flag '-n <namespace>'." >&2
  exit 1
fi

EVENTS_OPERATOR_IMAGE=icr.io/cpopen/ibm-events-operator@sha256:064b7e71d623f89ae1a51af3f4b6ec897a440ca0dadcea2e0ec046528fbfa41b

# Check required cluster permissions.
echo "=== Checking required cluster permissions ==="
RBAC_FAILED=0

check_permission() {
  local verb="$1" resource="$2" extra="${3:-}"
  local args=("$verb" "$resource")
  [[ -n "$extra" ]] && args+=($extra)
  if ! $OC auth can-i "${args[@]}" &>/dev/null; then
    echo "  MISSING: $verb $resource${extra:+ $extra}" >&2
    RBAC_FAILED=1
  fi
}

check_permission "get"    "customresourcedefinitions.apiextensions.k8s.io"
check_permission "list"   "customresourcedefinitions.apiextensions.k8s.io"
check_permission "patch"  "customresourcedefinitions.apiextensions.k8s.io"
check_permission "update" "customresourcedefinitions.apiextensions.k8s.io"
check_permission "create" "clusterroles.rbac.authorization.k8s.io"
check_permission "patch"  "clusterroles.rbac.authorization.k8s.io"
check_permission "delete" "clusterroles.rbac.authorization.k8s.io"
check_permission "create" "clusterrolebindings.rbac.authorization.k8s.io"
check_permission "patch"  "clusterrolebindings.rbac.authorization.k8s.io"
check_permission "delete" "clusterrolebindings.rbac.authorization.k8s.io"

# Check IBM Events Operator installations across all namespaces.
# - The installation in the target namespace must be >= 6.0.0 (earlier versions do not support v1 APIs).
# - An installation in any other namespace is flagged for review: it shares the cluster-scoped
#   ibmevents CRDs, so it can break once the CRDs are migrated to v1 unless it is also on v7.
echo ""
echo "=== Checking IBM Events Operator installations across all namespaces ==="
TARGET_VERSION_FAILED=0
OTHER_CSVS=()
while IFS=$'\t' read -r ns csv_name version reason; do
  [[ -z "$ns" ]] && continue
  major=$(echo "$version" | cut -d. -f1)
  # Strip any non-numeric suffix so arithmetic comparisons are safe.
  major=${major//[^0-9]/}; major=${major:-0}
  if [[ "$ns" == "$NAMESPACE" ]]; then
    echo "  Target namespace '$ns': $csv_name ($version)"
    # Versions < 6.0.0 do not support v1 APIs.
    if [[ "$major" -lt 6 ]]; then
      echo "  ERROR: IBM Events Operator version $version in namespace $ns does not support v1 API migration" >&2
      TARGET_VERSION_FAILED=1
    fi
  else
    # Copied CSVs are projections of a cluster-wide install; the original CSV is reported instead.
    [[ "$reason" == "Copied" ]] && continue
    note=""
    [[ "$major" -lt 7 ]] && note=" [NOT v7]"
    OTHER_CSVS+=("$ns: $csv_name ($version)$note")
  fi
done < <(
  $OC get csv --all-namespaces \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.version}{"\t"}{.status.reason}{"\n"}{end}' \
    2>/dev/null | grep $'\t''ibm-events-operator\.' || true
)

if [[ "$TARGET_VERSION_FAILED" -ne 0 ]]; then
  echo "ERROR: The IBM Events Operator in '$NAMESPACE' does not support v1 APIs. Upgrade to >= 6.0.0 before running this script." >&2
  exit 1
fi

# Check for IBM Events custom resources in every namespace other than the target.
echo ""
echo "=== Checking for IBM Events custom resources outside namespace '$NAMESPACE' ==="
IBMEVENTS_RESOURCES=(
  kafkas.ibmevents.ibm.com
  kafkanodepools.ibmevents.ibm.com
  kafkaconnects.ibmevents.ibm.com
  kafkaconnectors.ibmevents.ibm.com
  kafkabridges.ibmevents.ibm.com
  kafkamirrormaker2s.ibmevents.ibm.com
  kafkarebalances.ibmevents.ibm.com
  kafkatopics.ibmevents.ibm.com
  kafkausers.ibmevents.ibm.com
  strimzipodsets.core.ibmevents.ibm.com
)
OTHER_CRS=()
for resource in "${IBMEVENTS_RESOURCES[@]}"; do
  while IFS=$'\t' read -r ns name; do
    [[ -z "$ns" || "$ns" == "$NAMESPACE" ]] && continue
    OTHER_CRS+=("$ns: $resource/$name")
  done < <(
    $OC get "$resource" --all-namespaces \
      -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' \
      2>/dev/null || true
  )
done

OTHER_EVENTS_FOUND=0
if [[ "${#OTHER_CSVS[@]}" -gt 0 || "${#OTHER_CRS[@]}" -gt 0 ]]; then
  OTHER_EVENTS_FOUND=1
  echo ""
  echo "=== WARNING - ACTION REQUIRED: IMPACT TO OTHER PROJECTS DETECTED ==="
  echo "IBM Events resources exist outside the migration namespace '$NAMESPACE'."
  echo "The ibmevents CRDs are cluster-scoped, so migrating them to v1 can break these"
  echo "installations unless they are also running IBM Events Operator v7."
  echo "Plan version alignment of ALL projects using IBM Events to IBM Events Operator v7."
  echo "Please open a ticket with IBM Support to get assistance before proceeding. Include"
  echo "the product names for each namespace to expedite the process."

  if [[ "${#OTHER_CSVS[@]}" -gt 0 ]]; then
    echo ""
    echo "IBM Events Operator installations (CSVs) in other namespaces:"
    for entry in "${OTHER_CSVS[@]}"; do
      echo "  - $entry"
    done
  fi

  if [[ "${#OTHER_CRS[@]}" -gt 0 ]]; then
    echo ""
    echo "IBM Events custom resources in other namespaces:"
    for entry in "${OTHER_CRS[@]}"; do
      echo "  - $entry"
    done
  fi

  # A dry run only reports findings; it never prompts.
  if [[ "$DRY_RUN" -ne 1 ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      exit 1
    fi

    echo ""
    read -r -p "Do you wish to proceed (y/n)? " CONFIRM || CONFIRM=""
    CONFIRM_LC=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRM_LC" != "y" && "$CONFIRM_LC" != "yes" ]]; then
      echo "Aborting."
      exit 1
    fi
  fi
else
  echo "No IBM Events Operator installations or custom resources found outside '$NAMESPACE'."
fi

# run_conversion_job <arg> [<arg> ...]
# Creates (or recreates) the ibm-events-v1-api-conversion Job with the given
# command arguments, streams its logs, and exits non-zero if the job fails.
run_conversion_job() {
  local -a cmd_args=("$@")

  echo ""
  echo "=== Running conversion step: ${cmd_args[*]} ==="

  # Delete any pre-existing Job so re-runs are idempotent (image or command may differ).
  if $OC get job ibm-events-v1-api-conversion -n "$NAMESPACE" &>/dev/null; then
    echo "Deleting existing job ibm-events-v1-api-conversion..."
    $OC delete job ibm-events-v1-api-conversion -n "$NAMESPACE" --wait=true
  fi

  $OC apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ibm-events-v1-api-conversion
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ibm-events-v1-api-conversion
rules:
  - apiGroups:
      - ibmevents.ibm.com
    resources:
      - kafkas
      - kafkanodepools
      - kafkaconnects
      - kafkaconnectors
      - kafkabridges
      - kafkamirrormaker2s
      - kafkarebalances
      - kafkatopics
      - kafkausers
    verbs:
      - get
      - list
      - patch
      - update
  - apiGroups:
      - core.ibmevents.ibm.com
    resources:
      - strimzipodsets
    verbs:
      - get
      - list
      - patch
      - update
  - apiGroups:
      - apiextensions.k8s.io
    resources:
      - customresourcedefinitions
      - customresourcedefinitions/status
    verbs:
      - get
      - list
  - apiGroups:
      - apiextensions.k8s.io
    resources:
      - customresourcedefinitions
      - customresourcedefinitions/status
    resourceNames:
      - kafkabridges.ibmevents.ibm.com
      - kafkaconnectors.ibmevents.ibm.com
      - kafkaconnects.ibmevents.ibm.com
      - kafkamirrormaker2s.ibmevents.ibm.com
      - kafkanodepools.ibmevents.ibm.com
      - kafkarebalances.ibmevents.ibm.com
      - kafkas.ibmevents.ibm.com
      - kafkatopics.ibmevents.ibm.com
      - kafkausers.ibmevents.ibm.com
      - strimzipodsets.core.ibmevents.ibm.com
    verbs:
      - patch
      - update
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
      - list
      - create
      - patch
      - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ibm-events-v1-api-conversion
subjects:
  - kind: ServiceAccount
    name: ibm-events-v1-api-conversion
    namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: ibm-events-v1-api-conversion
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ibm-events-v1-api-conversion
  namespace: $NAMESPACE
spec:
  template:
    spec:
      serviceAccountName: ibm-events-v1-api-conversion
      securityContext:
        runAsNonRoot: true
      containers:
        - name: ibm-events-v1-api-conversion
          image: $EVENTS_OPERATOR_IMAGE
          command:
            - /opt/v1-api-conversion/bin/v1-api-conversion.sh
$(printf '            - %s\n' "${cmd_args[@]}")
          resources:
            limits:
              cpu: 100m
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 200Mi
          securityContext:
            capabilities:
              drop:
                - ALL
            privileged: false
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
          imagePullPolicy: Always
      restartPolicy: OnFailure
EOF

  # Wait for the new Job pod - exclude any pods from a previous run that are still
  # present (Succeeded/Failed) to avoid latching onto a stale pod name.
  echo "Waiting for job pod to be scheduled..."
  local job_pod=""
  for i in $(seq 1 60); do
    job_pod=$(
      $OC get pod -n "$NAMESPACE" \
        -l job-name=ibm-events-v1-api-conversion \
        --field-selector=status.phase!=Succeeded,status.phase!=Failed \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
    )
    if [[ -n "$job_pod" ]]; then
      break
    fi
    sleep 2
  done

  if [[ -z "$job_pod" ]]; then
    echo "ERROR: Timed out waiting for job pod to be scheduled." >&2
    exit 1
  fi

  echo "Waiting for pod $job_pod to start..."
  $OC wait pod "$job_pod" -n "$NAMESPACE" \
    --for=condition=Ready \
    --timeout=120s 2>/dev/null || true

  local pod_phase
  pod_phase=$($OC get pod "$job_pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
  if [[ "$pod_phase" == "Failed" ]]; then
    echo "ERROR: Pod $job_pod failed before logs could be collected." >&2
    $OC logs -n "$NAMESPACE" "$job_pod" --all-containers || true
    exit 1
  fi

  echo "Following logs for pod $job_pod..."
  set +e
  $OC logs -n "$NAMESPACE" "$job_pod" -f --tail=-1
  while [[ "$($OC get pod -n $NAMESPACE $job_pod -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null)" == "True" ]]; do
    $OC logs -n "$NAMESPACE" "$job_pod" -f --since=20s
  done
  set -e

  # Wait for the Job itself to reach a terminal condition, then check the outcome.
  # This avoids a race where the condition field isn't set yet when we query it.
  echo "Waiting for job ibm-events-v1-api-conversion to complete..."
  if ! $OC wait job ibm-events-v1-api-conversion -n "$NAMESPACE" \
      --for=condition=Complete \
      --timeout=120s &>/dev/null; then
    echo "ERROR: Job ibm-events-v1-api-conversion failed for step '${cmd_args[*]}'." >&2
    exit 1
  fi
  echo "Step '${cmd_args[*]}' completed successfully."
}

# verify_crd_stored_versions [--verbose]
# Checks every ibmevents CRD's storedVersions.
# kafkamirrormakers.ibmevents.ibm.com (singular, not kafkamirrormaker2s) is exempt.
# Returns 0 if all are ["v1"], 1 otherwise.
# With --verbose, prints each CRD and its stored versions and errors to stderr on failure.
verify_crd_stored_versions() {
  local verbose=0
  [[ "${1:-}" == "--verbose" ]] && verbose=1

  local failed=0
  while IFS= read -r crd; do
    local stored
    stored=$($OC get "$crd" -o jsonpath='{.status.storedVersions}' 2>/dev/null || true)
    # kafkamirrormakers (singular, not kafkamirrormaker2s) is exempt.
    if [[ "$crd" == *"kafkamirrormakers.ibmevents.ibm.com" && "$crd" != *"kafkamirrormaker2s"* ]]; then
      [[ "$verbose" -eq 1 ]] && echo "  $crd  $stored (exempt)"
      continue
    fi
    if [[ "$stored" != '["v1"]' ]]; then
      [[ "$verbose" -eq 1 ]] && echo "  ERROR: $crd has stored versions $stored (expected [\"v1\"])" >&2
      failed=1
    else
      [[ "$verbose" -eq 1 ]] && echo "  OK: $crd  $stored"
    fi
  done < <($OC get crd -o name | grep 'ibmevents\.ibm\.com')

  if [[ "$failed" -ne 0 ]]; then
    if [[ "$verbose" -eq 1 ]]; then
      echo "ERROR: One or more CRDs still have unexpected stored versions." >&2
      exit 1
    fi
    return 1
  fi
  return 0
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "=== Dry run: checking CRD stored versions ==="
  if verify_crd_stored_versions; then
    echo "All ibmevents CRDs are already at stored version v1 - no conversion would be performed."
  else
    echo "All ibmevents CRDs are not at stored version v1 - a real run would convert them."
  fi
  echo ""
  if [[ "$OTHER_EVENTS_FOUND" -eq 1 ]]; then
    echo "Dry run complete: review the IBM Events resources outside '$NAMESPACE' reported above. No changes were made."
    exit 1
  fi
  echo "Dry run complete: verification passed. No changes were made."
  exit 0
fi

echo ""
echo "=== Checking CRD stored versions ==="
if verify_crd_stored_versions; then
  echo "All ibmevents CRDs are already at stored version v1 - skipping conversion jobs."
else
  run_conversion_job convert-resource --all-namespaces
  run_conversion_job crd-upgrade

  echo ""
  echo "=== Verifying CRD stored versions ==="
  verify_crd_stored_versions --verbose
  echo "All CRD stored versions verified successfully."

  # Clean up RBAC resources; leave the Job in place for post-run debugging.
  echo ""
  echo "=== Cleaning up RBAC resources ==="
  $OC delete clusterrolebinding ibm-events-v1-api-conversion --ignore-not-found
  $OC delete clusterrole ibm-events-v1-api-conversion --ignore-not-found
  $OC delete serviceaccount ibm-events-v1-api-conversion -n "$NAMESPACE" --ignore-not-found
fi

