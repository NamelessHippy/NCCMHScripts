#Requires -Version 7.0

#Variables
#$logPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\Logs\Logs.log"
$modules=Get-Content \\scripts-srvr\Scripts\PowerShell\RoleManagement\setmodules.txt
$client=Get-Content \\scripts-srvr\Scripts\PowerShell\RoleManagement\client.txt
$tenant=Get-Content \\scripts-srvr\Scripts\PowerShell\tenant.txt

Write-Host "Hello, I am the Admin Role Assignment script."

#Modules
Write-Host "First I have to verify all required Modules are loaded."
Import-Module \\scripts-srvr\Scripts\PowerShell\Custom_Modules\Logging\Logging.psm1 -Force
#Save-Log -message "Starting Role Management Set Admin Script" -logPath $logPath
#Save-Log -message "Begin module verification" -logPath $logPath
#Check that required modules or sub modules are installed
foreach($module in $modules){
    if($module -ne 'ActiveDirectory'){
        if(Get-Module -Name $module -ListAvailable -All|Sort-Object -Property Version -Descending|Select-Object -First 1){
            Write-Host "You have $($module) Module installed already.  I will move on."
            #Save-Log -message "$($module) Module installation verified." -logPath $logPath
        }else{
            Write-Host "Oh, you don't have $($module).  I will get that installed for you."
            #Save-Log -message "Install module $($module) Module" -logPath $logPath
            #Install module is not present
            try{
                Install-Module -Name $module -Force -AllowClobber -Confirm:$false
                #Save-Log -message "Install module $($module) complete" -level Success -logPath $logPath
            }
            catch{
                #Save-Log -message "Install module $($module) failed: $($_)" -level Error -logPath $logPath
                Write-Host "Oh no.  Critical error.  Terminating all processes."
                Pause
                exit
            }
        }
    }
}

