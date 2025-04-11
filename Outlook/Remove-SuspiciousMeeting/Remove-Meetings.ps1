$subject=$null
$user=$null
Write-Host "Hello, I am the-"
Write-Host "Oh, we need to remove a Suspicious Meeting."

Write-Host "Tell me the subject of the meeting."
Write-Host "Just copy and paste it from Defender, or the Ticket from the reported phish."
while(!$subject){
$subject=Read-Host "Subject"
}

Write-Host "Ok, now I just need the email address of one of the users."
Write-Host "Just one mind you, I will get the rest my self."
while(!$user){
    $user=Read-Host "User"
    if($user){
        if($user -match "@"){
            Write-Host "Great, moving on."
        }else{
            $user="$($user)@domain.com"
            Write-Host "Ok, that wasn't an email, but I fixed it."
        }
    }
}

Connect-MgGraph -CertificateSubjectName "CN=<certificatName>" -ClientId "<app id>" -TenantId "<tenant id>" -NoWelcome

Write-Host "Ok, I am connected to the Graph.  Now to get the meeting."

$meeting=Get-MgUserEvent -UserId $userId -Filter "subject eq '$($subject)'" -Property "subject,attendees"

Write-Host "I have it.  Now I will go through everyone that was invited and remove the meeting from their calendars."

foreach($attendee in $meeting.Attendees){
    Write-Host "I need to get the email address for $($attendee.EmailAddress.Name) first."
    $address=$attendee.EmailAddress.Address
    Write-Host "Now to check if they are actually North Country emails."
    if($address -match "@domain\.com$"){
        Write-Host "Oh, this one is.  I will get the User ID"
        $userId=(Get-MgUser -UserId $address).Id
        Write-Host "Now to get the Meeting ID"
        $meetingId=(Get-MgUserEvent -UserId $userId -Filter "subject eq '$($subject)'").Id
        if($meetingId){
            Write-Host "Now to remove the meeting from their calendar."
            Write-Host "Ok! It's do or die."
            Remove-MgUserEvent -UserId $userId -EventId $meetingId
        }else{
            Write-Host "Oh, $($attendee.EmailAddress.Name) is not a North Country email."
            Write-Host "I'm glad I check, that would be kind of awkward if I just went to some other organization's system and started deleting things."
            Write-Host "It could be fun though."
        }
    }
    $address=$null,$userId=$null,$meetingId=$null
    Write-Host "Finished with $($attendee.EmailAddress.Name)"
}

Disconnect-MgGraph|Out-Null
$subject=$null,$user=$null,$meeting=$null
Write-Host "I have finished removing the suspected phishing meeting from all attendies."
Write-Host "Don't be afraid to run me again if there is another suspicious meeting invite that goes around."
Pause