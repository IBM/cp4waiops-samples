# Schemas

Schemas for reporting in Cloud Pak for AIOps using Cognos Analytics with DB2

## Before installing

Decide if you want to create a new database or install into an existing one. To create a new database (replacing the database \<name\>, \<user\> and \<password\>),
```
db2 CREATE DATABASE <name>
db2 CONNECT TO <name> USER <user> USING <password>
```

Otherwise, install into an existing database. Make sure you are connected and using the desired database (replacing the database \<name\>, \<user\> and \<password\>),
```
db2 CONNECT TO <name> USER <user> USING <password>
```

If you wish to namespace the reporting tables, you can also use a DB2 SCHEMA in which the new reporting tables will belong. Refer to DB2 documentation on using a DB2 SCHEMA.

### Customization
The alerts table provides a number of basic columns for reporting, but it's often the case where you have enriched alerts with custom properties. To include custom properties in this schema, simply edit the db2/reporter_aiops_alerts.sql and add columns to the ALERTS_REPORTER_STATUS table.

```
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_REPORTER_STATUS table contains raw alert data.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ALERTS_REPORTER_STATUS (
    MYCUSTOMCOLUMN      VARCHAR(128),
    tenantid            VARCHAR(64) NOT NULL,
    severity            INTEGER,
    ...
```

## Installing
You may install alerts and incidents schemas from the DB2 command line.
```
db2 -td@ -vf db2/reporter_aiops_alerts.sql
```
```
db2 -td@ -vf db2/reporter_aiops_incidents.sql
```
```
db2 -td@ -vf db2/reporter_aiops_noise_reduction.sql
```

If you prefer to use the UI (as with IBM DB2 on Cloud), paste the contents of each script into the SQL command window to run. Make sure to configure the command terminator to use @.

> If you run the install script multiple times, only those components that do not yet exist will be created.

## Using the schemas

Now that the schemas have been installed, you can take steps to integrate with AIOps. The following are the basic steps to get data into DB2 to be used in Cognos. Refer to AIOps and Cognos documentation for complete details.

1. Configure an integration - The schemas can be used for Cloud Pak for AIOps Netcool Impact or IBM Db2 integrations. 

2. Configure a policy - For alert and incidents data to flow into the DB2 database, configure the "Invoke IBM Tivoli Netcool/Impact" or "Populate a dashboard or report" policy. You'll need separate policies for alerts and incidents. Use the details of the integration you configured in the previous step, and customize the column mappings. The id and tenantid are required.

The following are provided as defaults for alerts:
```
{
  "id": alert.id,
  "tenantid": "cfd95b7e-3bc7-4006-a4a8-a73a79c71255",
  "severity": alert.severity,
  "businessCriticality": $join(alert.insights[type="aiops.ibm.com/insight-type/business/criticality"].details.criticalityLabel, ','),
  "state": alert.state,
  "summary": alert.summary,
  "eventType": alert.type.classification,
  "sender": alert.sender.name,
  "resource": alert.resource.name,
  "firstOccurrenceTime": alert.firstOccurrenceTime,
  "lastOccurrenceTime": alert.lastOccurrenceTime,
  "runbooks": $count(alert.insights[type="aiops.ibm.com/insight-type/runbook"]),
  "topology": $count(alert.insights[type="aiops.ibm.com/insight-type/topology/resource"]),
  "seasonal": $count(alert.insights[type="aiops.ibm.com/insight-type/seasonal-occurrence"].details[isSeasonal=true]),
  "inIncident": $count(alert.relatedContextualStoryIds) + $count(alert.relatedStoryIds),
  "suppressed": $number(alert.suppressed),
  "goldenSignal": $join([alert.insights[type="aiops.ibm.com/insight-type/golden-signal"].details.goldenSignal], ","),
  "acknowledged": $number(alert.acknowledged),
  "owner": alert.owner,
  "team": alert.team,
  "eventCount": alert.eventCount,
  "lastStateChangeTime": alert.lastStateChangeTime
}
```

If you've added custom alert columns to the schema, you can include these in the mappings to ensure they are available for reporting, for example
```
  ...
  "MYCUSTOMCOLUMN": alert.details.somethingSpecial
}
```

These are the default mappings for incidents:
```
{
  "tenantid": "cfd95b7e-3bc7-4006-a4a8-a73a79c71255",
  "id": incident.id,
  "createdTime": incident.createdTime,
  "createdBy": incident.createdBy,
  "title": incident.title,
  "description": incident.description,
  "priority": incident.priority,
  "state": incident.state,
  "lastChangedTime": incident.lastChangedTime,
  "owner": incident.owner,
  "team": incident.team,
  "alerts": $count(incident.contextualAlertIds) + $count(incident.alertIds),
  "similarIncidents": $count(incident.insights[type="aiops.ibm.com/insight-type/similar-incidents"].details.similar_incidents),
  "probableCauseAlerts": $count(incident.insights[type="aiops.ibm.com/insight-type/probable-cause"]),
  "tickets": $count(incident.insights[type="aiops.ibm.com/insight-type/itsm/metadata"]),
  "chatOpsIntegrations": $count(incident.insights[type="aiops.ibm.com/insight-type/chatops/metadata"]),
  "resourceId": incident.insights[type="aiops.ibm.com/insight-type/topology/resource"].details.id,
  "policyId": incident.insights[type="aiops.ibm.com/insight-type/proposed-by"].details.policyId
}
```

