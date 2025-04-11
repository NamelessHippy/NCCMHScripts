# Remove-SuspiciousMeeting
Requirements:
- Administrator Roles
  - Any
- PowerShell Module:
  - Microsoft.Graph

This script uses certificate based authentication, and is intended to be used if there is a meeting that is suspected of having a malichous attachment or link.
When you run this, it will ask for the subject of the meeting and one of the user's that the meeting was sent to.  It is writen assuming that the subject will be unique.
It will then get the meeting from that user's calendar and a list of all atendees.  It will then itterate through all emails from the list of invited attendees and remove the meeting from their calendar.  

# Certificate-Based authentication
Please refer to Microsoft's documentation for configuring certificate-based authentication

- API Permission Type:
  - Application
- API Permissions:
  - Calendars.ReadWrite
  - User.Read.All
