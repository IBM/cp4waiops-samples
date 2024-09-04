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

--   (2) At the DB2 command window prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2_reporter_aiops_noise_reduction_remove.sql
--------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Drop triggers related to noise reduction.
------------------------------------------------------------------------------
DROP TRIGGER AIOPS_ALERT_COUNT_UPDATER_ON_UPDATE @

DROP TRIGGER ALERT_AIOPS_COUNT_UPDATER_ON_INSERT @

DROP TRIGGER AIOPS_INCIDENT_COUNT_UPDATER_ON_UPDATE @

DROP TRIGGER AIOPS_INCIDENT_COUNT_UPDATER_ON_INSERT @

------------------------------------------------------------------------------
-- Drop procedures related to noise reduction.
------------------------------------------------------------------------------
DROP PROCEDURE INSERT_ALERT_COUNTS_UPDATE @

------------------------------------------------------------------------------
-- Drop tables related to noise reduction.
------------------------------------------------------------------------------
DROP TABLE AIOPS_NOISE_REDUCTION_TIMELINE_TABLE @

COMMIT WORK @
