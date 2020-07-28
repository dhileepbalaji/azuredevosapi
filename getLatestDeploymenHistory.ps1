# Environment 
$env=''
#Function to get current timestamp
$FileTime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
$OutFile = '.\'+"deploymentlist_"+$env+$FileTime+".csv"


#Azure Devops PAT Token
$pat = ''
$encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))


#AZ Devops URL Construction
$AzureDevOpsProjectURL = 'https://vsrm.dev.azure.com/<organisation>/<project>'
$ReleaseListApiUrl = "$AzureDevOpsProjectURL/_apis/release/definitions"

# Call the Release REST API and Get Release ids in Powershell CS Object array.
$Releases = Invoke-RestMethod -Uri $ReleaseListApiUrl -Headers @{Authorization = "Basic $encodedPat" } 
$ReleaseDefinitionIDs = $Releases.value.id

# array to store the releases
$ReleaseObjs = @()

# Iterate Through Each Release ID
#Loop 1
foreach ($ReleaseID in $ReleaseDefinitionIDs) {
        # Get Json of release history in desending order and Store it as PS Custom object 
        $ReleaseHistoryUrl = "$AzureDevOpsProjectURL/_apis/release/deployments?definitionId=$ReleaseID&queryOrder=descending&deploymentStatus=succeeded&api-version=6.0-preview.2"
        $ReleaseHistoryResponse = Invoke-RestMethod -Uri $ReleaseHistoryUrl -Headers @{Authorization = "Basic $encodedPat" }
        # iterate through all the release history of a release definition
        foreach ( $release in $ReleaseHistoryResponse.value) {
            # filter the json for $env
            if ($release.releaseEnvironment.name = $env) {
                $Obj = [PSCustomObject]@{
                    ReleaseName = $release.releaseDefinition.name;
                    ReleaseNo = $release.release.name;
                    ReleaseURL = $release.release.webAccessUri;}
                $ReleaseObjs += $Obj
                # break the loop AFTER first match
                break
            }
        }
    }
    $ReleaseObjs | Export-Csv -NoTypeInformation -Append -Path $OutFile
