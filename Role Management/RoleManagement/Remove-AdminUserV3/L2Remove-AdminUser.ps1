param(
    [string]$pipeName
)

$mod=Get-Module -Name ActiveDirectory -ListAvailable
if($mod){
}else{
    try{
        Add-WindowsCapability -Online -Name "Rsat.ActiveDirectroy.DS-LDS.Tools~~~~0.0.1.0"
    }
    catch{
        Write-Host "Oh no! I had an error. $($_)"
        Pause
        exit
    }
}

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
$users=$json|ConvertFrom-Json

Write-Host "Ok, I will disable $($displayName). In AD"
Write-Host "Even if you have disabled them already, I should not get any errors."
#get AD User object
foreach($user in $users){
    try{
        $adUser=Get-ADUser -Server $server -Identity $userInfo.Mail
    }
    catch{
        Write-Host "Oh no! I had an error. $($_)"
        Pause
        exit
    }
    #Verify User has an On-Prem account
    if($adUser){
        #Disable user on AD
        try{
            Disable-ADAccount -Server $server -Identity $userInfo.Mail
        }
        catch{
        }
    }else{
    }
    $adUser=$null
    Write-Host "Ok.  All accounts are disabled in AD."
}

Pause