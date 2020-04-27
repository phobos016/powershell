function SwitchDiagnosticLogging {
    param(
        [string] $subscriptionId,
        [string] $resourceGroupName,
        [string] $storageAccountName,
        [string] $keyVaultName,
        [switch] $loggingEnabled
    )
    set-azcontext -SubscriptionId $subscriptionId
    $sa = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $kv = Get-AzKeyVault -VaultName $keyVaultName
    Set-AzDiagnosticSetting -ResourceId $kv.ResourceId -StorageAccountId $sa.Id -Enabled $loggingEnabled -Category AuditEvent
}