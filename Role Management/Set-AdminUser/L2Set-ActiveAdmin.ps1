#Get the paramatrs for the script to run.
param(
    [string]$givenName,
    [string]$surname,
    [string]$userId,
    [int]$userType,
    [string]$path
)
$displayName="$($givenName) $($surname)"
#connect to the Graph API for the terminal window the sub script is running in.
Connect-MgGraph -CertificateName <cert name> -ClientId <client ID> -TenantId <Tenant ID> -NoWelcome #Replace text in angled bracets with your information

Write-Host "Ok, now I will begin Assigning " -NoNewline
Write-Host "Active" -NoNewline -ForegroundColor DarkBlue
Write-Host " Roles for $($displayName)."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."

Write-Host "Let me just get the roles again."
#import the CSV for the list of active roles to be assigned
$roles=Import-Csv -Path $path

#Loop through the roles listed
foreach($role in $roles){
    Write-Host "Ok, now to get the Role ID for $($role.displayName)."
    Write-Host "I will need this to assign it to $($displayName)."
    #get the role definition id
    $roleDefinitionId=(Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($role.displayName)'").Id
    Write-Host "Getting additional information for $($role.displayName)"
    #Get the eligible assignment information for the role and the user.
    $eligible=Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($userId)' and RoleDefinitionId eq '$($roleDefinitionId)'"
    #If the user is assigned to the role as eligible already, remove the assignment
    if($eligible){
        Write-Host "Oops, $($DisplayName) is currently Eligible for $($role.displayName).  Let me remove that."
        #Build the body to remove assignment for the user
        $body=@{
            action="adminRemove"
            directoryScopeId="/"
            roleDefinitionId=$roleDefinitionId
            principalId=$userId
            justification="Set by PIM Managment Script"
            scheduleInfo=@{
                startDateTime=(Get-Date).ToUniversalTime()
                expiration=@{
                    type="noExpiration"
                }
            }
        }
        #remove the assignment
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $body|Out-Null
        Write-Host "They don't need to be assigned as both Active and Eligible, that is just silly."
    }
    #Get the active assignment information for the role and the user.
    $active=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($userId)' and RoleDefinitionId eq '$($roleDefinitionId)'"
    #if the user is currently assigned the role as active, do nothing.
    if($active){
        Write-Host "Ok, $($DisplayName) is already Active in $($role.displayName)!"
        Write-Host "Why am I even here?"
    }else{
        #If not assigned the role as active, assign the role.
        Write-Host "Now to assign $($role.displayName) to $($displayName) as Active."
        #Build the body to assign the role.
        $body=@{
            action="adminAssign"
            directoryScopeId="/"
            roleDefinitionId=$roleDefinitionId
            principalId=$userId
            justification="Set by PIM Managment Script"
            scheduleInfo=@{
                startDateTime=(Get-Date).ToUniversalTime()
                expiration=@{
                    type="noExpiration"
                }
            }
        }
        #assign the role.
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body|Out-Null
        Write-Host "$($DisplayName) is assigned $($role.displayName) as Active."
    }
}
#subscript is finished.
Disconnect-MgGraph|Out-Null