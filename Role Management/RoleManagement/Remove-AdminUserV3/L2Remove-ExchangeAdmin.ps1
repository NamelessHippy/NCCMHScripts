#Paramaters for running the subscript.
param(
    [string]$pipeName,
    [string]$eventName
)
#variables
$clear=$false
$memberships=$null
Import-Module \\scripts-srvr\Scripts\PowerShell\Custom_Modules\Certificates\CertificateSecurity.psm1 -Force
Import-Module \\scripts-srvr\Scripts\PowerShell\Custom_Modules\Logging\Logging.psm1 -Force
Import-Module \\scripts-srvr\Scripts\PowerShell\Custom_Modules\Module_Management\Modules.psm1 -Force

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

#connect to Exchange Online
try{
    Connect-ExchangeOnline -ShowBanner:$false
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Now I will remove all Admin Roles for $($user.DisplayName) in Defender and Purview."
Write-Host "Ok, here we go. with the Removal."
Write-Host "Wait, there are multiples of me?" -ForegroundColor Blue
Write-Host "Ok, this is sureal."

Write-Host "First I will get all of the Role Groups in Defender/Purivew."
try{
    $roles=Get-RoleGroup
}
catch{
    Write-Host "Critical error terminating all processes"
    $_
    exit
}

Write-Host "Now to see if $($user.DisplayName) is in any of the Role Groups."
do{
    $memberships=0
    foreach($role in $roles){
        Write-Host "Getting Membership of $($role.DisplayName)"
        try{
            $member=Get-RoleGroupMember -Identity $role.DisplayName|Where-Object{$_.Name -eq $user.DisplayName}
        }
        catch{
        }
        if($member){
            $memberships++
            Write-Host "I will remove $($user.DisplayName) from $($role.DisplayName)"
            try{
                Remove-RoleGroupMember -Identity $role.Name -Member $user.DisplayName -Confirm:$false
            }
            catch{
            }
        }else{
            Write-Host "Oh, $($user.DisplayName) was not in $($role.DisplayName)"
        }
    }
    if($memberships -gt 0){
        $clear=$false
    }else{
        $clear=$true
    }
}while(!$clear)

Disconnect-ExchangeOnline -Confirm:$false

Write-Host "$($displayName) Has been removed from any Exchange Online Roles"
Pause