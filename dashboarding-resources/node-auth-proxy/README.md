# JWT Authentication Proxy

A Node.js proxy server that validates JWT tokens, generates an Ltpa token, and forwards authenticated requests to a target API.

## Features

- JWT token validation using JWKS (JSON Web Key Set)
- JWKS key caching for improved performance
- Ltpa token creation with shared keys file
- SSL/HTTPS support for secure communication
- SSL certificate validation disabled for development environments

## Prerequisites
1) LDAP server setup and both AIOps and Impact connected to it

Follow the guidance [for AIOps configuration](https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/4.11.0?topic=users-configuring-ldap-connection).
Follow the guidance [for Impact configuration](https://www.ibm.com/docs/en/tivoli-netcoolimpact/7.1.0?topic=ldap-configuring).

2) Ltpa configured on Impact

Follow the guidance [here](https://www.ibm.com/docs/en/was-liberty/nd?topic=liberty-configuring-ltpa-in). In a typical Impact installation, you will edit the Impact GUI server's server.xml file found at: `/opt/IBM/tivoli/impact/wlp/usr/servers/ImpactUI/server.xml`. The resulting keys file will be pointed to in the proxy env file.

3) A host for the node-proxy

The suggestion is to run the proxy alongside Impact on the same VM. The proxy can then easily access the Impact Ltpa keys file and proxy requests directly to Impact. The Impact VM will need NodeJS (currently this has been tested using V22, the current active LTS version). You can start by using [nvm](https://github.com/nvm-sh/nvm) and then `nvm install 22`.

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

   # LDAP user template to be added in LTPA token. This is effectively a translation from the `aiopsUser` to the LDAP user as AIOps does not pass this
   # back during the JWT validation. You will need to configure this depending on your own LDAP configuration.
   LTPA_USER_TEMPLATE='user\:customRealm/uid=${aiopsUser},ou=People,dc=ibm,dc=com'

   # Enable SSL
   SSL_ENABLED=true

   # SSL Key path for this node auth proxy cerfificate
   SSL_KEY_PATH=certs/key.pem

   # SSL Cert path for this node auth proxy cerfificate
   SSL_CERT_PATH=certs/cert.pem

   # Directory to store trusted certificates for JWKS endpoint and Impact
   TRUST_CERTS_DIR=trusted-certs

## SSL Configuration

To enable SSL for secure HTTPS communication:

0. (If testing) Generate SSL certificates by running:
```
node generate-cert.js
```
This will create self-signed certificates in the `certs` directory.

1. Set the following environment variables in your `.env` file:
```
SSL_ENABLED=true
SSL_KEY_PATH=certs/key.pem
SSL_CERT_PATH=certs/cert.pem
TRUST_CERTS_DIR=trusted-certs
```

For the `certs`, replace the certificates with proper certificates from a trusted Certificate Authority.

For the `trusted-certs`, you will either need to add your AIOps cluster certificate and your Impact GUI server certificate to the folder OR a CA certificate which has signed them.

AIOps:
If you are using the default certifcate, it can be found via:
`oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d`

If you are using a [custom certifificate](https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/4.11.0?topic=certificates-using-custom-certificate) then you will need to add that instead.

Impact GUI:
`openssl s_client -showcerts -servername noi-impact.mycluster.com -connect noi-impact.mycluster.com:16311 </dev/null`

Simply create `.pem` files for each of the above and store in the `trusted-certs` directory.

## Usage

Start the server:

```
npm start
```

The proxy is now ready for use.

## API Endpoints

- `/api/*` - Proxied endpoints (requires JWT authentication)
- `/health` - Health check endpoint

## Testing SSL Implementation

To test if SSL is properly configured:

1. First, generate the SSL certificates if you haven't already:
   ```
   npm run generate-cert
   ```

2. Start the server with SSL enabled:
   ```
   npm start
   ```

3. Run the SSL test script:
   ```
   npm run test-ssl
   ```

The test script will attempt to connect to the server using HTTPS and verify that the SSL configuration is working correctly.

## Ldap configuration
The proxy will take the LTPA user template and replace `${impactUser}` with the value of the username coming from AIOps. Impact will then use the resulting user when validating against the LDAP server. The template is defined in the `LTPA_USER_TEMPLATE` environment variable and should be configured to match your LDAP server configuration.
