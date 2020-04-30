function CheckAzureRepositories {
    <#
        .SYNOPSIS
        Reports on repository state
            
        .DESCRIPTION
        retrieves all repos from a known devops instance, writes subsequent report out to table storage
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $coreServer,
        [Parameter(Mandatory = $true)]
        [string] $organisation,
        [Parameter(Mandatory = $true)]
        [string] $personalAccessToken,
        [Parameter(Mandatory = $true)]
        [Int16] $staleMonths,
        [Parameter(Mandatory = $true)]
        [string] $subscriptionId,
        [Parameter(Mandatory = $true)] 
        [string] $reviewDataResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string] $reviewDataStorageAccountName
    )
    
    Import-Module $PSScriptRoot\CheckAzureRepositories.psm1 -force
    
    try {
        $authHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }


        $projects = GetProjects `
                        -authHeader $authHeader `
                        -coreServer $coreServer `
                        -organisation $organisation
                        
        $staleDate = (Get-Date).AddMonths(-$staleMonths)
        $staleCount = 0
        $emptyCount = 0
        $repoCount = 0
        $buildSuccessCount = 0
        $buildFailedCount = 0
    
        $dateString = $dateString = Get-Date -format "yyyyMMddHHmm"
    
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $reviewDataResourceGroupName -Name $reviewDataStorageAccountName
        $tableName = "repoaudit$($dateString)"
        $table = (New-AzStorageTable -Name $tableName -Context $storageAccount.Context).CloudTable
            
        $projects.value | ForEach-Object {
            $projectId = $_.id
            $projectName = $_.name
            Write-Host "Project ($($projectName)) :  $($projectId)"
            $repos = GetRepos `
                        -authHeader $authHeader `
                        -coreServer $coreServer `
                        -organisation $organisation `
                        -projectId $projectId
    
            $repos.value | ForEach-Object {
                $repoCount++
                $repoId = $_.id
                $repoName = $_.name
                $repoUri = $_.url
    
                $lastCommitUri = $null
                $lastCommitDate = $null
                $status = $null
                $lastBuildDate = $null
                $lastBuildOutcome = $null
                $buildDefinitionName = $null
    
                $commit = GetLastCommit `
                            -authHeader $authHeader `
                            -coreServer $coreServer `
                            -organisation $organisation `
                            -projectId $projectId `
                            -repoId $repoId

                $builds = ListBuildsForRepository `
                            -authHeader $authHeader `
                            -coreServer $coreServer `
                            -organisation $organisation `
                            -projectId $projectId `
                            -repoId $repoId
    
                if ($commit) {
                    $lastCommitUri = $commit.url
                    
                    $status = GetBuildStatus `
                                -authHeader $authHeader `
                                -coreServer $coreServer `
                                -organisation $organisation `
                                -projectId $projectId `
                                -repoId $repoId `
                                -commitId $commit.commitId
    
                    $lastCommitDate = $commit.author.date
                    $stale = $lastCommitDate -lt $staleDate
                    if ($status -and $status.count -gt 0) {
                        $lastBuildDate = $status.value[0].creationDate
                        $lastBuildOutcome = $status.value[0].state
                        $buildDefinitionName = $status.value[0].context.name
                        if ($lastBuildOutcome -eq 'succeeded') { $buildSuccessCount++ } else { $buildFailedCount++ }
                    }
                    If ($stale) { $staleCount++ } 
                } else {
                    $emptyCount++
                }
    
                $lastCommitValue = if ($lastCommitDate) { $lastCommitDate.ToString('u') } else { $null }
                $lastBuildValue = if ($lastBuildDate) { $lastBuildDate.ToString('u') } else { $null }
    
                WriteTableRow `
                        -tableParam $table `
                        -projectNameParam $projectName `
                        -repoNameParam $repoName `
                        -repoUriParam $repoUri `
                        -lastCommitUriParam $lastCommitUri `
                        -lastCommitDateParam $lastCommitValue `
                        -lastBuildDateParam $lastBuildValue `
                        -lastBuildOutcomeParam $lastBuildOutcome `
                        -buildDefinitionNameParam $buildDefinitionName
            }
        }
        Write-Host "Done - $($staleCount)/$($repoCount) ($($emptyCount) Empty) repos found with commits over $($staleMonths) months old : $($buildSuccessCount) Successful and $($buildFailedCount) failed builds"
    }
    catch {
        Write-Host $_.Exception.Message -Foreground Black -Background Red
    }    
}
