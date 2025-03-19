#Paramaters for running the subscript.
param(
    [string]$displayName,
    [string]$Id
)
$clear=$false

#Connect to Graph using a certificate.
Connect-MgGraph -CertificateName <cert name> -ClientId <client ID> -TenantId <Tenant ID> -NoWelcome #Replace text in angled bracets with your information

Write-Host "Ok, here we go. with the Removal."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."
#Loop to check if assigned Eligible for a role.
while(!$clear){
    "Before we do anything, I want to make sure I check for an Eligible Assignment to Global Administrator."
    #check for Global Admin first and remove it if assigned.
    $gAdmin=Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($Id)' and RoleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'"
    if($gAdmin){
        Write-Host "Oh, it looks like this $($DisplayName) was assigned Global Administrator as Eligible."
        #Body to remove assignment.
        $body=@{
            action="adminRemove"
            directoryScopeId="/"
            roleDefinitionId="62e90394-69f5-4237-9190-012177145e10"
            principalId=$Id
            justification="Removed by Admin Removal Script"
            scheduleInfo=@{
                startDateTime=(Get-Date).ToUniversalTime()
                expiration=@{
                    type="noExpiration"
                }
            }
        }
        Write-Host "I will Remove that now."
        #Remove assignment.
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $body|Out-Null
        $body=$null
        Write-Host "Ok, that has been taken care of.  Now to the rest of the roles."
        Write-Host "I will check Global Admin again during this just to be sure."
    }else{
        "Ok, good.  $($DisplayName) did not have an Eligible Assignment for Global Administrator."
    }
    #Get all eligible roles assigned to the user.
    $directoryRoles=Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($Id)'"
    if($directoryRoles){
        Write-Host "Ok, lets get started!"
        #Loop through all roles, including Global Admin and remove assignment then start the main loop over.
        foreach($role in $directoryRoles){
            $roleName=Get-MgRoleManagementDirectoryRoleDefinition -Filter "Id eq '$($role.RoleDefinitionId)'"
            Write-Host "Now to remove $($roleName.DisplayName) as an Eligible Assignement for $($DisplayName)"
            #Body to remove assignment.
            $body=@{
                action="adminRemove"
                directoryScopeId="/"
                roleDefinitionId=$role.RoleDefinitionId
                principalId=$Id
                justification="Removed by Admin Removal Script"
                scheduleInfo=@{
                    startDateTime=(Get-Date).ToUniversalTime()
                    expiration=@{
                        type="noExpiration"
                    }
                }
            }
            #Remove assignment.
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $body|Out-Null
            $body=$null
            Write-Host "I have removed $($roleName.DisplayName) as an Eligible Assignment."
        }
        Write-Host "Ok, now I am going to loop back, and verify everything was removed."
    }else{
        #If no roles are found assigned as eligible, exit the loop.
        Write-Host "Ok, it looks like we are finished."
        $clear=$true
    }
}
Disconnect-MgGraph|Out-Null
#End of subscript.
Start-Sleep 10