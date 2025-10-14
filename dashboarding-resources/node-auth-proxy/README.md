# JWT Authentication Proxy

A Node.js proxy server that validates JWT tokens, generates an Ltpa token, and forwards authenticated requests to a target API.

## Features

- JWT token validation using JWKS (JSON Web Key Set)
- JWKS key caching for improved performance
- Ltpa token creation with shared keys file
- SSL certificate validation disabled for development environments

## Prerequisites
1) LDAP server setup and both AIOps and Impact connected to it
Follow the guidance in https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/4.11.0?topic=users-configuring-ldap-connection for AIOps configuration.
Follow the guidance in https://www.ibm.com/docs/en/tivoli-netcoolimpact/7.1.0?topic=ldap-configuring for Impact configuration.

2) Ltpa configured on Impact
Follow the guidance in https://www.ibm.com/docs/en/was-liberty/nd?topic=liberty-configuring-ltpa-in. In a typical Impact installation, you will edit the Impact GUI server's server.xml file found at: `/opt/IBM/tivoli/impact/wlp/usr/servers/ImpactUI/server.xml`. The resulting keys file will be pointed to in the proxy env file.

3) A host for the node-proxy
The suggestion is to run the proxy alongside Impact on the same VM. The proxy can then easily access the Impact Ltpa keys file and proxy requests directly to Impact. The Impact VM will need NodeJS (currently this has been tested using V22, the current active LTS version). You can start by using nvm (https://github.com/nvm-sh/nvm) and then `nvm install 22`.

## Setup

1. Clone the repository
2. Install dependencies:
   ```
   npm install
   ```
3. Configure environment variables in `.env` file:
   ```
   # Port for the proxy server
   PORT=3000

   # Target API URL
   TARGET_URL=https://myimpact.com:16311

   # JWKS endpoint
   JWKS_URI=https://cpd-aiops.apps.myaiops.com/auth/jwks

   # JWKS cache TTL in milliseconds
   JWKS_CACHE_TTL=3600000

   # LTPA password for the keys
   LTPA_PASSWORD=smadmin

   # LTPA expiry time in milliseconds
   LTPA_EXPIRY=3600000

   # LTPA keys file path
   LTPA_KEYS_PATH='/opt/IBM/tivoli/impact/wlp/usr/servers/ImpactUI/myltpa.keys'

   # LTPA user template
   LTPA_USER_TEMPLATE='user\\:customRealm/uid=${impactUser},ou=People,dc=ibm,dc=com'
   ```


## Usage

Start the server:

```
npm start
```

## API Endpoints

- `/api/*` - Proxied endpoints (requires JWT authentication)
- `/health` - Health check endpoint

## Ldap configuration
The proxy will take the LTPA user template and replace `${impactUser}` with the value of the username coming from AIOps. Impact will then use the resulting user when validating against the LDAP server. The template is defined in the `LTPA_USER_TEMPLATE` environment variable and should be configured to match your LDAP server configuration.

## SSL Certificate Validation

SSL certificate validation is disabled for outgoing requests from the proxy. This is useful for development environments where self-signed certificates or internal certificate authorities might be used.

**Security Warning**: Disabling certificate validation reduces security and should only be used in development or controlled environments. For production deployments, consider enabling certificate validation and properly configuring trusted certificates.

The certificate validation is disabled in two ways:
1. Setting `NODE_TLS_REJECT_UNAUTHORIZED=0` for Node.js HTTP requests
2. Setting `secure: false` in the proxy middleware options