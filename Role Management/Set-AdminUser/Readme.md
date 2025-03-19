#Set-AdminUser scripts

This script is to facilitate quickly assigning Directory Role Groups to Administrators when using Privilaged Identity Management.  
If you are not employing PIM in your Tenant, then this script will not be needed.

Requriements:
- Certificate-Base Authentication
  - Refer to Microsoft Documentation to create the app and certificate
  - API Permissions:
    - Riectory.ReadWrite.All
    - RoleManagement.ReadWrite.Directory
    - User.ReadWrite.All
  - API Permission Type:
    - Application
- PowerShell Modules
  - Microsoft.Graph

Certificate-Based authentication is used for two reason.  First: If you are using Privilaged Idenity Management, it eliminates the need to activate the role to work with Directory Roles.  Second: This script opens two subscripts for each user listed in a separate PowerShell window to run all of them simultaniously.  The separate windows require reauthentication, so certficiate-based authentication is significatly more efficent.
If using the Remove-AdminUser script, the same certificate and Entra App can be used for both scripts.  
Do to the nature of this script, it is recomended to keep the script, and certficate, on an internal server that requires authentication to access.  Not on an Administrator's workstation.

This script will ask for the username or email of the account that is you are working with.  You can specify multiple accounts separated by a comma (,), semi-colun (;) or dash (-).  More separators can be added inside the -split property value on Line 19.

The script automatically checks if each of the values entered do not contain an email address and appends the domain to create an email address, since that is needed by the command. You will need to update the domain on Line 27 to your domain for this to work.

Line 46 and 47 are job roles that Admin fill.  Adjust them for the specific roles in your Tenant.  
If you have a different number of roles, change the max value in the If condition on Line 55 and the conditions in the Switch on Line 58.

This script by default will grab all Directory Role Groups, then it gets the currated CSV of Active Roles.  It will then filter Eligible roles to remove any that are being assigned as Active, to avoid confusion why the role cannot be activated.
A currated list of Eligible roles can be generated and used, example of this is the Data Analysit role.
This script also has an option for Global Admin, which will assign Global Admin as active and all roles as Eligible.  As Global Admin has access to all areas, but may not have full access in all areas.  This gives the global admin the ability to easily activate a role if they need more access.
