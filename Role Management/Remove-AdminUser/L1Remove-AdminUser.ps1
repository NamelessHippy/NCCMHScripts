#Requires -Modules Microsoft.Graph
#Requires -Version 7.0
#Requires -RunAsAdministrator
$users=New-Object System.Collections.ArrayList

Write-Host "Hello, I am the Admin Role Removal script."
Write-Host "First I will connect to the Graph.  I need to do this to do the work you are asking me to do."
#Connect to Graph API using a certificate.
Connect-MgGraph -CertificateName <cert name> -ClientId <client ID> -TenantId <Tenant ID> -NoWelcome #Replace text in angled bracets with your information

#User can enter one or several user names or email addresses.
#Can be used to remove roles from any user or users.
Write-Host "Please give me the Email Address or User Name of the user you wish Remove Administrator access for."
"You can enter one, or several user names or email addresses separated by a comma or semi-colon."
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
    $userInfo=Get-MgUser -UserId $userId
    #Loop to verify removal of Admin roles.
    while(!$conif){
        Write-Host "This will remove all Directory Roles form " -NoNewline
        Write-Host "$($userInfo.DisplayName)" -NoNewline -ForegroundColor DarkGreen
        Write-Host " account.  This will" -NoNewline
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
                $userInfo2=[PSCustomObject]@{
                    DisplayName=$userInfo.DisplayName
                    UserId=$userInfo.Id
                    Email=$userInfo.Mail
                }
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
    #Add user object to the array.
    [void]$users.Add($userInfo2)
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
        1{
            Write-Host "Ok, I will disable $($userInfo.DisplayName)."
            Write-Host "Even if you have disabled them already, I should not get any errors."
            Write-Host "Unless they have been deleted."
            #disable user
            Update-MgUser -UserId $userInfo.Id -AccountEnabled:$false
            Write-Host "Ok, done in Entra ID."
            Disable-ADAccount -Server "dc-pet" -Identity $userInfo.Mail
            Write-Host "Ok.  All accounts are disabled in AD also."
        }
        2{
            Write-Host "Ok, then."
            Write-Host "We can move on."
            Write-Host "Just take away all my fun :(" -ForegroundColor DarkGray
        }
        default{
            Write-Host "Please select y or n."
        }
    }
}

#Loop to run the subscripts for each identified user simultaniously.
foreach($user in $users){
    #Start subscript to remove all active roles in a new windows.
    Start-Process pwsh -ArgumentList "-File","\\scripts-srvr\scripts\PowerShell\RoleManagement\Remove-AdminUser\L2Remove-ActiveAdmin.ps1","-displayName","$($user.DisplayName)","-Id",$user.UserId
    #Start subscript to remove all eligible roles in a new window.
    Start-Process pwsh -ArgumentList "-File","\\scripts-srvr\scripts\PowerShell\RoleManagement\Remove-AdminUser\L2Remove-EligibleAdmin.ps1","-displayName","$($user.DisplayName)","-Id",$user.UserId
}
Disconnect-MgGraph|Out-Null

Write-Host "The directory roles for each user identified will be removed."
Write-Host "If any of the windows conitinue running, contact my Admin as this may be an indication of a script running to assign Admin Roles to the user."
Write-Host "It could also be an error that my Admin has not resolved yet."
Write-Host "Thank, have a nice day."
#script finished.
Pause