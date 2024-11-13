-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- DANGER: This script will remove all schema objects needed
-- to store reporting data. This includes tables, indexes and constraints.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command window prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_incidents_remove.sql
--------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Drop indexes on required tables.
------------------------------------------------------------------------------
DROP INDEX INCIDENTS_AUDIT_OWNER_IDX @

DROP INDEX INCIDENTS_AUDIT_TEAM_IDX @

DROP INDEX INCIDENTS_AUDIT_PRIORITY_IDX @

DROP INDEX INCIDENTS_AUDIT_STATE_IDX @

------------------------------------------------------------------------------
-- Drop triggers related to incidents.
------------------------------------------------------------------------------
DROP TRIGGER INCIDENTS_AUDIT_INSERT @

DROP TRIGGER INCIDENTS_AUDIT_UPDATE_PRIORITY @

DROP TRIGGER INCIDENTS_AUDIT_UPDATE_OWNER @

DROP TRIGGER INCIDENTS_AUDIT_UPDATE_TEAM @

DROP TRIGGER INCIDENTS_AUDIT_UPDATE_STATE @

------------------------------------------------------------------------------
-- Drop views related to incidents.
------------------------------------------------------------------------------

DROP VIEW INCIDENTS_STATUS_VW @

DROP VIEW INCIDENTS_AUDIT @

------------------------------------------------------------------------------
-- Drop tables related to incidents.
------------------------------------------------------------------------------
DROP TABLE INCIDENTS_REPORTER_STATUS @

DROP TABLE INCIDENTS_AUDIT_OWNER @

DROP TABLE INCIDENTS_AUDIT_TEAM @

DROP TABLE INCIDENTS_AUDIT_PRIORITY @

DROP TABLE INCIDENTS_AUDIT_STATE @

COMMIT WORK @
