-------------------------------------------------------------------------------
--
-- © Copyright IBM Corp. 2024, 2026

-- This source code is licensed under the Apache-2.0 license found in the
-- LICENSE file in the root directory of this source tree.
--
-------------------------------------------------------------------------------
-- This script will create all the schema objects needed
-- to store alert and incident activity data. This includes tables, indexes and constraints.

-- To run this script, you must do the following:
--   (1) Put this script in directory of your choice.

--   (2) At the command prompt, run this script.

--       EXAMPLE:    db2 -td@ -vf /tmp/reporter_aiops_activity.sql
--------------------------------------------------------------------------------
--#SET TERMINATOR @

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- THIS SECTION OF THE SCRIPT CREATES ALL THE TABLES DIRECTLY
-- ACCESSED BY THE REPORTER

-- TABLES:
--        ACTIVITY_ENTRY
--        ACTIVITY_ENTRY_TYPES
--//////////////////////////////////////////////////////////////////////


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ACTIVITY_ENTRY table contains raw activity entry data.
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE TABLE ACTIVITY_ENTRY (
    tenantid            VARCHAR(64) NOT NULL,
    id                  VARCHAR(255) NOT NULL,
    parentId            VARCHAR(255),
    parentType          VARCHAR(32),
    createdTime         TIMESTAMP NOT NULL,
    type                VARCHAR(32),
    userId              VARCHAR(255),
    comment             VARCHAR(4096),
    policyId            VARCHAR(255),
    runbookId           VARCHAR(255),
    runbookName         VARCHAR(512),
    runbookVersion      INTEGER,
    runbookInstanceId   VARCHAR(255),
    runbookStatus       VARCHAR(32),
    runbookType         VARCHAR(32),
    actionInstanceId    VARCHAR(255),
    timeAdded           TIMESTAMP,
    oldValue            CLOB,
    newValue            CLOB,
    uuid                VARCHAR(255) NOT NULL,
    PRIMARY KEY (uuid) )@
--DATA CAPTURE NONE@


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Indexes to query by parent and user ID
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CREATE INDEX ACTIVITY_PARENT_IDX
       ON ACTIVITY_ENTRY (
               parentId,
               parentType,
               createdTime DESC )@

CREATE INDEX ACTIVITY_USER_IDX
       ON ACTIVITY_ENTRY (
               userId,
               createdTime DESC )@

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- The ACTIVITY_ENTRY_TYPES is used to hold the STATIC activity type data
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Create table to store Activity Type Values
CREATE TABLE ACTIVITY_ENTRY_TYPES (
        type            VARCHAR(32) NOT NULL,
        name            VARCHAR(128) NOT NULL,
        description     VARCHAR(512),
        PRIMARY KEY (type) )@
--DATA CAPTURE NONE @


INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'alertadded', 'Alert Added', 'Details on addition of alert to element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'automation', 'Automation', 'Details on runbook action on element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'comment', 'Comment', 'System or operator comment on element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'created', 'Created', 'Details on element creation' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'eventadded', 'Event Added', 'Details on addition of event to element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'notification', 'Notification', 'Notification of a activity entry related to an element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'ownerchange', 'Owner Change', 'Details on element ownership change' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'policy', 'Policy', 'Details on policy affect on element' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'statechange', 'State Change', 'Details on element state change' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'unknown', 'Unknown', 'Unknown content type for activity' ) @
INSERT INTO ACTIVITY_ENTRY_TYPES VALUES ( 'updated', 'Updated', 'Details on element update not related to owner or state' ) @

COMMIT WORK @

-- ////////////////////////////////////////////////////////////////////
-- The view is specific to reporter and is referenced
-- by the canned reports.
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

CREATE VIEW ACTIVITY_VW (
        createdTime,
        userId,
        type,
        comment,
        oldValue,
        newValue,
        parentId,
        parentType,
        policyId,
        runbookInstanceId,
        actionInstanceId
) AS SELECT
        REPLACE(CHAR(createdTime),'.',':'),
        userId,
        ACTIVITY_ENTRY_TYPES.name,
        comment,
        oldValue,
        newValue,
        parentId,
        parentType,
        policyId,
        runbookInstanceId,
        actionInstanceId
FROM
        ACTIVITY_ENTRY, ACTIVITY_ENTRY_TYPES
WHERE
        ACTIVITY_ENTRY.type = ACTIVITY_ENTRY_TYPES.type @

COMMIT WORK @
