<powershell>
# standalone (workgroup/no-domain) Windows box hosting BOTH the DNS and DHCP roles.
# data source for the NetBox Microsoft DNS and Microsoft DHCP integrations (same host/creds/WinRM).

# install the DHCP role + management tools (this is what the DHCP integration reads over WinRM)
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

# --- DNS role (added alongside DHCP; same box, same .\svc-netbox account, same WinRM listener) ---

# install the DNS role + management tools (this is what the DNS integration reads over WinRM)
Install-WindowsFeature DNS -IncludeManagementTools

# standalone, file-backed primary zones (NO AD - these are plain .dns files, not AD-integrated).
# the DNS integration ingests A/AAAA from forward zones and PTR from reverse zones.
# IPs deliberately land inside the fake DHCP scopes above so forward/reverse data correlates.

# forward primary zone
Add-DnsServerPrimaryZone -Name "lab.example.com" -ZoneFile "lab.example.com.dns"

# A records inside the 192.168.50.0/24 and 10.99.0.0/24 scopes
Add-DnsServerResourceRecordA -ZoneName "lab.example.com" -Name "gw" -IPv4Address "192.168.50.1"
Add-DnsServerResourceRecordA -ZoneName "lab.example.com" -Name "printer" -IPv4Address "192.168.50.50"
Add-DnsServerResourceRecordA -ZoneName "lab.example.com" -Name "web" -IPv4Address "192.168.50.80"
Add-DnsServerResourceRecordA -ZoneName "lab.example.com" -Name "app" -IPv4Address "10.99.0.20"
Add-DnsServerResourceRecordA -ZoneName "lab.example.com" -Name "db" -IPv4Address "10.99.0.30"

# at least one AAAA record
Add-DnsServerResourceRecordAAAA -ZoneName "lab.example.com" -Name "v6host" -IPv6Address "fd00:50::10"

# reverse primary zones matching the seeded scopes, with PTRs lining up to the A records above
Add-DnsServerPrimaryZone -NetworkId "192.168.50.0/24" -ZoneFile "50.168.192.in-addr.arpa.dns"
Add-DnsServerResourceRecordPtr -ZoneName "50.168.192.in-addr.arpa" -Name "1" -PtrDomainName "gw.lab.example.com"
Add-DnsServerResourceRecordPtr -ZoneName "50.168.192.in-addr.arpa" -Name "50" -PtrDomainName "printer.lab.example.com"
Add-DnsServerResourceRecordPtr -ZoneName "50.168.192.in-addr.arpa" -Name "80" -PtrDomainName "web.lab.example.com"

Add-DnsServerPrimaryZone -NetworkId "10.99.0.0/24" -ZoneFile "0.99.10.in-addr.arpa.dns"
Add-DnsServerResourceRecordPtr -ZoneName "0.99.10.in-addr.arpa" -Name "20" -PtrDomainName "app.lab.example.com"
Add-DnsServerResourceRecordPtr -ZoneName "0.99.10.in-addr.arpa" -Name "30" -PtrDomainName "db.lab.example.com"

</powershell>
