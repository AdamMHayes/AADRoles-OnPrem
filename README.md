# AADRoles-OnPrem
This solution was written to solve use-case where a client needed to be able to assign members of on-prem AD groups to AAD Roles.

If you want to skip all of this overview and jump right in, go to the [Implementation Guide](https://github.com/theacerbic1/AADRoles-OnPrem/blob/main/ImplementationGuide.md)

## Client Overview
Client is a highly distributed 60k+ workforce with distributed IT model across the globe. Their Azure implementation is a federated hybrid identity on Microsoft Azure Government (MAG) using Azure AD Connect. On-premises Active Directory is considered the “source of truth” for all identities (users, groups, etc). When new admin staff are hired, the client has an existing process to add these accounts to the appropriate on-premises administrative groups

## Problem to Solve
Client wanted to use existing on-premises Active Directory (AD) groups to assign Azure AD (AAD) Roles.
Example: Admin accounts in the on-premises AD groups that have permission to administer desktops should have the similar capability for Azure AD joined workstations

So how could we simplify the admin model so that users could be assigned their necessary Azure AD Role without administrative overhead of manually assigning users to roles within Azure AD

## We thought this would work but...
A new feature in Preview allows [Cloud Groups to Manage Role Assignments in Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/roles/groups-concept)

### Limitations that stopped us (for a little while)
* The ability to use synchronized on-premises groups is not supported 
* The ability to use dynamic AAD groups is not supported at this time
* This capability does not support nesting of groups

## Our Solution
### Technical Requirements
* Use a PowerShell script to query members of a source group and add and remove them as direct members to the cloud groups flagged as isAssignableToRole
* Run this on a set schedule to ensure repeatable results
* Had to be scalable to handle 1-1/1-many/many-1/many-many scenarios
* Had to be as least-privileged as possible
### Azure Storage Account
  - Table storage to handle mapping of Source to Destination
### Azure Automation (AA)
  - Used to host and run PowerShell scripts
  - Specific API permissions granted to RunAs account to limit security reach
### PowerShell Modules
  - Azure AD module
  - Az.Storage/Az.Resources/AzTable/Az.Account/AzTable 
  - [Perform Azure Table storage operations with PowerShell | Microsoft Docs](https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell)
### Azure Storage Explorer
  - To be able to read/review contents of Azure Storage table
### Add Members (GroupMemberSync-Add)
This PowerShell script will read the Azure Storage table created above. For each Source listed, it will query Azure AD for the group members and add them to the corresponding Destination.
## Remove Members (GroupMemberSync-Remove)
This PowerShell script will read all Destination groups and select just the unique entries to handle the Many-1 and Many-Many scenarios. After the unique list is created, it retrieves the membership and objectID for each Destination group.

For each Destination Group listed, all rows that match that destination will have their Source groups queried and added to a 'master' Source Membership list. This is done to prevent a user removed from 1 source group but not another, from being accidentally removed. If the user is not found in ANY of the Source groups, the user is removed from the Destination group
