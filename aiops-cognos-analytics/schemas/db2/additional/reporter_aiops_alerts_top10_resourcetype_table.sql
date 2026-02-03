-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024
--
-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script creates the ALERTS_TOP10_RESOURCETYPE table to store the
-- top 10 resource types by alert count, and a procedure to refresh it.
--
-- The table stores aggregated distinct alert counts by resourceType,
-- limited to the top 10 resource types with the highest alert counts.
--
-- Columns:
--   - resourceType: The type of resource
--   - alert_count: Count of distinct alert IDs for that resource type
--   - max_severity: Maximum severity value for that resource type
--
-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.
--   (2) At the command prompt, run this script.
--
--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_alerts_top10_resourcetype_table.sql
--
-- To refresh the data, call the stored procedure:
--       CALL REFRESH_ALERTS_TOP10_RESOURCETYPE()@
--------------------------------------------------------------------------------
--#SET TERMINATOR @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Drop existing objects if they exist
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DROP TRIGGER TRG_ALERTS_TOP10_AFTER_INSERT @
DROP TRIGGER TRG_ALERTS_TOP10_AFTER_UPDATE @
DROP TRIGGER TRG_ALERTS_TOP10_AFTER_DELETE @

DROP TABLE ALERTS_TOP10_RESOURCETYPE @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Create the ALERTS_TOP10_RESOURCETYPE table
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ALERTS_TOP10_RESOURCETYPE (
    resourceType VARCHAR(255) NOT NULL,
    alert_count INTEGER NOT NULL,
    max_severity INTEGER,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Create triggers to auto-refresh on ALERTS_REPORTER_STATUS changes
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TRIGGER TRG_ALERTS_TOP10_AFTER_INSERT
AFTER INSERT ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_TOP10_RESOURCETYPE;

    INSERT INTO ALERTS_TOP10_RESOURCETYPE (resourceType, alert_count, max_severity, last_updated)
    SELECT
        COALESCE(resourceType, 'Unknown') AS resourceType,
        COUNT(DISTINCT id) AS alert_count,
        MAX(severity) AS max_severity,
        CURRENT_TIMESTAMP
    FROM
        ALERTS_REPORTER_STATUS
    WHERE
        resourceType IS NOT NULL
    GROUP BY
        resourceType
    ORDER BY
        alert_count DESC
    FETCH FIRST 10 ROWS ONLY;
END @

CREATE TRIGGER TRG_ALERTS_TOP10_AFTER_UPDATE
AFTER UPDATE ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_TOP10_RESOURCETYPE;

    INSERT INTO ALERTS_TOP10_RESOURCETYPE (resourceType, alert_count, max_severity, last_updated)
    SELECT
        COALESCE(resourceType, 'Unknown') AS resourceType,
        COUNT(DISTINCT id) AS alert_count,
        MAX(severity) AS max_severity,
        CURRENT_TIMESTAMP
    FROM
        ALERTS_REPORTER_STATUS
    WHERE
        resourceType IS NOT NULL
    GROUP BY
        resourceType
    ORDER BY
        alert_count DESC
    FETCH FIRST 10 ROWS ONLY;
END @

CREATE TRIGGER TRG_ALERTS_TOP10_AFTER_DELETE
AFTER DELETE ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_TOP10_RESOURCETYPE;

    INSERT INTO ALERTS_TOP10_RESOURCETYPE (resourceType, alert_count, max_severity, last_updated)
    SELECT
        COALESCE(resourceType, 'Unknown') AS resourceType,
        COUNT(DISTINCT id) AS alert_count,
        MAX(severity) AS max_severity,
        CURRENT_TIMESTAMP
    FROM
        ALERTS_REPORTER_STATUS
    WHERE
        resourceType IS NOT NULL
    GROUP BY
        resourceType
    ORDER BY
        alert_count DESC
    FETCH FIRST 10 ROWS ONLY;
END @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Initial population of the table
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

INSERT INTO ALERTS_TOP10_RESOURCETYPE (resourceType, alert_count, max_severity, last_updated)
SELECT
    COALESCE(resourceType, 'Unknown') AS resourceType,
    COUNT(DISTINCT id) AS alert_count,
    MAX(severity) AS max_severity,
    CURRENT_TIMESTAMP
FROM
    ALERTS_REPORTER_STATUS
WHERE
    resourceType IS NOT NULL
GROUP BY
    resourceType
ORDER BY
    alert_count DESC
FETCH FIRST 10 ROWS ONLY @

COMMIT WORK @


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- NOTES ON USAGE
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- ALERTS_TOP10_RESOURCETYPE is a materialized table containing the top 10
-- resource types by distinct alert count.
--
-- The table includes:
--   - resourceType: The type of resource
--   - alert_count: Count of distinct alerts for that resource type
--   - max_severity: Maximum severity value for that resource type
--   - last_updated: Timestamp of when the data was last refreshed
--
-- AUTOMATIC REFRESH:
-- The table automatically refreshes immediately whenever ALERTS_REPORTER_STATUS
-- is modified (INSERT, UPDATE, or DELETE operations). The triggers use
-- FOR EACH STATEMENT mode, so the refresh happens once per SQL statement
-- rather than once per row, which is more efficient for bulk operations.
--
-- Example queries:
--
-- Get all top 10 resource types:
--   SELECT resourceType, alert_count, max_severity FROM ALERTS_TOP10_RESOURCETYPE
--   ORDER BY alert_count DESC
--
-- Get top 5 resource types only:
--   SELECT resourceType, alert_count, max_severity FROM ALERTS_TOP10_RESOURCETYPE
--   ORDER BY alert_count DESC
--   FETCH FIRST 5 ROWS ONLY
--
-- Get resource types with more than 100 alerts:
--   SELECT resourceType, alert_count FROM ALERTS_TOP10_RESOURCETYPE
--   WHERE alert_count > 100
--   ORDER BY alert_count DESC
--
-- Get total alerts across top 10 resource types:
--   SELECT SUM(alert_count) as total_alerts
--   FROM ALERTS_TOP10_RESOURCETYPE
--
-- Check when data was last updated:
--   SELECT MAX(last_updated) as last_refresh
--   FROM ALERTS_TOP10_RESOURCETYPE
--
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++