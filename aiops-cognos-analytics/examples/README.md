# Examples
This folder contains dashboard examples.  <br />

This requires IBM Cognos Analytics **version 11.2 or higher**.

## Files

[Cloud_Pak_for_AIOps_examples.zip](Cloud_Pak_for_AIOps_examples.zip) - Example dashboards

## Installation 
[Installation video demo](videoSteps/ImportDemo.mov)

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
kubectl cp ./Cloud_Pak_for_AIOps_examples.zip <pod_name>:/data/deployment/Cloud_Pak_for_AIOps_examples.zip
```

_For a standalone Cognos server_
```bash
 cp ./Cloud_Pak_for_AIOps_examples.zip /opt/ibm/cognos/analytics/deployment/Cloud_Pak_for_AIOps_examples.zip
```

#### 3. Open the `Manage > Administration console...` menu option from the IBM Cognos Analytics home page.

#### 4. Go to `Configuration > Content Administration` and click the `New Import` button in the top-right.

#### 5. Select the package `Cloud_Pak_for_AIOps_examples` and click Next.

#### 6. You will be prompted for a passcode. Enter `examples`, and click OK.

#### 7. Update the name and description if desired and click Next.

#### 8. Select the checkbox next to the `Cloud Pak for AIOps examples` folder, and click Next.

#### 9. Click Next through the remaining steps, updating defaults as needed.

#### 10. Click Finish, Run, OK. The examples package should then show up in the content list.

#### 11. The incident dashboard example requires a custom funnel extension. [Download](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FVIZ00024&id=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&objRef=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22iD8FDBEAFC25E4D1BA440A9FFA9FD5401%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22VIZ00024%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) then install this from the `Manage > Customization > Custom Visuals` menu option on the Cognos Analytics home page.

#### 12. The examples folder will show up under `Content > Team content` from the IBM Cognos Analytics home page.
- If you don't immediately see the examples, you may need to wait a minute and reload the `Team content` page.

#### 13. Example dashboards use mock data by default. To use your own live data with the examples,
1. [Setup dashboard integration](https://ibm.biz/BdaveZ).
2. [Re-link the example DB2 data module](videoSteps/RelinkDataDemo.mov) to use your database server connection from the previous step.
3. [Re-link the dashboard](videoSteps/RelinkDemo.mov) to use the DB2 data module.


## Troubleshooting 

1. Color of severity is off - Install the [custom color extension](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FEXT00064&id=i208E818772C44592A1CFDDC59C6E48A1&objRef=i208E818772C44592A1CFDDC59C6E48A1&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22i208E818772C44592A1CFDDC59C6E48A1%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22EXT00064%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) which provides a richer color palette.

2. Funnel graph is blank - Install the [custom funnel extension](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FVIZ00024&id=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&objRef=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22iD8FDBEAFC25E4D1BA440A9FFA9FD5401%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22VIZ00024%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D).

3. Missing data in the DB2 module - Re-link the provided DB2 data source in the `Data` sub-folder to your own DB2 server connection. Or try loading the page in a private browser window.

4. Warning "One or more data caches could not be loaded." - This message can occur after re-linking data sources. It's harmless, simply letting you know the data from the new source is not found in the local cache. You may dismiss the notification.

---

## Additional details 

[Exporting just the dashboard without a data source](https://www.ibm.com/support/pages/how-importexport-dashboard-specification-ibm-Cognos-analytics)

[Exporting reports or deployment packages](https://www.ibm.com/support/pages/how-move-Cognos-analytics-reports-dashboards-and-data-modules-one-environment-another)
