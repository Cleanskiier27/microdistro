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

function Get-Summary {
    param([object[]]$Addresses, [object[]]$PortResults)

    $openPorts = @($PortResults | Where-Object { $_.status -eq "open" }).Count
    $closedPorts = @($PortResults | Where-Object { $_.status -eq "closed" }).Count

    return [pscustomobject]@{
        resolved_addresses = @($Addresses).Count
        open_ports = $openPorts
        closed_ports = $closedPorts
    }
}

function Get-LedState {
    param(
        [string]$PingStatus,
        [object[]]$PortResults,
        [string]$ResolutionError
    )

    if ($ResolutionError) {
        return "resolve"
    }

    if ($PingStatus.StartsWith("failed") -or $PingStatus.StartsWith("unavailable")) {
        return "alert"
    }

    if ($PortResults | Where-Object { $_.status -eq "open" }) {
        return "active"
    }

    return "idle"
}

function Format-ColorizedText {
    param(
        [string]$Text,
        [string]$State
    )

    $palette = @{
        idle = "`e[36m"
        active = "`e[32m"
        alert = "`e[31m"
        resolve = "`e[33m"
    }

    return "$($palette[$State])$Text`e[0m"
}

function Get-NeuralLedArt {
    param(
        [string]$PingStatus,
        [object[]]$PortResults,
        [string]$ResolutionError,
        [pscustomobject]$Summary
    )

    $state = Get-LedState -PingStatus $PingStatus -PortResults $PortResults -ResolutionError $ResolutionError

    switch ($state) {
        "active" {
            $art = @"
NEURAL LED GRID :: ACTIVE
[*]  .oO0OOO0Oo.   [*]
 |  o0O..:::..O0o  |
 | 0O:::/|\\:::\\O0 |
 | O:::/_+_\\:::O |
 | 0O:::\\|//:::O0 |
 |  o0O..:::..O0o  |
[*]  `oO0OOO0Oo'   [*]
"@
        }
        "alert" {
            $art = @"
NEURAL LED GRID :: ALERT
[!]   xX#=====#Xx   [!]
 |   ##::!!!::##   |
 |   #!:/###\\:!#   |
 |   ##::!!!::##   |
[!]   `xX#===#Xx'   [!]
"@
        }
        "resolve" {
            $art = @"
NEURAL LED GRID :: RESOLVE
[?]   .-==???==-..  [?]
 |   :: dns flux :: |
 |   :/ unresolved\: |
 |   :: retry path :: |
[?]   `-==???==-.'  [?]
"@
        }
        default {
            $art = @"
NEURAL LED GRID :: IDLE
[.]   .o..o..o.    [.]
 |   ..::---::..   |
 |   ::::...::::   |
 |   ..::---::..   |
[.]   `o..o..o.'   [.]
"@
        }
    }

    if ($ResolutionError) {
        $summaryLine = "STATE $($state.ToUpper()) | addrs $($Summary.resolved_addresses) | open $($Summary.open_ports) | dns $ResolutionError"
    } else {
        $summaryLine = "STATE $($state.ToUpper()) | addrs $($Summary.resolved_addresses) | open $($Summary.open_ports) | ping $PingStatus"
    }

    return Format-ColorizedText -Text ($art.TrimEnd() + "`n" + $summaryLine) -State $state
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

$exitCode = 0
$resolutionError = $null
$addresses = @()
$portResults = @()
$pingStatus = "skipped"

try {
    $portList = Get-PortList -RawPorts $Ports
    $addresses = Resolve-Target -Name $Target
} catch {
    $resolutionError = $_.Exception.Message
    $exitCode = 1
}

if (-not $resolutionError) {
    $pingStatus = if ($SkipPing) { "skipped" } else { Test-TargetPing -Name $Target -Attempts $Count }
    $portResults = if ($SkipPortScan) { @() } else { Test-TargetPorts -Name $Target -PortList $portList -PortTimeout $Timeout }
}

$summary = Get-Summary -Addresses $addresses -PortResults $portResults
$report = [pscustomobject]@{
    host = $Target
    addresses = $addresses
    ping = $pingStatus
    port_scan = $portResults
    resolution_error = $resolutionError
    summary = $summary
    led_state = (Get-LedState -PingStatus $pingStatus -PortResults $portResults -ResolutionError $resolutionError)
}

if ($Json) {
    $report | ConvertTo-Json -Depth 5
    exit $exitCode
}

Write-Output (Get-NeuralLedArt -PingStatus $report.ping -PortResults $report.port_scan -ResolutionError $report.resolution_error -Summary $report.summary)
Write-Output "host: $($report.host)"

if ($report.resolution_error) {
    Write-Output "dns: $($report.resolution_error)"
    Write-Output "addresses: unavailable"
    Write-Output "ping: skipped"
    Write-Output "ports: skipped"
    exit $exitCode
}

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

exit $exitCode
