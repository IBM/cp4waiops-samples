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

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_noise_reduction_remove.sql
----------------------------------- ---------------------------------------------

------------------------------------------------------------------------------
-- Drop views related to noise reduction.
------------------------------------------------------------------------------
--#SET TERMINATOR @

DROP VIEW INCIDENT_DASHBOARD @

COMMIT WORK @
