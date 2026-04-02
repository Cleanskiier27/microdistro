param(
    [Alias("Host")]
    [string]$Target = "localhost",
    [int]$Count = 2,
    [string]$Ports = "22,80,443",
    [double]$Timeout = 1.0,
    [switch]$SkipPing,
    [switch]$SkipPortScan,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-NeuralLedArt {
    return @"
NEURAL LED GRID
[*]  .oO0OOO0Oo.   [*]
 |  o0O..:::..O0o  |
 | 0O:::/|\\:::\\O0 |
 | O:::/_+_\\:::O |
 | 0O:::\\|//:::O0 |
 |  o0O..:::..O0o  |
[*]  `oO0OOO0Oo'   [*]
"@
}

function Get-PortList {
    param([string]$RawPorts)

    $portList = @()
    foreach ($chunk in $RawPorts.Split(",")) {
        $value = $chunk.Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        $port = [int]$value
        if ($port -lt 1 -or $port -gt 65535) {
            throw "invalid port: $port"
        }

        $portList += $port
    }

    return $portList | Sort-Object -Unique
}

function Resolve-Target {
    param([string]$Name)

    $addresses = [System.Net.Dns]::GetHostAddresses($Name)
    $resolved = @()
    $seen = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($address in $addresses) {
        $family = if ($address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) { "ipv6" } else { "ipv4" }
        $ip = $address.IPAddressToString
        $key = "$family|$ip"
        if (-not $seen.Add($key)) {
            continue
        }

        $reverseDns = $null
        try {
            $reverseDns = [System.Net.Dns]::GetHostEntry($address).HostName
        } catch {
            $reverseDns = $null
        }

        $resolved += [pscustomobject]@{
            family = $family
            address = $ip
            reverse_dns = $reverseDns
        }
    }

    return $resolved
}

function Test-TargetPing {
    param(
        [string]$Name,
        [int]$Attempts
    )

    try {
        if (Test-Connection -TargetName $Name -Count $Attempts -Quiet) {
            return "ok"
        }

        return "failed"
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

function Test-TargetPorts {
    param(
        [string]$Name,
        [int[]]$PortList,
        [double]$PortTimeout
    )

    $results = @()

    foreach ($port in $PortList) {
        $client = $null
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $asyncResult = $client.BeginConnect($Name, $port, $null, $null)
            $completed = $asyncResult.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($PortTimeout))

            if (-not $completed) {
                $status = "closed"
            } else {
                $client.EndConnect($asyncResult)
                $status = "open"
            }
        } catch {
            $status = "closed"
        } finally {
            if ($null -ne $client) {
                $client.Dispose()
            }
        }

        $results += [pscustomobject]@{
            port = $port
            status = $status
        }
    }

    return $results
}

try {
    $portList = Get-PortList -RawPorts $Ports
    $addresses = Resolve-Target -Name $Target
} catch {
    Write-Error "Target inspection failed for $Target. $($_.Exception.Message)"
    exit 1
}

$pingStatus = if ($SkipPing) { "skipped" } else { Test-TargetPing -Name $Target -Attempts $Count }
$portResults = if ($SkipPortScan) { @() } else { Test-TargetPorts -Name $Target -PortList $portList -PortTimeout $Timeout }

$report = [pscustomobject]@{
    host = $Target
    addresses = $addresses
    ping = $pingStatus
    port_scan = $portResults
}

if ($Json) {
    $report | ConvertTo-Json -Depth 4
    exit 0
}

Write-Output (Get-NeuralLedArt)
Write-Output "host: $($report.host)"
Write-Output "addresses:"
foreach ($entry in $report.addresses) {
    $reverseDns = if ($null -ne $entry.reverse_dns -and $entry.reverse_dns -ne "") { $entry.reverse_dns } else { "unavailable" }
    Write-Output "- $($entry.family) $($entry.address) (reverse: $reverseDns)"
}

Write-Output "ping: $($report.ping)"

if ($report.port_scan.Count -gt 0) {
    Write-Output "ports:"
    foreach ($result in $report.port_scan) {
        Write-Output "- $($result.port): $($result.status)"
    }
} else {
    Write-Output "ports: skipped"
}

exit 0
