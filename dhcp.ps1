<powershell>
# standalone (workgroup) Windows DHCP server for the NetBox Microsoft DHCP integration.
# no domain, so everything runs inline in this one user_data pass - no reboot, no scheduled task.

# install the DHCP role + management tools (this is what the integration reads over WinRM)
Install-WindowsFeature DHCP -IncludeManagementTools

# local service account the integration authenticates as (.\svc-netbox over WinRM/NTLM)
$svcPassword = ConvertTo-SecureString "NetBoxDHCP123!" -AsPlainText -Force
New-LocalUser -Name "svc-netbox" -Password $svcPassword -PasswordNeverExpires -AccountNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member "svc-netbox"

# enable WinRM; leave AllowUnencrypted = false (NTLM gives message-level encryption over 5985)
winrm quickconfig -quiet
Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true
Enable-PSRemoting -Force
New-NetFirewallRule -DisplayName "WinRM HTTP 5985" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow

# seed some read-only DHCP config on fake ranges (unrelated to the VPC CIDR).
# this will never serve leases (the VPC drops broadcast) - the integration only reads config.

# scope 1 - 192.168.50.0/24 with an exclusion + a reservation
Add-DhcpServerv4Scope -Name "lab-office" -StartRange 192.168.50.10 -EndRange 192.168.50.200 -SubnetMask 255.255.255.0 -State Active
Add-DhcpServerv4ExclusionRange -ScopeId 192.168.50.0 -StartRange 192.168.50.10 -EndRange 192.168.50.20
Add-DhcpServerv4Reservation -ScopeId 192.168.50.0 -IPAddress 192.168.50.50 -ClientId "00-11-22-33-44-55" -Name "lab-printer"
Set-DhcpServerv4OptionValue -ScopeId 192.168.50.0 -Router 192.168.50.1 -DnsServer 192.168.50.1

# scope 2 - 10.99.0.0/24
Add-DhcpServerv4Scope -Name "lab-lab" -StartRange 10.99.0.10 -EndRange 10.99.0.200 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 10.99.0.0 -Router 10.99.0.1 -DnsServer 8.8.8.8, 8.8.4.4

# scope 3 - 172.31.200.0/24
Add-DhcpServerv4Scope -Name "lab-voice" -StartRange 172.31.200.10 -EndRange 172.31.200.100 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 172.31.200.0 -Router 172.31.200.1 -DnsServer 172.31.200.1

</powershell>
