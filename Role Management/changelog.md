
#Change Log
Version 1.1.0
   -added Named Pipe Stream Server to hand off User Objects to Subscripts
   -Removed Certificate Based Authentication (It created risks on the app)
   -Updated to use WAM Functionality in Graph SDK version 3.24.x or higher
   -This includes pulling Graph authentication context into subscripts without certificate based authentication
   -Changed to use an app with delegated permissions
   -This is needed because RBAC changes are in Azure, which is not updated for WAM functionality
   -Strongly recomended to restrict Authentication on the app to only Administrators allowed to run this script
   -Added Event Handler functionality to control disconnecting from Graph API and Exchange Online only after all subscripts are finished