#Connect to MG Graph
Write-Host "Ok, I am now connected to the Graph."
try{
    Connect-MgGraph -ClientId $client -TenantId $tenant -NoWelcome
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

#User can enter one or several user names or email addresses.  
#Current version does not have validation that the users entered are authorized to have admin privliges.  
#Save-Log -message "Begin username input." -logPath $logPath
Write-Host "Please give me the Email Address or User Name of the user you wish to be an Administrator"
Write-Host "You can enter one, or several user names or email addresses separated by a comma or semi-colon."
$userIds=Read-Host "Input"

Write-Host "Ok, before I can begin the work, I will activate Privilaged Role Administrator for you"
try{
    $adminId=(Get-MgUser -UserId (Get-MgContext).Account).Id
    $praDefID=(Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId 'e8611ab8-c189-46e8-94e1-60213ab1f814').Id
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "I have the role ID, now to Activate it."
try{
    $scheduleTime=(Get-Date).ToUniversalTime()
    $praActive=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$adminId' and RoleDefinitionId eq '$praDefID'"
    if($praActive){
        Write-Host "Privilaged Role Administrator is currently Active."
        $praInstance=Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "PrincipalId eq '$adminId' and RoleDefinitionId eq '$praDefID' and status eq 'Active'"
        if($praInstance.EndDateTime -lt $scheduleTime){
            $praBody=@{
                action="adminExtend"
                directoryScopeId="/"
                roleDefinitionId=$praDefID
                principalId=$adminId
                justification="Set by Role Management Script to set admin roles for $userIds"
                scheduleInfo=@{
                    startDateTime=$scheduleTime
                    expiration=@{
                        type="afterDuration"
                        duration="PT30M"
                    }
                }
            }
            $praSchedule=New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $praBody
        }
    }else{
        $praBody=@{
            action="selfActivate"
            directoryScopeId="/"
            roleDefinitionId=$praDefID
            principalId=$adminId
            justification="Set by Role Management Script to set admin roles for $userIds"
            scheduleInfo=@{
                startDateTime=$scheduleTime
                expiration=@{
                    type="afterDuration"
                    duration="PT30M"
                }
            }
        }
        $praSchedule=New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $praBody
    }
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

$userIds=$userIds -split '[,;-]'
$userIds=$userIds.Trim()

#Loop through each user name entered.
#Save-Log -message "Begin User input standarization" -logPath $logPath
foreach($userId in $userIds){
    $conif=$false
    #check if there is an @ sign to validate if it is an email address entered and append domain to user name if not.
    if($userId-notmatch"@"){
        #Save-Log -message "Append domain." -logPath $logPath
        $userId="$($userId)@norcocmh.org" #replace @domain.com with your domain
    }    
    #Loop will verify what role the user will be given.
    #Save-Log -message "Begin select job role for $($userInfo.DisplayName)." -logPath $logPath
    while(($userType -lt 1 -or $userType -gt 6) -and ($respond -ne "y" -or $respond -ne "n") -and !$conif){
        $respond=""
        $userType=$null
        Write-Host "What is the specific Job Role will " -NoNewline
        Write-Host "$($userInfo.DisplayName)" -NoNewline -ForegroundColor DarkGreen
        Write-Host " fill?"
        #select what job role the user has.  This is to decentralize who has perminiant active roles to reduce the attach surface if an administrator account is compromised.
        Write-Host "[1] Help Desk Administrator" -NoNewline -ForegroundColor DarkYellow
        $userType=Read-Host " [2] Network Administrator [3] Intune Administrator [4] Security Administrator [5] Global Administrator [6] Data Analyst"
        #Check if the value entered is blank
        if([string]::IsNullOrWhiteSpace($userType)){
            #Set to 1 if blank, making 1 the default.
            $userType=1
        }
        #Check if the value entered is a number from 1 to 6
        #If using a different number of job roles, adjust the max numbers to match.
        if($userType -match "^\d+$" -and ($userType -ge 1 -and $userType -le 6)){
            "Now I will get a list of Roles that the user will be Eligable for and Active in."
            #switch to identify which list of active roles will be assigned for the selected role.
            switch($userType){
                1{
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\1HDActive.csv'
                    $role="Help Desk Administrator"
                }
                2{
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\2NAActive.csv'
                    $role="Network Administrator"
                }
                3{
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\3IAActive.csv'
                    $role="Intune Administrator"
                }
                4{
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\4SAActive.csv'
                    $role="Security Administrator"
                }
                5{
                    Write-Host "Oh! Oh my."
                    Start-Sleep 1
                    Write-Host "A Global Administrator."
                    Write-Host "They do exists O.O"
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\5GAActive.csv'
                    $role="Global Administrator" 
                }
                6{
                    $csvPath='\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\6.5DAActive.csv'
                    $role="Data Analyst"
                }
                Default{
                    Write-Host "Please select a number between 1 and 6."
                    break
                }
            }
            #Save-Log -message "Selected $($role) for $($userInfo.DisplayName)" -logPath $logPath
            #Loop to verify selection.  If n, no, or any other word starting with n is entered it will go back to the role selection.
            while($respond -ne "y" -and $respond -ne "n"){
                Write-Host "You have selected $($role)."
                Write-Host "Is this correct?"
                Write-Host "[" -NoNewline
                Write-Host "y" -NoNewline -ForegroundColor DarkYellow
                $respond=(Read-Host "/n]").ToLower()
                #check if the value entered is blank
                if([string]::IsNullOrWhiteSpace($respond)){
                    #if blank, sets value to y as the default
                    $respond="y"
                }else{
                    #If not blank, gets just the first letter of the value entered.
                    $respond=$respond.Substring(0,1)
                }
                if($respond -eq "y"){
                    Write-Host "Great!  Now we can continue."
                    Start-Process pwsh -ArgumentList "-File","\\scripts-srvr\Scripts\PowerShell\RoleManagement\Set-AdminUserv2\L2Set-AdminUser.ps1","-userId",$userId,"-role",$role,"-csvPath"$csvPath -Wait
                    $conif=$true
                }
                elseif($respond -eq "n"){
                    Write-Host "Right! Then let's start over"
                    #If not verified as correct, will reset variables and restart the loop from role selection.
                    $userType=$null,$respond=$null
                    Break
                }
                else{
                    #if the value entered did not start with a y or n it will restart the inner loop to ask for verification again.
                    "Please select y or n."
                }
            }
        }else{
            #If not a number between 1 and 6, will return to the beginning.
            "Please enter a number between 1 and 6."
            $userType=$null
        }
    }
}

Write-Host "OK, you have been given an extreamly high level of access for this script.  I should make sure to deactivate that since I am done."

$praBody=@{
    action="selfDeactivate"
    principalId=$adminId
    roleDefinitionId=$praDefID
    directoryScopeId="/"
    targetScheduleId=$praSchedule.Id
}

try{
    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $praBody|Out-Null
}
catch{
    $_
    Write-Host "Oops, I had an error (,,>`﹏<,,)"
}

#script is finished.
#Save-Log -message "Disconnecting parent script from Microsoft Graph." -logPath $logPath
Disconnect-MgGraph|Out-Null
#Save-Log -message "Connection to Microsoft Graph terminated for parent script." -logPath $logPath
Write-Host "Ok, I have assigned the requested Admin Roles for all users."
Write-Host "You may need to give it an hour or two for some roles to get full access."
Write-Host "Except " -NoNewline
Write-Host "SharePoint Admin" -NoNewline -ForegroundColor Green
Write-Host "."
Write-Host "Per Microsoft" -NoNewline -ForegroundColor DarkBlue
Write-Host " that could take " -NoNewline
Write-Host "24 hours" -NoNewline -BackgroundColor DarkYellow
Write-Host " for access to be granted."
Write-Host "So please be patient, and thank you."
Write-Host "Have a great day!"
Pause