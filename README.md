# NCCMHScripts
Scripts by NCCMH IT that are shared with external contacts

All of my scripts have verbose feedback for all actions being taken, with a bit of sass thrown in there.  This is to keep the user informed of what step the script is on if they are not activly monitoring it as it runs.  It also make it so you are not looking at a blank screen when monitoring the script running.

Scripts currently available
- Outlook
  - Get-MailboxRules.ps1 - Retrives Outlook Rules from all mailboxes and compares with the history
- Role Management
  - Remove-AdminUser - Removes all Admin Roles from specfied users
  - Set-AdminUser - Used for PIM roles, sets specified roles for specified users

Scripts planned to be shared
- Copy-Groups - Migrats groups from AD to Entra ID with option to change the group type.
