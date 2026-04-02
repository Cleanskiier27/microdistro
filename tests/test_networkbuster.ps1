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
Assert-True (($textOutput -join "`n") -match "NEURAL LED GRID") "Expected neural LED banner in text output"
Assert-True (($textOutput -join "`n") -match "host: localhost") "Expected host line in text output"
Assert-True (($textOutput -join "`n") -match "ports: skipped") "Expected skipped ports in text output"

$jsonOutput = & ./networkbuster.ps1 -Target localhost -Json -SkipPing -SkipPortScan
Assert-True ($LASTEXITCODE -eq 0) "Expected JSON diagnostics to succeed"

$report = $jsonOutput | ConvertFrom-Json
Assert-True ($report.host -eq "localhost") "Expected JSON host to equal localhost"
Assert-True ($report.ping -eq "skipped") "Expected JSON ping status to be skipped"
Assert-True ($report.addresses.Count -ge 1) "Expected at least one resolved address"

Write-Output "PowerShell tests passed"
