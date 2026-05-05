#Requires -Version 7.0

#Version 1.1.0

#Writen by Tim Stapp Jr

#AI was used to learn to configure Named Pipe Stream Server and Event Handler, and to research App permissions needed.

<#ChangeLog:
1.1.0:
   -added Named Pipe Stream Server to hand off User Objects to Subscripts
   -Removed Certificate Based Authentication (It created risks on the app)
   -Updated to use WAM Functionality in Graph SDK version 3.24.x or higher
   -This includes pulling Graph authentication context into subscripts without certificate based authentication
   -Changed to use an app with delegated permissions
   -This is needed because RBAC changes are in Azure, which is not updated for WAM functionality
   -Strongly recomended to restrict Authentication on the app to only Administrators allowed to run this script
   -Added Event Handler functionality to control disconnecting from Graph API and Exchange Online only after all subscripts are finished#>

<#For use:
Adiminstrator Roles:
Global Administrator 
--or--
Priviliaged Role Administrator (Least Priviliaged)

Registered app with Delegated Permissions and Admin Consent
Permissions:
    Directory.ReadWrite.All
    Group.ReadWrite.All
    GroupMember.ReadWrite.All
    RoleAssignmentSchedule.ReadWrite.Directory
    RoleAssignmentSchedule.Remove.Directory
    RoleEligibilitySchedule.ReadWrite.Directory
    RoleEligibilitySchedule.Remove.Directory


Record Registered App ID to a text file clinent.txt
Record Tenant ID to a text file tenant.txt (note: this ID is the same for all apps, you can save this text file to a location can be reused by any script that needs the teant id)
Update Paths to the location chosen for scripts and text files
#>


#Variables
$users=@()
#CSV with the location of the subscript to run the subscripts and the name for Event Handler
$subscripts=Import-Csv -LiteralPath \\path\to\RoleManagement\Remove-AdminUserV3\subscripts.csv
#client and tenant see #For Use
$client=Get-Content \\path\to\RoleManagement\client.txt
$tenant=Get-Content \\path\to\tenant.txt
#All modules required to run, except ActiveDirectory module as it requires elevated shell to install/use
$modules=Get-Content \\path\to\RoleManagement\Remove-AdminUserV3\modules.txt
#initialize the empty Event Handler Names array
$eventHand=@()

Write-Host "Hello, I am the Admin Role Removal script."
Write-Host "First I need to import the Modules used in this script."
foreach($module in $modules){
    $mod=Get-Module $module -ListAvailable|Sort-Object -Property Version -Descending|Select-Object -First 1
    if(!$mod){
        Write-Host "Oh, $($module) is not installed!  Let me take care of that for you."
        try{
            Install-Module -Name $module -AllowClobber -Force|Out-Null
            Write-Host "Ok, it is installed now."
        }
        catch{
            Write-Host "Oh no! I had an error. $($_)"
            Pause
            exit
        }
    }else{
        Write-Host "Oh, $($mod.Name) is installed and up to date.  Good."
    }
    $mod=$null
}
$modules=$null
Remove-Variable mod,modVer, modules

