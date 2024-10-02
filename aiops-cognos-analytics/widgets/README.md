# Widgets

Build and install Cloud Pak for AIOps widgets for Cognos.

## Prereqs
- [Node.js](https://nodejs.org/en/download/package-manager) v18+
  - From the `aiops-cognos-analytics` path, run `npm ci` to install dependencies (one time).
- Install jq where you plan to run this script (if needed).
- Obtain a Cognos API key from an administrator.
  - The Cognos administrator can get the key from any existing namespace under "Profile and Settings - My API keys".
  - The Cognos administrator will first need to "Renew" credentials if "My credentials - Manage" is disabled.
  ![credentials](../images/credentials.png)
  - The Cognos user should have Portal Administrator or System Administrator privileges.
- If the Cognos server is embedded within Cloud Pak for AIOps, authenticate with AIOps from the command-line as an admin user.

## Install widgets
From the `aiops-cognos-analytics/widgets` path run
```bash
./installWidgets.sh -u cognos_url [-k cognos_api_key] [-e]
```

`-u cognos_url` (required) Cognos server in the form of `http(s)://hostname:port`

`-k cognos_api_key` (optional) API key of the Cognos user installing the widgets. If no API key is specified, anonymous user will be used.

`-e` (optional) indicates that Cognos is embedded within an AIOps cluster. The default is *not* embedded (standalone) Cognos.
