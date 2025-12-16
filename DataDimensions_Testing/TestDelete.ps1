## CONFIGURATION SECTION ##########################

# Define root folders to clean up
$RootFolders = @('C:\TestDelete\Folder1','C:\TestDelete\Folder2','C:\TestDelete\Folder3','C:\TestDelete\Folder4','C:\TestDelete\Folder5','C:\TestDelete\Folder6','C:\TestDelete\Folder7','C:\TestDelete\Folder8','C:\TestDelete\Folder9','C:\TestDelete\Folder10','C:\TestDelete\Folder11','C:\TestDelete\Folder12','C:\TestDelete\Folder13','C:\TestDelete\Folder14','C:\TestDelete\Folder15','C:\TestDelete\Folder16','C:\TestDelete\Folder17')
$DaysOld = 60                                   # Define age threshold for deletion
$CutoffDate = (Get-Date).AddDays(-$DaysOld)     # Calculate cutoff date
$MaxThreads = 8                                 # Define maximum parallel threads

## END CONFIGURATION SECTION ##########################

# Create runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()

$Jobs = @()
Measure-Command {
foreach ($Root in $RootFolders) {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool

    [void]$PowerShell.AddScript({
        param($Path, $CutoffDate)

        Get-ChildItem -Path $Path -File -Recurse -Force |
        Where-Object { $_.LastWriteTime -lt $CutoffDate }| 
        Remove-Item -Force
    })

    [void]$PowerShell.AddArgument($Root)
    [void]$PowerShell.AddArgument($CutoffDate)

    $Jobs += [PSCustomObject]@{
        Path       = $Root
        PowerShell = $PowerShell
        Handle     = $PowerShell.BeginInvoke()
    }
}

# Progress indicator + wait for all to finish
Write-Host "Deleting files from 17 folders in parallel..." -ForegroundColor Cyan

while ($Jobs.Handle.IsCompleted -contains $false) {
    $Remaining = ($Jobs | Where-Object { -not $_.Handle.IsCompleted }).Count
    Write-Host "Still running: $Remaining folders" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# Collect results and clean up
foreach ($job in $Jobs) {
    $job.PowerShell.EndInvoke($job.Handle) | Out-Null
    $job.PowerShell.Dispose()
    Write-Host "Finished: $($job.Path)" -ForegroundColor Green
}

$RunspacePool.Close()
$RunspacePool.Dispose()

Write-Host "`nAll done! files removed from 17 folders." -ForegroundColor Cyan
}

#1 TEST <# TOOK FROM 12:18:00 - 12:21:30 (3 min and 30 seconds) to delete in sequence #> (SIMILAR TO HEPPS SCRIPT) - CPU went from 1-4% to ~30%
#2 TEST - Running in Parellel with RunspacePools - 12:47:10 -> 12:47:36 (26 seconds)