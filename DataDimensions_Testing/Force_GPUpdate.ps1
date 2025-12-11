# Force-GPUpdate.ps1
# Usage: .\Force-GPUpdate.ps1
# Requires: hosts.txt in the same folder (one hostname or FQDN per line)

$HostsFile = "hosts.txt"

if (-not (Test-Path $HostsFile)) {
    Write-Warning "hosts.txt not found in current directory!"
    exit 1
}

Get-Content $HostsFile | ForEach-Object {
    $Computer = $_.Trim()
    if ($Computer -eq "") { return }

    Write-Host "Processing $Computer ..." -ForegroundColor Cyan

    try {
        # Test connectivity first
        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            Write-Warning "$Computer  -> Offline or unreachable"
            return
        }

        # Run gpupdate /force remotely
        Invoke-Command -ComputerName $Computer -ScriptBlock { gpupdate /force } -ErrorAction Stop |
            ForEach-Object { Write-Host "  $_" }

        Write-Host "$Computer  -> gpupdate /force completed" -ForegroundColor Green
    }
    catch {
        Write-Warning "$Computer  -> Failed: $($_.Exception.Message)"
    }

    Write-Host ""
}
Write-Host "All done!" -ForegroundColor Yellow