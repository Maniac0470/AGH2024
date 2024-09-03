###Basic AD User Check Script###
# get-aduser -filter {name -like "*heck*"} -Properties * | Select Name, Description | Sort-Object
# working through how to make Powershell work

# Define the Organizational Unit (OU)
$ou = "DC=DS,DC=local"

# Get all users in the specified OU
$users = Get-ADUser -Filter * -SearchBase $ou -Property MemberOf

# Loop through each user and display their Name and Groups
$users | ForEach-Object {
    $user = $_
    $groups = $user.MemberOf | ForEach-Object {
        # Get the group name from the Distinguished Name
        (Get-ADGroup $_).Name
    }
    [PSCustomObject]@{
        Name = $user.Name
        Groups = $groups -join "; "
    }
} | Select-Object Name, Groups | Format-Table -AutoSize