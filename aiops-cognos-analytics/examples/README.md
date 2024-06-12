# Importing deployment packages
Example packages containing `data modules` and `dashboard` examples  <br />
Cognos `visualizations` and `extensions` require **version 11.2 +** 

## Files
_Examples with data require a password to import_

**alert data example:** [TelcoDash.zip](https://github.ibm.com/hdm/aiops-custom-widget-cognos-integration/files/1343805/TelcoDash.zip)

## Installation 

1. Find the location of Cognos packages, these can be found in either

`<pod>/data/deployment/` 
or
`../<Server2>/deployment/`

_If you are having trouble locating the pod that contains /data/deployment/ search `ca-` to find Cognos pods_

2. Place the desired example zip file into the above location

3. Open the [admin console](https://media.github.ibm.com/user/430455/files/a347c775-3da1-4626-8cef-16898eca96f0) in the Cognos UI

4. Go to [configuration then content administration then select the new import button](https://media.github.ibm.com/user/430455/files/5f90126c-8edd-4c61-a8a4-b9abc4197c0a)

5. Select the [package name](https://media.github.ibm.com/user/430455/files/fd762b21-5606-4ee3-9d64-bdf778526235)

6. Select next and select the [checkbox next to the folder](https://media.github.ibm.com/user/430455/files/435f34b7-9112-41a1-8013-82115af34cd2)

7. Select next and finish

8. Deployment will show up in **Team content**

9. [Re-link](https://media.github.ibm.com/user/430455/files/8b689e77-cd96-4210-81d2-caf4d8ef1100) the dashboard to the data source provided in the same folder.

10. Reload the page if visualizations will not load
---
## Extensions 
Install the [custom color extension](https://accelerator.ca.analytics.ibm.com/bi/?perspective=authoring&pathRef=.public_folders%2FIBM%2BAccelerator%2BCatalog%2FContent%2FEXT00064&id=i208E818772C44592A1CFDDC59C6E48A1&objRef=i208E818772C44592A1CFDDC59C6E48A1&action=run&format=HTML&cmPropStr=%7B%22id%22%3A%22i208E818772C44592A1CFDDC59C6E48A1%22%2C%22type%22%3A%22reportView%22%2C%22defaultName%22%3A%22EXT00064%22%2C%22permissions%22%3A%5B%22execute%22%2C%22read%22%2C%22traverse%22%5D%7D) to change the color of visualizations.


## Sources 

[Exporting just the dashboard without a data source](https://www.ibm.com/support/pages/how-importexport-dashboard-specification-ibm-Cognos-analytics)

[Exporting reports or deployment packages](https://www.ibm.com/support/pages/how-move-Cognos-analytics-reports-dashboards-and-data-modules-one-environment-another)
