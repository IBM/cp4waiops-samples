-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script will create all the schema objects needed
-- to store reporting data. This includes tables, indexes and constraints.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_incidents.sql
--------------------------------------------------------------------------------
--#SET TERMINATOR @

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- THIS SECTION OF THE SCRIPT CREATES ALL THE TABLES DIRECTLY
-- ACCESSED BY THE REPORTER

-- TABLES:
--        INCIDENTS_REPORTER_STATUS
--//////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_REPORTER_STATUS table contains raw incident data.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE INCIDENTS_REPORTER_STATUS (
    tenantid            VARCHAR(64) NOT NULL,
    id	                VARCHAR(255) NOT NULL,
    createdTime		TIMESTAMP,
    createdBy		VARCHAR(255),
    title		VARCHAR(255),
    description		VARCHAR(1024),
    langId		VARCHAR(3),
    priority            INTEGER,
    state		VARCHAR(30),
    lastChangedTime	TIMESTAMP,
    owner		VARCHAR(255),
    team		VARCHAR(255),
    alerts              INTEGER,
    similarIncidents    INTEGER,
    splitIncidents      INTEGER,
    probableCauseAlerts INTEGER,
    tickets             INTEGER,
    chatOpsIntegrations INTEGER,
    resourceId          VARCHAR(255),
    policyId            VARCHAR(64),
    uuid                VARCHAR(255) NOT NULL,
    PRIMARY KEY (uuid) )@
--DATA CAPTURE NONE@

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--  THIS SECTION LISTS THE AUDIT TABLES WHICH ARE POPULATED OFF THE 
--  INCIDENTS_REPORTER_STATUS TABLE

