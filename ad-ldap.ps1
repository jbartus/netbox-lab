<powershell>
$script = @"
Start-Sleep -Seconds 30
Import-Module ActiveDirectory
net user administrator "DomainAdminPassword1"

`$bindPassword = ConvertTo-SecureString "LdapSearch1" -AsPlainText -Force

New-ADUser ``
    -Name "netboxservice" ``
    -SamAccountName "netboxservice" ``
    -UserPrincipalName "netboxservice@corp.example.local" ``
    -EmailAddress "netboxservice@corp.example.local" ``
    -GivenName "Netbox" ``
    -Surname "Service" ``
    -AccountPassword `$bindPassword ``
    -Enabled `$true ``

`$userPassword = ConvertTo-SecureString "UserPass1" -AsPlainText -Force

New-ADUser ``
    -Name "exampleuser" ``
    -SamAccountName "exampleuser" ``
    -UserPrincipalName "exampleuser@corp.example.local" ``
    -EmailAddress "exampleuser@corp.example.local" ``
    -GivenName "Example" ``
    -Surname "User" ``
    -AccountPassword `$userPassword ``
    -Enabled `$true ``

New-ADUser ``
    -Name "exampleadmin" ``
    -SamAccountName "exampleadmin" ``
    -UserPrincipalName "exampleadmin@corp.example.local" ``
    -EmailAddress "exampleadmin@corp.example.local" ``
    -GivenName "Example" ``
    -Surname "Admin" ``
    -AccountPassword `$userPassword ``
    -Enabled `$true ``

New-ADUser ``
    -Name "examplesuperuser" ``
    -SamAccountName "examplesuperuser" ``
    -UserPrincipalName "examplesuperuser@corp.example.local" ``
    -EmailAddress "examplesuperuser@corp.example.local" ``
    -GivenName "Example" ``
    -Surname "Superuser" ``
    -AccountPassword `$userPassword ``
    -Enabled `$true ``

New-ADGroup ``
    -Name "Netbox Users" ``
    -SamAccountName "NetboxUsers" ``
    -GroupCategory Security ``
    -GroupScope Global ``
    -Path "CN=Users,DC=corp,DC=example,DC=local"

New-ADGroup ``
    -Name "Netbox Admins" ``
    -SamAccountName "NetboxAdmins" ``
    -GroupCategory Security ``
    -GroupScope Global ``
    -Path "CN=Users,DC=corp,DC=example,DC=local"

New-ADGroup ``
    -Name "Netbox Superusers" ``
    -SamAccountName "NetboxSuperusers" ``
    -GroupCategory Security ``
    -GroupScope Global ``
    -Path "CN=Users,DC=corp,DC=example,DC=local"

Add-ADGroupMember -Identity "NetboxUsers" -Members "exampleuser", "exampleadmin", "examplesuperuser"
Add-ADGroupMember -Identity "NetboxAdmins" -Members "exampleadmin"
Add-ADGroupMember -Identity "NetboxSuperusers" -Members "examplesuperuser"

"@

$script | Out-File -FilePath "C:\create-users.ps1" -Encoding UTF8

Register-ScheduledTask -TaskName "CreateADUsers" `
  -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Action (New-ScheduledTaskAction `
  -Execute "PowerShell.exe" `
  -Argument "-ExecutionPolicy Bypass -File C:\create-users.ps1") `
  -RunLevel Highest -User "SYSTEM"

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSForest `
  -DomainName "corp.example.local" `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "AReallyStrongPassword!" -AsPlainText -Force) `
  -Force

</powershell>
