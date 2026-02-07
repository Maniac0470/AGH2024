$zoneName = "ddc.local"

$servers = @{
    # "jppiruops001" = "10.23.132.209"
    # "jppiruops002" = "10.23.132.208"
    # "jppiruops003" = "10.23.132.231"
    # "jppiruops004" = "10.23.132.207"
    # "jppiruops005" = "10.23.132.205"
    # "jppiruops006" = "10.23.132.200"
    # "jppiruops007" = "10.23.132.210"
    # "jppiruops008" = "10.23.132.215"
    # "jppiruops009" = "10.23.132.216"
    # "jppiruops010" = "10.23.132.220"
    # "jppiruops011" = "10.23.132.224"
    # "jppiruops012" = "10.23.132.228"
    # "jppiruops013" = "10.23.132.232"
    # "jppiruops014" = "10.23.132.235"
    # "jppiruops015" = "10.23.132.236"
    # "jppiruops016" = "10.23.132.240"
    # "jppiruops017" = "10.23.132.244"
    # "jppiruops018" = "10.23.132.193"
    # "jppiruops019" = "10.23.132.248"
    # "jppiruops020" = "10.23.132.251"
    # "jppiruops021" = "10.23.132.254"
    # "jppiruops022" = "10.23.132.242"
}

Write-Host "Creating A + PTR records in zone: $zoneName`n" -ForegroundColor Cyan

foreach ($server in $servers.GetEnumerator()) {
    $name = $server.Key
    $ip   = $server.Value

    Write-Host "Processing $name → $ip ..." -NoNewline

    try {
        # Check if record already exists
        $existing = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $name -RRType A -ErrorAction SilentlyContinue

        if ($existing -and $existing.RecordData.IPv4Address -eq $ip) {
            Write-Host " already exists with correct IP → skipped" -ForegroundColor DarkGray
            continue
        }

        # Add (or update) the A record + auto-create PTR
        Add-DnsServerResourceRecordA `
            -ZoneName $zoneName `
            -Name $name `
            -IPv4Address $ip `
            -CreatePtr `
            -ErrorAction Stop

        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nFinished." -ForegroundColor Cyan
Write-Host "Tip: If you get 'Reverse lookup zone does not exist' errors → create the reverse zone first:"