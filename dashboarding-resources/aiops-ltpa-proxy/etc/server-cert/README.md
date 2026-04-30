# Server Certificates

This directory stores the TLS certificate and private key for the proxy server.

## Generation

Generate a self-signed certificate for local development:

```bash
npm run generate-cert
```

This creates:
- `server-cert.pem` - Server certificate
- `server-key.key` - Private key
- `server-cert_csr.pem` - Certificate signing request

## Production

In production, use proper certificates from your organization's CA:

```bash
# Create secret from your certificates
oc create secret tls proxy-tls-cert \
  --cert=/path/to/server-cert.pem \
  --key=/path/to/server-key.key
```

The deployment mounts this secret at `/etc/secrets/proxy-cert/`.

## Notes

- All files in this directory are ignored by git (except this README)
- Never commit private keys to version control
- Use proper CA-signed certificates in production environments