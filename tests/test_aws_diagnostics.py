import os
import subprocess
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT_ROOT / "scripts" / "aws-network-check.sh"


# Helper: Run a Bash diagnostic script with a fake AWS CLI
def run_diagnostics(tmp_path, script=SCRIPT):
    env = os.environ.copy()
    env["PATH"] = f"{tmp_path}:{env['PATH']}"

    return subprocess.run(
        ["bash", str(script)],
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
    )


# Helper: Create a fake AWS CLI with configurable HTTP rules
def create_fake_aws(tmp_path, http_cidr="0.0.0.0/0"):
    fake_aws = tmp_path / "aws"

    mock_code = """#!/usr/bin/env python3
import sys

args = sys.argv[1:]

def query():
    return args[args.index("--query") + 1]

q = query()

if "State.Name" in q:
    print("stopped")

elif "PrivateIpAddress" in q:
    print("10.20.1.203")

elif "PublicIpAddress" in q:
    print("None")

elif "IpPermissions" in q and "80" in q:
    print("HTTP_CIDR_PLACEHOLDER")

elif "IpPermissions" in q and "22" in q:
    print("223.181.12.187/32")

elif "Routes" in q:
    print("igw-0b10418f649815b8b")

elif "EnableDnsSupport" in q:
    print("True")

elif "EnableDnsHostnames" in q:
    print("False")

elif "Entries" in q:
    print("100")

else:
    print("Unexpected AWS query", file=sys.stderr)
    sys.exit(1)
"""

    fake_aws.write_text(
        mock_code.replace("HTTP_CIDR_PLACEHOLDER", http_cidr)
    )

    fake_aws.chmod(0o755)


# TEST 1: AWS CLI failure
def test_aws_cli_failure(tmp_path):
    fake_aws = tmp_path / "aws"

    fake_aws.write_text(
        "#!/bin/sh\n"
        "echo 'Simulated AWS CLI failure' >&2\n"
        "exit 1\n"
    )

    fake_aws.chmod(0o755)

    result = run_diagnostics(tmp_path)

    assert result.returncode == 2
    assert "[ERROR] AWS CLI command failed" in (
        result.stdout + result.stderr
    )


# TEST 2 & 3: Healthy configuration and HTTP misconfiguration
@pytest.mark.parametrize(
    "http_cidr, expected_exit_code, expected_status",
    [
        ("0.0.0.0/0", 0, "HEALTHY"),
        ("None", 1, "UNHEALTHY"),
    ],
)
def test_aws_configuration(
    tmp_path, http_cidr, expected_exit_code, expected_status
):
    create_fake_aws(tmp_path, http_cidr)

    result = run_diagnostics(tmp_path)

    assert result.returncode == expected_exit_code, (
        result.stdout + result.stderr
    )

    assert f"Overall Status: {expected_status}" in result.stdout

    if expected_exit_code == 0:
        assert "Passed Checks : 7" in result.stdout
        assert "Failed Checks : 0" in result.stdout

    else:
        assert "[FAIL] HTTP port 80 is not open to the internet" in result.stdout
        assert "Passed Checks : 6" in result.stdout
        assert "Failed Checks : 1" in result.stdout


# TEST 4: Missing required diagnostic check
def test_missing_required_checks(tmp_path):
    # Create a healthy mock so all AWS CLI commands succeed
    create_fake_aws(tmp_path)

    original_script = SCRIPT.read_text()

    # Simulate expecting 8 checks when only 7 are performed
    assert "REQUIRED_CHECKS=7" in original_script

    modified_script = original_script.replace(
        "REQUIRED_CHECKS=7",
        "REQUIRED_CHECKS=8",
    )

    # Write to a temporary file; preserve the original script
    temporary_script = tmp_path / "aws-network-check-test.sh"
    temporary_script.write_text(modified_script)

    result = run_diagnostics(tmp_path, temporary_script)

    # Verify the script reached the missing-check safeguard
    assert result.returncode == 2, result.stdout + result.stderr

    assert (
        "[ERROR] Expected at least 8 checks, but only 7 were completed"
        in result.stdout
    )

    assert "Passed Checks : 7" not in result.stdout or (
        "Overall Status: HEALTHY" not in result.stdout
    )
