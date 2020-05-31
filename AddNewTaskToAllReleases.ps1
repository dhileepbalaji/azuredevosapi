###############################################################################
# Description : Script to add new task to all release definition[all env]
# Version : 1.0
# Todo : Add Env Filters/Release Filters
###############################################################################
#JSON
# Add the Json definition of task need to be addded.
$Addtask = @'
  [
    {
        "environment": {},
        "taskId": "ef097476-2daa-40d4-99fc-4f8c06909a13",
        "version": "1.*",
        "name": "Task group: NR_APM task group $(NRAPP_GROUP)",
        "refName": "",
        "enabled": true,
        "alwaysRun": true,
        "continueOnError": true,
        "timeoutInMinutes": 0,
        "definitionType": "metaTask",
        "overrideInputs": {},
        "condition": "succeededOrFailed()",
        "inputs": {
            "MACHINE_NAME": "$(MACHINE_NAME)",
            "NEW_RELIC_APP_NAME": "$(NEW_RELIC_APP_NAME)",
            "NR_APP_URL": "$(NR_APP_URL)",
            "NR_PLATFORM": "$(NR_PLATFORM)",
            "NRAPP_GROUP": "$(NRAPP_GROUP)",
            "NRTarget_Location": "$(NRTarget_Location)"
        }
    },
    {
        "environment": {},
        "taskId": "fac46576-b313-47e8-ada2-44ddc4fbaa7b",
        "version": "1.*",
        "name": " NewRelic Deployment Marker(Windows Only)",
        "refName": "",
        "enabled": true,
        "alwaysRun": true,
        "continueOnError": true,
        "timeoutInMinutes": 0,
        "definitionType": "metaTask",
        "overrideInputs": {},
        "condition": "succeededOrFailed()",
        "inputs": {
            "NEW_RELIC_APP_NAME": "$(Release.DefinitionName).$(Release.EnvironmentName)"
        }
    }
]
'@
#PAT BASED AUTH
$pat = ''
$encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))
$comment = 'Adding NewRelic Deployment Marker(Windows Only) and Task group: NR_APM task group $(NRAPP_GROUP) '

#Add your Comment here
$comment = 'Automation: Adding and enabling new tasks in releases'

#AZ Devops URL Construction
$AzureDevOpsProjectURL = 'https://vsrm.dev.azure.com/<yourorg>/<projectname>'
$ReleaseListApiUrl = "$AzureDevOpsProjectURL/_apis/release/definitions"

# Call the Release REST API and Get Release ids Powershell CS Object array.
$Releases = Invoke-RestMethod -Uri $ReleaseListApiUrl -Headers @{Authorization = "Basic $encodedPat" } 
$ReleaseDefinitionIDs = $Releases.value.id


# Iterate Through Each Release ID
foreach ($ReleaseID in $ReleaseDefinitionIDs) {
    # Get Json of Release and Store it as PS Custom object
    $ReleaseUrl = "$AzureDevOpsProjectURL/_apis/release/definitions/$ReleaseID"
    $ReleaseDefinitionResponse = Invoke-RestMethod -Uri $ReleaseUrl -Headers @{Authorization = "Basic $encodedPat" } 
    
    foreach ($env in $ReleaseDefinitionResponse.environments) {
        foreach ($deployphase in $env.deployPhases) {
            $Additional_task = ConvertFrom-Json -InputObject $Addtask
            $deployphase.workflowTasks += $Additional_task 
        }

    }
    
	#Add Comment
    $ReleaseDefinitionResponse | Add-Member -MemberType NoteProperty -Name comment -Value $comment -Force
	# Convert back to JSON to update the release
    $UpdatedReleaseDefinition = $ReleaseDefinitionResponse | ConvertTo-Json -Depth 100
    # Use updated response to update release definition.
    $UpdateDefinitionURI = "$AzureDevOpsProjectURL/_apis/release/definitions?api-version=5.0"
    try {
        $UpdateRelease = Invoke-RestMethod -Uri $UpdateDefinitionURI -Method Put -ContentType application/json -Headers @{Authorization = "Basic $encodedPat" } -Body $UpdatedReleaseDefinition
        Write-Host "Successfully updated release definition", $ReleaseDefinitionResponse.Name -ForegroundColor Green
    }
    catch {
        Write-Error "There was an error updating the release definiton.`n$($_.Exception.Message)"
    }

}
    
