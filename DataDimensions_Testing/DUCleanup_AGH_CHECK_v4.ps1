#-------------- Configuration ------------------------------------------
$FolderConfigs = @(
    @{ Path = 'C:\TestDelete\Folder1';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder2';  DaysOld = 90 },
    @{ Path = 'C:\TestDelete\Folder3';  DaysOld = 90 },
    @{ Path = 'C:\TestDelete\Folder4';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder5';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder6';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder7';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder8';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder9';  DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder10'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder11'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder12'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder13'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder14'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder15'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder16'; DaysOld = 60 },
    @{ Path = 'C:\TestDelete\Folder17'; DaysOld = 60 }
)
#--------------------------------------------------------------------------
$MaxThreads = 12  # Adjust if needed; allows high parallelism for 17 folders

# Create runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()
$Jobs = @()

Measure-Command {
    foreach ($Config in $FolderConfigs) {
        $CutoffDate = (Get-Date).AddDays(-$Config.DaysOld)

        $PowerShell = [powershell]::Create()
        $PowerShell.RunspacePool = $RunspacePool
        [void]$PowerShell.AddScript({
            param($Path, $CutoffDate)
            Get-ChildItem -Path $Path -File -Recurse -Force |
                Where-Object { $_.LastWriteTime -lt $CutoffDate } |
                Remove-Item -Force
        })
        [void]$PowerShell.AddArgument($Config.Path)
        [void]$PowerShell.AddArgument($CutoffDate)

        $Jobs += [PSCustomObject]@{
            Path    = $Config.Path
            DaysOld = $Config.DaysOld
            PowerShell = $PowerShell
            Handle  = $PowerShell.BeginInvoke()
        }
    }

    # Progress indicator + wait for all to finish
    Write-Host "Deleting files from folders in parallel..." -ForegroundColor Cyan
    while ($Jobs.Handle.IsCompleted -contains $false) {
        $Remaining = ($Jobs | Where-Object { -not $_.Handle.IsCompleted }).Count
        $Timestamp = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
        Write-Host "[$Timestamp] Still running: $Remaining folders" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }

    # Collect results and clean up
    foreach ($job in $Jobs) {
        $job.PowerShell.EndInvoke($job.Handle) | Out-Null
        $job.PowerShell.Dispose()
        Write-Host "Finished ($($job.DaysOld) days retention): $($job.Path)" -ForegroundColor Green
    }

    $RunspacePool.Close()
    $RunspacePool.Dispose()
    Write-Host "`nScript has completed." -ForegroundColor Cyan
}