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

--       EXAMPLE:    db2 -td@ -vf c:\temp\db2\reporter_aiops_alerts.sql
--------------------------------------------------------------------------------
--#SET TERMINATOR @

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- THIS SECTION OF THE SCRIPT CREATES ALL THE TABLES DIRECTLY
-- ACCESSED BY THE REPORTER

-- TABLES:
--        ALERTS_REPORTER_STATUS
--//////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_REPORTER_STATUS table contains raw alert data.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ALERTS_REPORTER_STATUS (
    tenantid            VARCHAR(64) NOT NULL,
    severity            INTEGER,
    businessCriticality VARCHAR(255),
    state               VARCHAR(32),
    id                  VARCHAR(255) NOT NULL,
    summary             VARCHAR(2048),
    eventType           VARCHAR(255),
    sender              VARCHAR(255),
    resource            VARCHAR(255),
    firstOccurrenceTime TIMESTAMP,
    lastOccurrenceTime  TIMESTAMP,
    runbooks            INTEGER,
    topology            INTEGER,
    seasonal            INTEGER,
    inIncident          INTEGER,
    triggerAlert        INTEGER,
    resolutions         INTEGER,
    templates           INTEGER,
    suppressed          INTEGER,
    anomalyInsights     INTEGER,
    incidentControl     INTEGER,
    subTopology         INTEGER,
    scopeGroup          INTEGER,
    temporal            INTEGER,
    owner               VARCHAR(255),        
    goldenSignal        VARCHAR(255),
    eventCount          INTEGER,
    acknowledged        INTEGER,
    team                VARCHAR(255),
    deduplicationKey    VARCHAR(255),
    signature           VARCHAR(255),
    lastStateChangeTime TIMESTAMP,
    langId              VARCHAR(32),
    expirySeconds       INTEGER,
    uuid                VARCHAR(255) NOT NULL,
    PRIMARY KEY (uuid) )@
--DATA CAPTURE NONE@

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--  THIS SECTION LISTS THE AUDIT TABLES WHICH ARE POPULATED OFF THE 
--  ALERTS_REPORTER_STATUS TABLE

