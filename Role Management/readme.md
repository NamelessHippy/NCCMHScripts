After creating the app, go to API permissions
Remove default permissions
click Add Permiss
Microsoft APIs>Microsoft Graph
- API Permission Type:
    - Application
- API Permissions:
    - Directory.ReadWrite.All
    - RoleManagement.ReadWrite.Directory
    - User.ReadWrite.All
Generate a self-signed certficiate on the server the scripts will be run on
In the app
Go to Certficates & secrets
Upload the certificatee
You can use the cert name, in the Description column, or Thumbprint in the scripts.

Do to the nature of these scripts, it is recomended to keep the scripts, and any certficates, on an internal server that requires authentication to access. Not on an Administrator's workstation.
