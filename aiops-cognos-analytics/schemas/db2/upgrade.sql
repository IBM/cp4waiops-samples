-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024, 2025

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script will update existing schemas with updates for the latest
-- Cloud Pak for AIOps release.

-- NOTE: This script requires incidents and alerts schemas to be installed beforehand.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command prompt, run this script.

--       EXAMPLE:    db2 -t -vf c:\temp\db2\upgrade.sql
--------------------------------------------------------------------------------

ALTER TABLE ALERTS_REPORTER_STATUS
    ALTER UUID DROP GENERATED;

ALTER TABLE INCIDENTS_REPORTER_STATUS
    ALTER UUID DROP GENERATED;
