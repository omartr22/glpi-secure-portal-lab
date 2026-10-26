#Requires -RunAsAdministrator
<#
  Aegis Corp - Phase 2
  Creates the OU structure, GLPI security groups, test users and the LDAP bind account.
  Run on dc01 AFTER the domain ad.aegis-corp.lab has been created.
  Passwords are asked at runtime and are never stored in this repository.
#>

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName      # DC=ad,DC=aegis-corp,DC=lab
$upnSuffix = (Get-ADDomain).DNSRoot               # ad.aegis-corp.lab
$root = "OU=Aegis,$domainDN"

# --- Organizational Units ---------------------------------------------------
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Aegis'" -SearchBase $domainDN -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name "Aegis" -Path $domainDN -ProtectedFromAccidentalDeletion $true
}
foreach ($ou in "Users", "Groups", "Computers", "Service Accounts") {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $root -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $ou -Path $root -ProtectedFromAccidentalDeletion $true
    }
}

# --- Security groups (mapped to GLPI profiles in Phase 6) ----------------------
$groups = @{
    "GLPI-Admins"  = "GLPI Super-Admin profile"
    "GLPI-Support" = "GLPI Technician profile"
    "GLPI-Hotline" = "GLPI Hotliner profile"
    "GLPI-Users"   = "GLPI Self-Service profile"
}
foreach ($g in $groups.Keys) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'")) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security `
            -Path "OU=Groups,$root" -Description $groups[$g]
    }
}

# --- Test users -----------------------------------------------------------------
$userPassword = Read-Host -AsSecureString "Password for the test users"
$users = @(
    @{ Sam = "agharbi";     Given = "Amine"; Sur = "Gharbi";     Group = "GLPI-Admins"  },
    @{ Sam = "sbenyoussef"; Given = "Salma"; Sur = "Ben Youssef"; Group = "GLPI-Support" },
    @{ Sam = "ymejri";      Given = "Yassine"; Sur = "Mejri";    Group = "GLPI-Hotline" },
    @{ Sam = "rhamdi";      Given = "Rania"; Sur = "Hamdi";      Group = "GLPI-Users"   }
)
foreach ($u in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'")) {
        New-ADUser -Name "$($u.Given) $($u.Sur)" `
            -GivenName $u.Given -Surname $u.Sur `
            -SamAccountName $u.Sam `
            -UserPrincipalName "$($u.Sam)@$upnSuffix" `
            -EmailAddress "$($u.Sam)@aegis-corp.lab" `
            -Path "OU=Users,$root" `
            -AccountPassword $userPassword `
            -Enabled $true `
            -PasswordNeverExpires $true      # lab convenience only
    }
    Add-ADGroupMember -Identity $u.Group -Members $u.Sam
}

# --- LDAP bind account for GLPI (least privilege: plain domain user) -----------
$svcPassword = Read-Host -AsSecureString "Password for svc-glpi-ldap (different from the test users)"
if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc-glpi-ldap'")) {
    New-ADUser -Name "svc-glpi-ldap" `
        -SamAccountName "svc-glpi-ldap" `
        -UserPrincipalName "svc-glpi-ldap@$upnSuffix" `
        -Description "GLPI LDAP bind account (read only)" `
        -Path "OU=Service Accounts,$root" `
        -AccountPassword $svcPassword `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -CannotChangePassword $true
}

Write-Host "`nDone. Users per group:" -ForegroundColor Green
foreach ($g in $groups.Keys) {
    Write-Host " $g :" ((Get-ADGroupMember $g | Select-Object -ExpandProperty SamAccountName) -join ", ")
}
