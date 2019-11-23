function GetWebRequest {
    param(
        [string] $uri,
        [string] $authToken
    )
    return ConvertFrom-Json (Invoke-WebRequest -Headers @{ Authorization = "Basic $($authToken)" } -Method Get -Uri $uri -UseBasicParsing -TimeoutSec 300).Content
}

function GetProjects {
    param(
        [string] $authToken,
        [string] $coreServer,
        [string] $organisation
    )
    return GetWebRequest -authToken $authToken -uri "https://$($coreServer)/$($organisation)/_apis/projects?api-version=5.1" 
}

function GetRepos {
    param(
        [string] $authToken,
        [string] $coreServer,
        [string] $organisation,
        [string] $projectId
    )
    return GetWebRequest -authToken $authToken -uri "https://$($coreServer)/$($organisation)/$($projectId)/_apis/git/repositories?includeLinks=true&includeAllUrls=true&includeHidden=true&api-version=5.1"
}

function GetLastCommit {
    param(
        [string] $authToken,
        [string] $coreServer,
        [string] $organisation,
        [string] $projectId,
        [string] $repoId
    )
    $commits = GetWebRequest -authToken $authToken -uri "https://$($coreServer)/$($organisation)/$($projectId)/_apis/git/repositories/$($repoId)/commits?api-version=5.1&searchCriteria.excludeDeletes=true" 
    if ($commits.count -gt 0) {
        $sorted = $commits.value | Sort-Object -Property author.date -Descending
        $last = $sorted[0]
    }
    return $last
}

function GetBuildStatus {
    param(
        [string] $authToken,
        [string] $coreServer,
        [string] $organisation,
        [string] $projectId,
        [string] $repoId,
        [string] $commitId
    )
    return GetWebRequest -authToken $authToken -uri "https://$($coreServer)/$($organisation)/$($projectId)/_apis/git/repositories/$($repoId)/commits/$($commitId)/statuses?api-version=5.1&latestOnly=true&top=1"
}

function ListBuildsForRepository{
    param(
        [string] $authToken,
        [string] $coreServer,
        [string] $organisation,
        [string] $projectId,
        [string] $repoId
    )
    return GetWebRequest -authToken $authToken -uri "https://$($coreServer)/$($organisation)/$($projectId)/_apis/build/builds?repositoryId=$($repoId)&api-version=5.1"
}

function WriteTableRow {
    param(
        [Microsoft.Azure.Cosmos.Table.CloudTable] $tableParam,
        [string] $projectNameParam,
        [string] $repoNameParam,
        [string] $repoUriParam,
        [string] $lastCommitUriParam,
        [string] $lastCommitDateParam,
        [string] $lastBuildDateParam,
        [string] $lastBuildOutcomeParam,
        [string] $buildDefinitionNameParam
    )
    
    $rowData = @{
        "ProjectName" = $projectNameParam;
        "RepositoryName" = $repoNameParam;
        "RepositoryUri" = $repoUriParam;
        "LastCommitUri" = $lastCommitUriParam;
        "LastCommitDate" = $lastCommitDateParam;
        "LastCommitBuildDate" = $lastBuildDateParam;
        "LastCommitBuildOutcome" = $lastBuildOutcomeParam;
        "LastCommitBuildDefinitionName" = $buildDefinitionNameParam;
    }

    Add-AzTableRow -Table $tableParam -PartitionKey (Get-Date).ToString('u') -RowKey ([guid]::newguid()) -property $rowData
}
