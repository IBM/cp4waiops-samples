-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024, 2026

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- DANGER: This script will remove all schema objects needed
-- to store activity reporting data. This includes tables, indexes and constraints.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command window prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf /tmp/db2/reporter_aiops_activity_remove.sql
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Drop indexes on required tables.
------------------------------------------------------------------------------
DROP INDEX ACTIVITY_PARENT_IDX @

DROP INDEX ACTIVITY_USER_IDX @

------------------------------------------------------------------------------
-- Drop views related to activity.
------------------------------------------------------------------------------
DROP VIEW ACTIVITY_VW @

------------------------------------------------------------------------------
-- Drop tables related to activity.
------------------------------------------------------------------------------
DROP TABLE ACTIVITY_ENTRY @

DROP TABLE ACTIVITY_ENTRY_TYPES @

COMMIT WORK @
