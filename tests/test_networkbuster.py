import io
import json
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

import networkbuster


class ParsePortsTest(unittest.TestCase):
    def test_parse_ports_deduplicates_and_sorts(self):
        self.assertEqual(networkbuster.parse_ports("443,22,80,22"), [22, 80, 443])

    def test_parse_ports_rejects_invalid_port(self):
        with self.assertRaises(ValueError):
            networkbuster.parse_ports("0,80")


class BuildReportTest(unittest.TestCase):
    @patch("networkbuster.scan_ports")
    @patch("networkbuster.ping_host")
    @patch("networkbuster.reverse_lookup")
    @patch("networkbuster.resolve_host")
    def test_build_report_collects_expected_fields(self, mock_resolve, mock_reverse, mock_ping, mock_scan):
        mock_resolve.return_value = [
            {"family": "ipv4", "address": "127.0.0.1", "canonical_name": "localhost"},
            {"family": "ipv6", "address": "::1", "canonical_name": "localhost"},
        ]
        mock_reverse.side_effect = ["localhost", "localhost"]
        mock_ping.return_value = True
        mock_scan.return_value = [{"port": 80, "status": "open"}]

        report = networkbuster.build_report("localhost", 2, False, [80], 1.0, False)

        self.assertEqual(report["host"], "localhost")
        self.assertEqual(report["ping"], "ok")
        self.assertEqual(report["port_scan"], [{"port": 80, "status": "open"}])
        self.assertEqual(report["addresses"][0]["reverse_dns"], "localhost")
        self.assertEqual(report["addresses"][1]["family"], "ipv6")

    @patch("networkbuster.resolve_host")
    def test_build_report_skips_ping_and_port_scan(self, mock_resolve):
        mock_resolve.return_value = [{"family": "ipv4", "address": "127.0.0.1", "canonical_name": "localhost"}]

        report = networkbuster.build_report("localhost", 2, True, [80], 1.0, True)

        self.assertEqual(report["ping"], "skipped")
        self.assertEqual(report["port_scan"], [])


class MainTest(unittest.TestCase):
    @patch("networkbuster.build_report")
    def test_main_json_output(self, mock_build_report):
        mock_build_report.return_value = {
            "host": "localhost",
            "addresses": [{"family": "ipv4", "address": "127.0.0.1", "reverse_dns": "localhost"}],
            "ping": "skipped",
            "port_scan": [],
        }

        stdout = io.StringIO()
        with patch("sys.argv", ["networkbuster.py", "--host", "localhost", "--json", "--skip-ping", "--skip-port-scan"]):
            with redirect_stdout(stdout):
                exit_code = networkbuster.main()

        self.assertEqual(exit_code, 0)
        payload = json.loads(stdout.getvalue())
        self.assertEqual(payload["host"], "localhost")
        self.assertEqual(payload["ping"], "skipped")

    def test_main_rejects_invalid_ports(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch("sys.argv", ["networkbuster.py", "--ports", "70000"]):
            with patch("sys.stderr", stderr):
                with redirect_stdout(stdout):
                    exit_code = networkbuster.main()

        self.assertEqual(exit_code, 2)
        self.assertIn("invalid input", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
