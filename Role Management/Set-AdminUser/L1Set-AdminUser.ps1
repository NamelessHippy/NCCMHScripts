#Requires -Version 7.0
#Requires -RunAsAdministrator

#Variables -
#$users is initialized as an array to be populated with relivent information in the sub scripts.
$users=New-Object System.Collections.ArrayList

Write-Host "Hello, I am the Admin Role Assignment script."
Write-Host "First I will connect to the Graph.  I need to do this to do the work you are asking me to do."
#connect to the Graph API using a certificate.
Connect-MgGraph -CertificateName <cert name> -ClientId <client ID> -TenantId <Tenant ID> -NoWelcome #Replace text in angled bracets with your information

#User can enter one or several user names or email addresses.  
#Current version does not have validation that the users entered are authorized to have admin privliges.  
Write-Host "Please give me the Email Address or User Name of the user you wish to be an Administrator"
Write-Host "You can enter one, or several user names or email addresses separated by a comma or semi-colon."
$userIds=Read-Host "Input"
$userIds=$userIds -split '[,;-]'
$userIds=$userIds.Trim()

#Loop through each user name entered.
foreach($userId in $userIds){
    $conif=$false
    #check if there is an @ sign to validate if it is an email address entered and append domain to user name if not.
    if($userId-notmatch"@"){
        $userId="$($userId)@domain.com" #replace @domain.com with your domain
    }
    Write-Host "Next I will get the user information."
    #get user information
    $userInfo=Get-MgUser -UserId $userId
    Write-Host "Now to get all of the directory roles and filter out Global Administrator."
    #gets all roles, then filters out Global Admin.
    $eligibleRoles=Get-MgDirectoryRole|Where-Object{$_.Id -ne '17af4e2d-65bc-4d0b-82db-6b1742112c69'}
    Write-Host "I have it!  I will use this later in the script."
    
    #Loop will verify what role the user will be given.
    while(($userType -lt 1 -or $userType -gt 6) -and ($respond -ne "y" -or $respond -ne "n") -and !$conif){
        $respond=""
        $userType=$null
        Write-Host "What is the specific Job Role will " -NoNewline
        Write-Host "$($userInfo.DisplayName)" -NoNewline -ForegroundColor DarkGreen
        Write-Host " fill?"
        #select what job role the user has.  This is to decentralize who has perminiant active roles to reduce the attach surface if an administrator account is compromised.
        Write-Host "[1] Help Desk Administrator" -NoNewline -ForegroundColor DarkYellow
        Write-Host " [2] Network Administrator [3] Intune Administrator [4] Security Administrator [5] Global Administrator [6] Data Analyst"
        $userType=Read-Host "Selection"
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
                    $aPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\1HDActive.csv"
                    $activeRoles=Import-Csv -Path $aPath
                    $role="Help Desk Administrator"
                }
                2{
                    $aPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\2NAActive.csv"
                    $activeRoles=Import-Csv -Path $aPath
                    $role="Network Administrator"
                }
                3{
                    $aPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\3IAActive.csv"
                    $activeRoles=Import-Csv -Path $aPath
                    $role="Intune Administrator"
                }
                4{
                    $aPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\4SAActive.csv"
                    $activeRoles=Import-Csv -Path 
                    $role="Security Administrator"
                    $role
                }
                5{
                    Write-Host "Oh! Oh my."
                    Start-Sleep 1
                    Write-Host "A Global Administrator."
                    Write-Host "They do exists O.O"
                    $activeRoles=Import-Csv -Path \\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\5GAActive.csv
                    $role="Global Administrator" 
                }
                6{
                    $aPath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\6.5DAActive.csv"
                    $activeRoles=Import-Csv -Path $aPath
                    $eligibleRoles=Import-Csv -Path \\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\6.0DAEligible.csv
                    $role="Data Analyst"
                }
                Default{
                    Write-Host "Please select a number between 1 and 6."
                    break
                }
            }
            #Loop to verify selection.  If n, no, or any other word starting with n is entered it will go back to the role selection.
            while($respond -ne "y" -and $respond -ne "n"){
                #displays the list of active and eligible roles to be assigned for review.
                $activeRoles|Out-GridView -Title "Active Roles"
                $eligibleRoles|Out-GridView -Title "Eligible Roles"
                "You have selected $($role)."
                "Please review the assignments."
                "Are these correct?"
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
                Write-Host "I will now make sure I have all of the roles $($userInfo.DisplayName) will be Assigned.  Then sort by Active or Eligible."
                #set the path for the eligible roles that will be assigned to this user.
                #Multiple users with the same job role will have the same active/eligible roles, so overwriting is not an issue.
                $ePath="\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\$($role)active.csv"
                #compare the list of eligible and active roles and output to the CSV defined in $ePath for use by the subscript.
                Compare-Object -ReferenceObject $eligibleRoles -DifferenceObject $activeRoles -Property id,description,displayName,roleTemplateId -IncludeEqual:$false|Export-Csv -Path $path|Out-Null
                if($respond -eq "y"){
                    Write-Host "Great!  That is done, now we can continue."
                    #If verified as correct, the user information and roles will be collected into an object.
                    $userInfo2=[PSCustomObject]@{
                        GivenName=$userInfo.GivenName
                        Surname=$userInfo.Surname
                        UserId=$userInfo.Id
                        Email=$userInfo.Mail
                        AdminRole=$role
                        UserType=$userType
                        ActiveRoles=@($activeRoles)
                        EligibleRoles=@($eligibleRoles)
                    }
                    $conif=$true
                }
                elseif($respond -eq "n"){
                    "Right! Then let's start over"
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
    $userType=$null,$userinfo=$null
    #add the user object to the $users array initialized at the start.
    [void]$users.Add($userInfo2)
    $userInfo2=$null
}

#Loop through the $users array to start the subscript to assign active and eligible roles.
#Each run of the subscript for active and for eligible assignments for each user will open in a new window and run simultaniously.  This saves time as running each user individually can take 20 minutes per user.
foreach($user in $users){
    Write-Host "Now to assign " -NoNewline
    Write-Host "$($user.AdminRole)" -NoNewline -ForegroundColor DarkBlue
    Write-Host " Job Role to " -NoNewline
    Write-Host "$($user.DisplayName)." -ForegroundColor DarkGreen
    Write-Host "I will assign Active Roles to $($user.displayName) in a separate window."
    #start the script to assign active roles
    Start-Process pwsh -ArgumentList "-File","\\scripts-srvr\Scripts\PowerShell\RoleManagement\Set-AdminUser\L2Set-ActiveAdmin.ps1","-givenName",$user.GivenName,"-surname",$user.Surname,"-userId","$($user.UserId)","-userType","$($user.UserType)","-aPath",$aPath
    Write-Host "I will assign Eligible roles to $($user.DisplayName) in a separate window."
    #start the script to assign eligible roles.
    Start-Process pwsh -ArgumentList "-File","\\scripts-srvr\Scripts\PowerShell\RoleManagement\Set-AdminUser\L2Set-EligibleAdmin.ps1","-givenName",$user.GivenName,"-surname",$user.Surname,"-userId","$($user.UserId)","-userType","$($user.UserType)","-ePath",$ePath
}
$users=$null

#script is finished.
Disconnect-MgGraph|Out-Null
Write-Host "Ok, I have assigned the requested Admin Roles for all users."
Write-Host "Thank you, and have a great day."
Pause