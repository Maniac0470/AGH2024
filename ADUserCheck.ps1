###Basic AD User Check Script###
get-aduser -filter {name -like "*heck*"} -Properties * | Select Name, Description | Sort-Object