#!/usr/bin/env bash
# install-operator.sh
#
# Installs IBM components on a CNCF Kubernetes cluster (not OpenShift), in order:
#   1. OLM (skipped if already running)
#   2. Pull secrets (ibm-entitlement-key)
#   3. IBM IA CatalogSource
#   4. IBM cert-manager (skipped if cert-manager.io is already present)
#   5. IBM License Service
#   6. Zen RBAC (StorageClass/Namespace read, Ingress management for the Zen SA)
#   7. IBM IA operator
# The IAConfig CR is not applied; apply it once the operator is running.
#
# Usage:
#   ./install-operator.sh [OPTIONS]
#
# Options:
#   --namespace <ns>               Namespace where the IBM IA operator is installed.
#                                  Env: INSTALL_NAMESPACE  Default: cp4aiops
#   --olm-namespace <ns>           Namespace where OLM is installed or will be installed.
#                                  Env: OLM_NAMESPACE  Default: olm
#   --catalogsource-url <url>      Image URL for the IBM IA CatalogSource index image.
#                                  Env: IA_CATALOGSOURCE_URL  Default: release default
#   --catalog-name <name>          Name of the CatalogSource resource.
#                                  Env: CATALOG_NAME  Default: ibm-aiops-ia-catalog
#   --ia-channel <channel>         OLM subscription channel for the IBM IA operator.
#                                  Env: IA_CHANNEL  Default: release default
#   --cert-manager-channel <ch>    OLM subscription channel for IBM cert-manager.
#                                  Env: IBM_CERT_MANAGER_CHANNEL  Default: v4.2
#   --licensing-channel <ch>       OLM subscription channel for IBM License Service.
#                                  Env: IBM_LICENSING_CHANNEL  Default: v4.2
#   --cert-manager-namespace <ns>  Namespace where IBM cert-manager is installed.
#                                  Env: IBM_CERT_MANAGER_NS  Default: ibm-cert-manager
#   --licensing-namespace <ns>     Namespace where IBM License Service is installed.
#                                  Env: IBM_LICENSING_NS  Default: ibm-licensing
#   --pull-secrets-conf <path>     Pull-secrets conf file (see pull-secrets.conf.template),
#                                  used only if ibm-entitlement-key does not already exist.
#                                  Env: PULL_SECRETS_CONF  Default: ./pull-secrets.conf
#   --kubeconfig <path>            Kubeconfig path. Overrides KUBECONFIG and the k3s default
#                                  /etc/rancher/k3s/k3s.yaml.
#   --dry-run                      Print what would be applied without touching the cluster.
#   -y, --yes                      Skip the confirmation prompt (non-interactive / CI use).
#   -h, --help                     Show this help and exit.
#
# CLI options take precedence over environment variables.
#
# Exit codes: 0 = all steps passed, 1 = one or more steps failed.
# Dependencies: kubectl, awk, curl, grep, sed, base64, python3

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

readonly LOG_FILE="/tmp/install-operator-$(date '+%Y%m%d-%H%M%S').log"

# Release defaults - update on every release.
readonly DEFAULT_IA_CATALOGSOURCE_URL="icr.io/cpopen/ibm-aiops-ia-catalog:v5.4.0"
readonly DEFAULT_IA_CHANNEL="v5.4"

readonly OLM_DEPLOY_TIMEOUT=300

# ---------------------------------------------------------------------------
# OLM install constants (formerly in install-aiops-version-olm-k3s.sh)
# ---------------------------------------------------------------------------
readonly OLM_VERSION="v0.45.0"
readonly OLM_MIRROR_REGISTRY="icr.io/cpopen/k8s-mirror"
readonly OLM_IMAGE_DIGEST="sha256:4427e684c86ea9c6db2286ae3c6be7547dfc0c83de4eeede9c2b4f03bc6e2816"
readonly OLM_IMAGE="${OLM_MIRROR_REGISTRY}/operator-framework/olm@${OLM_IMAGE_DIGEST}"
# configmapServerImage uses :latest without a digest pin -- the mirror
# /bin/catalog binary accepts it and avoids the digest-vs-tag mismatch that
# caused "flag provided but not defined".
readonly OLM_CONFIGMAP_OPERATOR_IMAGE="quay.io/operator-framework/configmap-operator-registry:latest"
# OPM image passed to catalog-operator as --opmImage.
# When --opmImage is present, catalog-operator uses OPM for bundle unpacking
# (gzip, no 1 MB size limit).  Without it, catalog-operator falls back to
# configmap-operator-registry and hits the 1 MB limit on large operator bundles.
# Source: dependency-images.json config.overrides[] "operator-framework/opm"
#   upstream tag : v1.72.0
#   mirror tag   : v1.72.0_v0.4.0
#   mirror digest: sha256:0d7396...
# To refresh for a new OLM mirror release see the comments in
# install-aiops-version-olm-k3s.sh (steps 1-3).
readonly OLM_OPM_IMAGE="${OLM_MIRROR_REGISTRY}/operator-framework/opm@sha256:0d73968483a9b893e9c88018e6f80ba68f34816ebaf76f84ce5f77d2ce25a963"
readonly OLM_RELEASE_BASE_URL="https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}"
readonly OLM_QUICKSTART_URL="https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/${OLM_VERSION}/deploy/upstream/quickstart"
readonly OLM_CRD_WAIT_TIMEOUT="180s"

# Per-step result: PASS | FAIL | SKIP
declare -A STEP_STATUS=(
  [olm]="SKIP"
  [pull_secrets]="SKIP"
  [catalogsource]="SKIP"
  [cert_manager]="SKIP"
  [license_service]="SKIP"
  [zen_rbac]="SKIP"
  [ia_operator]="SKIP"
)

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
die()  { log "ERROR $*" >&2; exit 1; }

# Prints the usage section of the header above (keep the line range in sync).
usage() {
  sed -n '15,46p' "$0" | sed 's/^# \{0,1\}//'
}

