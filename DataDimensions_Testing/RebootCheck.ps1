<#
.SYNOPSIS
    Retrieves the most recent User32 (user logon/logoff/restart/etc.) event from the System log 
    on one or more remote Windows computers.

.DESCRIPTION
    Uses Get-WinEvent to query the System log for events from the "User32" provider 
    (typically Event ID 1074 = shutdown/restart initiated by user, or related logon events).
    Returns the newest matching event (-MaxEvents 1) per computer.

.PARAMETER ComputerName
    One or more computer names to query. Accepts pipeline input.

.PARAMETER Credential
    Optional PSCredential for remote authentication.

.PARAMETER Path
    Optional path to CSV file containing computer names 
    (looks for columns: Device, ComputerName, Hostname, Name, Server).

.EXAMPLE
    # Query specific servers with credentials
    .\Get-LastUser32Event.ps1 -ComputerName SRV01,SRV02 -Credential $cred

.EXAMPLE
    # Pipe computer names
    "PC-001","PC-007" | .\Get-LastUser32Event.ps1

.EXAMPLE
    # Use CSV file
    .\Get-LastUser32Event.ps1 -Path "C:\ServerList.csv"

.EXAMPLE
    # Show full help
    Get-Help .\Get-LastUser32Event.ps1 -Full

.EXAMPLE
    # Quick usage when run with no parameters
    .\Get-LastUser32Event.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
    [Alias("HostName", "Computer", "Name", "Server")]
    [string[]] $ComputerName,

    [Parameter(Mandatory = $false)]
    [PSCredential] $Credential,

    [Parameter(Mandatory = $false)]
    [string] $Path
)

begin {
    # ──────────────────────────────────────────────────────────────
    # Show friendly usage message when script is run with no arguments
    # ──────────────────────────────────────────────────────────────
    if ($PSBoundParameters.Count -eq 0 -and $MyInvocation.Line -notmatch ' -') {
        Write-Host "`nGet-LastUser32Event - Show most recent User32 event (logon/shutdown/etc.) from remote servers`n" -ForegroundColor Cyan
        
        Write-Host "Quick usage examples:" -ForegroundColor Yellow
        Write-Host "  .\Get-LastUser32Event.ps1 -ComputerName JTVCOSCCM001,JTVCOSCCM002       " -ForegroundColor White
        Write-Host "  .\Get-LastUser32Event.ps1 -Path C:\servers.csv                           " -ForegroundColor White
        Write-Host "  'SRV01','SRV02' | .\Get-LastUser32Event.ps1                             " -ForegroundColor White
        Write-Host "  Get-Help .\Get-LastUser32Event.ps1 -Full                                 " -ForegroundColor White
        Write-Host "`nFor detailed help and parameters, run:" -ForegroundColor Gray
        Write-Host "  Get-Help .\Get-LastUser32Event.ps1 -Full`n" -ForegroundColor Gray
        
        return
    }

    $allComputers = [System.Collections.Generic.List[string]]::new()

    # ── Collect from CSV if provided ─────────────────────────────────
    if ($Path -and (Test-Path $Path -PathType Leaf)) {
        Write-Verbose "Reading computer list from: $Path"
        $csv = Import-Csv -Path $Path -ErrorAction SilentlyContinue
        
        $possibleColumns = @('Device', 'ComputerName', 'Hostname', 'Name', 'Server')
        $foundColumn = $possibleColumns | Where-Object { $csv[0].PSObject.Properties.Name -contains $_ } | Select-Object -First 1
        
        if ($foundColumn) {
            $allComputers.AddRange(($csv | Select-Object -ExpandProperty $foundColumn -ErrorAction SilentlyContinue))
        }
        else {
            Write-Warning "CSV lacks expected column (tried: $($possibleColumns -join ', '))"
        }
    }

    # ── Add computers from parameter or pipeline ─────────────────────
    if ($ComputerName) {
        $allComputers.AddRange($ComputerName)
    }

    # Clean: remove duplicates, empty entries, trim whitespace
    $allComputers = $allComputers |
        Where-Object { $_ -and $_.Trim() } |
        Sort-Object -Unique

    if ($allComputers.Count -eq 0) {
        Write-Error "No valid computer names were provided."
        return
    }

    Write-Verbose "Will query $($allComputers.Count) computer(s)"
}

process {
    foreach ($computer in $allComputers) {
        Write-Verbose "Querying: $computer"

        try {
            $params = @{
                ComputerName   = $computer
                FilterHashtable = @{
                    LogName      = 'System'
                    ProviderName = 'User32'
                }
                MaxEvents      = 1
                ErrorAction    = 'Stop'
            }

            if ($Credential) {
                $params.Credential = $Credential
            }

            $event = Get-WinEvent @params

            if ($event) {
                [PSCustomObject]@{
                    ComputerName = $computer
                    TimeCreated  = $event.TimeCreated
                    Id           = $event.Id
                    Message      = $event.Message -replace '\s+', ' '  # clean up whitespace
                    Provider     = $event.ProviderName
                    Level        = $event.LevelDisplayName
                } | Format-List
            }
            else {
                Write-Host "No User32 events found on $computer" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Warning "Failed to query $computer → $($_.Exception.Message)"
        }

        # Optional: small separator between computers
        Write-Host "" -NoNewline
    }
}

end {
    Write-Verbose "Query complete."
}