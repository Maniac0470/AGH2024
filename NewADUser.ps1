# Prompt for user details
$SamAccountName = Read-Host "Enter the SamAccountName (username)"
$FirstName = Read-Host "Enter the First Name"
$LastName = Read-Host "Enter the Last Name"
$Description = Read-Host "Enter the Description"
$UserPrincipalName = Read-Host "Enter the UserPrincipalName (e.g., username@DS.local)"
$PlainTextPassword = Read-Host "Enter the Password" -AsSecureString

# Convert the SecureString password back to plaintext for use
$SecurePassword = $PlainTextPassword

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
