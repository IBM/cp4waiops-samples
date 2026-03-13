# Importing Users and Groups into Cognos Analytics

This guide explains how to import users and groups from your LDAP server into Cognos Analytics using CSV files. This is necessary to ensure proper authentication and authorization when integrating Cloud Pak for AIOps with Cognos Analytics. Once you have completed this process, you will be able to setup permissions for your groups with relation to the content you create in Cognos. For example, you may provide your 'operators' group the ability to 'read' a dashboard, whereas your 'administrators' group the ability to 'write' a dashboard.

## Overview

When using LDAP authentication with Cognos Analytics, you need to import user and group information so that Cognos can map LDAP identities to its internal namespace. The key requirement is that the `camIdentity` field must match the Distinguished Name (DN) from your LDAP server.

## Prerequisites

- Access to your LDAP server's user and group information
- Administrative access to Cognos Analytics
- Understanding of your LDAP directory structure

## Creating the Users CSV File

### CSV Format

The users CSV file must contain the following columns:

- `camIdentity`: The full Distinguished Name (DN) from LDAP
- `defaultName`: The username
- `givenName`: The user's first name
- `surname`: The user's last name (optional)

### Example LDAP to CSV Translation

**LDAP Entry (LDIF format):**
```ldif
dn: uid=john.doe,ou=People,dc=ibm,dc=com
objectClass: inetOrgPerson
uid: john.doe
cn: John Doe
givenName: John
sn: Doe
mail: john.doe@ibm.com

dn: uid=jane.smith,ou=People,dc=ibm,dc=com
objectClass: inetOrgPerson
uid: jane.smith
cn: Jane Smith
givenName: Jane
sn: Smith
mail: jane.smith@ibm.com
```

**Corresponding users.csv:**
```csv
camIdentity,defaultName,givenName,surname
"uid=john.doe,ou=People,dc=ibm,dc=com",john.doe,John,Doe
"uid=jane.smith,ou=People,dc=ibm,dc=com",jane.smith,Jane,Smith
```

## Creating the Groups CSV File

### CSV Format

The groups CSV file must contain the following columns:

- `camIdentity`: The full Distinguished Name (DN) from LDAP
- `defaultName`: The group name
- `type`: Must be set to "group"

**Important Note:** While the official Cognos documentation for group imports doesn't mention the `camIdentity` field, it is **required** for proper integration with Cloud Pak for AIOps LDAP authentication.

### Example LDAP to CSV Translation

**LDAP Entry (LDIF format):**
```ldif
dn: cn=operators,ou=groups,dc=ibm,dc=com
objectClass: groupOfNames
cn: operators
member: uid=john.doe,ou=People,dc=ibm,dc=com
member: uid=jane.smith,ou=People,dc=ibm,dc=com

dn: cn=administrators,ou=groups,dc=ibm,dc=com
objectClass: groupOfNames
cn: administrators
member: uid=admin,ou=People,dc=ibm,dc=com
```

**Corresponding groups.csv:**
```csv
camIdentity,defaultName,type
"cn=operators,ou=groups,dc=ibm,dc=com",operators,group
"cn=administrators,ou=groups,dc=ibm,dc=com",administrators,group
```

## Importing into Cognos Analytics

### Importing Users

1. Log into Cognos Analytics as an administrator
2. Navigate to **Manage** > **People** > **Accounts**
3. Select your namespace (the one created by the `setupCognos.sh` script)
4. Click the **Import user or group** icon in the top right corner of the table
5. Follow the import wizard and upload your `users.csv` file
6. After some time the page should refresh and the users will appear. It may take a short while for all users to be added, but you can use the refresh icon to check on the status of the import

For detailed instructions, see: [Creating a CSV file containing user account information](https://www.ibm.com/docs/en/cognos-analytics/12.1.x?topic=namespaces-creating-csv-file-containing-user-account-information)

### Importing Groups

1. Log into Cognos Analytics as an administrator
2. Navigate to **Manage** > **People** > **Accounts**
3. Select your namespace (the one created by the `setupCognos.sh` script)
4. Click the **Import user or group** icon in the top right corner of the table
5. Follow the import wizard and upload your `groups.csv` file
6. After some time the page should refresh and the groups will appear. It may take a short while for all users to be added, but you can use the refresh icon to check on the status of the import

For detailed instructions, see: [Creating a CSV file containing group information](https://www.ibm.com/docs/en/cognos-analytics/12.1.x?topic=namespaces-creating-csv-file-containing-group-information)


## Best Practices

1. **Export from LDAP first**: Use LDAP tools to export your directory structure before creating CSV files
2. **Test with a small subset**: Import a few users and groups first to verify the process
3. **Document your LDAP structure**: Keep a record of your DN patterns for future imports
4. **Regular updates**: Plan for periodic imports if your LDAP directory changes frequently and you wish to synchronise these with Cognos
5. **Backup**: Always backup your Cognos configuration before performing imports

## Related Documentation

- [Cognos Analytics Security Documentation](https://www.ibm.com/docs/en/cognos-analytics/12.1.x?topic=security)
- [OIDC Authentication in Cognos](https://www.ibm.com/docs/en/cognos-analytics/12.1.x?topic=authentication-openid-connect-oidc)
- Cloud Pak for AIOps Integration: See `setupCognos.sh` script in this directory