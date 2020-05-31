###############################################################################
# Description : Script to Enable Work items reporting / Release badges in all releases
# Version : 1.0
# Todo : Add Env Filters/Release Filters
###############################################################################
#Azure Devops PAT Token
$pat = ''
$encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))


#Add your Comment here
$comment = 'Automation: Enabling Intergrations in Options'

#AZ Devops URL Construction
$AzureDevOpsProjectURL = 'https://vsrm.dev.azure.com/<yourorg>/<projectname>'
$ReleaseListApiUrl = "$AzureDevOpsProjectURL/_apis/release/definitions"
# Create Properties
$envproperties = @'

{
    "LinkBoardsWorkItems": {
        "$type": "System.String",
        "$value": "True"
    },
    "BoardsEnvironmentType": {
        "$type": "System.String",
        "$value": "dummy"
    }
}
'@



$globalproperties = @'
{
    "IntegrateBoardsWorkItems": {
        "$type": "System.String",
        "$value": "True"
        }
}
'@

$globalpropertiesobj = ConvertFrom-Json($globalproperties )


# Call the Release REST API and Get Release ids in Powershell CS Object array.
$Releases = Invoke-RestMethod -Uri $ReleaseListApiUrl -Headers @{Authorization = "Basic $encodedPat" } 
$ReleaseDefinitionIDs = $Releases.value.id

# If you want to add badges to selected releases, add the release names to filter releases file.
# by default it will search for release_names.txt, from path where the script is executed.
$filterReleaseList = Get-Content -Path './release_names.txt'

# Iterate Through Each Release ID
#Loop 1
foreach ($ReleaseID in $ReleaseDefinitionIDs) {

    # Get Json of Release and Store it as PS Custom object $ReleaseDefinitionResponse
    $ReleaseUrl = "$AzureDevOpsProjectURL/_apis/release/definitions/$ReleaseID"
    $ReleaseDefinitionResponse = Invoke-RestMethod -Uri $ReleaseUrl -Headers @{Authorization = "Basic $encodedPat" }
    if ($filterReleaseList -icontains $ReleaseDefinitionResponse.name) {
              
        $ReleaseDefinitionResponse.PSObject.Properties.Remove('properties')
        $ReleaseDefinitionResponse | Add-Member -MemberType NoteProperty -Name "properties" -Value $globalpropertiesobj

        # Iterating through each environment in release 
        #Loop 2
        foreach ( $env in $ReleaseDefinitionResponse.environments) {
            $envpropertiesobj = ConvertFrom-Json($envproperties)
            $env.PSObject.Properties.Remove('properties')
            $env | Add-Member -MemberType NoteProperty -Name "properties" -Value $envpropertiesobj
        }
        $ReleaseDefinitionResponse_1 = $ReleaseDefinitionResponse
        #Loop 3
        foreach ( $env in $ReleaseDefinitionResponse_1.environments) {
            $env.environmentOptions.publishDeploymentStatus = $true
            $env.environmentOptions.autoLinkWorkItems = $true
            if ($env.name -ilike "*dev*") {$env.properties.BoardsEnvironmentType.'$value' = "development"}
            elseif ($env.name -ilike "*qa*") { $env.properties.BoardsEnvironmentType.'$value' = "testing"}
            elseif ($env.name -ilike "*uat*") { $env.properties.BoardsEnvironmentType.'$value' = "staging"}
            elseif ($env.name -ilike "*prod*") {$env.properties.BoardsEnvironmentType.'$value' = "production"}
            else {write-host "No matching env"} 
        }

        #Add Comment
        $ReleaseDefinitionResponse | Add-Member -MemberType NoteProperty -Name comment -Value $comment -Force
        # Convert back the object to JSON and update the release
        $UpdatedReleaseDefinition = $ReleaseDefinitionResponse | ConvertTo-Json -Depth 100
        # Use $UpdatedReleaseDefinition to update release definition.
        $UpdateDefinitionURI = "$AzureDevOpsProjectURL/_apis/release/definitions?api-version=5.0"
        try {

            #Call Azure Devops API and update the release
            $UpdateRelease = Invoke-RestMethod -Uri $UpdateDefinitionURI -Method Put -ContentType application/json -Headers @{Authorization = "Basic $encodedPat" } -Body $UpdatedReleaseDefinition
            Write-Host "Successfully updated release definition", $ReleaseDefinitionResponse.Name -ForegroundColor Green           
        }
        catch {
            Write-Error "There was an error updating the release definiton.`n$($_.Exception.Message)"
        }
    }

}


