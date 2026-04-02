import argparse
import json
import platform
import shutil
import socket
import subprocess
import sys
from typing import Any


LED_PATTERNS = {
    "idle": """NEURAL LED GRID :: IDLE
[.]   .o..o..o.    [.] 
 |   ..::---::..   | 
 |   ::::...::::   | 
 |   ..::---::..   | 
[.]   `o..o..o.'   [.]""",
    "active": """NEURAL LED GRID :: ACTIVE
[*]  .oO0OOO0Oo.   [*]
 |  o0O..:::..O0o  |
 | 0O:::/|\\:::\\O0 |
 | O:::/_+_\\:::O |
 | 0O:::\\|//:::O0 |
 |  o0O..:::..O0o  |
[*]  `oO0OOO0Oo'   [*]""",
    "alert": """NEURAL LED GRID :: ALERT
[!]   xX#=====#Xx   [!]
 |   ##::!!!::##   | 
 |   #!:/###\\:!#   | 
 |   ##::!!!::##   | 
[!]   `xX#===#Xx'   [!]""",
}


def determine_led_state(report: dict[str, Any]) -> str:
    if report["ping"].startswith("failed") or report["ping"].startswith("unavailable"):
        return "alert"
    if any(result["status"] == "open" for result in report["port_scan"]):
        return "active"
    return "idle"


def render_neural_led_art(report: dict[str, Any] | None = None) -> str:
    if report is None:
        return LED_PATTERNS["idle"]
    return LED_PATTERNS[determine_led_state(report)]


def parse_ports(raw_ports: str) -> list[int]:
    ports: list[int] = []
    for chunk in raw_ports.split(","):
        value = chunk.strip()
        if not value:
            continue
        port = int(value)
        if port < 1 or port > 65535:
            raise ValueError(f"invalid port: {port}")
        ports.append(port)
    return sorted(set(ports))


def resolve_host(host: str) -> list[dict[str, str]]:
    results = socket.getaddrinfo(host, None, proto=socket.IPPROTO_TCP)
    addresses: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    for family, _, _, canonical_name, sockaddr in results:
        family_name = "ipv6" if family == socket.AF_INET6 else "ipv4"
        address = sockaddr[0]
        key = (family_name, address)
        if key in seen:
            continue
        seen.add(key)
        addresses.append(
            {
                "family": family_name,
                "address": address,
                "canonical_name": canonical_name or host,
            }
        )

    return addresses


def reverse_lookup(address: str) -> str | None:
    try:
        host, _, _ = socket.gethostbyaddr(address)
        return host
    except (socket.herror, socket.gaierror, OSError):
        return None


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


def scan_ports(host: str, ports: list[int], timeout: float) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for port in ports:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                status = "open"
        except OSError:
            status = "closed"
        results.append({"port": port, "status": status})
    return results


def build_report(host: str, count: int, skip_ping: bool, ports: list[int], timeout: float, skip_port_scan: bool) -> dict[str, Any]:
    addresses = resolve_host(host)
    report: dict[str, Any] = {
        "host": host,
        "addresses": [],
        "ping": "skipped",
        "port_scan": [],
    }

    for entry in addresses:
        report["addresses"].append(
            {
                **entry,
                "reverse_dns": reverse_lookup(entry["address"]),
            }
        )

    if not skip_ping:
        try:
            report["ping"] = "ok" if ping_host(host, count) else "failed"
        except RuntimeError as error:
            report["ping"] = f"unavailable: {error}"

    if not skip_port_scan:
        report["port_scan"] = scan_ports(host, ports, timeout)

    return report


def print_report(report: dict[str, Any]) -> None:
    print(render_neural_led_art(report))
    print(f"host: {report['host']}")
    print("addresses:")
    for entry in report["addresses"]:
        reverse_dns = entry["reverse_dns"] or "unavailable"
        print(f"- {entry['family']} {entry['address']} (reverse: {reverse_dns})")

    print(f"ping: {report['ping']}")

    if report["port_scan"]:
        print("ports:")
        for result in report["port_scan"]:
            print(f"- {result['port']}: {result['status']}")
    else:
        print("ports: skipped")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run basic network diagnostics for a host.")
    parser.add_argument("--host", default="localhost", help="Host name or IP address to inspect")
    parser.add_argument("--count", type=int, default=2, help="Number of ping attempts")
    parser.add_argument("--ports", default="22,80,443", help="Comma-separated TCP ports to probe")
    parser.add_argument("--timeout", type=float, default=1.0, help="Per-port timeout in seconds")
    parser.add_argument("--skip-ping", action="store_true", help="Resolve only, do not ping")
    parser.add_argument("--skip-port-scan", action="store_true", help="Skip TCP port checks")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON output")
    args = parser.parse_args()

    try:
        ports = parse_ports(args.ports)
        report = build_report(args.host, args.count, args.skip_ping, ports, args.timeout, args.skip_port_scan)
    except ValueError as error:
        print(f"invalid input: {error}", file=sys.stderr)
        return 2
    except socket.gaierror as error:
        print(f"DNS resolution failed for {args.host}: {error}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
