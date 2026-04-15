# Grafana Dashboards - Version 4.11.0

## Changes from Version 4.10.1

### 6 New Dashboards Added

- **aiops_analytics_dashboard.json** - New dashboard for analytics and insights visualization
- **aiops_event_integrations_dashboard.json** - New dashboard for monitoring event integration sources
- **aiops_log_integrations_dashboard.json** - New dashboard for monitoring log integration sources
- **aiops_metric_integrations_dashboard.json** - New dashboard for monitoring metric integration sources
- **aiops_prometheus_stack_dashboard.json** - New dashboard for Prometheus stack monitoring
- **aiops_top_level_dashboard.json** - New top-level overview dashboard providing high-level system status

### Existing Dashboards Updated

- All component dashboards updated with "lowest pod uptime" panels for quick identification pod stability issues
- **aiops_topology_dashboard.json** - Updated with message processing lag metrics
- **aiops_usage_dashboard.json** - Updated with specific metrics for Jira, Git, & ChatOps
- **aiops_web_ui_dashboard.json** - Updated with request/response metrics for all UI pages

### Summary

Version 4.11.0 represents a major expansion of the dashboard collection, more than doubling the number of available dashboards. This release introduces comprehensive integration monitoring capabilities across events, logs, and metrics, along with a new top-level overview dashboard and dedicated analytics dashboard. The Prometheus stack dashboard provides enhanced monitoring for the underlying metrics infrastructure.

To ensure compatibility, always use the version of the dashboards that matches the version of IBM Cloud Pak for AIOps.