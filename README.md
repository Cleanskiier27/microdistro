# microdistro

Minimal starter repository for a network utility that can be implemented in either Python or PowerShell.

## Order

1. `networkbuster.py` is the primary entrypoint and now provides real network diagnostics.
2. `networkbuster.ps1` is the PowerShell alternative.
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

Run:

```powershell
./networkbuster.ps1 -Host example.com
```

## Notes

- The Python tool still uses only the standard library.
- Dependabot will start tracking Python dependencies once they are added to `pyproject.toml`.
- The PowerShell script remains a lightweight alternative and can be expanded separately.
