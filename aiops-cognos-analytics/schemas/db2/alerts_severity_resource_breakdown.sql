-- Run with: db2 -td@ -vf alerts_severity_resource_breakdown.sql
--#SET TERMINATOR @

-- Alter ALERTS_REPORTER_STATUS table to include new fields
ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceLatitude VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceLongitude VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceLocation VARCHAR(255) @

ALTER TABLE ALERTS_REPORTER_STATUS
    ADD COLUMN resourceType VARCHAR(255) @

-- Create or replace view for severity breakdown by resource location
-- This view provides a complete matrix of all severity types for all resource locations
-- including zero counts where no alerts exist for a particular combination

CREATE OR REPLACE VIEW ALERTS_SEVERITY_RESOURCE_BREAKDOWN (
  Severity,
  Name,
  Resourcelocation,
  AlertCount,
  ResourceLatitude,
  ResourceLongitude
) AS
select
  slc.Severity,
  slc.Name,
  slc.Resourcelocation,
  coalesce(count(ars.Id), 0),
  slc.ResourceLatitude,
  slc.ResourceLongitude
from (
  select
    st.Severity,
    st.Name,
    dl.Resourcelocation,
    dl.ResourceLatitude,
    dl.ResourceLongitude
  from alerts_severity_types st
  cross join (
    select distinct
      Resourcelocation,
      resourceLatitude ,
      resourceLongitude
    from alerts_reporter_status
  ) dl
) slc
left join alerts_reporter_status ars
  on slc.Severity = ars.Severity
  and slc.Resourcelocation = ars.Resourcelocation
group by
  slc.Resourcelocation,
  slc.ResourceLongitude,
  slc.ResourceLatitude,
  slc.Severity,
  slc.Name @

-- Drop existing objects if they exist
DROP TRIGGER TRG_MAX_SEVERITY_AFTER_INSERT @
DROP TRIGGER TRG_MAX_SEVERITY_AFTER_UPDATE @
DROP TRIGGER TRG_MAX_SEVERITY_AFTER_DELETE @

DROP TABLE ALERTS_MAX_SEVERITY_BY_LOCATION @

-- Create table for maximum severity by resource location
-- This table shows only the highest severity alert for each location
-- Sorted by MaxSeverity (highest severity first)
-- Useful for map visualizations where you want to show the worst-case scenario per location
CREATE TABLE ALERTS_MAX_SEVERITY_BY_LOCATION (
  MaxSeverity INTEGER NOT NULL,
  SeverityName VARCHAR(255),
  Resourcelocation VARCHAR(255) NOT NULL,
  AlertCount INTEGER NOT NULL,
  Latitude VARCHAR(255),
  Longitude VARCHAR(255),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) @

-- Create triggers to auto-refresh on ALERTS_REPORTER_STATUS changes
CREATE TRIGGER TRG_MAX_SEVERITY_AFTER_INSERT
AFTER INSERT ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_MAX_SEVERITY_BY_LOCATION;

    INSERT INTO ALERTS_MAX_SEVERITY_BY_LOCATION (MaxSeverity, SeverityName, Resourcelocation, AlertCount, Latitude, Longitude, last_updated)
    SELECT
      ms.MaxSeverity,
      st.Name as SeverityName,
      ms.Resourcelocation,
      ms.AlertCount,
      ms.Latitude,
      ms.Longitude,
      CURRENT_TIMESTAMP
    FROM (
      SELECT
        MAX(ars.Severity) as MaxSeverity,
        ars.Resourcelocation,
        COUNT(ars.Id) as AlertCount,
        MAX(ars.ResourceLatitude) as Latitude,
        MAX(ars.ResourceLongitude) as Longitude
      FROM alerts_reporter_status ars
      WHERE ars.Severity IS NOT NULL
      GROUP BY ars.Resourcelocation
    ) ms
    INNER JOIN alerts_severity_types st
      ON ms.MaxSeverity = st.Severity
    ORDER BY ms.MaxSeverity DESC;
END @

CREATE TRIGGER TRG_MAX_SEVERITY_AFTER_UPDATE
AFTER UPDATE ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_MAX_SEVERITY_BY_LOCATION;

    INSERT INTO ALERTS_MAX_SEVERITY_BY_LOCATION (MaxSeverity, SeverityName, Resourcelocation, AlertCount, Latitude, Longitude, last_updated)
    SELECT
      ms.MaxSeverity,
      st.Name as SeverityName,
      ms.Resourcelocation,
      ms.AlertCount,
      ms.Latitude,
      ms.Longitude,
      CURRENT_TIMESTAMP
    FROM (
      SELECT
        MAX(ars.Severity) as MaxSeverity,
        ars.Resourcelocation,
        COUNT(ars.Id) as AlertCount,
        MAX(ars.ResourceLatitude) as Latitude,
        MAX(ars.ResourceLongitude) as Longitude
      FROM alerts_reporter_status ars
      WHERE ars.Severity IS NOT NULL
      GROUP BY ars.Resourcelocation
    ) ms
    INNER JOIN alerts_severity_types st
      ON ms.MaxSeverity = st.Severity
    ORDER BY ms.MaxSeverity DESC;
END @

CREATE TRIGGER TRG_MAX_SEVERITY_AFTER_DELETE
AFTER DELETE ON ALERTS_REPORTER_STATUS
FOR EACH STATEMENT
MODE DB2SQL
BEGIN ATOMIC
    -- Clear and refresh the table
    DELETE FROM ALERTS_MAX_SEVERITY_BY_LOCATION;

    INSERT INTO ALERTS_MAX_SEVERITY_BY_LOCATION (MaxSeverity, SeverityName, Resourcelocation, AlertCount, Latitude, Longitude, last_updated)
    SELECT
      ms.MaxSeverity,
      st.Name as SeverityName,
      ms.Resourcelocation,
      ms.AlertCount,
      ms.Latitude,
      ms.Longitude,
      CURRENT_TIMESTAMP
    FROM (
      SELECT
        MAX(ars.Severity) as MaxSeverity,
        ars.Resourcelocation,
        COUNT(ars.Id) as AlertCount,
        MAX(ars.ResourceLatitude) as Latitude,
        MAX(ars.ResourceLongitude) as Longitude
      FROM alerts_reporter_status ars
      WHERE ars.Severity IS NOT NULL
      GROUP BY ars.Resourcelocation
    ) ms
    INNER JOIN alerts_severity_types st
      ON ms.MaxSeverity = st.Severity
    ORDER BY ms.MaxSeverity DESC;
END @

-- Initial population of the table
INSERT INTO ALERTS_MAX_SEVERITY_BY_LOCATION (MaxSeverity, SeverityName, Resourcelocation, AlertCount, Latitude, Longitude, last_updated)
SELECT
  ms.MaxSeverity,
  st.Name as SeverityName,
  ms.Resourcelocation,
  ms.AlertCount,
  ms.Latitude,
  ms.Longitude,
  CURRENT_TIMESTAMP
FROM (
  SELECT
    MAX(ars.Severity) as MaxSeverity,
    ars.Resourcelocation,
    COUNT(ars.Id) as AlertCount,
    MAX(ars.ResourceLatitude) as Latitude,
    MAX(ars.ResourceLongitude) as Longitude
  FROM alerts_reporter_status ars
  WHERE ars.Severity IS NOT NULL
  GROUP BY ars.Resourcelocation
) ms
INNER JOIN alerts_severity_types st
  ON ms.MaxSeverity = st.Severity
ORDER BY ms.MaxSeverity DESC @

COMMIT WORK @