For the "Invoke IBM Tivoli Netcool/Impact" policy type, you'll need to convert the timestamp fields using Jsonata like this,
```
$replace($replace($replace(<timestamp property>}, 'T', '-'), ':', '.'), 'Z', '000')
```

Once the policy has been saved, new alerts and incidents and state changes to existing ones (if update trigger type is configured) will be forwarded to the database.

After you've created or updated alerts or incidents, verify data exists in the database from the DB2 command prompt or view it the DB2 UI:
```
db2 SELECT * from ALERTS_REPORTER_STATUS
```
and
```
db2 SELECT * from INCIDENTS_REPORTER_STATUS
```
You should see a row for every alert and incident that has been created or updated based on the policy conditions and triggers.

Now you're all set to create reports in Cognos Analytics. See AIOps product documentation on how set up the data server connection and import data.

## Removing

> DANGER: This will remove all reporting data and schema components from your database.

```
db2 -td@ -vf db2/reporter_aiops_alerts_remove.sql
```
```
db2 -td@ -vf db2/reporter_aiops_incidents_remove.sql
```
```
db2 -td@ -vf db2/reporter_aiops_noise_reduction_remove.sql
```

## Testing
1. Complete the `config.json` with database connection details. You can also set these values in the command-line window, e.g. `export connection__user=db2inst1`.
2. Make sure the database is running.
3. Connect to the database defined in the config file, e.g. `db2 connect to bludb user db2inst1`
4. Run `npm run test`.
> NOTE: Testing from Linux AMD64 is currently supported.

## Reference

### Tables
ALERTS_REPORTER_STATUS - Alerts list

ALERTS_AUDIT_OWNER - Audit of alert owner changes

ALERTS_AUDIT_TEAM - Audit of alert team changes

ALERTS_AUDIT_SEVERITY - Audit of alert severity changes

ALERTS_AUDIT_ACK - Audit of alert acknowledged changes

ALERTS_SEVERITY_TYPES - Alert severity type definitions

INCIDENTS_REPORTER_STATUS - Incidents list

INCIDENTS_AUDIT_OWNER - Audit of incident owner changes

INCIDENTS_AUDIT_TEAM - Audit of incident team changes

INCIDENTS_AUDIT_PRIORITY - Audit of incident priority changes

INCIDENTS_AUDIT_STATE - Audit of incident status changes

### Views
ALERTS_STATUS_VW - View similar to alerts list in the UI

ALERTS_AUDIT - View of audited alert state changes

INCIDENTS_STATUS_VW - View similar to incidents list in the UI

INCIDENTS_AUDIT - View of audited incident state changes

INCIDENT_DASHBOARD - Example view of incident health

### Indexes
ALERTS_AUDIT_OWNER_IDX - Index for alert owner audit

ALERTS_AUDIT_TEAM_IDX - Index for alert team audit

ALERTS_AUDIT_SEVERITY_IDX - Index for alert severity audit

ALERTS_AUDIT_ACK_IDX - Index for alert acknowledged audit

INCIDENTS_AUDIT_OWNER_IDX - Index for incident owner audit

INCIDENTS_AUDIT_TEAM_IDX - Index for incident team audit

INCIDENTS_AUDIT_PRIORITY_IDX - Index for incident priority audit

INCIDENTS_AUDIT_STATE_IDX - Index for incident status audit

### Triggers
ALERTS_AUDIT_INSERT - Inserts an audit record when alert state changes

ALERTS_AUDIT_UPDATE_SEVERITY - Updates previous alert severity state

ALERTS_AUDIT_UPDATE_OWNER - Updates previous alert owner state

ALERTS_AUDIT_UPDATE_TEAM - Updates previous alert team state

ALERTS_AUDIT_UPDATE_ACK - Updates previous alert acknowedged state

INCIDENTS_AUDIT_INSERT - Inserts an audit record when incident state changes

INCIDENTS_AUDIT_UPDATE_PRIORITY - Updates previous incident priority state

INCIDENTS_AUDIT_UPDATE_OWNER - Updates previous incident owner state

INCIDENTS_AUDIT_UPDATE_TEAM - Updates previous incident team state

INCIDENTS_AUDIT_UPDATE_STATE - Updates previous incident status
