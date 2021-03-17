#
# From https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell
#
{
#Connect to Azure
Connect-AzAccount -Environment AzureCloud #AzureUSGovernment
}

{
#Read Azure Storage Table 
$storageAccountName = "groupmembersyncsa"
#$storageAccountKey = "accessKey from your storage account"
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$cloudtable = (Get-AzStorageTable -Name "AdminGroupSync" -Context $context).CloudTable
$rows = Get-AzTableRow -Table $cloudtable
$rows | ft
}

{
#Add a row to the table
$partitionKey = "Helpdesk Administrator"
$rowKey = "2"
Add-AzTableRow `
    -table $cloudTable `
    -partitionKey $partitionKey `
    -rowKey ($rowKey) -property @{"Source"="OnPrem-Tier2HelpDesk";"Destination"="AADRole-Helpdesk Administrator"}
$rows = Get-AzTableRow -Table $cloudtable
$rows | ft
}

{
#Query specific partition
$partitionKey = "Helpdesk Administrator"
Get-AzTableRow -table $cloudTable -partitionKey $partitionKey | ft
}

{
#Delete a row from the table
$rowKey = "2"
[string]$filter = `
    [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("RowKey",`
    [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$rowKey)
$rowToDelete = Get-AzTableRow `
    -table $cloudTable `
    -CustomFilter $filter
$rowToDelete | Remove-AzTableRow -table $cloudTable 
Get-AzTableRow -Table $cloudtable | ft
}
