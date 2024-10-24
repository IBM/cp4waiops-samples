-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script will create all the schema objects needed
-- to store reporting data. This includes tables, indexes and constraints.

-- NOTE: This script requires incidents and alerts schemas to be installed beforehand.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_noise_reduction.sql
--------------------------------------------------------------------------------

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- THIS SECTION OF THE SCRIPT CREATES ALL THE TABLES DIRECTLY
-- ACCESSED BY THE REPORTER

-- VIEWS:
--        INCIDENT_DASHBOARD
--//////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENT_DASHBOARD provides a an example view of incident health.
-- This includes noise reduction and summarization metrics.
-- Since the alert and incident tables are not joined, this is a union
-- of summarization metrics needed for the example dashboard.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--#SET TERMINATOR @

CREATE VIEW INCIDENT_DASHBOARD (
        eventCount, 
        alertCount, 
        incidentCount,
        unassignedCount,
        inProgressCount,
        ticketedCount,
        criticalPct) 
AS SELECT
        SUM(EVENTCOUNT),
        COUNT(*),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        CAST(NULL AS DECIMAL)
FROM ALERTS_REPORTER_STATUS
		WHERE ININCIDENT <> 0
UNION SELECT
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        SUM(case when STATE <> 'closed' then 1 else 0 end),
        SUM(case when STATE = 'unassigned' then 1 else 0 end),
        SUM(case when STATE = 'inProgress' then 1 else 0 end),
        SUM(case when TICKETS > 0 and STATE <> 'closed' then 1 else 0 end),
        CAST(CAST(SUM(case when PRIORITY = 1 then 1 else 0 end) AS FLOAT) / SUM(case when STATE <> 'closed' then 1 else 0 end) * 100 AS DECIMAL(5,2))
FROM INCIDENTS_REPORTER_STATUS @

COMMIT WORK @
