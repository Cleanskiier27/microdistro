param(
    [string]$Host = "localhost",
    [int]$Count = 2,
    [switch]$SkipPing
)

$ErrorActionPreference = "Stop"

try {
    $addresses = [System.Net.Dns]::GetHostAddresses($Host) | ForEach-Object { $_.IPAddressToString } | Sort-Object -Unique
} catch {
    Write-Error "DNS resolution failed for $Host. $($_.Exception.Message)"
    exit 1
}

Write-Output "host: $Host"
Write-Output "addresses:"
$addresses | ForEach-Object { Write-Output "- $_" }

if ($SkipPing) {
    Write-Output "ping: skipped"
    exit 0
}

try {
    $reachable = Test-Connection -TargetName $Host -Count $Count -Quiet
    if ($reachable) {
        Write-Output "ping: ok"
        exit 0
    }

    Write-Output "ping: failed"
    exit 2
} catch {
    Write-Output "ping: unavailable ($($_.Exception.Message))"
    exit 0
}
