-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024
--
-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script amends the ALERTS_REPORTER_STATUS table to support the
-- nested object structures found in clean-console-test-alerts.json
--
-- The JSON structure contains nested objects for:
--   - sender: { name, type }
--   - resource: { name, type, location, uniqueId, service }
--   - type: { classification, eventType }
--
-- This amendment adds individual columns for each nested property and
-- deprecates the original single-column fields.
--
-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.
--   (2) At the command prompt, run this script.
--
--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_alerts_amendment.sql
--------------------------------------------------------------------------------
--#SET TERMINATOR @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Add new columns to ALERTS_REPORTER_STATUS table
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Add sender object properties
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN senderName VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN senderType VARCHAR(255) @

-- Add resource object properties
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceName VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceType VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceLocation VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceService VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceUniqueId VARCHAR(255) @

-- Add type object properties
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN typeClassification VARCHAR(255) @

-- Note: eventType already exists in the table, but it was a single field
-- The new structure has type.eventType, so we add typeEventType for clarity
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN typeEventType VARCHAR(255) @

-- Add occurrence fields
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN occurrenceTime TIMESTAMP @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN occurrenceCount INTEGER @

-- Add alert details properties for CleanConsole dashboard
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN detailsWait INTEGER DEFAULT 0 @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN detailsMaintenance INTEGER DEFAULT 0 @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN detailsAutomation INTEGER DEFAULT 0 @

COMMIT WORK @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Update the ALERTS_STATUS_VW view to include new fields
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Drop the existing view
DROP VIEW ALERTS_STATUS_VW @

-- Recreate the view with new columns
CREATE VIEW ALERTS_STATUS_VW (
        severity,
        businessCriticality,
        state,
        summary,
        eventType,
        sender,
        senderName,
        senderType,
        resource,
        resourceName,
        resourceType,
        resourceLocation,
        resourceUniqueId,
        resourceService,
        typeClassification,
        typeEventType,
        firstOccurrenceTime,
        lastOccurrenceTime,
        occurrenceTime,
        occurrenceCount,
        runbooks,
        topology,
        seasonal,
        inIncident,
        suppressed,
        goldenSignal,
        detailsWait,
        detailsMaintenance,
        detailsAutomation
) AS SELECT
        ALERTS_SEVERITY_TYPES.name,
        businessCriticality,
        state,
        summary,
        eventType,
        sender,
        senderName,
        senderType,
        resource,
        resourceName,
        resourceType,
        resourceLocation,
        resourceUniqueId,
        resourceService,
        typeClassification,
        typeEventType,
        (REPLACE(CHAR(firstOccurrenceTime),'.',':')),
        (REPLACE(CHAR(lastOccurrenceTime),'.',':')),
        (REPLACE(CHAR(occurrenceTime),'.',':')),
        occurrenceCount,
        runbooks,
        case
            when topology > 0 then 'Yes'
            when topology = 0 then 'No'
        end as topology,
        case
            when seasonal > 0 then 'Yes'
            when seasonal = 0 then 'No'
        end as seasonal,
        case
            when inIncident > 0 then 'Yes'
            when inIncident = 0 then 'No'
        end as inIncident,
        case
            when suppressed > 0 then 'Yes'
            when suppressed = 0 then 'No'
        end as suppressed,
        goldenSignal,
        case
            when detailsWait > 0 then 'Yes'
            when detailsWait = 0 then 'No'
        end as detailsWait,
        case
            when detailsMaintenance > 0 then 'Yes'
            when detailsMaintenance = 0 then 'No'
        end as detailsMaintenance,
        case
            when detailsAutomation > 0 then 'Yes'
            when detailsAutomation = 0 then 'No'
        end as detailsAutomation
FROM
        ALERTS_REPORTER_STATUS, ALERTS_SEVERITY_TYPES
WHERE
        ALERTS_REPORTER_STATUS.severity = ALERTS_SEVERITY_TYPES.severity @

COMMIT WORK @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- NOTES ON MIGRATION
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- The original columns (sender, resource, eventType) are retained for
-- backward compatibility. Applications should migrate to use the new
-- structured columns:
--
-- OLD FIELD          NEW FIELDS
-- ---------          ----------
-- sender       -->   senderName, senderType
-- resource     -->   resourceName, resourceType, resourceLocation,
--                    resourceUniqueId, resourceService
-- eventType    -->   typeClassification, typeEventType
--
-- Additionally, the following new fields are available:
--   - occurrenceTime: Timestamp of the alert occurrence
--   - occurrenceCount: Number of times the alert has occurred
--   - detailsWait: Flag indicating alert is in wait status (0/1)
--   - detailsMaintenance: Flag indicating alert is in maintenance (0/1)
--   - detailsAutomation: Flag indicating alert is automated (0/1)
--
-- The new details fields support the CleanConsole dashboard visualization:
--   - detailsWait: Maps to alert.details.wait in JSON data
--   - detailsMaintenance: Maps to alert.details.maintenance in JSON data
--   - detailsAutomation: Maps to alert.details.automation in JSON data
--
-- To populate the new fields from existing data, you may need to:
--   1. Parse JSON strings stored in sender/resource fields
--   2. Update records to populate the new structured columns
--   3. Set the details flags based on alert.details properties
--   4. Eventually deprecate the old single-column fields
--
-- For CleanConsole dashboard integration, use the ALERTS_CLEANCONSOLE_VW
-- view which aggregates alerts by location and status type.
--
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++