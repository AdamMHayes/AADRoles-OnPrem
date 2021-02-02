
# Implementation Guide
This guide will walk you through the deployment steps for this solution. There are some key decision points you can make regarding Azure implementation, but this guide covers the basic requirements for the solution. Recommended permissions for initial setup is Global Administrator. You will need an active subscription to create these resources.
- As always the Azure interface is constantly evolving, so the following steps may alter slightly based on your cloud environment (Commercial, Azure for Goverment, etc)

## Architecture Prerequisites
This guide assumes a hybrid identity envrionment where Azure AD Connect is used to synchronize on-premises groups to Azure AD.

## Informational Prerequisites
1. Have a test group that is synchronized from on-premises available with only a few users to test
2. Determine what will be your first AAD role that you want to test with. I recommend something like Global Reader to ensure that any mistakes do not open you up to larger security risks
3. As you go through this guide, you will be gathering some key information that will be needed later. Have a text editor handy to make notes

## Azure Resource Group Configuration
As this was the first of many expected Azure Automation (AA) solutions in our Identity space, the decision was made to create an Azure Resource Group dedicated to the various pieces of this solution and future AA solutions around our Identity processes.
1. Azure Portal > All Services > Resource groups > Create
- Resource Group Name: *IdentityAutomation-RG*
- Region: Your choice

## Azure Storage Account
### Create the Storage Account
This step will create the storage account you will use for table storage as part of this solution
1. In the Azure Portal navigate to Storage accounts and select Create
- Subscription: *Select the subscription where you created the Resource Group above*
- Resource Group: *Select the Resource Group you created above*
- Storage account name: *groupmembersyncsa*
  - Note: Make a note of this name, it will be added later as a variable in AA
- Location: *Match the location of your Resource Group*
- Performance/Account Kind/Replication:
  - This is really your preference and requirement.This was not deemed hyper critical so we chose a Standard V2 with LRS, but your individual needs may vary
2. Review + create > Create
3. Once the account is created, select *Go to resource* on the Deployment screen
### Add a Table
1. Within the storage account scroll down and select Table Service > Tables
2. Select \+ Table
- Enter the table Name of  *AdminGroupSync* and select OK
  - If you select another name, the source code will need to be updated to match this new name
3. Still within the Storage Account, scroll up to Access Keys
4. Select Show keys and make a note of key1. This will be saved as a variable in AA
### Setup the Table
1. Launch Azure Storage Explorer and connect with your Global Admin accounts
2. Expand your subscription > Storage Accounts > *the storage account created above* > Tables > Select the table you created above and Select Add
- Set Partition Key to the Role Name of the RBAC you are initially using (i.e. Helpdesk Administrator)
- Set Row Key equal to 1
3. Select Add and select Add Property
  - Property Name: *Source*
  - Type: *String*
  - Value: *The name of the first on-prem Active Directory group*
4. Add another property with the these values:
  - Property Name: *Destination*
  - Type: *String*
  - Value: *The name of the Azure AD group created above*
5. Close Azure Storage Explorer

<table>
  <tr>
    <td>PartitionKey</td>
    <td>RowKey</td>
    <td>Source</td>
    <td>Destination</td>
  </tr>
  <tr>
    <td>RoleName1</td>
    <td>1</td>
    <td>OnPremGroupA</td>
    <td>AADGroupA</td>
  </tr>
</table>

## Azure Automation Accounts
### Create the Automation Account
1. Navigate to Azure Portal > All services > Automation Accounts
2. Select \+ Create
- Name: *AdminGroupSync-AA*
- Subscription: *Select the subscription you have used for the other resources so far*
- Resource group: *Select the Resource Group you created above*
- Location: *Match the location to the other resources you have created above*
3. Create Azure Run As account: *Yes*
4. Once the Automation Account is created, select it in the console (you'll likely need to hit Refresh to see it)
### Set Azure AD App Registration Permissions
1. Navigate to Azure Portal > Azure Active Directory > Roles and Administrators
2. Select *Group administrator* and add *AdminGroupSync* as a member
3. Navigate to Azure Portal > Azure Active Directory > App registrations
4. Search for *AdminGroupSync* and select it from the list
5. Scroll down to API Permissions and add the following Microsoft Graph permissions:
  - User.Read.All
### Add PowerShell Modules
1. Scroll down and select Shared Resouces > Modules gallery
2. Add the following modules in order:
  - AzureADPreview
  - Az.Accounts (you'll need to wait until this shows as installed to continue)
  - Az.Storage
  - Az.Resources
  - AzTable
### Add Variables
1. Select Shared Resources > Variables and select *Add a variable*
  - Name: *MembershipSA*
  - Note: If you select a different name, you'll need to update source code
  - Type: *String*
  - Value: *groupmembersyncsa* or whatever you named your Storage Account
  - Encrypted: *No* \- You can choose to encrypt this, but the name of the storage account is not really deemed sensitive by most
2. Select *Add a variable*
  - Name: *MembershipSAKey*
  - Note: If you select a different name, you'll need to update source code
  - Type: String
  - Value *The value of the access key you copied above from the storage account*
  - Encrypted **YES** \- This should be considered sensitive and encrypted
### Run As Account Name
1. Select Account Settings > Run as accounts
2. Select the Azure Run As Account
3. Copy the *Display Name* and save for future use
### Add Scripts
1. Select Process Automation > Runbooks
2. Select \+ Create a runbook
  - Name: GroupMemberSync-Add
  - Runbook Type: PowerShell
  - Description: Your discretion
3. Paste the contents of GroupMemberSync-Add.ps1 from this Git into the body
4. Review the connection strings for the body to ensure that Connect-AzureAD and Connect-AzAccount are set to the correct Azure envrionment.
5. Select Save and Publish when you are done
6. Select \+ Create a runbook
  - Name: GroupMemberSync-Remove
  - Runbook Type: PowerShell
  - Description: Your discretion
7. Paste the contents of GroupMemberSync-Add.ps1 from this Git into the body
8. Review the connection strings for the body to ensure that Connect-AzureAD and Connect-AzAccount are set to the correct Azure envrionment.
9. Select Save and Publish when you are done

## Azure AD Groups to be used for RBAC
These steps will need to be repeated for each group you plan on assigning to Azure AD Roles
### Create the groups
1. Azure Portal > Azure Active Directory > Groups > New Group
- Name: *Your discretion*
  - I **HIGHLY** recommend a naming convention for these groups to keep track of them. We used *AADRole-\<AAD Role Name>*
- Azure AD roles can be assigned to the group: *YES*
  - **NOTE:** This must be set during group creation. At this time, you cannot go back via the Portal and change this setting
- Members: *No members selected*
- Owner: *Add the DisplayName of the Azure Automation Run As Account* 
  - **NOTE:** If this is missing, the AA runbook cannot add users to the group(s) as it is required as part of the Azure capability unless you grant much larger permissions across the entire tenant
- Group description and Owners are at your discretion
### Assign Group to Azure AD Role
1. After the groups are created navigate to Azure Portal > Azure Active Directory > Roles and Administrators
2. Select the role you are wanting to use and add the group(s) created above

## Testing
1. To test the solution, navigate back to the Azure Automation Account runbooks created above
2. Select GroupMemberSync-Add and then select Start
3. After this completes, review the onscreen output and the membership of your Destination group

## Moving to Production
Once you are getting consistent results with Adds and Removes, you can add a Schedule to your Azure Automation account and link the jobs. I would recommend staggering the jobs to avoid overlap.You can also modify the Add runbook to automatically call the Remove runbook at the end of script run so they run in series.
