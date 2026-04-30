# Trusted Certificates

This directory is used to store trusted CA certificates for local development.

## Usage

Place any trusted CA certificates (`.crt`, `.pem` files) in this directory. The proxy will automatically load them when validating TLS connections to:
- The AIOps JWKS endpoint
- The downstream target server (e.g., Impact)

## Example

```bash
# Add AIOps ingress certificate
oc get secret router-certs-default -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > aiops-ingress.crt

# Add Impact server certificate
cp /path/to/impact-server.crt ./impact.crt
```

## Notes

- Files in this directory are ignored by git (except this README)
- The proxy loads all `.crt` and `.pem` files from this directory at startup
- This is only needed for local development with self-signed certificates
- In production, certificates should be mounted via ConfigMaps/Secrets