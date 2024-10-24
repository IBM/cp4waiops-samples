
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

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_alerts_remove.sql
--------------------------------------------------------------------------------
--#SET DELIMITER @
------------------------------------------------------------------------------
-- Drop indexes on required tables.
------------------------------------------------------------------------------
DROP INDEX ALERTS_AUDIT_OWNER_IDX @

DROP INDEX ALERTS_AUDIT_TEAM_IDX @

DROP INDEX ALERTS_AUDIT_SEVERITY_IDX @

DROP INDEX ALERTS_AUDIT_ACK_IDX @

------------------------------------------------------------------------------
-- Drop triggers related to alerts.
------------------------------------------------------------------------------
DROP TRIGGER ALERTS_AUDIT_INSERT @

DROP TRIGGER ALERTS_AUDIT_UPDATE_SEVERITY @

DROP TRIGGER ALERTS_AUDIT_UPDATE_OWNER @

DROP TRIGGER ALERTS_AUDIT_UPDATE_TEAM @

DROP TRIGGER ALERTS_AUDIT_UPDATE_ACK @

------------------------------------------------------------------------------
-- Drop views related to alerts.
------------------------------------------------------------------------------

DROP VIEW ALERTS_STATUS_VW @

DROP VIEW ALERTS_AUDIT @

------------------------------------------------------------------------------
-- Drop tables related to alerts.
------------------------------------------------------------------------------
DROP TABLE ALERTS_REPORTER_STATUS @

DROP TABLE ALERTS_AUDIT_OWNER @

DROP TABLE ALERTS_AUDIT_TEAM @

DROP TABLE ALERTS_AUDIT_SEVERITY @

DROP TABLE ALERTS_AUDIT_ACK @

DROP TABLE ALERTS_SEVERITY_TYPES @

COMMIT WORK @
