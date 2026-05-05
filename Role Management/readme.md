# Role Management App
Create an App Registration (this is required because Azure is not updated for WAM authentication)
Open the app:
Go to Authentication
- Settings tab
    - Add Redirect URI
        - Choose Mobile and desktop applications
        - Add msal://redirect
    - Add recirect URI
        - Choose Mobile and desktop applications
        - Add http://localhost
go to API permissions
Remove default permissions
click Add Permissions
Microsoft APIs>Microsoft Graph
- API Permission Type:
    - Delegated
- API Permissions:
    Directory.ReadWrite.All
    Group.ReadWrite.All
    GroupMember.ReadWrite.All
    RoleAssignmentSchedule.ReadWrite.Directory
    RoleAssignmentSchedule.Remove.Directory
    RoleEligibilitySchedule.ReadWrite.Directory
    RoleEligibilitySchedule.Remove.Directory
- Save Client (Application) ID to a text file (client.txt is the default name in this script)
- Save Tenant ID to a text file (tenant.txt is the default name in this script)

Optional but recommended:
Go to Enterprise Apps and search for the app you just created
- Go to Users and groups
    - Assign administrators authorized to use this app
    - A group can be used for easier management (including by this script)
This restricts login to only the admin accounts assign.

Update all file paths with the locations of the scripts/text files
It is encuraged to use a repository so the same version of this script is accessable to all administrators.
The Tenant ID is the same for all apps in your tenant, so keeping it in a location that is accessable to other apps that use app authentication (either delegated as  this one, or Certificat-based authentication).

Change Log
Version 1.1.0
	- added Named Pipe Stream Server to hand off User Objects to Subscripts
	- Removed Certificate Based Authentication (It created risks on the app)
	- Updated to use WAM Functionality in Graph SDK version 3.24.x or higher
	- This includes pulling Graph authentication context into subscripts without certificate based authentication
	- Changed to use an app with delegated permissions
	- This is needed because RBAC changes are in Azure, which is not updated for WAM functionality
	- Strongly recomended to restrict Authentication on the app to only Administrators allowed to run this script
	- Added Event Handler functionality to control disconnecting from Graph API and Exchange Online only after all subscripts are finished

