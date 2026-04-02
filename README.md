# microdistro

Minimal starter repository for a network utility that can be implemented in either Python or PowerShell.

## Order

1. `networkbuster.py` is the primary entrypoint and provides network diagnostics plus a neural LED terminal banner.
2. `networkbuster.ps1` matches the Python feature set and renders the same neural LED art in text mode.
3. `tests/` validates both entrypoints.
4. `.github/workflows/ci.yml` runs the automated checks.
5. `.github/dependabot.yml` keeps Python and GitHub Actions dependencies up to date.

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

- renders a neural LED banner in text mode
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

- renders a neural LED banner in text mode
- resolves IPv4 and IPv6 addresses
- attempts reverse DNS lookups
- optionally pings the target
- checks selected TCP ports

## Tests

Run Python tests:

```bash
python -m unittest discover -s tests -p "test_*.py" -v
```

Run PowerShell tests:

```powershell
./tests/test_networkbuster.ps1
```

## Notes

- Both entrypoints currently use only built-in platform capabilities.
- JSON mode stays machine-readable and does not include the art banner.
- Dependabot will start tracking Python dependencies once they are added to `pyproject.toml`.
- The PowerShell script accepts `-Host` as an alias, but `-Target` is the preferred parameter name to avoid the built-in PowerShell `$Host` variable.
