function RetrieveDiagnosticLogs {
    param(
        [string] $subscriptionId,
        [string] $resourceGroupName,
        [string] $storageAccountName,
        [string] $keyVaultName
    )
    set-azcontext -SubscriptionId $subscriptionId
    $container = 'insights-logs-auditevent'
    $sa = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $kv = Get-AzKeyVault -VaultName $keyVaultName
    Get-AzDiagnosticSetting -ResourceId $kv.ResourceId 
    Get-AzStorageBlob -Container $container -Context $sa.Context
}




