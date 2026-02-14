<#
.SYNOPSIS
    Collects non-Microsoft scheduled tasks from remote Windows computers 
    that are not running as SYSTEM and are not disabled.

.DESCRIPTION
    Queries one or more remote computers for scheduled tasks that appear 
    to be user- or admin-created (excludes Microsoft folder tasks, SYSTEM,
    disabled tasks, and User_Feed_Synchronization*).

    Shows results grouped by host in console-friendly format.

.PARAMETER ComputerName
    One or more computer names / hostnames to query. Accepts pipeline input.

.PARAMETER Credential
    Optional PSCredential object for remote authentication.

.PARAMETER Path
    Optional path to a CSV file containing computer names 
    (looks for columns: Device, ComputerName, or Hostname).

.EXAMPLE
    # Query two servers using stored credentials
    .\Get-CustomScheduledTasks.ps1 -ComputerName SRV01,SRV02 -Credential $cred

.EXAMPLE
    # Pipe computer names from anywhere
    "PC-001","PC-007" | .\Get-CustomScheduledTasks.ps1

.EXAMPLE
    # Use a CSV file (column "Device" or "ComputerName")
    .\Get-CustomScheduledTasks.ps1 -Path "C:\ServerList.csv"

.EXAMPLE
    # Show this help
    Get-Help .\Get-CustomScheduledTasks.ps1 -Full
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
    [Alias("HostName", "Computer", "Name")]
    [string[]] $ComputerName,

    [Parameter(Mandatory = $false)]
    [PSCredential] $Credential,

    [Parameter(Mandatory = $false)]
    [string] $Path
)

begin {
    # ──────────────────────────────────────────────────────────────
    # Show usage/help when called with NO parameters at all
    # This mimics common PowerShell script behavior
    # ──────────────────────────────────────────────────────────────
    if ($PSBoundParameters.Count -eq 0 -and $MyInvocation.Line -notmatch ' -') {
        Write-Host "`nGet-CustomScheduledTasks - Collect custom scheduled tasks from remote computers`n" -ForegroundColor Cyan
        
        Write-Host "Usage examples:" -ForegroundColor Yellow
        Write-Host "  .\Get-CustomScheduledTasks.ps1 -ComputerName SRV01,SRV02                  " -ForegroundColor White
        Write-Host "  .\Get-CustomScheduledTasks.ps1 -Path C:\servers.csv                      " -ForegroundColor White
        Write-Host "  'PC-001','PC-007' | .\Get-CustomScheduledTasks.ps1                      " -ForegroundColor White
        Write-Host "  Get-Help .\Get-CustomScheduledTasks.ps1 -Full                            " -ForegroundColor White
        Write-Host "  Get-Help .\Get-CustomScheduledTasks.ps1 -Examples                        " -ForegroundColor White
        Write-Host "`nFor full parameter details and more examples, run:" -ForegroundColor Gray
        Write-Host "  Get-Help .\Get-CustomScheduledTasks.ps1 -Full`n" -ForegroundColor Gray
        
        # Exit gracefully instead of proceeding with empty input
        return
    }

    $allComputers = [System.Collections.Generic.List[string]]::new()

    # Collect from CSV if provided
    if ($Path -and (Test-Path $Path -PathType Leaf)) {
        Write-Verbose "Reading computers from CSV: $Path"
        $csv = Import-Csv -Path $Path -ErrorAction SilentlyContinue
        
        $possibleColumns = @('Device', 'ComputerName', 'Hostname', 'Name')
        $foundColumn = $possibleColumns | Where-Object { $csv[0].PSObject.Properties.Name -contains $_ } | Select-Object -First 1
        
        if ($foundColumn) {
            $allComputers.AddRange(($csv | Select-Object -ExpandProperty $foundColumn -ErrorAction SilentlyContinue))
        }
        else {
            Write-Warning "CSV has no recognizable computer column (tried: $($possibleColumns -join ', '))"
        }
    }

    # Add from parameter / pipeline
    if ($ComputerName) {
        $allComputers.AddRange($ComputerName)
    }

    # Clean up: remove duplicates, trim, skip empty
    $allComputers = $allComputers |
        Where-Object { $_ -and $_.Trim() } |
        Sort-Object -Unique

    if ($allComputers.Count -eq 0) {
        Write-Error "No valid computer names provided (via parameter, pipeline, or CSV)."
        return
    }

    Write-Verbose "Querying $($allComputers.Count) computer(s)"
    
    $results = [System.Collections.Generic.List[PSObject]]::new()
}

process {
    foreach ($computer in $allComputers) {
        Write-Verbose "→ $computer"

        try {
            $invokeParams = @{
                ComputerName = $computer
                ScriptBlock  = {
                    Get-ScheduledTask |
                        Where-Object {
                            $_.TaskPath -notlike '\Microsoft*' -and
                            $_.Principal.UserId -notlike 'S-1-5-18' -and
                            $_.Principal.UserId -notlike '*User_Feed_Synchronization*' -and
                            $_.State -ne 'Disabled'
                        }
                }
                ErrorAction  = 'Stop'
            }
            if ($Credential) { $invokeParams.Credential = $Credential }

            $tasks = Invoke-Command @invokeParams

            foreach ($task in $tasks) {
                $actionStrings = $task.Actions | ForEach-Object {
                    switch ($_.CimClass.CimClassName) {
                        'MSFT_TaskExecAction'       { "$($_.Execute) $($_.Arguments)".Trim() }
                        'MSFT_TaskEmailAction'      { "Email: To=$($_.To); Subject=$($_.Subject)".Trim() }
                        'MSFT_TaskComHandlerAction' { "COM: ClassId=$($_.ClassId)".Trim() }
                        default                     { "Unknown: $($_.CimClass.CimClassName)" }
                    }
                }

                $actions = if ($actionStrings) { $actionStrings -join '; ' } else { "<No actions>" }

                $null = $results.Add([PSCustomObject]@{
                    Host        = $computer
                    TaskName    = $task.TaskName
                    TaskPath    = $task.TaskPath
                    RunAs       = $task.Principal.UserId
                    Actions     = $actions
                    Description = $task.Description
                    State       = $task.State
                })
            }
        }
        catch {
            Write-Warning "Failed to connect to $computer : $($_.Exception.Message)"
        }
    }
}

end {
    if ($results.Count -eq 0) {
        Write-Host "No matching custom scheduled tasks found." -ForegroundColor DarkGray
        return
    }

    $results | Group-Object Host | ForEach-Object {
        Write-Host "`nHost: $($_.Name)" -ForegroundColor Cyan
        $_.Group |
            Select-Object TaskName, RunAs, Actions, Description, State |
            Format-Table -AutoSize
    }

    Write-Host "`nTotal custom tasks found: $($results.Count)" -ForegroundColor Green
}