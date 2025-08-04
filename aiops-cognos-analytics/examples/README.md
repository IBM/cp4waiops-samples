# Examples
This folder contains dashboard examples.  <br />

This requires IBM Cognos Analytics **version 12.0.x**.

## Files

[Cloud_Pak_for_AIOps_examples.zip](Cloud_Pak_for_AIOps_examples.zip) - Example dashboards

## Installation 
[Installation video demo](videoSteps/ImportDemo.mov)

#### 1. Find the location for Cognos extensions

_This file will be on the Cognos server typically in the path `/opt/ibm/cognos/analytics/deployment`_

#### 2. Install the example zip file

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

#### 11. The incident dashboard example requires a custom funnel extension. [Download](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FVIZ00024&id=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&objRef=iD8FDBEAFC25E4D1BA440A9FFA9FD5401&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22iD8FDBEAFC25E4D1BA440A9FFA9FD5401%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22VIZ00024%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) then install this from the `Manage > Customization > Custom Visuals` menu option on the IBM Cognos Analytics home page.

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