--  TABLES:
--        INCIDENTS_AUDIT_OWNER
--        INCIDENTS_AUDIT_TEAM
--        INCIDENTS_AUDIT_PRIORITY
--        INCIDENTS_AUDIT_STATE
--/////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_AUDIT_OWNER table is used to hold the User details
-- if the User id of a record is changed.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE INCIDENTS_AUDIT_OWNER (
        lastChangedTime TIMESTAMP NOT NULL,
        oldOwner        VARCHAR(255) NOT NULL,
        owner           VARCHAR(255) NOT NULL,
        tenantid        VARCHAR(64) NOT NULL,
        id              VARCHAR(255) NOT NULL,
        uuid            VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES INCIDENTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for INCIDENTS_AUDIT_OWNER

CREATE INDEX INCIDENTS_AUDIT_OWNER_IDX
       ON INCIDENTS_AUDIT_OWNER (
               uuid )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_AUDIT_TEAM table is used to hold the team details
-- if the team id of a record is changed.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE INCIDENTS_AUDIT_TEAM (
        lastChangedTime TIMESTAMP NOT NULL,
        oldTeam         VARCHAR(255) NOT NULL,
        team            VARCHAR(255) NOT NULL,
        tenantid        VARCHAR(64) NOT NULL,
        id              VARCHAR(255) NOT NULL,
        uuid            VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES INCIDENTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for INCIDENTS_AUDIT_TEAM

CREATE INDEX INCIDENTS_AUDIT_TEAM_IDX
       ON INCIDENTS_AUDIT_TEAM (
               tenantid,
               id )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_AUDIT_PRIORITY table is used to record the changes in priority
-- of a record in the Reporter_status table.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Create the Table INCIDENTS_AUDIT_PRIORITY
CREATE TABLE INCIDENTS_AUDIT_PRIORITY (
        lastChangedTime TIMESTAMP NOT NULL,
        endDate         TIMESTAMP,
        priority        INTEGER,
        complete        INTEGER,
        tenantid        VARCHAR(64) NOT NULL,
        id              VARCHAR(255) NOT NULL,
        uuid            VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES INCIDENTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @


-- Create the Index for INCIDENTS_AUDIT_PRIORITY

CREATE INDEX INCIDENTS_AUDIT_PRIORITY_IDX
       ON INCIDENTS_AUDIT_PRIORITY (
               uuid,
               complete )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_AUDIT_STATE table is used to record each state change
-- made to a record in the reporter status table.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


-- Create table used for storing audit trail of State changes
CREATE TABLE INCIDENTS_AUDIT_STATE (
        state           VARCHAR(30),
        lastChangedTime TIMESTAMP NOT NULL,
        endDate         TIMESTAMP,
        owner           VARCHAR(255) NOT NULL,
        complete        INTEGER,
        tenantid        VARCHAR(64) NOT NULL,
        id              VARCHAR(255) NOT NULL,
        uuid            VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES INCIDENTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for INCIDENTS_AUDIT_STATE

CREATE INDEX INCIDENTS_AUDIT_STATE_IDX
       ON INCIDENTS_AUDIT_STATE (
               uuid,
               complete )
       PCTFREE 10 @

COMMIT WORK @

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- This section lists the triggers and the procedures for audit

-- There are only three triggers acting on the status table.
-- They are called INCIDENTS_AUDIT_INSERT,
--                 INCIDENTS_AUDIT_UPDATE,
--                 INCIDENTS_AUDIT_STATE.

-- There are four procedures that are performed from the triggers.
-- The procedures are:   
--
-- State Procedure:
--      The state procedure is used to record each state change
--      made to a record in the reporter status table.
--
-- Team Procedure:
--      The team procedure is used to record the Team id details
--      if the team id of a record is changed.
--
-- Owner Procedure:
--      The owner procedure is used to record the User id details
--      if the User id of a record is changed.
--
-- Priority Procedure:
--      The priority procedure table is used to record the changes in
--      priority of a record in the reporter status table.
--///////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The INCIDENTS_AUDIT_INSERT and INCIDENTS_AUDIT_UPDATE triggers are the only ones 
-- that fire off the INCIDENTS_REPORTER_STATUS table. They are used to record all
-- types of changes a record may undergo whether manually performed or
-- carried out by automation.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TRIGGER INCIDENTS_AUDIT_INSERT
AFTER INSERT ON INCIDENTS_REPORTER_STATUS
REFERENCING NEW AS N
FOR EACH ROW 
MODE DB2SQL
WHEN ( N.lastChangedTime IS NOT NULL )
BEGIN ATOMIC
        -- start state change procedure
        UPDATE INCIDENTS_AUDIT_STATE SET 
                enddate = N.lastChangedTime,
                complete = 1
        WHERE
                uuid = N.uuid AND
                complete = 0 ;
        INSERT INTO INCIDENTS_AUDIT_STATE VALUES (
                N.state, 
                N.lastChangedTime, 
                NULL, 
                N.owner, 
                0, 
                N.tenantid, 
                N.id,
                N.uuid ) ;
        -- start priority procedure
        UPDATE INCIDENTS_AUDIT_PRIORITY SET
                enddate = N.lastChangedTime,
                complete = 1
        WHERE
                uuid = N.uuid AND
                complete = 0 ;
        INSERT INTO INCIDENTS_AUDIT_PRIORITY VALUES ( 
                N.lastChangedTime, 
                NULL, 
                N.priority,
                0,
                N.tenantid, 
                N.id,
                N.uuid ) ;
END @

CREATE TRIGGER INCIDENTS_AUDIT_UPDATE_PRIORITY
AFTER UPDATE ON INCIDENTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.priority <> N.priority AND N.lastChangedTime IS NOT NULL )
BEGIN ATOMIC
                -- start priority procedure
                UPDATE INCIDENTS_AUDIT_PRIORITY SET
                        enddate = N.lastChangedTime,
                        complete = 1
                WHERE
                        uuid = N.uuid AND
                        complete = 0 ;
              
                INSERT INTO INCIDENTS_AUDIT_PRIORITY VALUES ( 
                        N.lastChangedTime, 
                        NULL, 
                        N.priority,
                        0,
                        N.tenantid,
                        N.id,
                        N.uuid ) ;
END @

CREATE TRIGGER INCIDENTS_AUDIT_UPDATE_OWNER
AFTER UPDATE ON INCIDENTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.owner <> N.owner AND N.lastChangedTime IS NOT NULL )
BEGIN ATOMIC
                -- start owner procedure
                INSERT INTO INCIDENTS_AUDIT_OWNER VALUES ( 
                        N.lastChangedTime,
                        O.owner,
                        N.owner,
                        N.tenantid,
                        N.id,
                        N.uuid );
END @

CREATE TRIGGER INCIDENTS_AUDIT_UPDATE_TEAM
AFTER UPDATE ON INCIDENTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.team <> N.team AND N.lastChangedTime IS NOT NULL )
BEGIN ATOMIC
                -- start team procedure
                INSERT INTO INCIDENTS_AUDIT_TEAM VALUES (
                        N.lastChangedTime,
                        O.team,
                        N.team,
                        N.tenantid,
                        N.id,
                        N.uuid );
END @

CREATE TRIGGER INCIDENTS_AUDIT_UPDATE_STATE
AFTER UPDATE ON INCIDENTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.state <> N.state AND N.lastChangedTime IS NOT NULL )
BEGIN ATOMIC
                -- start state change procedure
                UPDATE INCIDENTS_AUDIT_STATE SET 
                        enddate = N.lastChangedTime,
                        complete = 1
                WHERE
                        uuid = N.uuid AND
                        complete = 0;
        
                INSERT INTO INCIDENTS_AUDIT_STATE VALUES (
                        N.state,
                        N.lastChangedTime, 
                        NULL, 
                        N.owner, 
                        0, 
                        N.tenantid, 
                        N.id,
                        N.uuid );
END @


-- ////////////////////////////////////////////////////////////////////
-- The final two views are specific to reporter and are referenced
-- by the canned reports.
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

CREATE VIEW INCIDENTS_STATUS_VW (
        priority,
        state,
        id,
        title,
        alerts,
        createdTime,
        team,
        owner
) AS SELECT 
        priority,
        state,
        id,
        title,
        alerts,
        REPLACE(CHAR(createdTime),'.',':'),
        team,
        owner
FROM 
        INCIDENTS_REPORTER_STATUS @

CREATE VIEW INCIDENTS_AUDIT (
        id, 
        lastChangedTime, 
        valueState, 
        valuePriority, 
        valueOwner, 
        valueTeam) 
AS SELECT
        id,
        lastChangedTime,
        state,
        CAST(NULL AS INTEGER),
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR)
FROM INCIDENTS_AUDIT_STATE
UNION SELECT
        id,
        lastChangedTime,
        CAST(NULL AS VARCHAR),
        priority,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR)
FROM INCIDENTS_AUDIT_PRIORITY
UNION SELECT
        id,
        lastChangedTime,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS INTEGER),
        owner,
        CAST(NULL AS VARCHAR)
FROM INCIDENTS_AUDIT_OWNER 
UNION SELECT 
        id,
        lastChangedTime,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS INTEGER),
        CAST(NULL AS VARCHAR),
        team
FROM INCIDENTS_AUDIT_TEAM @

COMMIT WORK @
