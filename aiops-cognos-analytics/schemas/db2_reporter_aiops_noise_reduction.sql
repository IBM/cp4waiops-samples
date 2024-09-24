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

--   (2) At the DB2 command prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2_reporter_aiops_noise_reduction.sql
--------------------------------------------------------------------------------

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- THIS SECTION OF THE SCRIPT CREATES ALL THE TABLES DIRECTLY
-- ACCESSED BY THE REPORTER

-- TABLES:
--        AIOPS_NOISE_REDUCTION_TIMELINE_TABLE
--//////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The AIOPS_NOISE_REDUCTION_TIMELINE_TABLE contains noise reduction over time.
-- Only includes alerts which are part of an incident.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


CREATE TABLE AIOPS_NOISE_REDUCTION_TIMELINE_TABLE(
  UUIDCOL INT not null GENERATED ALWAYS AS IDENTITY(START WITH 0, INCREMENT BY 1), 
  EVENTCOUNT BIGINT, 
  ALERTCOUNT BIGINT,
  INCIDENTCOUNT BIGINT,
  UPDATETIME TIMESTAMP
)@

CREATE OR REPLACE PROCEDURE INSERT_ALERT_COUNTS_UPDATE(in incidentCount BIGINT, in alertCount BIGINT, in eventCount BIGINT)
BEGIN ATOMIC
  INSERT INTO AIOPS_NOISE_REDUCTION_TIMELINE_TABLE(
    EVENTCOUNT,
    ALERTCOUNT,
    INCIDENTCOUNT,
    UPDATETIME
  ) VALUES(
    eventCount,
    alertCount,
    incidentCount,
    CURRENT TIMESTAMP(3)
  );
END@

CREATE OR REPLACE TRIGGER AIOPS_ALERT_COUNT_UPDATER_ON_UPDATE
  AFTER UPDATE ON ALERTS_REPORTER_STATUS
  FOR EACH ROW
BEGIN ATOMIC
  declare incidentCount BIGINT;
  declare alertCount BIGINT;
  declare eventCount BIGINT;
  set incidentCount=(select count(*) from INCIDENTS_REPORTER_STATUS);
  set alertCount=(select count(*) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  set eventCount=(select sum(EVENTCOUNT) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  CALL INSERT_ALERT_COUNTS_UPDATE(incidentCount, alertCount, eventCount);
END@

CREATE OR REPLACE TRIGGER ALERT_AIOPS_COUNT_UPDATER_ON_INSERT
  AFTER INSERT ON ALERTS_REPORTER_STATUS
  FOR EACH ROW
BEGIN ATOMIC
  declare incidentCount BIGINT;
  declare alertCount BIGINT;
  declare eventCount BIGINT;
  set incidentCount=(select count(*) from INCIDENTS_REPORTER_STATUS);
  set alertCount=(select count(*) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  set eventCount=(select sum(EVENTCOUNT) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  CALL INSERT_ALERT_COUNTS_UPDATE(incidentCount, alertCount, eventCount);
END@

CREATE OR REPLACE TRIGGER AIOPS_INCIDENT_COUNT_UPDATER_ON_UPDATE
  AFTER UPDATE ON INCIDENTS_REPORTER_STATUS
  FOR EACH ROW
BEGIN ATOMIC
  declare incidentCount BIGINT;
  declare alertCount BIGINT;
  declare eventCount BIGINT;
  set incidentCount=(select count(*) from INCIDENTS_REPORTER_STATUS);
  set alertCount=(select count(*) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  set eventCount=(select sum(EVENTCOUNT) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  CALL INSERT_ALERT_COUNTS_UPDATE(incidentCount, alertCount, eventCount);
END@

CREATE OR REPLACE TRIGGER AIOPS_INCIDENT_COUNT_UPDATER_ON_INSERT
  AFTER INSERT ON INCIDENTS_REPORTER_STATUS
  FOR EACH ROW
BEGIN ATOMIC
  declare incidentCount BIGINT;
  declare alertCount BIGINT;
  declare eventCount BIGINT;
  set incidentCount=(select count(*) from INCIDENTS_REPORTER_STATUS);
  set alertCount=(select count(*) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  set eventCount=(select sum(EVENTCOUNT) from ALERTS_REPORTER_STATUS where ININCIDENT <> 0);
  CALL INSERT_ALERT_COUNTS_UPDATE(incidentCount, alertCount, eventCount);
END@

COMMIT WORK @
