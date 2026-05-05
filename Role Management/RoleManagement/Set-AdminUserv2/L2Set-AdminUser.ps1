#Parameters
<#param(
    [string]$userId,
    [string]$role,
    [string]$csvPath
)#>

Write-Host "Ok, here I go with one user."
$aRoles=Import-Csv -LiteralPath $csvPath

Write-Host "Connecting to the Graph again."
Write-Host "you should not need to log in again."
#Connect to Graph
try{
    Connect-MgGraph -ErrorAction Stop
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Ok, now that I have pulled the Graph connection context into this window, I can get going."
Write-Host "Getting the Entra ID user object."
#Get Entra ID user object
try{
    $user=Get-MgUser -UserId $userId -ErrorAction Stop
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Ok, now to get all directory roles from Entra ID."
#Get Entra Roles
try{
    $direcRoles=Get-MgDirectoryRole -ErrorAction Stop
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Oh, I should get which ones are Eligible first."
#Get Eligible Roles
try{
    if($role -eq 'Data Analyst'){
        Write-Host "Oh, this person is a Data Analyst.  They get a trimmed down list of eligible roles."
        Write-Host "Let me get that list from the CSV."
        $eRoles=Import-Csv -LiteralPath "\\scripts-srvr\Scripts\PowerShell\RoleManagement\CSVs\6.0DAEligible.csv" -ErrorAction Stop
        Write-Host "Now to get the matching directory objects from Entra ID"
        $eligibleRoles=$direcRoles|Where-Object{$eRoles.id -contains $_.Id}
    }else{
        Write-Host "Ok, now to filter out Global Admin."
        $eligibleRoles=$direcRoles|Where-Object{$_.Id -ne '17af4e2d-65bc-4d0b-82db-6b1742112c69'}
    }
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Now to get all of the Entra ID objects for the roles in the CSV."
Write-Host "I got that at the start of the script.  Did I not mention that?"
#Get Active Roles
try{
    $activeRoles=$direcRoles|Where-Object{$aRoles.Id -contains $_.Id}
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Ok, now to compare Active and Eligible."
Write-Host "Now you understand why I needed to get the Entra ID Objects, don't you."
#Sort Eligible and Active Roles
try{
    $allRoles=Compare-Object -ReferenceObject $eligibleRoles -DifferenceObject $activeRoles -IncludeEqual:$true -ErrorAction Stop
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Ok, now to assign the roles to $($user.DisplayName)."
#Assign each role
foreach($r in $allRoles){
    Write-Host "I need the Definition ID for $($r.InputObject.DisplayName) before I can do anything."
    try{
        $roleDefinitionId=(Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($r.InputObject.DisplayName)'").Id
    }catch{
        $_
        Write-Host "Oops, I had an error (,,>`﹏<,,)"
    }

    Write-Host "Ok, now to see if $($r.InputObject.DisplayName) is already Assigned as Active."
    Write-Host "This information is needed later."
    #Get Active Assignment for this user and this role to verify if an active assignment exists later
    try{
        $active=Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($user.Id)' and RoleDefinitionId eq '$($roleDefinitionId)"
    }catch{
        $_
        Write-Host "Oops, I had an error (,,>`﹏<,,)"
    }

    Write-Host "Got it.  Now to see if it is already Assigned as Eligible."
    Write-Host "Also, later."
    #get eligible assignment for this user and this role to verify if an eligible assignment exists later
    try{
        $eligible=Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($user.Id)' and RoleDefinitionId eq '$($roleDefinitionId)"
    }catch{
        $_
        Write-Host "Oops, I had an error (,,>`﹏<,,)"
    }

    Write-Host "Ok, now the really screwy part."
    Write-Host "I need to craft the request bodies.  Yes, plural!"
    #Build the body of the payload to remove assignment
    $rBody=@{
        action="adminRemove"
        directoryScopeId="/"
        roleDefinitionId=$roleDefinitionId
        principalId=$user.Id
        justification="Set by PIM Managment Script"
        scheduleInfo=@{
            startDateTime=(Get-Date).ToUniversalTime()
            expiration=@{
                type="noExpiration"
            }
        }
    }
    $sBody=@{
        action="adminAssign"
        directoryScopeId="/"
        roleDefinitionId=$roleDefinitionId
        principalId=$user.Id
        justification="Set by PIM Managment Script"
        scheduleInfo=@{
            startDateTime=(Get-Date).ToUniversalTime()
            expiration=@{
                type="noExpiration"
            }
        }
    }

    #Filter action on how it will be assigned
    if($r.SideIndicator -eq '<='){
        Write-Host "Ok, $($user.DisplayName) is supposed to be Assigned $($r.InputObject.DisplayName) as Eligible."
        Write-Host "I should verify it is not currently assigned as Active."
        if($active){
            Write-Host "Oh.  This could have caused some problems."
            Write-Host "It is currently assigned as Active.  Let me remove that."
            try{
                New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $rBody|Out-Null
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
        }
        if(!$eligible){
            Write-Host "It is not Assigned as Eligible!"
            Write-Host "I will just have to fix that."
            try{
                New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $sBody|Out-Null
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
        }else{
            Write-Host "$($user.DisplayName) is already Eligible for $($r.InputObject.DisplayName)"
            Write-Host "Ok, that makes things easier, moving on."
        }
    }else{
        Write-Host "Ok, $($user.DisplayName) is supposed to be Assigned $($r.InputObject.DisplayName) as Active."
        if($eligible){
            Write-Host "Oh, $($r.InputObject.DisplayName) is already assigned as Eligible."
            Write-Host "There is no reason for $($user.DisplayName) to be assigned both Active and Eligible at the same time."
            try{
                New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $rBody|Out-Null
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
            Write-Host "Honestly, it would probably just be confusing."
        }
        if(!$active){
            Write-Host "Ok, $($r.InputObject.DisplayName) is not Assigned as Active."
            Write-Host "Let me fix that."
            try{
                New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $sBody|Out-Null
            }
            catch{
                $_
                Write-Host "Oops, I had an error (,,>`﹏<,,)"
            }
        }else{
            Write-Host "$($user.DisplayName) is already Active for $($r.InputObject.DisplayName)"
            Write-Host "That makes things easy.  Moving on."
        }
    }
}

Write-Host "I have finished the Role assignments for $($user.DisplayName)"
Pause