#!/usr/bin/env bash
# ingress-nginx.sh
#
# Install, uninstall, or inspect the NGINX ingress controller (Helm) and manage
# its default IngressClass annotation. Use instead of the Traefik that ships
# with k3s. The IA operator creates Ingresses without an ingressClassName, so
# the default annotation must be set before the IAConfig CR is applied.
#
# Usage:
#   ./ingress-nginx.sh install [NodePort|LoadBalancer|ClusterIP]
#   ./ingress-nginx.sh uninstall
#   ./ingress-nginx.sh status
#   ./ingress-nginx.sh set-default
#   ./ingress-nginx.sh unset-default
#
# Environment variables (all optional):
#   NAMESPACE      Helm release namespace         (default: ingress-nginx)
#   RELEASE_NAME   Helm release name              (default: ingress-nginx)
#   INGRESS_CLASS  IngressClass name              (default: nginx)
#   SERVICE_TYPE   Default Service type           (default: LoadBalancer)
#   KUBECTL        kubectl binary                 (default: kubectl)
#
# Dependencies: helm (auto-installed with curl if missing), kubectl

set -euo pipefail

NAMESPACE="${NAMESPACE:-ingress-nginx}"
RELEASE_NAME="${RELEASE_NAME:-ingress-nginx}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"
# Use NodePort on bare-metal or k3s without a cloud load balancer.
SERVICE_TYPE="${SERVICE_TYPE:-LoadBalancer}"
KUBECTL="${KUBECTL:-kubectl}"

ensure_helm() {
    if command -v helm >/dev/null 2>&1; then
        echo "Helm is already installed:"
        helm version --short
        return 0
    fi

    echo "Helm not found. Installing Helm 3..."

    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: curl is required to install Helm."
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    echo "Downloading Helm installer..."

    curl -fsSL \
        -o "${tmp_dir}/get_helm.sh" \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

    chmod 700 "${tmp_dir}/get_helm.sh"

    if ! "${tmp_dir}/get_helm.sh"; then
        echo "ERROR: Helm installation failed."
        rm -rf "${tmp_dir}"
        exit 1
    fi

    rm -rf "${tmp_dir}"

    hash -r

    if ! command -v helm >/dev/null 2>&1; then
        echo "ERROR: Helm installation completed but helm is not in PATH."
        echo "PATH=${PATH}"
        exit 1
    fi

    echo "Helm installed successfully:"
    helm version --short
}

# Idempotent: skips the Helm install if the release already exists.
install_ingress_nginx() {
    local service_type="${1:-$SERVICE_TYPE}"

    ensure_helm

    if helm status "${RELEASE_NAME}" \
        -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "ingress-nginx is already installed in namespace ${NAMESPACE}. Nothing to do."
        set_default_ingressclass
        status_ingress_nginx
        return 0
    fi

    echo "Installing ingress-nginx with Service type: ${service_type}"

    helm repo add ingress-nginx \
        https://kubernetes.github.io/ingress-nginx \
        --force-update

    helm repo update

    helm upgrade --install "${RELEASE_NAME}" \
        ingress-nginx/ingress-nginx \
        --namespace "${NAMESPACE}" \
        --create-namespace \
        --set controller.service.type="${service_type}" \
        --set controller.ingressClassResource.name="${INGRESS_CLASS}" \
        --set controller.ingressClass="${INGRESS_CLASS}" \
        --set controller.ingressClassResource.default=true

    echo "Waiting for ingress-nginx controller..."

    "${KUBECTL}" rollout status \
        "deployment/${RELEASE_NAME}-controller" \
        -n "${NAMESPACE}"

    # Some chart versions do not persist the default annotation.
    set_default_ingressclass

    echo
    echo "ingress-nginx installation completed."
    status_ingress_nginx
}

uninstall_ingress_nginx() {
    ensure_helm

    echo "Uninstalling ingress-nginx..."

    helm uninstall "${RELEASE_NAME}" \
        -n "${NAMESPACE}" || true

    "${KUBECTL}" delete namespace "${NAMESPACE}" \
        --ignore-not-found=true
}

status_ingress_nginx() {
    echo "IngressClass:"
    "${KUBECTL}" get ingressclass || true

    echo
    echo "Pods:"
    "${KUBECTL}" get pods -n "${NAMESPACE}" || true

    echo
    echo "Service:"
    "${KUBECTL}" get svc -n "${NAMESPACE}" || true
}

set_default_ingressclass() {
    echo "Setting ${INGRESS_CLASS} as the default IngressClass..."

    "${KUBECTL}" annotate ingressclass "${INGRESS_CLASS}" \
        ingressclass.kubernetes.io/is-default-class="true" \
        --overwrite
}

# Run before switching to another ingress controller so only one default exists.
unset_default_ingressclass() {
    echo "Removing default annotation from ${INGRESS_CLASS}..."

    # The trailing '-' removes the annotation.
    "${KUBECTL}" annotate ingressclass "${INGRESS_CLASS}" \
        ingressclass.kubernetes.io/is-default-class- \
        --overwrite || true
}

usage() {
    echo "Usage:"
    echo "  $0 install [NodePort|LoadBalancer|ClusterIP]"
    echo "  $0 uninstall"
    echo "  $0 status"
    echo "  $0 set-default"
    echo "  $0 unset-default"
    echo
    echo "Environment variables:"
    echo "  NAMESPACE     Helm release namespace  (default: ingress-nginx)"
    echo "  RELEASE_NAME  Helm release name       (default: ingress-nginx)"
    echo "  INGRESS_CLASS IngressClass name        (default: nginx)"
    echo "  SERVICE_TYPE  Default Service type    (default: LoadBalancer)"
    echo "  KUBECTL       kubectl binary          (default: kubectl)"
    echo
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 install NodePort"
    echo "  $0 install LoadBalancer"
    echo "  KUBECTL=kubectl $0 install NodePort"
}

main() {
    case "${1:-}" in
        install)
            install_ingress_nginx "${2:-$SERVICE_TYPE}"
            ;;
        uninstall)
            uninstall_ingress_nginx
            ;;
        status)
            status_ingress_nginx
            ;;
        set-default)
            set_default_ingressclass
            ;;
        unset-default)
            unset_default_ingressclass
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
