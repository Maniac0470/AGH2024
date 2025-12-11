# Check-AutomaticUpdatesGPO.ps1
# Shows current "Autoupdate" setting after gpupdate
# Output example:  SERVER01 : Autoupdate SCCM = Disabled

$HostsFile = "hosts.txt"

if (-not (Test-Path $HostsFile)) {
    Write-Warning "hosts.txt not found in current directory!"
    exit 1
}

Get-Content $HostsFile | ForEach-Object {
    $Computer = $_.Trim()
    if ($Computer -eq "") { return }

    Write-Host "$Computer : " -NoNewline -ForegroundColor Cyan

    try {
        $Result = Invoke-Command -ComputerName $Computer -ScriptBlock {
            gpupdate /r | findstr /i /c:"Autoupdate SCCM"
        } -ErrorAction Stop

        if ($Result) {
            Write-Host $Result.Trim() -ForegroundColor Green
        }
        else {
            Write-Host "No Autoupdate SCCM line found (maybe delayed/not applied yet)" -ForegroundColor Yellow
        }
    }
    catch {
        if ($_.Exception.Message -like "*WinRM*") {
            Write-Host "WinRM/Ping failed or access denied" -ForegroundColor Red
        }
        else {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}