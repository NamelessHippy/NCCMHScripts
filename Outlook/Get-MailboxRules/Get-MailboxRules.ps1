#Requires -Modules ExchangeOnlineManagement
#Requires -RunAsAdministrator

#Get-Mailboxrules script is meant to collect all mailbox rules that contain an action to forward or delete a rule.
#It will sort out the rules so that if there is a to Forward then Delete an email, it should only show once.
#The script assumes you are using Exchange Online.  It is not configured for, nor confirmed to work for On-Prem Exchange Servers

<#Variables
$rules is an array used to collect relivent information for the CSV files
$date is used for creating the unique file name of the CSV
$riskyPath is used for the CSV for any new rules since the script was last run
$csvPath is used to get the most recent CSV from this script and to create the new CSV output from this script.
#>
#replace "\\replace\with\our\path\" with the path you are using.
$rules=New-Object System.Collections.ArrayList
$date=Get-Date -Format "ddMMyy"
$riskyPath="\\replace\with\our\path\RiskyRules\RiskyRules$($date).csv"
$csvPath="\\replace\with\our\path\MailBoxRules\"

#Verify you have the required role in Entra ID to run the script.
Write-Host "Hello, I am the MailBox Rule Investigation script."
Write-Host "I will get a list of all Mailbox rules that automatically delete or forward a message and save them in a CSV so you can compare them to the history."
Write-Host "You will need either Global Administrator or Exchange Administrator to run this script."
while(!$confirm){
    #Initialize $confirm as false, then also ensure $confirm is false until "y" is entered as a response.
    $confirm=$false
    Write-Host "Do you have Global Administrator or Exchange Administrator?"
    Write-Host "y" -NoNewline -ForegroundColor DarkYellow
    #Change all input text to lowercase letters.
    $response=(Read-Host "/n").ToLower()
    #Check if the input was blank and set "y" as the default.
    if([string]::IsNullOrWhiteSpace($response)){
        $response="y"
    }else{
        #if any text was entered get only the first letter of what was entered.
        #makes it so the input can work if the user enters "yes" or "Yes", or even "Yeah" for the response.
        $response=$response.Substring(0,1)
    }
    #Switch to evaluate the response after it has been validated, then take the action.
    switch($response){
        "y"{
            #Set $confirm as true to exit the loop.
            Write-Host "Great! Then we can continue"
            $confirm=$true
        }
        "n"{
            #Give the user the chance to assign or activate one of the required roles then restarts the loop.
            Write-Host "Please go and activate Exchange Administrator or Gloabal Administrator to continue."
            Write-Host "Let me know when you are ready to continue."
            Pause
        }
        default{
            #If the value entered does not start with y or n it will restart the loop.
            Write-Host "Please select y or n."
        }
    }
}
$confirm=$null,$response=$null


Write-Host "Now I will get the paths for the CSV's."
#get the most recent CSV to compare to the current rules
$csvPathOld="$($csvPath)$((Get-ChildItem -Path $csvPath|Sort-Object -Property LastWriteTime -Descending|Select-Object -First 1).Name)"
#Set the path that will be used for the Output CSV.
$csvPathNew="$($csvPath)MailboxRules$($date).csv"

Write-Host "Please loginto Exchange Online for me."
Connect-ExchangeOnline

#Get all mailboxes for users in the organization.
Write-Host "Now I will get all Mailboxes."
$mailBoxes=Get-Mailbox -ResultSize unlimited

#Loop through all mailboxes to get the rules that contation a risky action.
foreach($mailBox in $mailBoxes){
    Write-Host "I will get any rule to Delete or Forward messages in $($mailBox.name)'s Mailbox."
    $outRules=Get-InboxRule -MailBox $mailBox.Alias|Where-Object{$_.DeleteMessage -or $_.ForwardTo}
    #Loop will be skipped if there was not rules that contained a risky action.
    foreach($rule in $outRules){
        Write-Host "I will add $($rule.Name) to the list for the CSV."
        #Create an object for the mailbox rule that was found.  This is to limit data in the CSV to only what is relivent.
        $output=[PSCustomObject]@{
            Mailbox=$mailBox.name
            Alias=$mailBox.Alias
            RuleName=$rule.Name
            RuleIdentity=$rule.RuleIdentity
            IsError=$rule.InError
            Delete=$rule.DeleteMessage
            Forward=$rule.ForwardTo
        }
        #Add the object to the $rules array initialized at the start of the script
        [void]$rules.Add($output)
    }
}
Disconnect-ExchangeOnline
$mailBoxes=$null
Write-Host "Now to export the CSV, for future referance."
#create the new CSV.
$rules|Export-Csv -Path $csvPathNew

Write-Host "Next I will get the old CSV."
#bring the CSV from the last run into the memory.
$csvOld=Import-Csv -Path $csvPathOld
Write-Host "Oh, this is from a previous run.  I hope my admin fixed that System.Object issue."

Write-Host "Now I will compare them for you."
#Compare the rules by the unique idenfier in Exchange, then show only new rules.
$comparison=Compare-Object -ReferenceObject $rules -DifferenceObject $csvOld -PassThru -ExcludeDifferent:$false -Property RuleIdentity

Write-Host "Here are the Rules from the Previous run."
#Display the Old CSV in a new window that you can interact with.
$csvOld|Out-GridView -Title "Previous Rules"
Write-Host "Here is the CSV from this run."
#Open the most recent CSV to allow the user to verify it is safe.
Invoke-Item -Path $csvPathNew
Write-Host "If this Rule is safe, please update the CSV that you have verified it is safe."
#If $comparison variable is empty it will not try to create any outputs for new risky rules.
if($comparison){
    Write-Host "Now I will show any Risky Rules that were added since the last time I was ran."
    #Open a new window with any new risky rules.
    $comparison|Where-Object{$_.sideindicator -eq "<="}|Out-GridView -Title "New Rules"
    Write-Host "I will go ahead and save this comparison to $($riskyPath)."
    #Save the new risky rule to a unque file path for referance later if needed.
    $comparison|Where-Object{$_.sideindicator -eq "<="}|Export-Csv -Path $riskyPath   
}else{
    Write-Host "Oh, I didn't see any new Rules."
    Write-Host "If I was ran because of an Alert about a new Risky Rule, please review the New and Previous CSV's manually to find it."
    Write-Host "Also, please notify the rest of the Team so someone can look into why I didn't detect any new scripts."
}

Write-Host "You can review the latest CSV at $($csvPathNew)."
Write-Host "Thank you, have a nice day."
#pauses the script to allow you to review the outputs.
Pause