#Paramaters for running the subscript.
param(
    [string]$displayName,
    [string]$Id
)
$clear=$false

#Connect the new window using the same certificate.
Connect-MgGraph -CertificateName <cert name> -ClientId <client ID> -TenantId <Tenant ID> -NoWelcome #Replace text in angled bracets with your information

Write-Host "Ok, here we go. with the Removal."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."

#Recursive loop to repeate removal of roles until none are found.
while(!$clear){
    "Before we do anything, I want to make sure I check for an Active Assignment to Global Administrator."
    #Get Global Admin role
    $gAdmin=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($Id)' and RoleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'"
    #If assigned Global Admin role as Active, remove the role.
    if($gAdmin){
        Write-Host "Oh, it looks like this $($DisplayName) was assigned Global Administrator as Active."
        #build the body for removing the role.
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
        #Remove the role.
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body|Out-Null
        $body=$null
        Write-Host "Ok, that has been taken care of.  Now to the rest of the roles."
        Write-Host "I will check Global Admin again during this just to be sure."
    }else{
        "Ok, good.  $($DisplayName) did not have an Active Assignment for Global Administrator."
    }
    #Get all directory roles assigned.
    $directoryRoles=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($Id)'"
    #Check if there are any directory roles assigned.
    if($directoryRoles){
        Write-Host "Ok, lets get started!"
        #Loop through all directory roles, including Global Admin and remove roles assigned then start the main loop over.
        foreach($role in $directoryRoles){
            $roleName=Get-MgRoleManagementDirectoryRoleDefinition -Filter "Id eq '$($role.RoleDefinitionId)'"
            Write-Host "Now to remove $($roleName.DisplayName) as an Active Assignement for $($DisplayName)"
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
            New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body|Out-Null
            $body=$null
            Write-Host "I have removed $($roleName.DisplayName) as an Active Assignment."
        }
        Write-Host "Ok, now I am going to loop back, and verify everything was removed."
    }else{
        #If a run finds no roles assigned, it ends the loop.
        Write-Host "Ok, it looks like we are finished."
        $clear=$true
    }
}
Disconnect-MgGraph|Out-Null
#end of subscript.
Start-Sleep 10