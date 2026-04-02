# microdistro

Minimal starter repository for a network utility that can be implemented in either Python or PowerShell.

## Order

1. `networkbuster.py` is the primary entrypoint and provides network diagnostics.
2. `networkbuster.ps1` now matches the Python feature set for day-to-day diagnostics.
3. `.github/workflows/ci.yml` validates both entrypoints.
4. `.github/dependabot.yml` keeps Python and GitHub Actions dependencies up to date.

## Python

Run a basic DNS-only check:

```bash
python networkbuster.py --host example.com --skip-ping --skip-port-scan
```

Run diagnostics with TCP probes:

```bash
python networkbuster.py --host example.com --ports 22,80,443
```

Emit JSON:

```bash
python networkbuster.py --host example.com --json --skip-ping
```

What it does:

- resolves IPv4 and IPv6 addresses
- attempts reverse DNS lookups
- optionally pings the target
- checks selected TCP ports

## PowerShell

Run a basic DNS-only check:

```powershell
./networkbuster.ps1 -Target example.com -SkipPing -SkipPortScan
```

Run diagnostics with TCP probes:

```powershell
./networkbuster.ps1 -Target example.com -Ports 22,80,443
```

Emit JSON:

```powershell
./networkbuster.ps1 -Target example.com -Json -SkipPing
```

What it does:

- resolves IPv4 and IPv6 addresses
- attempts reverse DNS lookups
- optionally pings the target
- checks selected TCP ports

## Notes

- Both entrypoints currently use only built-in platform capabilities.
- Dependabot will start tracking Python dependencies once they are added to `pyproject.toml`.
- The PowerShell script accepts `-Host` as an alias, but `-Target` is the preferred parameter name to avoid the built-in PowerShell `$Host` variable.
