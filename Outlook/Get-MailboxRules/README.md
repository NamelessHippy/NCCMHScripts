# Get-MailboxRules.ps1 Readme
Requirements:
- Administrator Roles:
  - Global Administrator
    - or -
  - Exchange Administrator
- PowerShell Module:
  - ExchangeOnlineManagement
- Two directories accessable by the computer and user running the script located on
  - Network Share
  - Local Storage
This script will need to be run one time before the initial use to detect new scripts.  This is because it compares the rules found in the current run to the rules in the most recent run.

When you run the script, it will create a CSV with the current date (can be updated to include current time so that the script can be run multiple times in the same day) for all Outlook rules that have an action to Forward or Delete and email.
It should filter duplicates to prevent clutter in the output by having a rule that has both Forward and Delete actions recorded twice.
The script will also output another CSV to a separate directory with a list of any rules that have been added since the last run of the script.

#Possible revisions on your side
If you want this script to be run automatically by Task Scheduler, you will need to setup script based authentication.  Please refer to Microsoft's documentation for setting that up.

It is possible to have the CSVs saved to a SharePoint Document Library or OneDrive
This would add required modules and possible admin roles if not Global Administrator
- Administrator Role:
  - SharePoint Administrator
- Module:
  - SharePointOnline
  - or -
  - Microsoft.Graph
