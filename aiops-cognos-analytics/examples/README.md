# Examples
This folder contains `data modules` and `dashboard` examples.  <br />

This requires IBM Cognos Analytics **version 11.2 or higher**.

## Files

[TelcoDash.zip](telcoDash/TelcoDash.zip) - Alert data example

[AlertsData.csv](telcoDash/AlertsData.csv) - Static alert data (optional)

[PMdash.zip](pmDash/PMdash.zip) - Incident data example

[IncidentDataStatic.csv](pmDash/IncidentDataStatic.csv),  [EventCountStatic.csv](pmDash/EventCountStatic.csv) - Static incident data (optional) 

## Installation 
[Download video demo](videoSteps/ImportDemo.mov)

#### 1. Find the location for Cognos extensions

_For Cognos running within an OpenShift cluster, locate the pod that contains /data/deployment/. Search for `ca-` to find Cognos pods_.

``` bash
kubectl get pods | grep ca-
```

``` bash
ca1721852474940188-artifacts-bc9d68dc4-gzk6p 1/1 Running 0 21d
ca1721852474940188-ca-cpd-cm-78676c5d8f-gctsj 1/1 Running 0 21d
ca1721852474940188-ca-cpd-reporting-94bd774b8-d2thf 2/2 Running 0 21d
ca1721852474940188-ca-cpd-rest-bd5667547-m7dxq 2/2 Running 0 21d
ca1721852474940188-ca-cpd-smarts-7bbdd6ff97-vnwvl 2/2 Running 0 21d
ibm-ca-operator-controller-manager-7b7d67667b-tks6b 1/1 Running 6 (4h36m ago) 21d
```

_Check if the pod has /data/deployment/_.

``` bash
kubectl exec <pod_name> -- find / -type d -name 'deployment' 2>/dev/null
```

``` bash
/data/deployment
/deployment
```

_For standalone Cognos, this file will be on the Cognos server typically under `/opt/ibm/cognos/analytics/deployment`._

#### 2. Install the example zip file

_For Cognos running within an OpenShift cluster_

``` bash
kubectl cp ./<example>.zip <pod_name>:/data/deployment/<example>.zip
```

_For a standalone Cognos server_
```bash
 cp ./<example>.zip /opt/ibm/cognos/analytics/deployment/<example>.zip
```

#### 3. Open the admin console in the Cognos UI

#### 4. Go to configuration then content administration then select the new import button

#### 5. Select the package name

#### 6. Select next and select the checkbox next to the folder

#### 7. Select next and finish

#### 8. Deployment will show up in **Team content**

#### 9. For static dashboards which use csv data
- The examples will initially show errors due to missing data.
- Upload the corresponding csv. [(download demo)](videoSteps/StaticCSVUpload.mov)
- Re-link the example data source(s) to the uploaded .csv(s) with the same name.

#### 10. Reload the page if visualizations will not load

## Troubleshooting 

1. Color of severity is off - Check if the custom color extension has been installed and used.

2. Funnel graph is blank - Check if the funnel extension has been installed.

3. Missing data (errored visualizations) - Check if the data sources have been properly linked.

---
## Extensions 
[Custom color extension](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FEXT00064&id=i208E818772C44592A1CFDDC59C6E48A1&objRef=i208E818772C44592A1CFDDC59C6E48A1&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22i208E818772C44592A1CFDDC59C6E48A1%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22EXT00064%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) - Provides a richer color palette

[Custom funnel extension](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FVIZ00024&id=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&objRef=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22iD8FDBEAFC25E4D1BA440A9FFA9FD5401%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22VIZ00024%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) - Required for the incident dashboard example

## Additional details 

[Exporting just the dashboard without a data source](https://www.ibm.com/support/pages/how-importexport-dashboard-specification-ibm-Cognos-analytics)

[Exporting reports or deployment packages](https://www.ibm.com/support/pages/how-move-Cognos-analytics-reports-dashboards-and-data-modules-one-environment-another)