--  TABLES:
--        ALERTS_AUDIT_OWNER
--        ALERTS_AUDIT_TEAM
--        ALERTS_AUDIT_SEVERITY
--        ALERTS_AUDIT_ACK
--/////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_AUDIT_OWNER table is used to hold the User details
-- if the User id of a record is changed.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ALERTS_AUDIT_OWNER (
        lastStateChangeTime TIMESTAMP NOT NULL,
        oldOwner            VARCHAR(255) NOT NULL,
        owner               VARCHAR(255) NOT NULL,
        tenantid            VARCHAR(64) NOT NULL,
        id                  VARCHAR(255) NOT NULL,
        uuid                VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES ALERTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for ALERTS_AUDIT_OWNER

CREATE INDEX ALERTS_AUDIT_OWNER_IDX
       ON ALERTS_AUDIT_OWNER (
               uuid )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_AUDIT_TEAM table is used to hold the team details
-- if the team id of a record is changed.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ALERTS_AUDIT_TEAM (
        lastStateChangeTime TIMESTAMP NOT NULL,
        oldTeam             VARCHAR(255) NOT NULL,
        team                VARCHAR(255) NOT NULL,
        tenantid            VARCHAR(64) NOT NULL,
        id                  VARCHAR(255) NOT NULL,
        uuid                VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES ALERTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for ALERTS_AUDIT_TEAM

CREATE INDEX ALERTS_AUDIT_TEAM_IDX
       ON ALERTS_AUDIT_TEAM (
               tenantid,
               id )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_AUDIT_SEVERITY table is used to record the changes in severity
-- of a record in the Reporter_status table.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Create the Table ALERTS_AUDIT_SEVERITY
CREATE TABLE ALERTS_AUDIT_SEVERITY (
        lastStateChangeTime TIMESTAMP NOT NULL,
        endDate             TIMESTAMP,
        severity            INTEGER,
        state               INTEGER,
        tenantid            VARCHAR(64) NOT NULL,
        id                  VARCHAR(255) NOT NULL,
        uuid                VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES ALERTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @


-- Create the Index for ALERTS_AUDIT_SEVERITY

CREATE INDEX ALERTS_AUDIT_SEVERITY_IDX
       ON ALERTS_AUDIT_SEVERITY (
               uuid,
               state )
       PCTFREE 10 @

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_AUDIT_ACK table is used to record each acknowledgement
-- made to a record in the reporter status table.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


-- Create table used for storing audit trail of Acknowledgement changes
CREATE TABLE ALERTS_AUDIT_ACK (
        acknowledged        INTEGER,
        lastStateChangeTime TIMESTAMP NOT NULL,
        endDate             TIMESTAMP,
        owner               VARCHAR(255) NOT NULL,
        state               INTEGER,
        tenantid            VARCHAR(64) NOT NULL,
        id                  VARCHAR(255) NOT NULL,
        uuid                VARCHAR(255) NOT NULL,
        CONSTRAINT eventref FOREIGN KEY (uuid) REFERENCES ALERTS_REPORTER_STATUS(uuid) ON DELETE CASCADE )@
--DATA CAPTURE NONE @

-- Create the Index for ALERTS_AUDIT_ACK

CREATE INDEX ALERTS_AUDIT_ACK_IDX
       ON ALERTS_AUDIT_ACK (
               uuid,
               state )
       PCTFREE 10 @

-- Create Supplementary Tables

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_SEVERITY_TYPES is used to hold the STATIC severity types data
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Create table to store Severity Text Values
CREATE TABLE ALERTS_SEVERITY_TYPES (
        severity        INTEGER NOT NULL,
        name            CHAR (64) NOT NULL,
        PRIMARY KEY (severity) )@
--DATA CAPTURE NONE @


INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 0, 'Clear' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 1, 'Indeterminate' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 2, 'Information' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 3, 'Warning' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 4, 'Minor' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 5, 'Major' ) @
INSERT INTO ALERTS_SEVERITY_TYPES VALUES ( 6, 'Critical' ) @


COMMIT WORK @

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- This section lists the triggers and the procedures for audit

-- There are only three triggers acting on the status table.
-- They are called ALERTS_AUDIT_INSERT,
--                 ALERTS_AUDIT_UPDATE,
--                 ALERTS_AUDIT_ACK.

-- There are five procedures that are performed from the triggers.
-- The procedures are:   
--
-- Acknowledged Procedure:
--      The acknowledged procedure is used to record each acknowledgement
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
-- Severity Procedure:
--      The severity procedure table is used to record the changes in
--      severity of a record in the reporter status table.
--///////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ALERTS_AUDIT_INSERT and ALERTS_AUDIT_UPDATE triggers are the only ones 
-- that fire off the ALERTS_REPORTER_STATUS table. They are used to record all
-- types of changes a record may undergo whether manually performed or
-- carried out by automation.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TRIGGER ALERTS_AUDIT_INSERT
AFTER INSERT ON ALERTS_REPORTER_STATUS
REFERENCING NEW AS N
FOR EACH ROW 
MODE DB2SQL
WHEN ( N.lastStateChangeTime IS NOT NULL )
BEGIN ATOMIC
        -- start acknowledged procedure
        UPDATE ALERTS_AUDIT_ACK SET 
                enddate = N.lastStateChangeTime,
                state = 1
        WHERE
                uuid = N.uuid AND
                state = 0 ;
        INSERT INTO ALERTS_AUDIT_ACK VALUES (
                N.acknowledged, 
                N.lastStateChangeTime, 
                NULL, 
                N.owner, 
                0, 
                N.tenantid, 
                N.id,
                N.uuid ) ;
        -- start severity procedure
        UPDATE ALERTS_AUDIT_SEVERITY SET
                enddate = N.lastStateChangeTime,
                state = 1
        WHERE
                uuid = N.uuid AND
                state = 0 ;
        INSERT INTO ALERTS_AUDIT_SEVERITY VALUES ( 
                N.lastStateChangeTime, 
                NULL, 
                N.severity,
                0,
                N.tenantid, 
                N.id,
                N.uuid ) ;
END @

CREATE TRIGGER ALERTS_AUDIT_UPDATE_SEVERITY
AFTER UPDATE ON ALERTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.severity <> N.severity AND N.lastStateChangeTime IS NOT NULL )
BEGIN ATOMIC
                -- start severity procedure
                UPDATE ALERTS_AUDIT_SEVERITY SET
                        enddate = N.lastStateChangeTime,
                        state = 1
                WHERE
                        uuid = N.uuid AND
                        state = 0 ;
              
                INSERT INTO ALERTS_AUDIT_SEVERITY VALUES ( 
                        N.lastStateChangeTime, 
                        NULL, 
                        N.severity,
                        0,
                        N.tenantid,
                        N.id,
                        N.uuid ) ;
END @

CREATE TRIGGER ALERTS_AUDIT_UPDATE_OWNER
AFTER UPDATE ON ALERTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.owner <> N.owner AND N.lastStateChangeTime IS NOT NULL )
BEGIN ATOMIC
                -- start owner procedure
                INSERT INTO ALERTS_AUDIT_OWNER VALUES ( 
                        N.lastStateChangeTime,
                        O.owner,
                        N.owner,
                        N.tenantid,
                        N.id,
                        N.uuid );
