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

-- Create or replace view for maximum severity by resource location
-- This view shows only the highest severity alert for each location
-- Useful for map visualizations where you want to show the worst-case scenario per location
CREATE OR REPLACE VIEW ALERTS_MAX_SEVERITY_BY_LOCATION (
  MaxSeverity,
  SeverityName,
  Resourcelocation,
  AlertCount,
  Latitude,
  Longitude
) AS
select
  ms.MaxSeverity,
  st.Name as SeverityName,
  ms.Resourcelocation,
  ms.AlertCount,
  ms.Latitude,
  ms.Longitude
from (
  select
    max(ars.Severity) as MaxSeverity,
    ars.Resourcelocation,
    count(ars.Id) as AlertCount,
    max(ars.ResourceLatitude) as Latitude,
    max(ars.ResourceLongitude) as Longitude
  from alerts_reporter_status ars
  where ars.Severity is not null
  group by ars.Resourcelocation
) ms
inner join alerts_severity_types st
  on ms.MaxSeverity = st.Severity @

COMMIT WORK @