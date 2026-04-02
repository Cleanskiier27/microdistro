$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$textOutput = & ./networkbuster.ps1 -Target localhost -SkipPing -SkipPortScan
Assert-True ($LASTEXITCODE -eq 0) "Expected text diagnostics to succeed"
Assert-True (($textOutput -join "`n") -match "NEURAL LED GRID :: IDLE") "Expected idle neural LED banner in text output"
Assert-True (($textOutput -join "`n") -match "STATE IDLE") "Expected idle summary line in text output"
Assert-True (($textOutput -join "`n").Contains([string][char]27)) "Expected ANSI color in text output"
Assert-True (($textOutput -join "`n") -match "host: localhost") "Expected host line in text output"
Assert-True (($textOutput -join "`n") -match "ports: skipped") "Expected skipped ports in text output"

$jsonOutput = & ./networkbuster.ps1 -Target localhost -Json -SkipPing -SkipPortScan
Assert-True ($LASTEXITCODE -eq 0) "Expected JSON diagnostics to succeed"

$report = $jsonOutput | ConvertFrom-Json
Assert-True ($report.host -eq "localhost") "Expected JSON host to equal localhost"
Assert-True ($report.ping -eq "skipped") "Expected JSON ping status to be skipped"
Assert-True ($report.led_state -eq "idle") "Expected JSON led state to be idle"
Assert-True ($report.summary.resolved_addresses -ge 1) "Expected at least one resolved address"

$resolveOutput = & ./networkbuster.ps1 -Target invalid.invalid.invalid -SkipPing -SkipPortScan
Assert-True ($LASTEXITCODE -eq 1) "Expected invalid target to return failure"
Assert-True (($resolveOutput -join "`n") -match "NEURAL LED GRID :: RESOLVE") "Expected resolve banner for DNS issues"
Assert-True (($resolveOutput -join "`n") -match "dns:") "Expected DNS error output"

Write-Output "PowerShell tests passed"
