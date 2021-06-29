## Contents

## Introduction
This document will show you how to prepare the Cloud Pak for IBM Watson for AIOps environment for the Experimental beta release. You want to follow these steps in sequential order:

   * [Contents](#contents)
   * [Introduction](#introduction)
   * [Operation Steps](#operation-steps)
      * [Prerequisites](#prerequisites)
      * [Retrieve the cluster ID](#retrieve-the-cluster-id)
      * [Create the ServiceNow user](#create-the-servicenow-user)
      * [Creating the Slack channels and applications](#creating-the-slack-channels-and-applications)
         * [Create the reactive, proactive, and discussion channels for the customer](#create-the-reactive-proactive-and-discussion-channels-for-the-customer)
         * [Create the new slack application](#create-the-new-slack-application)
      * [Configure and run the ansible automation](#configure-and-run-the-ansible-automation)
      * [Finalize the Slack integration](#finalize-the-slack-integration)
      * [Create the Robotshop application in WAIOps](#create-the-robotshop-application-in-waiops)
      * [Create the ServiceNow connection](#create-the-servicenow-connection)
      * [Create the ServiceNow training definition](#create-the-servicenow-training-definition)
      * [Create the incidents training definition](#create-the-incidents-training-definition)
      * [Create the Log model training definition](#create-the-log-model-training-definition)
      * [Create the Event grouping service training definition](#create-the-event-grouping-service-training-definition)
      * [Enable the humio data flow](#enable-the-humio-data-flow)
      * [Create the kafka connection](#create-the-kafka-connection)
      * [Create the ServiceNow change request](#create-the-servicenow-change-request)
      * [Create the Out-of-memory scenario](#create-the-out-of-memory-scenario)
      * [Invite external customer to the Watson AI for IT Slack workspace](#invite-external-customer-to-the-watson-ai-for-it-slack-workspace)
   * [Clean up steps](#clean-up-steps)
      * [Slack clean-up](#slack-clean-up)
      * [Robotshop cleanup](#robotshop-cleanup)
      * [ServiceNow cleanup](#servicenow-cleanup)
         * [Delete the customer change requests](#delete-the-customer-change-requests)
         * [Change the customer password](#change-the-customer-password)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)

---

## Operation Steps
This section describes how to configure and run the automation

### Prerequisites
- An _available_ Katamari instance that has not had any automated integrations performed on it must exist in the Production Cloud account before proceeding
  - Verify the integration information is not already documented in the [Experimental Customer Instance Info](https://ibm.ent.box.com/folder/137759275064) Box folder.
  - To provision a new instance using the SRE console, follow the instructions to [provision a Katamari Instance](https://github.ibm.com/katamari/saas-operations/blob/master/Playbooks/Provision%20Katamari%20Instance%20-%20SRE%20Console.md)
- You have access to automation server **bod-work1.fyre.ibm.com** with _sudo_ privilege

Experimental environment details can be found here: 
https://ibm.ent.box.com/notes/812984673292

Contact @griffitj or @jsevidal for access to the referenced Box link(s) or the automation server

### Retrieve the cluster ID

You will need the cluster ID. To retrieve this:

1. Log into the SRE console: https://sre-console.aiops.cloud.ibm.com

2. You will see a table containing the service instance, cluster, etc. Click on the link under the **Cluster** column.

3. The cluster ID is located under the first column **Name**. (e.g. id:c2d6g9tw08muc7aemv6g) Record this cluster ID in the appropriate Box note in the [Experimental Customer Instance Info](https://ibm.ent.box.com/folder/137759275064) Box folder.

### Create the ServiceNow user 

1. Log into ServiceNow as admin (URL and passwords here: https://ibm.ent.box.com/notes/812984673292) 

2. Use the **Filter Navigator** to filter for the string _user_, then scroll down left-hand menu to **System Security > Users and Groups**,then click on **Users**

3. Click the **New** button on the top

4. Fill-out the following (where _customerX_ is customer1, customer2.. etc) :

   - User ID: _customerX_
   - First name: _customerX_
   - Email: _user@ibm.com_
   - Password: _any password with 8-9 digits_  
     - Use the Linux command `pwgen 8 1` to generate random password on **bod-work1.fyre.ibm.com**
   
5. Click **Submit**

6. Use the **Search** (by _User ID_) to find the new user you just created and click on the user id to edit it. 

7. Scroll down to the tabs below and click on the **Roles** tab.

8. Click **Edit** to add some roles. 

9. Locate **sn_change_write** and **sn_incident_write** and move them to the right. 

10. Click **Save** which will take you back the user details.

11. Click **Update** to save the user. 
   

### Creating the Slack channels and applications

In this section, you will follow-up steps to create the slack components for Katamari. Once a customer is done you will need to delete the application and the reactive, proactive, and discussion channels ([See the clean-up section](#slack-clean-up))

For more details please visit https://www.ibm.com/docs/en/cloud-paks/cp-waiops/3.1.0?topic=integrations-configuring-slack-integration. You should have everything you need in this README, however.

#### Create the reactive, proactive, and discussion channels for the customer

1. In Slack in the **Watson AI for IT** workspace, find the Channels twisty and click **+** to Add **channels**. Then select **Create a channel** from the menu. 

2. Name the channel using this format: _cp4waiops-exp-TYPE-CUSTOMER-guest_ where TYPE is proactive, reactive, and discuss. CUSTOMER is unique identifier. For example `cp4waiops-exp-discuss-customer4-guest`

3. Enable **Make Private**, then click **Create**

4. In the **Add people** dialog, add the **SaaS Ops team members** (exclude your own name since you are automatically a member of the Slack channel you are creating):

   _Landon Kirk_, _Jeannie Sevidal_, _John Griffith_, _Andrew Goldfaden_, _Lin He Wen_, _Dong Wang_, _Aurora Vogna_, and _Mike Crowley_

   Add the following **Product Managers** who will be interfacing with the external customers:
   - gscottj@us.ibm.com
   - sahuja@us.ibm.com
   - grace.williamson@ibm.com
   - jeremy.hughes@uk.ibm.com

   If another IBMer is requesting the instance, add them to the Slack channel as well.

5. Repeat steps 1-4 to create the remaining channels. You should have three channels for the customer. 

6. Retrieve the channel IDs from the proactive and reactive channels
   - From the Slack window, right-click the channel name, then click Copy Link to get the web URL link. The last part of the link is the channel ID.
   - Document them in here https://ibm.ent.box.com/notes/812984673292

#### Create the new slack application

1. Create a Slack app on https://api.slack.com/apps

    a. Click **Create New App** button. Select **From scratch**.

    b. Enter an App Name, and specify the workspace that you want to connect the app to, **Watson AI for IT**, then click Create App.

    The app name should look similar to this:

    cp4waiops-app-**customer4**

2. After you create your Slack app, you will be redirected to the **Basic Information** page of your Slack app. If you closed your browser and need to get back to this details page, go to your [Slack API Apps page](https://api.slack.com/apps) and click the name of the app that you just created. 

3. Add the operations team as collaborators by clicking _Collaborators_ under **Settings**. In the textbox within the dialog box **Add members collaborators on this app**, add _Landon Kirk_, _Jeannie Sevidal_, _John Griffith_, _Andrew Goldfaden_, _Lin He Wen_, _Dong Wang_, _Aurora Vogna_, and _Mike Crowley_.

4. Under the **Features** section of the left-hand menu, select _OAuth & Permissions_. In the **Scopes** section under **Bot Token Scopes**, click on _Add an OAuth Scope_ button and add the following scopes:

    * app_mentions:read
    * channels:manage
    * channels:read
    * chat:write
    * files:write
    * groups:read
    * groups:write
    * users:read
    * users:read.email

5. While still in the _OAuth & Permissions_ page:

    a. Scroll to the top and click on **Request to Install** button. Provide an explanation, e.g. "Required for CP4WAIOPs experimental release demo for external customer", then click **Submit Request** button.

    **Note**: This action requires Slack workspace owner approval. If you are an owner of the workspace, you can approve it yourself. If you are not an owner, you will need to wait for the approval, which will appear in the [_app_governance_bot_](https://watsonaiforit.slack.com/archives/D013CBAFE0J) in the **Watson AI for IT** workspace, e.g.:

    ![image](https://github.ibm.com/katamari/saas-operations/blob/master/images/slack_app_approval.jpg)

    After it is approved, click on **Complete Installation** button in the _app_governance_bot_ in Slack, then the **Add to Slack** button, then click on **Install to Workspace** button.
    
    OR, go directly to the the the **Basic Information** webpage of your app and click on the **Install to Workspace** button.
    
    b. Review the information and click **Allow**. You must reinstall your app every time you change the scope.
    
    c. Record the `Bot User OAuth Access Token` in https://ibm.ent.box.com/notes/812984673292
    
    d. Find the _signing secret_ under the app's _Basic Information -> App Credentials_ and document in your provisioning Box note under the [Experimental Customer Instance Info](https://ibm.ent.box.com/folder/137759275064) folder and in the [Experimental Environment details Box note](https://ibm.ent.box.com/notes/812984673292)

    You will continue and complete the slack app configuration after running the integrations. 
    
### Configure and run the ansible automation

**NOTE:** The automation script is run as the shared *builder* ID.  Make sure BEFORE YOU BEGIN that you are the **only** one performing integrations to avoid any conflicts with others who may be running the automation at the same time.

1. Gather info. You will need the following:
- Cluster ID
- Slack Bot Token
- Slack Signing Secret
- Slack proactive channel ID
- Slack reactive channel ID

2. Log into the bod-work1 as your assigned user which is your IBM short ID (e.g. `griffitj`, `jsevidal`). Then switch to user `builder` using _sudo_.

```
# ssh jsevidal@bod-work1.fyre.ibm.com 

# sudo su - builder
```

3. Change directory to `/usr/local/git-repos/<IBM short-id>` and back up any old `saas-operations` directories.  If `/usr/local/git-repos/<IBM short-id>` does not yet exist, create it now:  `mkdir /usr/local/git-repos/<IBM short-id>`.

For example:
```
# cd /usr/local/git-repos/jsevidal

# mv saas-operations saas-operations.0421
```

4. Clone the saas-operations git repository and change directory into the Katamari automation sub-directory.

For example:
```
# pwd
/usr/local/git-repos/jsevidal

# git clone git@github.ibm.com:katamari/saas-operations.git

# cd saas-operations/Automation/Katamari_Integration
```

5. Edit the `common/all_vars.yml`. Update **only** the following variables with the values specific to your Katamari cluster and related Slack channels/app:

```
KATAMARI_CLUSTER_ID
BOT_TOKEN (needs to be base64 encrypted)
SIGNING_SECRET (needs to be base64 encrypted)
PROACTIVE_CHANNEL
REACTIVE_CHANNEL
```

To get the "base64 encrypted" values, run the following command:

`echo '<your_string>' | base64`

6. Run the automation by running `new_customer.sh`. Pass an identifier that can be mapped to the customer. For example, the customer is Pepsi and we're using `customer1` profile:

```
# ./new_customer.sh customer1
```

The ansible playbook will begin. There are two tasks that will take more than 10 minutes:

- `TASK [Deploy Robotshop(Can take up to 15 minutes, be patient)]`- RobotShop deployment
- `TASK [Load the data]` - Loads the model data for Service Now

**DO NOT** break out of the ansible run. Contact John or Jeannie if either task is running extremely long.

7. After the automation run is complete, **the ansible output will contain the Robotshop URL.** Record that and put in the customer table in the box note.

8. You will need to upload the `all_vars.yml` to our S3 server. You will need this file later when you need to clean up after the customer is complete.

   **NOTE**: Each automation creates a subdirectory under `/usr/local/automation_work` defined by variable `BASEDIR` in `all_vars.yml`. This directory contains various files that are generated and used by the automation like payload JSON files and `robotshop-cert.crt`. You can look at these files if you need to debug a failed automation run.  

    a. On the bod-work1 work node there are some convenients scripts (under `/usr/local/bin`) that allow you to list, upload, and download files to the S3 server.

    b. To upload:
    ```
    # cd Automation/Katamari_Integration/common

    # cp all_vars.yml all_vars.yml.karline-kwmx

    # s3-upload all_vars.yml.karline-kwmx
    upload: ./all_vars.yaml.karline-kwmx to s3://bodops/experiment-saas/all_vars.yaml.karline-kwmx
    ```

    c. To verify the file was uploaded, run the list command:
    ```
    # s3-ls
                               PRE ./
    2021-05-03 14:53:28          0
    2021-05-03 14:56:07       1200 all_vars.yaml.acme01
    2021-05-03 15:38:34       1200 all_vars.yaml.karline-kwmx
    ```

### Finalize the Slack integration
In this section, we finish the slack integration. This part has to happen after running the automation for the AIOPs request URL. The following steps are based on procedure outline here and starting on step #6: https://www.ibm.com/docs/en/cloud-paks/cp-waiops/3.1.0?topic=integrations-configuring-slack-integration . I've reproduced the documentation in this README for convenience.

**Contact the OM (i.e. the Katamari instance owner) and have them add your IBMid as a user with "Automation Administrator" role to perform remaining Katmari UI tasks going forward.**

1. Obtain the URL of the IBM Cloud Pak for Watson AIOps instance:

    a. From the IBM Cloud Pak for Watson AIOps console, click the navigation menu (four horizontal bars), then click **Define > Data and tool integrations**.

    b. Locate the _Slack tile_, and click the link **1 Integration**

    c. On the Slack instances page, copy the request URL from the _Details_ column. This URL is required to enable two-way communication between Slack and IBM Cloud Pak for Watson AIOps.

2. From the Slack app page (https://api.slack.com/apps, then select the app), on the Event Subscriptions page, click Enable Events:

    a. Enter the Request URL obtained in the previous step. Slack automatically verifies the URL when you add it.

    b. Add `app_mention` and `member_joined_channel` bot events to the **Subscribe to bot events** section.
    
    c. Click **Save Changes** at the bottom-right.  
    
    **Note**: If Save Changes button is not enabled, then you need to check your Slack integration.

3. On the _Interactivity & Shortcuts_ page, enable _Interactivity_ and enter the Request URL that you obtained in previous step. Every message interaction (button press or drop-down menu select) now sends a request to this URL. Click **Save Changes** as well. 

4. Configure the _Welcome_ slash command. With this command, you can trigger the welcome message again if you closed it.

    a. Under _Features_, click *Slash Commands*, then click *Create New Command* to create a new slash command.

    Enter the following values:
    
      * The command must be `/welcome`.
      * The request URL is the same URL that you obtained in Step 6.
      * The short description is Welcome to IBM Cloud Pak for Watson AIOps
        
        
    Click **Save** at the bottom. 
    **Note**: For the changes to take effect, you might need to run the following command:
    ```
       oc set env deployment/$(oc get deploy -l app.kubernetes.io/component=chatops-slack-integrator -o jsonpath='{.items[*].metadata.name }') SLACK_WELCOME_COMMAND_NAME=/welcome
    ```

5. After the application is configured, it must be reinstalled, as several permissions changed. Go to *Install App* and click *Request to Install* button.

    **Note**: Reinstalling the app requires another approval of the application.

6. Add the Slack app to the channels.

   a. In each **proactive** and **channels**, enter an **`@`** symbol + application like this `@cp4waiops-app-acme06-2`. A pull-down will appear which will help you filter. 
   
   b. Hit enter to "invite" the application. You should see a slack message stating that the application was added to the channel by you. 
   
   c. This will followed by a message "I'm up and running" which indicates the application is ready. 
   
**Continue with the following integration steps before adding external guests to private Slack channels.**
   
### Create the Robotshop application in WAIOps
This section describes how to create the application in WAIOps. 

1. Navigate to **Operate->Application Management** in the WAIOps console

2. Click on Create Application button in the top-right as shown below.

  ![](https://github.ibm.com/katamari/saas-operations/blob/master/images/create-app1.png)
  
* You should see a group called robotshop-<identifier> (e.g. robotshop-pepsi01). Select the group and click **Add to application** as shown below.

  ![](https://github.ibm.com/katamari/saas-operations/blob/master/images/create-app2.png)

3. Complete the application name, add a tag, and click **Create Application** as shown in the screenshot below.

  ![](https://github.ibm.com/katamari/saas-operations/blob/master/images/create-app3.png)

* In the Application Management view, you should see the application under **All Applications** as shown: 

  ![](https://github.ibm.com/katamari/saas-operations/blob/master/images/create-app4.png)
  
### Create the ServiceNow connection
You will need to create the ServiceNow connection. 

1. In the hamburger menu, navigate to **Define > Data and tool integrations**

2. Locate ServiceNow tile and click on **Add integration**

3. Populate the following fields then click **Integrate**

- Name <-- e.g. **servicenow-manual**
- Description
- URL  <-- See [Box note](https://ibm.ent.box.com/notes/812984673292)
- User ID <-- Use **admin**
- Password  <-- See [Box note](https://ibm.ent.box.com/notes/812984673292)
- Encrypted password <-- Use **encrypted aiops controller password** in [Box note](https://ibm.ent.box.com/notes/812984673292)
- Click **Test connection** to test
- Enable **Data flow** , select **Live data for continuous AI training** mode.
- Enable **Collect inventory and topology data**
- Select PM or AM in the pull-down (under **Time**) 

Verify that the ServiceNow's observer job is running. 
 - Under _Data and tool integrations_ , go to **Advanced**
 - Click on **Manage observer jobs**
 - Verify you see ServiceNow and a Kubernetes observer jobs:
 
 ![image](https://github.ibm.com/katamari/saas-operations/blob/master/images/observer_jobs.png)

### Create the ServiceNow training definition
The automation loaded CR data. However, we'll need to manually create the training definition. 

1. In the hamburger menu, navigate to **Operate** -> **AI Model Management**

2. Click on the **Change risk** tile

3. Click on **Create training definition +** button

4. Name the training definition, leave the other default values, click **Next** 

5. Click **Create** which will take to the overview page.

6. In the change risk overview page, go to **Actions** in the top-right and select **Start training**.  The training will begin which takes about 10-15 minutes.  A message will be displayed:  _**Success** Training successfully started_

7. After the training is complete, you will see the label **Trained** at the top of the UI.  Go to **Actions** in the top-right and select **Deploy**. The deployment begins and completes in seconds.  The CR training is now complete. 

### Create the incidents training definition
The automation loaded incident model data. However, we'll need to manually create the training definition. 

1. In the hamburger menu, navigate to **Operate** -> **AI Model Management**

2. Click on the **Similar incidents** tile

3. Click on **Create training definition +** button

4. Name the training definition, leave the other default values, click **Next** 

5. Click **Create** which will take to the overview page.

6. In the similar incidents overview page, go to **Actions** in the top-right and select **Start training**.  The training will begin which takes about 1-2 minutes.  A message will be displayed:  _**Success** Training successfully started_

7. After the training is complete, you will see the label **Trained** at the top of the UI.  Go to **Actions** in the top-right and select **Deploy**. The deployment begins and completes in seconds.  The similar incidents model training is now complete. 

### Create the Log model training definition
The automation loaded the log model data. However, we'll need to create the log model training definition. 

1. In the hamburger menu, navigate to **AI Model Management**

2. Click on the **Log anomaly detection** tile

3. Click on **Create training definition +** 

4. Click on **Add data+** 

5. In the select date range, select **Apr 13, 2021 to Apr 15, 2021**

6. Leave filter section as default. 

7. Click **Add**, then **Next**.  Name your training definition, e.g. **log_anomaly_detection_1**.  Keep remaining default values and click **Next**, then **Create**.

8. Go to **Actions** in the top-right and select **Start training**.  The training will begin which takes about 15-20 minutes.

9. After the training is complete, go to **Actions** in the top-right and select **Deploy**. The deployment will begins and completes in seconds.  The log model training is now complete. 

### Create the Event grouping service training definition
This step creates the training for event groupings based on CR, incidents, and log model data.

1. In the hamburger menu, navigate to **Operate** -> **AI Model Management**

2. Click on the **Event grouping service** tile

3. Click on **Create training definition +** button

4. Name the training definition, leave the other default values, click **Next** 

5. Click **Create** which will take to the overview page.

6. In the similar incidents overview page, go to **Actions** in the top-right and select **Start training**.  The training will begin which takes about 1-2 minutes.  A message will be displayed:  _**Success** Training successfully started_

7. After the training is complete, you will see the label **Trained** at the top of the UI.  Go to **Actions** in the top-right and select **Deploy**. The deployment begins and completes in seconds.  The training is now complete.

### Enable the humio data flow
In order for the data to flow to the slack channel, you will need to turn on the data for the Humio connection. 

**Note:** Run this step only **after** the log model training is completed and deployed or you will get an error trying to enable the flow.

1. In the hamburger menu, navigate to **Data and tool integrations**

2. In the Humio tile, click the **1 integration** link. 

3. You will see the _Data flow_ is _Off_.  Click on the context menu (three dots) and select **Enable data flow**. 

### Create the kafka connection 
You will need to create a second kafka connection. 

1. In the hamburger menu, navigate to **Define > Data and tool integrations**

2. Locate Kafka tile and click on **Add integration**

3. Keep the default values but enable the data flow (_Data feed for continuous AI training and anomaly detection_) .

4. Click **Save**

### Create the ServiceNow change request
In this step, you will validate that the WAIOps and ServiceNow integrations are working. 

1. In your browser, navigate to ServiceNow (Instance is doc'd in https://ibm.ent.box.com/notes/812984673292) 

2. Log in as the customer user you previously created (e.g. customer2) 

3. In the **Filter navigator** search text area, type in 'change' to filter the navigation menu. You should now see the main menu _Change Request_ as shown below

![](https://github.ibm.com/katamari/saas-operations/blob/master/images/snow-crs.png)

4. Click on **Create New** to create a new CR. 

5. Click on **Normal: ...** as the type of change required. 

6. In the CR details page, fill out the **Short description** and **Description** . You can type in something descriptive like _"Robotshop application is failing"_

7. Click on the _Notes_ tab and type in a description in the **Additional comments** text area. You can use the same text as before. 

7. Click on the _Closure information_ tab, and enter the same description in the **Close notes** text area. 

8. Click on **Submit** to submit the ticket. 

9. Using the search at the top of ServiceNow UI, search for your change request (by **Short description**). You can also filter by **Requested by** and search for the user ID you created, e.g. **customer2**. Then click on your CR to view details. 

10. Scroll down and click on the **Notes** tab.  You should see a new Activity containing the model confidence as shown below.  This indicates that the integration between WAIOps and ServiceNow is working. 

![](https://github.ibm.com/katamari/saas-operations/blob/master/images/model-conf-snow.png)

11. We can also see if the slack integration is working. In the slack client, go to the customer **proactive** channel. Verify the the model confidence was posted to this channel as shown below:

![](https://github.ibm.com/katamari/saas-operations/blob/master/images/model-conf-slack.png)

### Create the Out-of-memory scenario
In this section, you will create the Out-of-memory error in the slack channel. 

1. In this extracted _saas-operations_ git repository,  change directory to _Automation/Katamari_Integration_ (same place where you ran the automation playbook). 

2. Run the  script called `trigger_oom.sh` and pass the customer shortname (same name when you ran the automation). This will trigger the OOM ansible playbook. For example: 

```
# ./trigger_oom.sh customer2
```

This script will use the same values in common/all_vars.yml that was used earlier when you ran the automation.

3. Check the reactive slack channel for results. 

### Invite external customer to the Watson AI for IT Slack workspace

In this section, you will start the process of inviting the external customer.  They should not be invited until all integrations have completed so that they do not access the Slack channels prematurely.

1. Invite external customer(s) to the **Watson AI for IT** Slack workspace
   
   a. Click the context menu of the workspace on the top-right of the Slack client.
   
   b. Select **Invite people to Watson AI for IT**
   
   ![](https://github.ibm.com/katamari/saas-operations/blob/master/Experimental%20Release/images/workspace-invite.png)
   
   b. Under **To:** add the email addresses
   
   c. Under **Invite as**, select **Guest**
   
   d. Under **Add to Channels** enter the reactive, proactive, and reactive channels.  
   
   **IMPORTANT:**
   
   **Double-check that you are adding customer email addresses to the CORRECT Slack channels assigned to this trial instance. There could be similarly named Slack channels that are dedicated to a different customer!**
   
   e. Under **Set a time limit**, select **Custom** and select date approximately 3 weeks from when customer is given access to Katamari SaaS instance
   
   f. Under **Custom Message**,  enter a reason for request
   
   The fields should look similar to the following:
   
   ![](https://github.ibm.com/katamari/saas-operations/blob/master/Experimental%20Release/images/workspace-invite2.png)
   
   g. Click **Send** to send the request.
   
   h. The request is automatically sent to Slack workspace admin for approval. 
      * External account users **cannot** be added using Gmail, Yahoo, etc. e-mail addresses. They must be added with their **corporate e-mail addresses** as **guests**. The Slack admin will reject the requests otherwise.
      * Per Slack admin Greg Odom, the Slack admin team only works _"during business hours for the CONUS...but between 0700 CST and 1600 CST requests are processed within seconds"_
      
   i. After the customer engagement is complete, follow the procedures below: [Slack clean-up](#slack-clean-up)

---

## Clean up steps

This section describes how to delete katamari components.

### Slack clean-up
#slack-clean-up

In this sub-section, you will follow steps to delete the slack application and the slack channel. 

**Deleting the Slack channels**

You will need to archive all three channels (reactive, proactive, and guest channels)

1. Right-click on the channel, and select **Additional options...**

2. Click on **Delete this channel** , then enable on **Yes, permanently delete the channel** and click **Delete Channel**

3. Repeat steps 1-2 for the other two channels. 


**Deleting the Slack app**

1. Navigate to https://api.slack.com/apps

2. Click on **Your Apps** in the upper-right hand then click on the app you need to delete in the list. This will take you to Settings > Basic Information for your app.

3. Scroll to the bottom and click on **Delete App**, then click on **Yes, I'm sure** in the popup. 

### Robotshop cleanup
#robotshop-cleanup

In this sub-section, you will follow steps to delete the customer's robotshop instance

1. Clone this repository and change directory to `Automation/Katamari_Integration`

2. To retrieve the customer info from all_vars.yml, use the s3 tool to download the file.
```
# s3-ls
                           PRE ./
2021-05-03 14:53:28          0
2021-05-03 14:56:07       1200 all_vars.yaml.acme01
2021-05-03 15:38:34       1200 all_vars.yaml.karline-kwmx

# s3-download all_vars.yaml.karline-kwmx
download: s3://bodops/experiment-saas/all_vars.yaml.karline-kwmx to ./all_vars.yaml.karline-kwmx

```
Now you can use this as reference if needed. 

3. To list the current robotshop customers, run the script below with no arguments, and you should see a list of customers. 
```
# ./list_robotshop_customers.sh
...
ok: [localhost] => {
    "msg": [
        "acme01",
        "john05",
        "johng06",
        "karline-kwmx",
        "pepsi01",
        "sandbox"
    ]
}
```
4. To delete a customer robotshop instance, run the following script and pass the customer identifier:
```
# ./delete_robotshop_customer.sh karline-kwmx
...
TASK [Delete Robotshop namespaces] *********************************************************************************
changed: [localhost]

PLAY RECAP *********************************************************************************************************
localhost                  : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

5. You can check to see if the instance is deleted by re-running `list_robotshop_customers.sh`.

### ServiceNow cleanup

#### Delete the customer change requests
1. Log into ServiceNow into the customer account (e.g. customer2)

2. Go to Change requests view, locate the CRs, and click on it to view details.

3. Click **Delete** to delete the CR.


#### Change the customer password

1. Prepare a new password for the customer account. You optionally use the pwgen command on the bod-work node by running the following command. 
```
# pwgen 8 1
FeiZo0De
```
2. Log into the Service Now instance as admin

3. Navigate to User Administration > Users. 

4. Search by User ID, and locate the corresponding customer profile associated with the customer (e.g. customer1, customer2 ,etc).

5. Click on the customer to view details.  

6. Enter a new password in the password field. 

7. Click update.

8. Note the new password in the ServiceNow section of Experimental environment box note: https://ibm.ent.box.com/notes/812984673292
