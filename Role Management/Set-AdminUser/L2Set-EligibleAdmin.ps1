#Get the paramatrs for the subscript to run.
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
Write-Host "Eligible" -NoNewline -ForegroundColor DarkCyan
Write-Host " Roles for $($displayName)."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."

Write-Host "Let me just get the roles again."
#import the CSV for the list of active roles to be assigned
$roles=Import-Csv -Path $path

#Loop through the roles listed
foreach($role in $roles){
    Write-Host "Ok, now I will get the Role ID for $($role.displayName)."
    Write-Host "I need this to assign $($user.DisplayName) to it."
    #get the role definition id
    $roleDefinitionId=(Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($role.displayName)'").Id
    Write-Host "Getting additional information for $($role.displayName)"
    #Get the active assignment information for the role and the user.
    $active=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($userId)' and RoleDefinitionId eq '$($roleDefinitionId)'"
    #If the user is assigned to the role as active already, remove the assignment
    if($active){
        Write-Host "Oops, $($DisplayName) is currently Active for $($role.displayName) Let me remove that."
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
        #Remove the assignment
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body|Out-Null
        Write-Host "I have already assigned them their active roles, if this was not on the list it shouldn't be active."
        Write-Host "However, if this was a temporary assignment I hope you informed them you were running this script so they don't encounter problems."
    }
    #Get the eligible assignment information for the role and the user.
    $eligible=Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($userId)' and RoleDefinitionId eq '$($roleDefinitionId)'"
    #if the user is currently assigned the role as eligible, do nothing.
    if($eligible){
        Write-Host "$($DisplayName) is Eligible for $($role.displayName).  I guess I don't need to do anything."
    }else{
        #If not assigned the role as active, assign the role.
        Write-Host "Now to assign $($DisplayName) to the role as Eligible."
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
        #assign the role
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $body|Out-Null
        Write-Host "$($DisplayName) is assigned $($role.displayName) as Eligible."
    }
}
#script finished
Disconnect-MgGraph