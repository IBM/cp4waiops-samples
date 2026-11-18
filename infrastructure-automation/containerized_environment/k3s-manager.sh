#!/usr/bin/env bash
set -Eeuo pipefail

# k3s-manager.sh
# Install, uninstall, or inspect a single-node K3s server.
#
# Usage:
#   sudo ./k3s-manager.sh install
#   sudo ./k3s-manager.sh install --version v1.33.3+k3s1
#   sudo ./k3s-manager.sh install --channel stable
#   sudo ./k3s-manager.sh status
#   sudo ./k3s-manager.sh uninstall
#   sudo ./k3s-manager.sh uninstall --yes
#
# Environment overrides:
#   K3S_CHANNEL=stable
#   K3S_VERSION=vX.Y.Z+k3s1
#   K3S_INSTALL_EXEC="server --write-kubeconfig-mode 644"
#   DISABLE_FIREWALL=true
#   RUN_DNF_UPDATE=false

readonly STATE_DIR="/var/lib/k3s-manager"
readonly STATE_FILE="${STATE_DIR}/state.env"
readonly INSTALL_URL="https://get.k3s.io"

ACTION="${1:-}"
shift || true

K3S_CHANNEL="${K3S_CHANNEL:-stable}"
K3S_VERSION="${K3S_VERSION:-}"
K3S_INSTALL_EXEC="${K3S_INSTALL_EXEC:-server}"
DISABLE_FIREWALL="${DISABLE_FIREWALL:-true}"
RUN_DNF_UPDATE="${RUN_DNF_UPDATE:-false}"
ASSUME_YES=false

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  sudo ./k3s-manager.sh install [options]
  sudo ./k3s-manager.sh uninstall [--yes]
  sudo ./k3s-manager.sh status

Install options:
  --channel CHANNEL     K3s release channel (default: stable)
  --version VERSION     Install a specific K3s version
  --exec "ARGS"         K3s server arguments
  --dnf-update          Run "dnf update -y" before installation
  --keep-firewalld      Do not disable firewalld

Uninstall options:
  --yes                 Skip destructive-action confirmation

Examples:
  sudo ./k3s-manager.sh install
  sudo ./k3s-manager.sh install --version 'v1.33.3+k3s1'
  sudo ./k3s-manager.sh install --exec 'server --disable traefik'
  sudo ./k3s-manager.sh uninstall --yes
EOF
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script as root or with sudo."
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --channel)
        [[ $# -ge 2 ]] || die "--channel requires a value."
        K3S_CHANNEL="$2"
        shift 2
        ;;
      --version)
        [[ $# -ge 2 ]] || die "--version requires a value."
        K3S_VERSION="$2"
        shift 2
        ;;
      --exec)
        [[ $# -ge 2 ]] || die "--exec requires a value."
        K3S_INSTALL_EXEC="$2"
        shift 2
        ;;
      --dnf-update)
        RUN_DNF_UPDATE=true
        shift
        ;;
      --keep-firewalld)
        DISABLE_FIREWALL=false
        shift
        ;;
      --yes|-y)
        ASSUME_YES=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

save_firewalld_state() {
  mkdir -p "${STATE_DIR}"
  chmod 700 "${STATE_DIR}"

  local enabled="not-found"
  local active="not-found"

  if systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
    enabled="$(systemctl is-enabled firewalld 2>/dev/null || true)"
    active="$(systemctl is-active firewalld 2>/dev/null || true)"
  fi

  cat >"${STATE_FILE}" <<EOF
FIREWALLD_PREVIOUS_ENABLED=${enabled}
FIREWALLD_PREVIOUS_ACTIVE=${active}
EOF
  chmod 600 "${STATE_FILE}"
}

restore_firewalld_state() {
  [[ -f "${STATE_FILE}" ]] || {
    warn "No saved firewalld state was found; leaving firewalld unchanged."
    return
  }

  # shellcheck disable=SC1090
  source "${STATE_FILE}"

  if ! systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
    warn "firewalld is not installed; nothing to restore."
    return
  fi

  case "${FIREWALLD_PREVIOUS_ENABLED:-}" in
    enabled)
      systemctl enable firewalld >/dev/null
      ;;
    disabled)
      systemctl disable firewalld >/dev/null
      ;;
  esac

  case "${FIREWALLD_PREVIOUS_ACTIVE:-}" in
    active)
      systemctl start firewalld
      ;;
    inactive|failed)
      systemctl stop firewalld
      ;;
  esac

  log "Restored the saved firewalld state."
}