_FLAG_NAMESPACE=""
_FLAG_OLM_NAMESPACE=""
_FLAG_CATALOGSOURCE_URL=""
_FLAG_CATALOG_NAME=""
_FLAG_IA_CHANNEL=""
_FLAG_CERT_MANAGER_CHANNEL=""
_FLAG_LICENSING_CHANNEL=""
_FLAG_CERT_MANAGER_NS=""
_FLAG_LICENSING_NS=""
_FLAG_PULL_SECRETS_CONF=""
_FLAG_KUBECONFIG=""
DRY_RUN=false
YES=false
KUBECTL_ARGS=()

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --namespace)
        (($# >= 2)) || die "--namespace requires a value"
        _FLAG_NAMESPACE="$2"; shift 2 ;;
      --olm-namespace)
        (($# >= 2)) || die "--olm-namespace requires a value"
        _FLAG_OLM_NAMESPACE="$2"; shift 2 ;;
      --catalogsource-url)
        (($# >= 2)) || die "--catalogsource-url requires a value"
        _FLAG_CATALOGSOURCE_URL="$2"; shift 2 ;;
      --catalog-name)
        (($# >= 2)) || die "--catalog-name requires a value"
        _FLAG_CATALOG_NAME="$2"; shift 2 ;;
      --ia-channel)
        (($# >= 2)) || die "--ia-channel requires a value"
        _FLAG_IA_CHANNEL="$2"; shift 2 ;;
      --cert-manager-channel)
        (($# >= 2)) || die "--cert-manager-channel requires a value"
        _FLAG_CERT_MANAGER_CHANNEL="$2"; shift 2 ;;
      --licensing-channel)
        (($# >= 2)) || die "--licensing-channel requires a value"
        _FLAG_LICENSING_CHANNEL="$2"; shift 2 ;;
      --cert-manager-namespace)
        (($# >= 2)) || die "--cert-manager-namespace requires a value"
        _FLAG_CERT_MANAGER_NS="$2"; shift 2 ;;
      --licensing-namespace)
        (($# >= 2)) || die "--licensing-namespace requires a value"
        _FLAG_LICENSING_NS="$2"; shift 2 ;;
      --pull-secrets-conf)
        (($# >= 2)) || die "--pull-secrets-conf requires a path"
        _FLAG_PULL_SECRETS_CONF="$2"; shift 2 ;;
      --kubeconfig)
        (($# >= 2)) || die "--kubeconfig requires a path"
        _FLAG_KUBECONFIG="$2"; shift 2 ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      -y|--yes)
        YES=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        die "Unknown argument: $1" ;;
    esac
  done
}

# Precedence: CLI flag > environment variable > built-in default.
resolve_config() {
  ZEN_SA="ibm-zen-operator-serviceaccount"
  ZEN_RBAC_NAME="ibm-zen-storageclass-rbac"
  ZEN_INGRESS_RBAC_NAME="ibm-zen-ingress-rbac"
  INSTALL_NAMESPACE="${_FLAG_NAMESPACE:-${INSTALL_NAMESPACE:-cp4aiops}}"
  OLM_NAMESPACE="${_FLAG_OLM_NAMESPACE:-${OLM_NAMESPACE:-olm}}"
  IA_CATALOGSOURCE_URL="${_FLAG_CATALOGSOURCE_URL:-${IA_CATALOGSOURCE_URL:-${DEFAULT_IA_CATALOGSOURCE_URL}}}"
  CATALOG_NAME="${_FLAG_CATALOG_NAME:-${CATALOG_NAME:-ibm-aiops-ia-catalog}}"
  IA_CHANNEL="${_FLAG_IA_CHANNEL:-${IA_CHANNEL:-${DEFAULT_IA_CHANNEL}}}"
  IBM_CERT_MANAGER_CHANNEL="${_FLAG_CERT_MANAGER_CHANNEL:-${IBM_CERT_MANAGER_CHANNEL:-v4.2}}"
  IBM_LICENSING_CHANNEL="${_FLAG_LICENSING_CHANNEL:-${IBM_LICENSING_CHANNEL:-v4.2}}"
  IBM_CERT_MANAGER_NS="${_FLAG_CERT_MANAGER_NS:-${IBM_CERT_MANAGER_NS:-ibm-cert-manager}}"
  IBM_LICENSING_NS="${_FLAG_LICENSING_NS:-${IBM_LICENSING_NS:-ibm-licensing}}"
  PULL_SECRETS_CONF="${_FLAG_PULL_SECRETS_CONF:-${PULL_SECRETS_CONF:-${SCRIPT_DIR}/pull-secrets.conf}}"
  readonly PULL_SECRET="ibm-entitlement-key"

  # Kubeconfig priority: --kubeconfig, $KUBECONFIG, k3s default, kubectl default.
  local kc="${_FLAG_KUBECONFIG:-}"
  if [[ -n "${kc}" ]]; then
    [[ -f "${kc}" ]] || die "Kubeconfig not found: ${kc}"
    KUBECTL_ARGS=(--kubeconfig "${kc}")
    export KUBECONFIG="${kc}"
  elif [[ -n "${KUBECONFIG:-}" ]]; then
    KUBECTL_ARGS=(--kubeconfig "${KUBECONFIG}")
  elif [[ -f "/etc/rancher/k3s/k3s.yaml" ]]; then
    KUBECTL_ARGS=(--kubeconfig "/etc/rancher/k3s/k3s.yaml")
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
    info "Using k3s default kubeconfig: /etc/rancher/k3s/k3s.yaml"
  fi
}

confirm_defaults() {
  [[ "${YES}" == "true" ]] && return 0
  [[ -t 0 ]]              || return 0   # stdin is not a tty

  echo ""
  echo "  install-operator.sh configuration summary"
  echo "  ============================================"
  printf "  %-28s %s\n" "INSTALL_NAMESPACE"        "${INSTALL_NAMESPACE}"
  printf "  %-28s %s\n" "OLM_NAMESPACE"            "${OLM_NAMESPACE}"
  printf "  %-28s %s\n" "IA_CATALOGSOURCE_URL"     "${IA_CATALOGSOURCE_URL}"
  printf "  %-28s %s\n" "CATALOG_NAME"             "${CATALOG_NAME}"
  printf "  %-28s %s\n" "IA_CHANNEL"               "${IA_CHANNEL}"
  printf "  %-28s %s\n" "IBM_CERT_MANAGER_CHANNEL" "${IBM_CERT_MANAGER_CHANNEL}"
  printf "  %-28s %s\n" "IBM_LICENSING_CHANNEL"    "${IBM_LICENSING_CHANNEL}"
  printf "  %-28s %s\n" "IBM_CERT_MANAGER_NS"      "${IBM_CERT_MANAGER_NS}"
  printf "  %-28s %s\n" "IBM_LICENSING_NS"         "${IBM_LICENSING_NS}"
  printf "  %-28s %s\n" "PULL_SECRETS_CONF"        "${PULL_SECRETS_CONF}"
  [[ "${DRY_RUN}" == "true" ]] && printf "  %-28s %s\n" "Mode" "DRY RUN"
  echo "  ============================================"
  echo ""
  echo "  Proceed with these settings? [y/N] "
  read -r answer
  case "${answer}" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo "Aborted."; exit 0 ;;
  esac
}

kctl() { kubectl "${KUBECTL_ARGS[@]}" "$@"; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_namespace() {
  kctl create namespace "$1" --dry-run=client -o yaml | kctl apply -f -
}

wait_for_deployment() {
  local ns="$1" deploy="$2" timeout="$3"
  info "Waiting for Deployment ${ns}/${deploy} (up to ${timeout}s) ..."
  local deadline=$(( $(date +%s) + timeout ))
  while true; do
    local avail
    avail=$(kctl get deployment "${deploy}" -n "${ns}" \
      -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    [[ "${avail}" -ge 1 ]] && { info "Deployment ${ns}/${deploy} is ready."; return 0; }
    (( $(date +%s) < deadline )) || {
      warn "Timed out waiting for Deployment ${ns}/${deploy}."
      return 1
    }
    sleep 5
  done
}

wait_for_catalogsource() {
  local name="$1" ns="$2" timeout="$3"
  info "Waiting for CatalogSource ${ns}/${name} to be READY (up to ${timeout}s) ..."
  local deadline=$(( $(date +%s) + timeout ))
  while true; do
    local state
    state=$(kctl get catalogsource "${name}" -n "${ns}" \
      -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || true)
    [[ "${state}" == "READY" ]] && { info "CatalogSource ${ns}/${name} is READY."; return 0; }
    (( $(date +%s) < deadline )) || {
      warn "Timed out waiting for CatalogSource ${ns}/${name} (last state: ${state:-unknown})."
      return 1
    }
    sleep 5
  done
}

# requires_pull_secret <package>
# Returns 0 if the package needs a pull secret, 1 if it uses public images.
# IBM cert-manager and License Service pull from public registries; all other
# IBM operators pull from icr.io and need ibm-entitlement-key.
requires_pull_secret() {
  case "$1" in
    ibm-cert-manager-operator|ibm-licensing-operator-app) return 1 ;;
    *) return 0 ;;
  esac
}

# verify_pull_secret <namespace> <secret>
# Exits with a clear message if the pull secret is absent or the wrong type,
# rather than letting the operator pod fail later with ImagePullBackOff.
verify_pull_secret() {
  local ns="$1" secret="$2" secret_type
  secret_type="$(kctl get secret "${secret}" -n "${ns}" \
    -o jsonpath='{.type}' 2>/dev/null)" \
    || die "Pull secret ${ns}/${secret} does not exist"
  case "${secret_type}" in
    kubernetes.io/dockerconfigjson|kubernetes.io/dockercfg) ;;
    *) die "Secret ${ns}/${secret} has unsupported type: ${secret_type}" ;;
  esac
}

# apply_operatorgroup <namespace> <package> <og_targets>
# og_targets: "global", a single namespace, or a comma-separated list.
# Global scope (empty targetNamespaces) is required for cluster-wide operators
# such as IBM cert-manager; namespace scope restricts watch to listed namespaces.
apply_operatorgroup() {
  local ns="$1" pkg="$2" og_targets="$3"
  local og_name="${pkg%-operator}-operatorgroup"

  if [[ "${og_targets}" == "global" ]]; then
    kctl apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${og_name}
  namespace: ${ns}
spec: {}
EOF
    return 0
  fi

  local target target_yaml=""
  IFS=',' read -r -a _og_targets <<< "${og_targets}"
  for target in "${_og_targets[@]}"; do
    target="${target#"${target%%[![:space:]]*}"}"
    target="${target%"${target##*[![:space:]]}"}"
    [[ -n "${target}" ]] || continue
    ensure_namespace "${target}"
    target_yaml+="    - ${target}"$'\n'
  done
  [[ -n "${target_yaml}" ]] || die "No valid OperatorGroup targets in: ${og_targets}"

  kctl apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${og_name}
  namespace: ${ns}
spec:
  targetNamespaces:
${target_yaml%$'\n'}
EOF
}

# apply_subscription <namespace> <package> <channel>
apply_subscription() {
  local ns="$1" pkg="$2" channel="$3"
  kctl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${pkg}
  namespace: ${ns}
spec:
  channel: ${channel}
  name: ${pkg}
  source: ${CATALOG_NAME}
  sourceNamespace: ${OLM_NAMESPACE}
  installPlanApproval: Automatic
EOF
}

# wait_for_csv <namespace> <package>
# Polls until the CSV exists on the cluster; prints its name on stdout.
# Prefers installedCSV (fully reconciled) but accepts currentCSV early on.
wait_for_csv() {
  local ns="$1" pkg="$2" elapsed=0 csv=""
  local timeout="${OPERATOR_TIMEOUT:-300}"
  while (( elapsed < timeout )); do
    csv="$(kctl get subscription "${pkg}" -n "${ns}" \
      -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)"
    [[ -z "${csv}" ]] && csv="$(kctl get subscription "${pkg}" -n "${ns}" \
      -o jsonpath='{.status.currentCSV}' 2>/dev/null || true)"
    if [[ -n "${csv}" ]] && kctl get csv "${csv}" -n "${ns}" >/dev/null 2>&1; then
      printf '%s\n' "${csv}"
      return 0
    fi
    sleep 5; elapsed=$(( elapsed + 5 ))
  done
  kctl get subscription,installplan,csv -n "${ns}" || true
  die "Timed out waiting for CSV for ${pkg} in ${ns}"
}

# attach_pull_secret_to_deployment <namespace> <deployment> <secret>
# Strategic-merge patches imagePullSecrets; skips if already present.
attach_pull_secret_to_deployment() {
  local ns="$1" deploy="$2" secret="$3" existing patch
  existing="$(kctl get deployment "${deploy}" -n "${ns}" \
    -o jsonpath='{.spec.template.spec.imagePullSecrets[*].name}' 2>/dev/null || true)"
  [[ " ${existing} " == *" ${secret} "* ]] && return 0
  info "Adding ${secret} to Deployment ${ns}/${deploy} ..."
  printf -v patch \
    '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"%s"}]}}}}' "${secret}"
  kctl patch deployment "${deploy}" -n "${ns}" --type=strategic --patch "${patch}"
}

# configure_operator_pull_secrets <namespace> <csv> <secret>
# Waits for every Deployment defined in the CSV to exist, then attaches the
# pull secret to each one so pods do not hit ImagePullBackOff on first start.
configure_operator_pull_secrets() {
  local ns="$1" csv="$2" secret="$3" deploy elapsed=0 deploys=""
  local timeout="${OPERATOR_TIMEOUT:-300}"
  while (( elapsed < timeout )); do
    deploys="$(kctl get csv "${csv}" -n "${ns}" \
      -o jsonpath='{range .spec.install.spec.deployments[*]}{.name}{"\n"}{end}' \
      2>/dev/null || true)"
    if [[ -n "${deploys}" ]]; then
      local all=true
      while IFS= read -r deploy; do
        [[ -n "${deploy}" ]] || continue
        kctl get deployment "${deploy}" -n "${ns}" >/dev/null 2>&1 || { all=false; break; }
      done <<< "${deploys}"
      [[ "${all}" == "true" ]] && break
    fi
    sleep 5; elapsed=$(( elapsed + 5 ))
  done
  [[ -n "${deploys}" ]] || die "Timed out waiting for Deployments listed in CSV ${csv}"
  while IFS= read -r deploy; do
    [[ -n "${deploy}" ]] || continue
    attach_pull_secret_to_deployment "${ns}" "${deploy}" "${secret}"
  done <<< "${deploys}"
}

# wait_for_csv_succeeded <namespace> <csv>
# Polls the CSV phase until Succeeded; exits immediately on Failed.
wait_for_csv_succeeded() {
  local ns="$1" csv="$2" elapsed=0 phase=""
  local timeout="${OPERATOR_TIMEOUT:-300}"
  while (( elapsed < timeout )); do
    phase="$(kctl get csv "${csv}" -n "${ns}" \
      -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    info "CSV ${csv}: phase=${phase:-Unknown}"
    case "${phase}" in
      Succeeded) return 0 ;;
      Failed)
        kctl describe csv "${csv}" -n "${ns}" || true
        die "CSV ${csv} failed" ;;
    esac
    sleep 10; elapsed=$(( elapsed + 10 ))
  done
  kctl describe csv "${csv}" -n "${ns}" || true
  kctl get subscription,installplan,csv,pods -n "${ns}" || true
  die "Timed out waiting for CSV ${csv} to succeed"
}

# wait_for_operator_deployments <namespace> <csv>
# Uses kubectl rollout status to confirm every Deployment in the CSV is available.
wait_for_operator_deployments() {
  local ns="$1" csv="$2" deploy deploys
  local timeout="${OPERATOR_TIMEOUT:-300}"
  deploys="$(kctl get csv "${csv}" -n "${ns}" \
    -o jsonpath='{range .spec.install.spec.deployments[*]}{.name}{"\n"}{end}')"
  [[ -n "${deploys}" ]] || die "CSV ${csv} defines no Deployments"
  while IFS= read -r deploy; do
    [[ -n "${deploy}" ]] || continue
    info "Waiting for Deployment ${ns}/${deploy} ..."
    kctl rollout status "deployment/${deploy}" -n "${ns}" \
      --timeout="${timeout}s" || {
        kctl describe deployment "${deploy}" -n "${ns}" || true
        kctl get pods -n "${ns}" -o wide || true
        die "Deployment ${ns}/${deploy} did not become available"
      }
  done <<< "${deploys}"
}

# apply_operator_subscription <namespace> <package> <channel> <og_targets>
# Runs the full OLM subscription sequence: OperatorGroup, Subscription, CSV
# wait, pull-secret attachment, CSV succeeded, Deployment rollout.
apply_operator_subscription() {
  local ns="$1" pkg="$2" channel="$3" og_targets="$4"

  info "Subscribing to ${pkg} in namespace ${ns} (channel: ${channel}) ..."

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would subscribe ${pkg} in ${ns} (channel: ${channel})"
    return 0
  fi

  if requires_pull_secret "${pkg}"; then
    verify_pull_secret "${ns}" "${PULL_SECRET}"
  fi

  apply_operatorgroup "${ns}" "${pkg}" "${og_targets}"
  apply_subscription  "${ns}" "${pkg}" "${channel}"

  local csv
  csv="$(wait_for_csv "${ns}" "${pkg}")"

  if requires_pull_secret "${pkg}"; then
    configure_operator_pull_secrets "${ns}" "${csv}" "${PULL_SECRET}"
  fi

  wait_for_csv_succeeded      "${ns}" "${csv}"
  wait_for_operator_deployments "${ns}" "${csv}"
}

# Config file format (pull-secrets.conf); blank lines and '#' lines are ignored:
#   namespace|secret-name|registry|username|password|email
build_dockerconfigjson() {
  local config_file="$1"
  local target_ns="$2"
  local target_secret="$3"
  local first_entry=true

  printf '{\n  "auths": {\n'

  while IFS='|' read -r line_ns line_secret line_registry line_user line_password line_email; do
    [[ "${line_ns}" == "${target_ns}" && "${line_secret}" == "${target_secret}" ]] || continue

    local token
    token=$(printf '%s:%s' "${line_user}" "${line_password}" | base64 -w0 2>/dev/null \
            || printf '%s:%s' "${line_user}" "${line_password}" | base64)

    if [[ "${first_entry}" == true ]]; then
      first_entry=false
    else
      printf ',\n'
    fi

    printf '    "%s": {\n'      "${line_registry}"
    printf '      "username": "%s",\n' "${line_user}"
    printf '      "password": "%s",\n' "${line_password}"
    printf '      "email": "%s",\n'    "${line_email}"
    printf '      "auth": "%s"\n'      "${token}"
    printf '    }'
  done < <(grep -v '^\s*#' "${config_file}" | grep -v '^\s*$')

  printf '\n  }\n}\n'
}

create_pull_secret() {
  local ns="$1"
  local secret="$2"
  local tmp_json

  tmp_json="$(mktemp)"
  info "  Creating secret ${ns}/${secret} from ${PULL_SECRETS_CONF}"

  ensure_namespace "${ns}"
  build_dockerconfigjson "${PULL_SECRETS_CONF}" "${ns}" "${secret}" > "${tmp_json}"

  kctl create secret generic "${secret}" \
    -n "${ns}" \
    --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson="${tmp_json}" \
    --dry-run=client -o yaml | kctl apply -f -

  rm -f "${tmp_json}"
}

# ---------------------------------------------------------------------------
# OLM install helpers (logic formerly in install-aiops-version-olm-k3s.sh)
# ---------------------------------------------------------------------------

olm_manifest_has_kubernetes_objects() {
  local f="$1"
  [[ -s "${f}" ]] || return 1
  grep -Eq '^[[:space:]]*apiVersion:[[:space:]]*[^[:space:]]+' "${f}" || return 1
  grep -Eq '^[[:space:]]*kind:[[:space:]]*[^[:space:]]+' "${f}" || return 1
}

olm_manifest_is_html() {
  grep -Eiq '^[[:space:]]*(<!DOCTYPE html|<html|<head|<body|<\?xml)' "$1"
}

olm_validate_manifest() {
  local label="$1" f="$2"
  [[ -f "${f}" ]] || die "${label} manifest does not exist: ${f}"
  [[ -s "${f}" ]] || die "${label} manifest is empty: ${f}"
  if olm_manifest_is_html "${f}"; then
    head -n 10 "${f}" >&2 || true
    die "${label} manifest contains HTML or XML instead of Kubernetes YAML"
  fi
  if ! olm_manifest_has_kubernetes_objects "${f}"; then
    head -n 20 "${f}" >&2 || true
    die "${label} manifest does not contain Kubernetes apiVersion and kind fields"
  fi
}

olm_download_manifest() {
  local url="$1" dest="$2"
  info "Downloading ${url}"
  curl --fail --silent --show-error --location \
       --retry 3 --retry-delay 2 \
       --output "${dest}" "${url}"
}

olm_select_crds_manifest() {
  local dest="$1" work_dir="$2"
  local local_manifest="${SCRIPT_DIR}/../pkg/serverup/manifests/olm/crd/crds.yaml"
  local download_url="${OLM_RELEASE_BASE_URL}/crds.yaml"

  if [[ -f "${local_manifest}" ]] \
     && olm_manifest_has_kubernetes_objects "${local_manifest}" \
     && ! olm_manifest_is_html "${local_manifest}"; then
    cp "${local_manifest}" "${dest}"
    info "Using local OLM CRD manifest"
  else
    warn "Local OLM CRD manifest not found or invalid -- downloading release CRDs"
    olm_download_manifest "${download_url}" "${dest}"
  fi

  olm_validate_manifest "OLM CRD" "${dest}"
}

olm_select_operator_manifest() {
  local dest="$1" work_dir="$2"
  local local_manifest="${SCRIPT_DIR}/../pkg/serverup/manifests/olm/operator/olm.yaml"
  local raw="${work_dir}/olm-raw.yaml"
  local download_url="${OLM_QUICKSTART_URL}/olm.yaml"

  if [[ -f "${local_manifest}" ]] \
     && olm_manifest_has_kubernetes_objects "${local_manifest}" \
     && ! olm_manifest_is_html "${local_manifest}"; then
    cp "${local_manifest}" "${raw}"
    info "Using local OLM operator manifest"
  else
    warn "Local OLM operator manifest not found or invalid -- downloading"
    olm_download_manifest "${download_url}" "${raw}"
  fi

  olm_validate_manifest "raw OLM operator" "${raw}"
  olm_resolve_operator_manifest "${raw}" "${dest}" "${work_dir}"
  olm_validate_operator_manifest "${dest}"
}

olm_resolve_operator_manifest() {
  local src="$1" dest="$2" work_dir="$3"
  local resolved="${work_dir}/olm-resolved.yaml"

  sed -E \
    -e "s#\\{\\{[[:space:]]*\\.Olm\\.OlmImage[[:space:]]*\\}\\}#${OLM_IMAGE}#g" \
    -e "s#\\{\\{[[:space:]]*\\.Olm\\.OpmImage[[:space:]]*\\}\\}#${OLM_OPM_IMAGE}#g" \
    -e "s#\\{\\{[[:space:]]*\\.Olm\\.Version[[:space:]]*\\}\\}#${OLM_VERSION}#g" \
    -e "s#quay\\.io/operator-framework/olm:[^[:space:]\"'@]+#${OLM_IMAGE}#g" \
    -e "s#quay\\.io/operator-framework/olm@sha256:[^[:space:]\"']+#${OLM_IMAGE}#g" \
    -e "s#quay\\.io/operator-framework/opm:[^[:space:]\"'@]+#${OLM_OPM_IMAGE}#g" \
    -e "s#quay\\.io/operator-framework/opm@sha256:[^[:space:]\"']+#${OLM_OPM_IMAGE}#g" \
    -e "s#-{1,2}configmapServerImage=[^[:space:]\"']+#--configmapServerImage=${OLM_CONFIGMAP_OPERATOR_IMAGE}#g" \
    -e "s#^([ \t]*- )'-namespace'#\1'--namespace'#g" \
    -e "s#^([ \t]*- )-namespace\b#\1--namespace#g" \
    -e "s#^([ \t]*- )-util-image\b#\1--util-image#g" \
    "${src}" >"${resolved}"

  # Inject --opmImage if the upstream manifest omits it (quickstart download
  # fallback).  catalog-operator needs this flag to use OPM for bundle unpacking
  # (gzip, no 1 MB size limit).
  if ! grep -Fq -- '--opmImage' "${resolved}"; then
    info "Upstream manifest has no --opmImage -- injecting OPM image into catalog-operator args"
    local configmap_line indent inject_line tmp="${resolved}.tmp"
    configmap_line=$(grep -m1 'configmapServerImage=' "${resolved}") \
      || die "Could not find configmapServerImage line to inject --opmImage after"
    indent="${configmap_line%%[^ 	]*}"
    inject_line="${indent}- --opmImage=${OLM_OPM_IMAGE}"
    local injected=false
    while IFS= read -r line; do
      printf '%s\n' "${line}"
      if [[ "${injected}" == "false" && "${line}" == *"configmapServerImage="* ]]; then
        printf '%s\n' "${inject_line}"
        injected=true
      fi
    done <"${resolved}" >"${tmp}"
    [[ "${injected}" == "true" ]] || die "Failed to inject --opmImage into resolved OLM manifest"
    mv "${tmp}" "${resolved}"
  fi

  if ! grep -Fq "configmapServerImage=${OLM_CONFIGMAP_OPERATOR_IMAGE}" "${resolved}"; then
    die "Failed to set configmapServerImage in resolved OLM manifest"
  fi

  # Remove the operatorhubio-catalog CatalogSource document.
  awk '
    BEGIN { RS = "---[[:space:]]*\n"; ORS = "" }
    {
      is_cs  = ($0 ~ /kind:[[:space:]]*CatalogSource/)
      is_hub = ($0 ~ /name:[[:space:]]*operatorhubio-catalog/)
      if (!(is_cs && is_hub)) {
        if ($0 ~ /[^[:space:]]/) {
          print "---\n"
          print $0
          if ($0 !~ /\n$/) { print "\n" }
        }
      }
    }
  ' "${resolved}" >"${dest}"
}

olm_validate_operator_manifest() {
  local f="$1"
  olm_validate_manifest "resolved OLM operator" "${f}"
  if ! grep -Eq -- 'opmImage' "${f}"; then
    die "Resolved OLM manifest is missing opmImage (bundle unpacking will fail for large CRDs)"
  fi
  if grep -Eq '\{\{[[:space:]]*\.Olm\.' "${f}"; then
    die "Resolved OLM manifest contains an unresolved template variable"
  fi
  if ! grep -Fq "configmapServerImage=${OLM_CONFIGMAP_OPERATOR_IMAGE}" "${f}"; then
    die "Resolved OLM manifest does not contain the pinned configmapServerImage"
  fi
}

olm_apply_manifest() {
  local label="$1" f="$2" validate="${3:-true}"
  olm_validate_manifest "${label}" "${f}"

  local size doc_count
  size="$(wc -c <"${f}")"
  doc_count="$(grep -Ec '^[[:space:]]*---[[:space:]]*$' "${f}" || true)"
  info "${label}: ${size} bytes, ${doc_count} YAML separators"
  info "Applying: ${label}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '%s\n' "--- DRY RUN: ${label} ---"
    cat "${f}"
    printf '%s\n' '---'
    return 0
  fi

  kctl apply --server-side --force-conflicts --validate="${validate}" -f "${f}" || {
    warn "Failed to apply ${label}"
    head -n 30 "${f}" >&2 || true
    return 1
  }
}

olm_wait_for_crd() {
  local crd="$1"
  info "Waiting for CRD ${crd} (${OLM_CRD_WAIT_TIMEOUT}) ..."
  [[ "${DRY_RUN}" == "true" ]] && return 0
  local timeout_secs="${OLM_CRD_WAIT_TIMEOUT%s}"
  local deadline=$(( $(date +%s) + timeout_secs ))
  while true; do
    local status
    status=$(kctl get crd "${crd}" \
      -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' \
      2>/dev/null || true)
    [[ "${status}" == "True" ]] && { info "CRD established: ${crd}"; return 0; }
    (( $(date +%s) < deadline )) || {
      info "ERROR: timed out waiting for CRD ${crd} to be Established"
      return 1
    }
    sleep 3
  done
}

olm_show_failure_status() {
  warn "OLM installation status:"
  kctl get namespace olm 2>/dev/null || true
  kctl get deployment,pod --namespace olm -o wide 2>/dev/null || true
  kctl get events --namespace olm --sort-by='.lastTimestamp' 2>/dev/null | tail -n 30 || true
}

# Skipped if olm-operator and catalog-operator are already available.
# Otherwise installs OLM inline using the IBM mirror images.
step_olm() {
  info "=== Step 1/7: OLM check / install ==="

  local olm_ready=true
  for deploy in olm-operator catalog-operator; do
    local available
    available=$(kctl get deployment "${deploy}" -n "${OLM_NAMESPACE}" \
      -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    [[ "${available}" -ge 1 ]] || { olm_ready=false; break; }
  done

  if [[ "${olm_ready}" == "true" ]]; then
    info "OLM is already running in namespace ${OLM_NAMESPACE}. Skipping install."
    STEP_STATUS[olm]="PASS"
    return 0
  fi

  info "OLM not detected or not ready. Installing OLM ${OLM_VERSION} ..."
  info "  OLM image            : ${OLM_IMAGE}"
  info "  OPM image            : ${OLM_OPM_IMAGE}"
  info "  configmapServerImage : ${OLM_CONFIGMAP_OPERATOR_IMAGE}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would install OLM ${OLM_VERSION}"
    STEP_STATUS[olm]="PASS"
    return 0
  fi

  local work_dir
  work_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${work_dir}'" RETURN

  local crds_manifest="${work_dir}/crds.yaml"
  local operator_manifest="${work_dir}/olm.yaml"

  olm_select_crds_manifest    "${crds_manifest}"    "${work_dir}"
  olm_select_operator_manifest "${operator_manifest}" "${work_dir}"

  info "OLM sub-step 1/4: Apply OLM CRDs"
  if ! olm_apply_manifest "OLM CRDs" "${crds_manifest}" false; then
    STEP_STATUS[olm]="FAIL"
    return 1
  fi

  info "OLM sub-step 2/4: Wait for OLM CRDs"
  local crd
  for crd in \
      subscriptions.operators.coreos.com \
      clusterserviceversions.operators.coreos.com \
      catalogsources.operators.coreos.com \
      olmconfigs.operators.coreos.com; do
    if ! olm_wait_for_crd "${crd}"; then
      STEP_STATUS[olm]="FAIL"
      return 1
    fi
  done

  info "OLM sub-step 3/4: Apply OLM operator manifest"
  if ! olm_apply_manifest "OLM operator" "${operator_manifest}" true; then
    STEP_STATUS[olm]="FAIL"
    return 1
  fi

  info "OLM sub-step 4/4: Wait for OLM deployments"
  local deadline=$(( $(date +%s) + OLM_DEPLOY_TIMEOUT ))
  for deploy in olm-operator catalog-operator; do
    info "Waiting for Deployment olm/${deploy} (up to ${OLM_DEPLOY_TIMEOUT}s) ..."
    while true; do
      local avail
      avail=$(kctl get deployment "${deploy}" -n olm \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
      [[ "${avail}" -ge 1 ]] && { info "Deployment olm/${deploy} is ready."; break; }
      (( $(date +%s) < deadline )) || {
        olm_show_failure_status
        warn "Timed out waiting for olm/${deploy}."
        STEP_STATUS[olm]="FAIL"
        return 1
      }
      sleep 5
    done
  done

  STEP_STATUS[olm]="PASS"
}

# Creates ibm-entitlement-key from PULL_SECRETS_CONF in each required namespace
# where it is missing.
step_pull_secrets() {
  info "=== Step 2/7: Pull secrets ==="

  local -a required_namespaces=("${OLM_NAMESPACE}" "${INSTALL_NAMESPACE}")

  local -a unique_namespaces=()
  declare -A _seen=()
  for ns in "${required_namespaces[@]}"; do
    [[ -z "${_seen[${ns}]+set}" ]] || continue
    _seen[${ns}]=1
    unique_namespaces+=("${ns}")
  done

  local -a missing=()
  for ns in "${unique_namespaces[@]}"; do
    if kctl get secret "${PULL_SECRET}" -n "${ns}" >/dev/null 2>&1; then
      info "Secret '${PULL_SECRET}' already exists in namespace '${ns}'. Skipping."
    else
      info "Secret '${PULL_SECRET}' not found in namespace '${ns}'. Will create."
      missing+=("${ns}")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    info "Secret '${PULL_SECRET}' present in all required namespaces."
    STEP_STATUS[pull_secrets]="PASS"
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would create '${PULL_SECRET}' in namespaces: ${missing[*]}"
    STEP_STATUS[pull_secrets]="PASS"
    return 0
  fi

  [[ -f "${PULL_SECRETS_CONF}" ]] \
    || die "Secret '${PULL_SECRET}' missing in: ${missing[*]}." \
           "Provide ${PULL_SECRETS_CONF} (copy from pull-secrets.conf.template) or" \
           "pre-create the secret manually in those namespaces and re-run."

  for ns in "${missing[@]}"; do
    create_pull_secret "${ns}" "${PULL_SECRET}"
  done

  local failed=false
  for ns in "${missing[@]}"; do
    if kctl get secret "${PULL_SECRET}" -n "${ns}" >/dev/null 2>&1; then
      info "Secret '${PULL_SECRET}' confirmed in namespace '${ns}'."
    else
      warn "Secret '${PULL_SECRET}' still missing in namespace '${ns}' after creation."
      warn "Check that ${PULL_SECRETS_CONF} contains an entry for namespace '${ns}'."
      failed=true
    fi
  done

  [[ "${failed}" == "false" ]] || { STEP_STATUS[pull_secrets]="FAIL"; return 1; }
  STEP_STATUS[pull_secrets]="PASS"
}

step_catalogsource() {
  info "=== Step 3/7: IBM IA CatalogSource ==="
  info "  Name      : ${CATALOG_NAME}"
  info "  Image     : ${IA_CATALOGSOURCE_URL}"
  info "  Namespace : ${OLM_NAMESPACE}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would apply CatalogSource ${OLM_NAMESPACE}/${CATALOG_NAME}."
    STEP_STATUS[catalogsource]="PASS"
    return 0
  fi

  kctl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOG_NAME}
  namespace: ${OLM_NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: install-operator
spec:
  sourceType: grpc
  image: ${IA_CATALOGSOURCE_URL}
  displayName: IBM AIops IA Catalog
  publisher: IBM
  secrets:
  - ${PULL_SECRET}
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

  if ! wait_for_catalogsource "${CATALOG_NAME}" "${OLM_NAMESPACE}" 300; then
    STEP_STATUS[catalogsource]="FAIL"
    return 1
  fi

  STEP_STATUS[catalogsource]="PASS"
}

step_cert_manager() {
  info "=== Step 4/7: IBM cert-manager ==="

  if kctl api-groups 2>/dev/null | grep -q "^cert-manager\.io$"; then
    info "cert-manager.io/v1 API group already present. Skipping cert-manager install."
    STEP_STATUS[cert_manager]="PASS"
    return 0
  fi

  info "No cert-manager detected. Installing IBM cert-manager ..."
  info "  Namespace : ${IBM_CERT_MANAGER_NS}"
  info "  Channel   : ${IBM_CERT_MANAGER_CHANNEL}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would subscribe ibm-cert-manager-operator in ${IBM_CERT_MANAGER_NS}."
    STEP_STATUS[cert_manager]="PASS"
    return 0
  fi

  ensure_namespace "${IBM_CERT_MANAGER_NS}"

  if ! apply_operator_subscription \
      "${IBM_CERT_MANAGER_NS}" \
      "ibm-cert-manager-operator" \
      "${IBM_CERT_MANAGER_CHANNEL}" \
      "global"; then
    STEP_STATUS[cert_manager]="FAIL"
    return 1
  fi

  if ! wait_for_deployment "${IBM_CERT_MANAGER_NS}" "cert-manager-webhook" 300; then
    warn "cert-manager webhook did not become ready."
    STEP_STATUS[cert_manager]="FAIL"
    return 1
  fi

  info "IBM cert-manager installed and webhook ready."
  STEP_STATUS[cert_manager]="PASS"
}

step_license_service() {
  info "=== Step 5/7: IBM License Service ==="
  info "  Namespace : ${IBM_LICENSING_NS}"
  info "  Channel   : ${IBM_LICENSING_CHANNEL}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would subscribe ibm-licensing-operator-app in ${IBM_LICENSING_NS}."
    STEP_STATUS[license_service]="PASS"
    return 0
  fi

  ensure_namespace "${IBM_LICENSING_NS}"

  if ! apply_operator_subscription \
      "${IBM_LICENSING_NS}" \
      "ibm-licensing-operator-app" \
      "${IBM_LICENSING_CHANNEL}" \
      "${IBM_LICENSING_NS},${INSTALL_NAMESPACE}"; then
    STEP_STATUS[license_service]="FAIL"
    return 1
  fi

  STEP_STATUS[license_service]="PASS"
}

# Grants the Zen operator ServiceAccount the access it needs on a CNCF cluster:
# cluster-scoped read of StorageClasses and Namespaces, and namespace-scoped
# Ingress management in INSTALL_NAMESPACE. The ServiceAccount need not exist yet;
# the bindings take effect once Zen creates it. Mirrors zen-rbac-k3s.sh.
step_zen_rbac() {
  info "=== Step 6/7: Zen RBAC ==="
  info "  Namespace       : ${INSTALL_NAMESPACE}"
  info "  Service Account : ${ZEN_SA}"
  info "  Cluster RBAC    : ${ZEN_RBAC_NAME}"
  info "  Ingress RBAC    : ${ZEN_INGRESS_RBAC_NAME}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would apply ClusterRole/ClusterRoleBinding ${ZEN_RBAC_NAME} (storageclasses, namespaces: get/list/watch)."
    info "[DRY RUN] Would apply Role/RoleBinding ${ZEN_INGRESS_RBAC_NAME} in ${INSTALL_NAMESPACE} (ingresses: full access)."
    STEP_STATUS[zen_rbac]="PASS"
    return 0
  fi

  ensure_namespace "${INSTALL_NAMESPACE}"

  if ! kctl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${ZEN_RBAC_NAME}
  labels:
    app.kubernetes.io/managed-by: install-operator
rules:
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ZEN_RBAC_NAME}
  labels:
    app.kubernetes.io/managed-by: install-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${ZEN_RBAC_NAME}
subjects:
- kind: ServiceAccount
  name: ${ZEN_SA}
  namespace: ${INSTALL_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${ZEN_INGRESS_RBAC_NAME}
  namespace: ${INSTALL_NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: install-operator
rules:
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ZEN_INGRESS_RBAC_NAME}
  namespace: ${INSTALL_NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: install-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${ZEN_INGRESS_RBAC_NAME}
subjects:
- kind: ServiceAccount
  name: ${ZEN_SA}
  namespace: ${INSTALL_NAMESPACE}
EOF
  then
    warn "Failed to apply Zen RBAC."
    STEP_STATUS[zen_rbac]="FAIL"
    return 1
  fi

  local identity="system:serviceaccount:${INSTALL_NAMESPACE}:${ZEN_SA}"
  local failed=false verb
  for verb in get list watch; do
    for res in storageclasses.storage.k8s.io namespaces; do
      if [[ "$(kctl auth can-i "${verb}" "${res}" --as="${identity}" 2>/dev/null || true)" != "yes" ]]; then
        warn "${identity} cannot ${verb} ${res}."
        failed=true
      fi
    done
  done
  for verb in get list watch create update patch delete; do
    if [[ "$(kctl auth can-i "${verb}" ingresses.networking.k8s.io \
          -n "${INSTALL_NAMESPACE}" --as="${identity}" 2>/dev/null || true)" != "yes" ]]; then
      warn "${identity} cannot ${verb} ingresses in ${INSTALL_NAMESPACE}."
      failed=true
    fi
  done

  [[ "${failed}" == "false" ]] || { STEP_STATUS[zen_rbac]="FAIL"; return 1; }
  info "Zen RBAC applied and verified for ${identity}."
  STEP_STATUS[zen_rbac]="PASS"
}

step_ia_operator() {
  info "=== Step 7/7: IBM IA operator ==="
  info "  Namespace : ${INSTALL_NAMESPACE}"
  info "  Channel   : ${IA_CHANNEL}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would subscribe ibm-infrastructure-automation-operator in ${INSTALL_NAMESPACE}."
    STEP_STATUS[ia_operator]="PASS"
    return 0
  fi

  ensure_namespace "${INSTALL_NAMESPACE}"

  if ! apply_operator_subscription \
      "${INSTALL_NAMESPACE}" \
      "ibm-infrastructure-automation-operator" \
      "${IA_CHANNEL}" \
      "${INSTALL_NAMESPACE}"; then
    STEP_STATUS[ia_operator]="FAIL"
    return 1
  fi

  STEP_STATUS[ia_operator]="PASS"
}

print_summary() {
  local all_passed=true

  echo ""
  echo "=========================================="
  echo "  install-operator.sh Summary"
  echo "=========================================="
  printf "  %-32s %s\n" "Step" "Status"
  printf "  %-32s %s\n" "--------------------------------" "------"

  local -a ordered_steps=(olm pull_secrets catalogsource cert_manager license_service zen_rbac ia_operator)
  local -a labels=(
    "1. OLM check / install"
    "2. Pull secrets"
    "3. IBM IA CatalogSource"
    "4. IBM cert-manager"
    "5. IBM License Service"
    "6. Zen RBAC"
    "7. IBM IA operator"
  )

  local i=0
  for step in "${ordered_steps[@]}"; do
    local status="${STEP_STATUS[${step}]}"
    printf "  %-32s %s\n" "${labels[$i]}" "${status}"
    [[ "${status}" == "PASS" ]] || all_passed=false
    (( i++ )) || true
  done

  echo "=========================================="
  echo ""

  if [[ "${all_passed}" == "true" ]]; then
    info "All steps completed successfully."
    info "Next step: apply the IAConfig CR to trigger the IA operator install."
    info "  kubectl apply -f iaconfig.yaml -n ${INSTALL_NAMESPACE}"
  else
    warn "One or more steps FAILED. Resolve the issues above and re-run."
  fi

  info "Log file: ${LOG_FILE}"
  echo ""

  [[ "${all_passed}" == "true" ]]
}

main() {
  exec > >(tee -a "${LOG_FILE}") 2>&1

  parse_args "$@"
  resolve_config
  confirm_defaults

  require_command kubectl
  require_command awk
  require_command curl
  require_command grep
  require_command sed
  require_command base64

  info "Log file: ${LOG_FILE}"
  info "install-operator.sh starting"
  info "  INSTALL_NAMESPACE        : ${INSTALL_NAMESPACE}"
  info "  OLM_NAMESPACE            : ${OLM_NAMESPACE}"
  info "  IA_CATALOGSOURCE_URL     : ${IA_CATALOGSOURCE_URL}"
  info "  CATALOG_NAME             : ${CATALOG_NAME}"
  info "  IA_CHANNEL               : ${IA_CHANNEL}"
  info "  IBM_CERT_MANAGER_CHANNEL : ${IBM_CERT_MANAGER_CHANNEL}"
  info "  IBM_LICENSING_CHANNEL    : ${IBM_LICENSING_CHANNEL}"
  info "  IBM_CERT_MANAGER_NS      : ${IBM_CERT_MANAGER_NS}"
  info "  IBM_LICENSING_NS         : ${IBM_LICENSING_NS}"
  info "  PULL_SECRETS_CONF        : ${PULL_SECRETS_CONF}"
  [[ "${DRY_RUN}" == "true" ]] && info "  Mode                     : DRY RUN"
  echo ""

  if [[ "${DRY_RUN}" != "true" ]]; then
    kctl cluster-info >/dev/null 2>&1 || die "Cannot connect to the Kubernetes cluster."
  fi

  step_olm             || true
  step_pull_secrets    || true
  step_catalogsource   || true
  step_cert_manager    || true
  step_license_service || true
  step_zen_rbac        || true
  step_ia_operator     || true

  print_summary
}

main "$@"
