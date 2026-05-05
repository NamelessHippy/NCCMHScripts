#Paramaters for running the subscript.
param(
    [string]$pipeName,
    [string]$eventName
)
#variables
$clear=$false
$i=0

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
    #Security and Compliance powershell connection is required to remove the user from Defender/Purview role groups.
    #This is done side by side with L2Remove-DefenderAdmin.ps1 as a method of ensureing removele
    Connect-IPPSSession -ShowBanner:$false
    #Exchagne Online connection is required if the group is a mail enabled security group
    Connect-ExchangeOnline -ShowBanner:$false
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

#get all groups the user is assigned too
try{
    $groups=Get-MgUserMemberGroup -UserId $Id -SecurityEnabledOnly:$false
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

#Get Role Groups in Defender/Purview to validate if the group is present
try{
    $roleGroups=Get-RoleGroup
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

#loop through each group
do{
    $i=0
    foreach($group in $groups){
        #Get the group information in Entra ID
        try{
            $groupCInfo=Get-MgGroup -GroupId $group
            $member=Get-MgGroupMember -GroupId $group
        }   
        catch{
        }
        if($member){
            $i++
        }
        if($groupCInfo.SecurityEnabled -and $null -eq $groupCInfo.Mail -or $groupCInfo.GroupTypes -eq "Unified"){
            #if matching conditions, remove the group member.  We have already verified that it is not AD managed so no errors should happen
            try{
                Remove-MgGroupMemberByRef -GroupId $group -Member $user.Id
            }
            catch{
            }
    #If not AD managed, or a Security Group, or Unified (M365) group, then it needs to be managed in Exchange
        }else{
            #Remove user from the group - this command should remove from both Distribution lists and Mail Enabled Security groups
            try{
                Remove-DistributionGroupMember -Identity $groupCInfo.DisplayName -Member $user.Id
            }
            catch{
            }
        }
    }
    foreach($rGroup in $roleGroups){
        $rMembers=Get-RoleGroupMember -Identity $rGroup.Name
        $rMember=$rMembers|Where-Object{$_.Guid -eq $user.Id}
        if($rMember){
            Remove-RoleGroupMember -Identity $rGroup.Name -Member $user.Id
            $i++
        }
    }
    if($i -gt 0){
        $clear=$false
    }else{
        $clear=$true
    }
}while(!$clear)

Write-Host "Ok, all group memberships are " -NoNewline
Write-Host "removed" -ForegroundColor DarkRed
Pause