install_dependencies() {
  if command_exists dnf; then
    if [[ "${RUN_DNF_UPDATE}" == "true" ]]; then
      log "Updating installed packages."
      dnf update -y
    fi
    log "Installing required packages."
    dnf install -y curl iptables iproute-tc
  else
    command_exists curl || die "curl is required, and dnf is unavailable."
    command_exists iptables || warn "iptables was not found."
    command_exists tc || warn "iproute-tc/tc was not found."
  fi
}

install_k3s() {
  require_root

  if systemctl is-active --quiet k3s 2>/dev/null; then
    die "k3s is already running. Use 'status' or uninstall it first."
  fi

  install_dependencies
  save_firewalld_state

  if [[ "${DISABLE_FIREWALL}" == "true" ]] &&
     systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
    log "Disabling firewalld for this K3s installation."
    systemctl disable --now firewalld
  fi

  log "Downloading and installing K3s."

  local -a env_args
  env_args=("INSTALL_K3S_EXEC=${K3S_INSTALL_EXEC}")

  if [[ -n "${K3S_VERSION}" ]]; then
    env_args+=("INSTALL_K3S_VERSION=${K3S_VERSION}")
  else
    env_args+=("INSTALL_K3S_CHANNEL=${K3S_CHANNEL}")
  fi

  curl -sfL "${INSTALL_URL}" | env "${env_args[@]}" sh -

  systemctl enable --now k3s
  systemctl is-active --quiet k3s || die "K3s installation completed, but the service is not active."

  log "K3s is installed and running."
  log "Kubeconfig: /etc/rancher/k3s/k3s.yaml"
  k3s kubectl get nodes -o wide || true
}

confirm_uninstall() {
  [[ "${ASSUME_YES}" == "true" ]] && return

  cat >&2 <<'EOF'
WARNING: Uninstalling K3s deletes the local cluster datastore,
local-storage PersistentVolume data, node configuration, and K3s tools.
EOF
  read -r -p "Type UNINSTALL to continue: " answer
  [[ "${answer}" == "UNINSTALL" ]] || die "Uninstall cancelled."
}

uninstall_k3s() {
  require_root
  confirm_uninstall

  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    log "Running the K3s server uninstall script."
    /usr/local/bin/k3s-uninstall.sh
  elif [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]]; then
    log "Running the K3s agent uninstall script."
    /usr/local/bin/k3s-agent-uninstall.sh
  else
    warn "No official K3s uninstall script was found."
    warn "K3s may already be uninstalled or was installed by another method."
  fi

  restore_firewalld_state
  rm -rf "${STATE_DIR}"

  log "K3s uninstall procedure completed."
}

show_status() {
  printf '%-24s %s\n' "k3s binary:" "$(command -v k3s || echo not-found)"

  if systemctl list-unit-files k3s.service >/dev/null 2>&1; then
    printf '%-24s %s\n' "k3s enabled:" "$(systemctl is-enabled k3s 2>/dev/null || true)"
    printf '%-24s %s\n' "k3s active:" "$(systemctl is-active k3s 2>/dev/null || true)"
  else
    printf '%-24s %s\n' "k3s service:" "not-found"
  fi

  if systemctl list-unit-files k3s-agent.service >/dev/null 2>&1; then
    printf '%-24s %s\n' "k3s-agent enabled:" "$(systemctl is-enabled k3s-agent 2>/dev/null || true)"
    printf '%-24s %s\n' "k3s-agent active:" "$(systemctl is-active k3s-agent 2>/dev/null || true)"
  fi

  if command_exists k3s && systemctl is-active --quiet k3s 2>/dev/null; then
    echo
    k3s kubectl get nodes -o wide || true
  fi
}

case "${ACTION}" in
  install)
    parse_args "$@"
    install_k3s
    ;;
  uninstall)
    parse_args "$@"
    uninstall_k3s
    ;;
  status)
    parse_args "$@"
    show_status
    ;;
  help|--help|-h|"")
    usage
    ;;
  *)
    usage
    die "Unknown action: ${ACTION}"
    ;;
esac
