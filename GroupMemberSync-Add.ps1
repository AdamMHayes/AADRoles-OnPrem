<#
    .SYNOPSIS
    Azure Automation PowerShell script to add members from a source group into a corresponding Destination group. 
    The source and destination mapping is stored in an Azure Storage account table

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
    Last Updated: 2020-08-04
#>

#Get Azure AD App registration details
$connectionName = "AzureRunAsConnection"
$SPC = Get-AutomationConnection -Name $connectionName         

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

foreach ($row in $rows) {
    $source = $row.Source
    $destination = $row.Destination
    Try {
        $sGroup = Get-AzureADGroup -SearchString $source | Where { $_.displayName -eq $source }
        $sMembers = Get-AzureADGroupMember -ObjectId $sGroup.ObjectId -All $true
    }
    Catch {
        Write-output "ERROR getting source group $($source)"
        continue
    }
    Try {
        $dGroup = get-azureadgroup -SearchString $destination | Where { $_.displayName -eq $destination }
        $dMembers = Get-AzureADGroupMember -ObjectId $dGroup.ObjectId -All $true
    }
    Catch {
        Write-output "ERROR getting destination group $($destination)"
        continue
    }    
    foreach ($member in $sMembers) {
        if ($dMembers -notcontains $member) {
            Try {
                Add-AzureADGroupMember -ObjectId $dGroup.ObjectID -RefObjectId $member.ObjectId
                Write-Output "Success: $($dGroup.displayName)`t`t$($member.displayName) added "
            }
            Catch {
                Write-Output "ERROR: Failed to add $($member.displayName) to $($dGroup.displayName)"
                continue
            }
        }
        else {
            Write-Output "SKIP: $($dGroup.displayName)`t`t`t $($member.displayName) already a member"
        }
    }
}
#test
