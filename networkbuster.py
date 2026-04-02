import argparse
import platform
import shutil
import socket
import subprocess
import sys


def resolve_host(host: str) -> list[str]:
    _, _, addresses = socket.gethostbyname_ex(host)
    return sorted(set(addresses))


def ping_host(host: str, count: int) -> bool:
    ping_command = shutil.which("ping")
    if ping_command is None:
        raise RuntimeError("ping command is not available on this system")

    system = platform.system().lower()
    count_flag = "-n" if system == "windows" else "-c"
    result = subprocess.run(
        [ping_command, count_flag, str(count), host],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve a host and optionally ping it.")
    parser.add_argument("--host", default="localhost", help="Host name or IP address to inspect")
    parser.add_argument("--count", type=int, default=2, help="Number of ping attempts")
    parser.add_argument("--skip-ping", action="store_true", help="Resolve only, do not ping")
    args = parser.parse_args()

    try:
        addresses = resolve_host(args.host)
    except socket.gaierror as error:
        print(f"DNS resolution failed for {args.host}: {error}", file=sys.stderr)
        return 1

    print(f"host: {args.host}")
    print("addresses:")
    for address in addresses:
        print(f"- {address}")

    if args.skip_ping:
        print("ping: skipped")
        return 0

    try:
        reachable = ping_host(args.host, args.count)
    except RuntimeError as error:
        print(f"ping: unavailable ({error})")
        return 0

    print(f"ping: {'ok' if reachable else 'failed'}")
    return 0 if reachable else 2


if __name__ == "__main__":
    raise SystemExit(main())
