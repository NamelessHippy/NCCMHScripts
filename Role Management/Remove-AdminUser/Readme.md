# Remove-AdminUser scripts
Requriements:
- Certificate-Base Authentication
  - Refer to Microsoft Documentation to create the app and certificate
  - Refer to Role Managment Readme for AIP permissions
- PowerShell Modules
  - Microsoft.Graph

Certificate-Based authentication is used for two reason.  First: If you are using Privilaged Idenity Management, it eliminates the need to activate the role to work with Directory Roles.  Second: This script opens two subscripts for each user listed in a separate PowerShell window to run all of them simultaniously.  The separate windows require reauthentication, so certficiate-based authentication is significatly more efficent.
If using the Set-AdminUser script, the same certificate and Entra App can be used for both scripts.  
Do to the nature of this script, it is recomended to keep the script, and certficate, on an internal server that requires authentication to access.  Not on an Administrator's workstation.

This script will ask for the username or email of the account that is you are working with.  You can specify multiple accounts separated by a comma (,), semi-colun (;) or dash (-).  More separators can be added inside the -split property value on Line 16.

The script automatically checks if each of the values entered do not contain an email address and appends the domain to create an email address, since that is needed by the command.
You will need to update the domain on Line 24 to your domain for this to work.

It asks if you want to disable the user account.  This is optional.  This does not toggle their status.  So if you are deactivating an Admin account, but do not know if they are deactivated; selecting this option will not reactivate their account.

