#Paramaters for running the subscript.
param(
    [string]$pipeName,
    [string]$eventName
)
#variables
$clear=$false
$pAdmin=@()

#Named Pipe Server Stream Connection
$client=New-Object System.IO.Pipes.NamedPipeClientStream(".",$pipeName,[PipeDirection]::In)
$client.Connect(60*1000)

#Read the prefix
$reader=New-Object System.IO.BinaryReader($client,[System.Text.Encoding]::UTF8,$true)
$preFix=$reader.ReadBytes(4)
if($preFix.Count -ne 4){
    throw "Prefix not recieved."
    exit
}
$len=[System.BitConverter]::ToInt32($preFix,0)
if($len -le 0){
    throw "Prefix length mismatch."
    exit
}

$buffer=New-Object byte[] $len
$offset=0
do{
    $read=$client.Read($buffer,$offset,$len - $offset)
    if($read -le 0){
        throw "unexpected end of stream at $offset/$len bits"
    }
    $offset+=$read
}while($offset -lt $len)

$json=[System.Text.Encoding]::UTF8.GetString($buffer)
$user=$json|ConvertFrom-Json

#Connect the new window using the same certificate.
try{
    Connect-MgGraph -NoWelcome
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Ok, here we go. with removing Active Roles for $($user.DisplayName)."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."

#Repeate removal of roles until none are found.
$i=0
while(!$clear){
    $i++
    Write-Host "Before we do anything, I want to make sure I check for an Active or Elegible Assignment to Global Administrator or Privilaged Role Administrator."
    try{
        #Get all directory roles assigned.
        $directoryRoles=Get-MgRoleManagementDirectoryRoleAssignment -Filter "PrincipalId eq '$($user.Id)'"
    }
    catch{
    }#Check if there are any directory roles assigned.
    if($directoryRoles){
        #Get Global Admin  and Privilaged Role Admin roles
        $pAdmin=$directoryRoles|Where-Object{$_.RoleDefinitionId -eq '62e90394-69f5-4237-9190-012177145e10' -or $_.RoleDefinitionId -eq 'e8611ab8-c189-46e8-94e1-60213ab1f814'}
        
        #If assigned Global Admin or Privilaged Role Admin is Active, remove the role.
        foreach($admin in $pAdmin){
            $sched=$null
            $body=$null
            try{
                Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $admin.Id -ErrorAction Stop
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
            $sched=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($user.Id)' and RoleDefinitionId eq '$($admin.Id)'"
            if($sched){
                #build the body for removing the role.
                $body=@{
                    action="adminRemove"
                    directoryScopeId="/"
                    roleDefinitionId=$sched.RoleDefinitionId
                    principalId=$Id
                    justification="Removed by Admin Removal Script"
                    scheduleInfo=@{
                        startDateTime=(Get-Date).ToUniversalTime()
                        expiration=@{
                            type="noExpiration"
                        }
                    }
                }
                #Remove the role.
                try{
                    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body -ErrorAction Stop|Out-Null
                }
                catch{
                    $code=@(
                        $_.Exception.StatusCode
                        $_.Exception.Response.StatusCode
                    )|Where-Object{$_}
                    if($code -notcontains 404 -and $code -notcontains 400){
                        $_
                        Write-Host "Oops, I had an error (,,>`﹏<,,)"
                    }
                }
            }
        }
        Write-Host "Ok, lets get started!"
        #Loop through all directory roles, including Global Admin and remove roles assigned then start the main loop over.
        foreach($role in $activRoles){
            $sched=$null
            $body=$null
            try{
                Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $role.Id
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
            $sched=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "principal eq '$($user.Id) and roleDefinitionId eq '$($role.roleDefinitionId)"
            if($sched){
                $roleName=Get-MgRoleManagementDirectoryRoleDefinition -Filter "Id eq '$($role.RoleDefinitionId)'"
                Write-Host "Now to remove $($roleName.DisplayName) as an Active Assignement for $($user.DisplayName)"
                $body=@{
                    action="adminRemove"
                    directoryScopeId="/"
                    roleDefinitionId=$role.RoleDefinitionId
                    principalId=$user.Id
                    justification="Removed by Admin Removal Script"
                    scheduleInfo=@{
                        startDateTime=(Get-Date).ToUniversalTime()
                        expiration=@{
                            type="noExpiration"
                        }
                    }
                }
                try{
                    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $body|Out-Null
                }
                catch{
                    $code=@(
                        $_.Exception.StatusCode
                        $_.Exception.Response.StatusCode
                    )|Where-Object{$_}
                    if($code -notcontains 404 -and $code -notcontains 400){
                        $_
                        Write-Host "Oops, I had an error (,,>`﹏<,,)"
                    }
                }
                $body=$null
            }
            Write-Host "I have removed $($roleName.DisplayName) as an Active Assignment."
        }
        Write-Host "Ok, now I am going to loop back, and verify everything was removed."
    }else{
        #If a run finds no roles assigned, it ends the loop.
        Write-Host "Ok, it looks like we are finished."
        $clear=$true
    }
}

#signal completion to parent script using Event
$evt=[System.Threading.EventWaitHandle]::OpenExisting($eventName)
$evt.Set()

Write-Host "I have finished removing all Active Assgined and Perminently Assigned Admin Roles from $($user.DisplayName)"
Pause