# AIOps LTPA Proxy

A Fastify-based proxy that validates JWT bearer tokens from AIOps and forwards requests to downstream systems (like Impact) with LTPA2 authentication cookies.

## Overview

This proxy:
- Validates incoming JWT tokens against a JWKS endpoint
- Generates LTPA2 cookies for authenticated requests
- Forwards requests to downstream Liberty-based targets
- Runs as a container on OpenShift

## Prerequisites

1. **LDAP Configuration**: Both AIOps and downstream target must use the same LDAP server
   - [AIOps LDAP setup](https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/4.11.0?topic=users-configuring-ldap-connection)
   - [Impact LDAP setup](https://www.ibm.com/docs/en/tivoli-netcoolimpact/7.1.0?topic=ldap-configuring) (if using Impact)

2. **LTPA Configuration**: Downstream target must have LTPA enabled
   - [Liberty LTPA configuration](https://www.ibm.com/docs/en/was-liberty/nd?topic=liberty-configuring-ltpa-in)
   - For Impact: Edit `/opt/IBM/tivoli/impact/wlp/usr/servers/ImpactUI/server.xml`

3. **Node.js 22+** (for local development)

## Quick Start

### 1. Obtain LTPA Keys

```bash
# Copy LTPA keys from Liberty server (e.g., Impact)
scp user@impact-vm:/opt/IBM/tivoli/impact/wlp/usr/servers/ImpactUI/resources/security/ltpa.keys ./ltpa.keys
```

### 2. Create OpenShift Secrets

```bash
# Login and switch to namespace
oc login --server=https://your-cluster:6443
oc project your-namespace

# Create LTPA secret
oc create secret generic ltpa-keys \
  --from-file=ltpa.key=./ltpa.keys \
  --from-literal=ltpa.password=your-ltpa-password

# Create proxy TLS secret (self-signed for testing)
npm run generate-cert
oc create secret tls proxy-tls-cert \
  --cert=./etc/server-cert/server-cert.pem \
  --key=./etc/server-cert/server-key.key
```

### 3. Configure

```bash
cp ./etc/config/config.yaml.template ./etc/config/config.yaml
```

Edit `config.yaml`:

```yaml
target:
  url: https://your-impact-server:16311
  authentication:
    ltpa_key_file_path: /etc/secrets/ltpa/ltpa.key
    ltpa_password: !file /etc/secrets/ltpa/ltpa.password
    ltpa_user_template: 'user\:customRealm/uid=${aiopsUser},ou=People,dc=ibm,dc=com'
    ltpa_expiry_ms: 7200000

proxy:
  port: 8443
  health_port: 8444
  tls:
    cert: !file /etc/secrets/proxy-cert/tls.crt
    key: !file /etc/secrets/proxy-cert/tls.key
  authentication:
    endpoints:
      issuer: https://cpd-aiops.apps.your-cluster.com
      jwks_path: /.well-known/jwks.json
```

Create ConfigMap:
```bash
oc create configmap aiops-ltpa-proxy-config --from-file=config.yaml=./etc/config/config.yaml
```

### 4. Build and Deploy

```bash
# Build image
podman build -t aiops-ltpa-proxy:latest -f ./Containerfile .

# Tag and push
podman tag aiops-ltpa-proxy:latest your-registry/aiops-ltpa-proxy:latest
podman push your-registry/aiops-ltpa-proxy:latest

# Deploy
oc apply -f k8s/deployment.yaml
oc apply -f k8s/service.yaml
oc apply -f k8s/route.yaml
```

### 5. Configure AIOps Integration

Deploy ZenExtension to route traffic through the proxy:

```bash
oc apply -f k8s/zen-extension.yaml
```

This configures AIOps nginx to:
- Route `/aiops/opview/*` through aiops-ltpa-proxy
- Validate JWT tokens
- Rewrite paths for the downstream target

## Configuration

### Key Fields

- `target.url`: Downstream server URL
- `target.authentication.ltpa_key_file_path`: Path to LTPA keys file
- `target.authentication.ltpa_password`: LTPA keys password
- `target.authentication.ltpa_user_template`: LDAP DN template for user mapping
- `proxy.authentication.endpoints.issuer`: JWT issuer URL (AIOps cluster)
- `proxy.authentication.endpoints.jwks_path`: JWKS endpoint path

### Secret Mounting

The deployment mounts secrets at these paths:
- `/etc/secrets/ltpa/` - LTPA keys and password
- `/etc/secrets/proxy-cert/` - Proxy TLS certificate
- `/etc/trusted-certs/` - Trusted CA certificates (optional)
- `/opt/app-root/src/etc/config/` - Configuration file

## Local Development

```bash
# Install dependencies
npm install

# Configure
cp ./etc/config/config.yaml.template ./etc/config/config.yaml
# Edit config.yaml with local paths

# Generate certificate
npm run generate-cert

# Place LTPA keys at configured path
cp /path/to/ltpa.keys ./etc/ltpa.key

# Start proxy
npm start
```

## Authentication Flow

1. User sends request with JWT bearer token
2. Proxy validates JWT against JWKS endpoint
3. Proxy generates LTPA2 cookie for downstream user
4. Proxy forwards request to target with LTPA cookie
5. Target validates LTPA token and returns response

## Endpoints

- **Proxy**: Port 8443 (HTTPS)
- **Health**: Port 8444 (HTTPS) - `/health`

## Troubleshooting

**Pod won't start:**
- Verify all secrets exist: `oc get secrets ltpa-keys proxy-tls-cert`
- Check configmap: `oc get configmap aiops-ltpa-proxy-config`
- View logs: `oc logs -f deployment/aiops-ltpa-proxy`

**LTPA token errors:**
- Verify LTPA password matches Liberty server configuration
- Check LTPA keys file is readable
- Ensure LDAP user template matches your LDAP structure

**Certificate errors:**
- Add trusted certificates to `trusted-certs` configmap
- For AIOps ingress cert: `oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d`

## Files

- `Containerfile` - Container image build
- `index.js` - Main proxy server
- `lib/` - Helper modules (config, LTPA, certificates)
- `etc/config/config.yaml.template` - Configuration template
- `k8s/` - Kubernetes deployment manifests
