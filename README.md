# microdistro

Minimal starter repository for a network utility that can be implemented in either Python or PowerShell.

## Order

1. `networkbuster.py` is the primary starter entrypoint.
2. `networkbuster.ps1` is the PowerShell alternative.
3. `.github/workflows/ci.yml` validates both entrypoints.
4. `.github/dependabot.yml` keeps Python and GitHub Actions dependencies up to date.

## Python

Run:

```bash
python networkbuster.py --host example.com
```

## PowerShell

Run:

```powershell
./networkbuster.ps1 -Host example.com
```

## Notes

- The Python starter uses only the standard library.
- The PowerShell starter resolves DNS and optionally performs a ping test.
- Add Python dependencies to `pyproject.toml` when the project grows.
