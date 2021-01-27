<#
    .SYNOPSIS
    Azure Automation PowerShell script to remove users from from the destionation groups once they have been removed from all corresponding Source groups.
    The mapping of these groups is stored in an Azure Storage Account table

    .DESCRIPTION
    Requires:
        * The AzTable, Az.Resources, Az.Storage and AzureAD PowerShell modules
        * Script is customized for a MAG infrastructure. If you are using commercial or some other 
            Azure environment, update the parameters for the Update-MSGraphEnvironment and 
            Connect-AzureAD cmdlets
    .PARAMETERS

    .NOTES
    Original Author: Adam Hayes
    Date: 2020-08-04
    Last Updated: 2021-01-27
#>

#Get Azure AD App registration details
$connectionName="AzureRunAsConnection"
$SPC=Get-AutomationConnection -Name $connectionName         

#Connect to Azure AD
Connect-AzureAD -TenantId $SPC.TenantId `
    -ApplicationId $SPC.ApplicationId `
    -CertificateThumbprint $SPC.CertificateThumbprint `
    -AzureEnvironmentName AzureUSGovernment | out-null
#Connect to Azure
Connect-AzAccount -Tenant $SPC.TenantId `
    -ApplicationId $SPC.ApplicationId `
    -CertificateThumbprint $SPC.CertificateThumbprint `
    -Environment AzureUSGovernment | out-null

#Get Azure Table 
$storageAccountName = Get-AutomationVariable -Name "MembershipSA"
$storageAccountKey = Get-AutomationVariable -Name "MembershipSAKey"
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$cloudtable = (Get-AzStorageTable -Name "AdminGroupSync" -Context $context).CloudTable
$rows = Get-AzTableRow -Table $cloudtable
$table = @()
#Build a PoSH Table out of the Azure storage table
foreach ($row in $rows){
    $source=$row.Source
    $destination = $row.Destination
    $object =[pscustomobject]@{
        Source = $source;
        Destination = $destination
    }
    $table += $object
}
#Filter down to only unique names in the destination
$UniqueDestinations = $table.Destination | Select -unique
#Find the membership of each destination group and add group objectID, name and members to array
$DestMem = @()
foreach($row in $UniqueDestinations){  
    $Doid = get-azureadgroup -SearchString $row | Where {$_.DisplayName -eq $row} | Select -expandProperty objectID
    $DMembers= Get-AzureADGroupMember -ObjectId $Doid -All $true
    $object = [pscustomObject]@{
        objectID = $Doid;
        GroupName = $row;
        Members = $DMembers
    }
    $DestMem +=$object
}

#For each membership in the DestMem array, query for all source groups in $table
#Gather members of each source group and add to master source members array (SMembers)
foreach ($line in $DestMem){   
    $Group = $line.GroupName
    $DMembers = $line.Members
    $Sources = $table | Where {$_.Destination -eq $Group} | Select -ExpandProperty Source
    $SMembers = @()
    foreach ($s in $Sources){
        $SMem= get-azureadgroup -SearchString $s | Where {$_.DisplayName -eq $s} | Get-AzureADGroupMember -All $true
        $sMembers += $sMem       
    }
    $UnSMembers = $SMembers | Select -unique | Sort objectId

    #If user exists in the destination members list, but not in the combined source list
    #Remove user from destination group
    Foreach ($dUser in $DMembers){
        if ($UnSMembers -notcontains $dUser){
            write-output "remove $($duser.DisplayName) from $($Group) - $($line.objectID)"
            Remove-AzureADGroupMember -objectId $($line.objectId) -MemberId $($duser.objectID)
        }
    }
}