END @

CREATE TRIGGER ALERTS_AUDIT_UPDATE_TEAM
AFTER UPDATE ON ALERTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.team <> N.team AND N.lastStateChangeTime IS NOT NULL )
BEGIN ATOMIC
                -- start team procedure
                INSERT INTO ALERTS_AUDIT_TEAM VALUES (
                        N.lastStateChangeTime,
                        O.team,
                        N.team,
                        N.tenantid,
                        N.id,
                        N.uuid );
END @

CREATE TRIGGER ALERTS_AUDIT_UPDATE_ACK
AFTER UPDATE ON ALERTS_REPORTER_STATUS
REFERENCING NEW AS N OLD AS O
FOR EACH ROW 
MODE DB2SQL
WHEN ( O.acknowledged <> N.acknowledged AND N.lastStateChangeTime IS NOT NULL )
BEGIN ATOMIC
                -- start acknowledged procedure
                UPDATE ALERTS_AUDIT_ACK SET 
                        enddate = N.lastStateChangeTime,
                        state = 1
                WHERE
                        uuid = N.uuid AND
                        state = 0;
        
                INSERT INTO ALERTS_AUDIT_ACK VALUES (
                        N.acknowledged,
                        N.lastStateChangeTime, 
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

CREATE VIEW ALERTS_STATUS_VW (
        severity,
        businessCriticality,
        state,
        summary,
        eventType,
        sender,
        resource,
        firstOccurrenceTime,
        lastOccurrenceTime,
        runbooks,
        topology,
        seasonal,
        inIncident,
        suppressed,
        goldenSignal
) AS SELECT 
        ALERTS_SEVERITY_TYPES.name,
        businessCriticality,
        state,
        summary,
        eventType,
        sender,
        resource,
        (REPLACE(CHAR(firstOccurrenceTime),'.',':')),
        (REPLACE(CHAR(lastOccurrenceTime),'.',':')),
        runbooks,
        case 
            when topology > 0 then 'Yes'
            when topology = 0 then 'No'
        end as topology,
        case 
            when seasonal > 0 then 'Yes'
            when seasonal = 0 then 'No'
        end as seasonal,
        case 
            when inIncident > 0 then 'Yes'
            when inIncident = 0 then 'No'
        end as inIncident,
        case 
            when suppressed > 0 then 'Yes'
            when suppressed = 0 then 'No'
        end as suppressed,
        goldenSignal
FROM 
        ALERTS_REPORTER_STATUS, ALERTS_SEVERITY_TYPES
WHERE
        ALERTS_REPORTER_STATUS.severity = ALERTS_SEVERITY_TYPES.severity @

CREATE VIEW ALERTS_AUDIT (
        id, 
        lastStateChangeTime, 
        valueAck, 
        valueSeverity, 
        valueOwner, 
        valueTeam) 
AS SELECT
        id,
        lastStateChangeTime,
        acknowledged,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR)
FROM ALERTS_AUDIT_ACK
UNION SELECT
        id,
        lastStateChangeTime,
        CAST(NULL AS VARCHAR),
        ALERTS_SEVERITY_TYPES.name,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR)
FROM ALERTS_AUDIT_SEVERITY, ALERTS_SEVERITY_TYPES
WHERE
        ALERTS_AUDIT_SEVERITY.severity = ALERTS_SEVERITY_TYPES.severity
UNION SELECT
        id,
        lastStateChangeTime,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR),
        owner,
        CAST(NULL AS VARCHAR)
FROM ALERTS_AUDIT_OWNER 
UNION SELECT 
        id,
        lastStateChangeTime,
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR),
        CAST(NULL AS VARCHAR),
        team
FROM ALERTS_AUDIT_TEAM @

COMMIT WORK @
