
# Implementation Guide
This guide will walk you through the deployment steps for this solution. There are some key decision points you can make regarding Azure implementation, but this guide covers the basic requirements for the solution. Recommended permissions for initial setup is Global Administrator. You will need an active subscription to create these resources.
- As always the Azure interface is constantly evolving, so the following steps may alter slightly based on your cloud environment (Commercial, Azure for Goverment, etc)

## Architecture Prerequisites
This guide assumes a hybrid identity envrionment where Azure AD Connect is used to synchronize on-premises groups to Azure AD.

## Azure Resource Group Configuration
As this was the first of many expected Azure Automation (AA) solutions in our Identity space, the decision was made to create an Azure Resource Group dedicated to the various pieces of this solution and future AA solutions around our Identity processes.
1. Azure Portal > All Services > Resource groups > Create
- Resource Group Name: *IdentityAutomation-RG*
- Region: Your choice

## Azure Storage Account
### Create the Storage Account
This step will create the storage account you will use for table storage as part of this solution
1. Azure Portal > Storage accounts > Create
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
2. Select *Privileged role administrator* and add *AdminGroupSync* as a member
3. Select *Group administrator* and add *AdminGroupSync* as a member
4. Navigate to Azure Portal > Azure Active Directory > App registrations
5. Search for *AdminGroupSync* and select it from the list
6. Scroll down to API Permissions and add the following Microsoft Graph permissions:
  - Group.Read.All
  - GroupMember.ReadWrite.All
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

## Azure AD Groups to be used for RBAC
These steps will need to be repeated for each group you plan on assigning to Azure AD Roles
### Create the groups
1. Azure Portal > Azure Active Directory > Groups > New Group
- Name: *Your discretion*
  - I **HIGHLY** recommend a naming convention for these groups to keep track of them. We used *AADRole-\<AAD Role Name>*
- Azure AD roles can be assigned to the group: *YES*
  - **NOTE:** This must be set during group creation. At this time, you cannot go back via the Portal and change this setting
- Members: *No members selected*
- Owner: 
- Group description and Owners are at your discretion
### Assign Group to Azure AD Role
1. After the groups are created navigate to Azure Portal > Azure Active Directory > Roles and Administrators
2. Select the role you are wanting to use and add the group(s) created above

## Rename Azure AD App Registration (Optional)
One of the annoying features for me is that when AA creates the Run As account for you, that AppRegistratoin ends up with a VERY hideous name. If you're like me and want to rename it, here's how:
- Azure Portal > Azure Active Directory > App registrations 
