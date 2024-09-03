param (
    [string]$SamAccountName,
    [string]$FirstName,
    [string]$LastName,
    [string]$Description,
    [string]$UserPrincipalName,
    [string]$PlainTextPassword
)

# Convert the plaintext password to a secure string
$SecurePassword = ConvertTo-SecureString $PlainTextPassword -AsPlainText -Force

# Construct the distinguished name for the new user
$DistinguishedName = "CN=$FirstName $LastName,OU=Users,DC=DS,DC=local"

# Create the new AD user
New-ADUser `
    -SamAccountName $SamAccountName `
    -GivenName $FirstName `
    -Surname $LastName `
    -Name "$FirstName $LastName" `
    -UserPrincipalName $UserPrincipalName `
    -Description $Description `
    -Path $DistinguishedName `
    -AccountPassword $SecurePassword `
    -Enabled $true `
    -PasswordNeverExpires $false `
    -ChangePasswordAtLogon $false

# Output success message
Write-Host "User $SamAccountName has been created successfully."