Write-Host "Now I can connect to the Graph.  I need to do this to do the work you are asking me to do."
#Connect to Graph API
try{
    Connect-MgGraph -ClientId $client -TenantId $tenant -NoWelcome
    Connect-ExchangeOnline -ShowBanner:$false
    Connect-IPPSSession -ShowBanner:$false
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

#User can enter one or several user names or email addresses.
#Can be used to remove roles from any user or users.
Write-Host "Please give me the Email Address or User Name of the user you wish Remove Administrator access for."
Write-Host "You can enter one, or several user names or email addresses separated by a comma or semi-colon."
$userIds=Read-Host "Input"
$userIds=$userIds -split '[,;-]'
$userIds=$userIds.Trim()

#Loop through each user name entered.
foreach($userId in $userIds){
    $conif=$false
    #check if there is an @ sign to validate if it is an email address entered and append domain to user name if not.
    if($userId-notmatch"@"){
        $userId="$($userId)@norcocmh.org" #replace @domain.com with your domain
    }
    Write-Host "I will now get the user information."
    #get user information
    try{
        $userInfo=Get-MgUser -UserId $userId
    }
    catch{
        Write-Host "Oh no!  I  had an error.  $($_)"
        Pause
        exit
    }
    $userInfo=Get-MgUser -UserId $userId
    #Loop to verify removal of Admin roles.
    while(!$conif){
        Write-Host "This will remove all Administrator Roles form " -NoNewline
        Write-Host "$($userInfo.DisplayName)" -NoNewline -ForegroundColor DarkGreen
        Write-Host " account.  This will " -NoNewline
        Write-Host "Remove" -NoNewline -ForegroundColor DarkRed 
        Write-Host " administrator permissions."
        Write-Host "Are you sure you want to proceed?" -ForegroundColor Red
        Write-Host "y" -NoNewline -ForegroundColor DarkYellow
        $respond=(Read-Host "/n").ToLower()
        #Check if value is blank and set y as default if it is blank.
        if([string]::IsNullOrWhiteSpace($respond)){
            $respond="y"
        }else{
            #If not blank, gets just the first letter of the value entered.
            $respond=$respond.Substring(0,1)
        }
        switch($respond){
            "y"{
                #Create object with  user information to pass to subscripts
                Write-Host "Ok, let me get all of this organized."
                $users+=$userInfo
                $conif=$true
            }
            "n"{
                #If any word starting with n is entered, the user will be skipped.
                Write-Host "Ok, Then we will skip this user."
                break
            }
            default{
                Write-Host "Please enter y or n."
            }
        }
    }
    $respond=$null
}
$userIds=$null
#Identify if the user should be Disabled.
while($respond -ne "y" -and $respond -ne "n"){
    Write-Host "Since we shutting people down, do you wish to " -NoNewline
    Write-Host "Disable" -NoNewline -ForegroundColor Blue
    if($userInfo.AdditionalProperties.Count -gt 1){
        Write-Host " this account?"
    }else{
        Write-Host " these accounts?"
    }
    Write-Host "y" -NoNewline -ForegroundColor DarkYellow
    $respond=(Read-Host "/n").ToLower()
    #verify you are sure you want to disable the user.
    if([string]::IsNullOrWhiteSpace($respond)){
        $respond="y"
    }else{
        $respond=$respond.Substring(0,1)
    }
    switch($respond){
        "y"{
            Write-Host "OK, will do."
            $aciton=$true
            Write-Host "Just give me a moment and I will get started."
        }
        "n"{
            Write-Host "Ok, then."
            Write-Host "We can move on."
            Write-Host "Just take away all my fun :(" -ForegroundColor DarkGray
        }
        default{
            Write-Host "Please select y or n."
        }
    }
}

#configure Named Pipe Stream Server details
$direction=[System.IO.Pipes.PipeDirection]::Out
$mode=[System.IO.Pipes.PipeTransmissionMode]::Byte
$options=[System.IO.Pipes.PipeOptions]::Asynchronous
#configure Named Pipe Stream Server security
$security=New-Object System.IO.Pipes.PipeSecurity
$security.AddAccessRule(
    [System.IO.Pipes.PipeAccessRule]::new(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
        [System.IO.Pipes.PipeAccessRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
)

#start subscript to deactivate the User
if($aciton){
    #get admin SID for elevated ACLs
    $admin=New-Object System.Security.Principal.SecurityIdentifier(
        [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid,
        $null
    )
    #Grant administrators read/wite
    $security.AddAccessRule(
        [System.IO.Pipes.PipeAccessRule]::new(
            $admin,
            [System.IO.Pipes.PipeAccessRights]::ReadWrite,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
    )
    $admin=$null
    Remove-Variable admin
    #Unique name for AD process
    $pipeName="ad-disable-"+[guid]::NewGuid().ToString("N")
    #Create the Server
    $server=[System.IO.Pipes.NamedPipeServerStreamAcl]::Create(
    $pipeName,$direction,1,$mode,$options,4096,4096,$security
    )
    #Create the Payload for elevated window
    #convert the $users array to json, depth 10 to avoid truncating content
    $json=$users|ConvertTo-Json -Depth 10 -Compress
    #create the payload
    $payLoad=[System.Text.Encoding]::UTF8.GetBytes($json)
    #create the prefix
    $preFix=[System.BitConverter]::GetBytes($payLoad.Length)

    #start AD Subscript in Elevated window
    Start-Process pwsh -ArgumentList "-File","\\path\to\RoleManagement\Remove-AdminUser\L2Remove-AdminUser.ps1"

    #Wait for elevated window to connect
    $server.WaitForConnection()
    #write the prefix to the server, so the client knows what to expect
    $server.Write($preFix,0,$preFix.Length)
    #write the user array to the server
    $server.Write($payLoad,0,$payLoad.Length)

    #close the connection
    $server.Flush()
    $sesrver.Dispose
}

#Loop to run the subscripts for each identified user simultaniously.
foreach($user in $users){
    if($aciton){
        Write-Host "I will deactivate this user in Entara ID"
        Update-MgUser -UserId $user.Id -AccountEnabled:$false|Out-Null
    }
    #unique name for each user
    $pipeName="admin-disable-$($user.id)-"+[guid]::NewGuid().ToString("N")
    foreach($subscript in $subscripts){
        #create the server
        $server=[System.IO.Pipes.NamedPipeServerStreamAcl]::Create(
            $pipeName,$direction,($subscripts.Count),$mode,$options,4096,4096,$security
        )

        #create the payload for each user
        #convert the current user object to json, depth 10 to avoid truncating
        $json=$user|ConvertTo-Json -Depth 10 -Compress
        #create the payload
        $payload=[System.Text.Encoding]::UTF8.GetBytes($json)
        #create the prefix
        $preFix=[System.BitConverter]::GetBytes($payLoad.Length)

        #create the event for subscripts to respond to and ensure coordinated completion
        $eventName="Global\User.$($user.Id).$($subscript.name).Complete"

        $evt=New-Object System.Threading.EventWaitHandle(
            $false,
            [System.Threading.EventResetMode]::ManualReset,
            $eventName
        )

        $eventHand+=$evt

        #Start subscript in a new window
        Start-Process pwsh -ArgumentList "-File",$($subscript.subscript),"-pipeName",$pipeName,"-eventName",$eventName

        #wait for first subscript to connect
        $server.WaitForConnection()
        #write prefix to the server
        $server.Write($preFix,0,$preFix.Length)
        #write payload to server
        $server.Write($payLoad,0,$payLoad.Length)
        #close this connection
        $server.Dispose()
    }
}

[System.Threading.WaitHandle]::WaitAll(
    $eventHand.toarray()
)
Disconnect-MgGraph|Out-Null
Disconnect-ExchangeOnline -Confirm:$false|Out-Null

Write-Host "The directory roles for each user identified have been removed."
Write-Host "Thank, have a nice day."
#script finished.
Pause