$rootFolders = @('C:\TestDelete\Folder1','C:\TestDelete\Folder2','C:\TestDelete\Folder3','C:\TestDelete\Folder4','C:\TestDelete\Folder5','C:\TestDelete\Folder6','C:\TestDelete\Folder7','C:\TestDelete\Folder8','C:\TestDelete\Folder9','C:\TestDelete\Folder10','C:\TestDelete\Folder11','C:\TestDelete\Folder12','C:\TestDelete\Folder13','C:\TestDelete\Folder14','C:\TestDelete\Folder15','C:\TestDelete\Folder16','C:\TestDelete\Folder17')
$MaxThreads = 17   # one thread per folder = maximum parallelism for only 17 items

# Create runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()

$Jobs = @()

foreach ($Root in $RootFolders) {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool

    [void]$PowerShell.AddScript({
        param($Path)

        1..20000 | ForEach-Object {
            $filename = "file$_.bin"
            $filePath = Join-Path -Path $Path -ChildPath $filename
            New-Item -Path $filePath -ItemType File | Out-Null
            }
    })

    [void]$PowerShell.AddArgument($Root)

    $Jobs += [PSCustomObject]@{
        Path       = $Root
        PowerShell = $PowerShell
        Handle     = $PowerShell.BeginInvoke()
    }
}

# Progress indicator + wait for all to finish
Write-Host "Adding 20k files to 17 folders in parallel..." -ForegroundColor Cyan

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

Write-Host "`nAll done! " -ForegroundColor Cyan
