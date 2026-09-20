#!/usr/bin/env python3
"""Behavioral tests for the Agent/AppSec LAPI registration init script."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile


CHART = Path(__file__).resolve().parents[1]


def render_command(template: str, *settings: str) -> str:
    command = [
        "helm",
        "template",
        "registration-test",
        str(CHART),
        "--show-only",
        f"templates/{template}",
        "--values",
        str(CHART / "ci" / "crowdsec-values.yaml"),
    ]
    for setting in settings:
        command.extend(["--set", setting])

    rendered = subprocess.run(
        command, check=True, capture_output=True, text=True
    ).stdout.splitlines()
    init_index = next(
        index
        for index, line in enumerate(rendered)
        if line.strip() == "- name: wait-for-lapi-and-register"
    )
    block_index = next(
        index
        for index in range(init_index, len(rendered))
        if rendered[index].strip() == "- |"
    )
    first_line = next(
        index
        for index in range(block_index + 1, len(rendered))
        if rendered[index].strip()
    )
    indentation = len(rendered[first_line]) - len(rendered[first_line].lstrip())
    script = []
    for line in rendered[first_line:]:
        if line.strip() and len(line) - len(line.lstrip()) < indentation:
            break
        script.append(line[indentation:] if line.strip() else "")
    return "\n".join(script).rstrip() + "\n"


def registration_script() -> str:
    scripts = {
        "Agent Deployment": render_command(
            "agent-deployment.yaml", "agent.isDeployment=true"
        ),
        "Agent DaemonSet": render_command(
            "agent-daemonSet.yaml", "agent.isDeployment=false"
        ),
        "AppSec Deployment": render_command("appsec-deployment.yaml"),
    }
    assert len(set(scripts.values())) == 1, "registration scripts differ by workload"
    return next(iter(scripts.values()))


FAKE_CSCLI = r"""#!/bin/sh
printf '%s\n' "$*" >> "$CALL_LOG"
if [ "$1 $2" = "lapi status" ]; then
  exit "${STATUS_RC:-0}"
fi
if [ "$1 $2" = "lapi register" ]; then
  if [ -e "$CSCLI_CONFIG_DIR/local_api_credentials.yaml" ]; then
    echo register_credentials=present >> "$CALL_LOG"
  else
    echo register_credentials=absent >> "$CALL_LOG"
  fi
  rc=${REGISTER_RC:-0}
  [ "$rc" -eq 0 ] || exit "$rc"
  printf 'url: %s\nlogin: %s\npassword: generated\n' "$LAPI_URL" "$USERNAME" \
    > "$CSCLI_CONFIG_DIR/local_api_credentials.yaml"
  exit 0
fi
exit 99
"""

FAKE_NC = r"""#!/bin/sh
echo nc >> "$CALL_LOG"
[ "${NC_DOWN:-0}" -eq 0 ]
"""

FAKE_SLEEP = "#!/bin/sh\nexit 0\n"

FAKE_CP = r"""#!/bin/sh
last=
for argument do last=$argument; done
if [ "${CP_FAIL_SAVE:-0}" -eq 1 ] && [ "$last" = "$TMP_CONFIG/local_api_credentials.yaml" ]; then
  exit 23
fi
exec /bin/cp "$@"
"""


def executable(path: Path, contents: str) -> None:
    path.write_text(contents)
    path.chmod(0o755)


def run_case(
    script: str,
    *,
    username: str,
    saved_username: str | None = None,
    status_rc: int = 0,
    register_rc: int = 0,
    nc_down: bool = False,
    cp_fail_save: bool = False,
    timeout: float = 2,
) -> tuple[subprocess.CompletedProcess[str] | None, list[str], str | None]:
    with tempfile.TemporaryDirectory(prefix="crowdsec-registration-test-") as temporary:
        root = Path(temporary)
        bin_dir = root / "bin"
        config_dir = root / "etc" / "crowdsec"
        staging_dir = root / "staging" / "etc" / "crowdsec"
        tmp_config = root / "tmp_config"
        bin_dir.mkdir()
        config_dir.parent.mkdir()
        staging_dir.mkdir(parents=True)
        tmp_config.mkdir()

        call_log = root / "calls"
        executable(bin_dir / "cscli", FAKE_CSCLI)
        executable(bin_dir / "nc", FAKE_NC)
        executable(bin_dir / "sleep", FAKE_SLEEP)
        executable(bin_dir / "cp", FAKE_CP)

        credentials = tmp_config / "local_api_credentials.yaml"
        if saved_username is not None:
            credentials.write_text(
                f"url: http://lapi:8080/\nlogin: {saved_username}\npassword: saved\n"
            )

        sandboxed = (
            script.replace("/staging/etc/crowdsec", "__STAGING_CONFIG__")
            .replace("/etc/crowdsec", str(config_dir))
            .replace("/tmp_config", str(tmp_config))
            .replace("__STAGING_CONFIG__", str(staging_dir))
        )
        environment = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "CALL_LOG": str(call_log),
            "CSCLI_CONFIG_DIR": str(config_dir),
            "TMP_CONFIG": str(tmp_config),
            "USERNAME": username,
            "LAPI_HOST": "lapi",
            "LAPI_PORT": "8080",
            "LAPI_URL": "http://lapi:8080/",
            "REGISTRATION_TOKEN": "test-token",
            "STATUS_RC": str(status_rc),
            "REGISTER_RC": str(register_rc),
            "NC_DOWN": "1" if nc_down else "0",
            "CP_FAIL_SAVE": "1" if cp_fail_save else "0",
        }

        result = None
        try:
            result = subprocess.run(
                ["sh", "-c", sandboxed],
                env=environment,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            pass

        calls = call_log.read_text().splitlines() if call_log.exists() else []
        saved = credentials.read_text() if credentials.exists() else None
        return result, calls, saved


def count(calls: list[str], prefix: str) -> int:
    return sum(call.startswith(prefix) for call in calls)


def main() -> None:
    script = registration_script()

    result, calls, saved = run_case(script, username="agent-fresh")
    assert result and result.returncode == 0
    assert count(calls, "lapi register") == 1 and count(calls, "lapi status") == 0
    assert saved and "login: agent-fresh" in saved
    print("PASS A: fresh registration persists generated credentials")

    result, calls, saved = run_case(
        script, username="agent-retained", saved_username="agent-retained"
    )
    assert result and result.returncode == 0
    assert count(calls, "lapi status") == 1 and count(calls, "lapi register") == 0
    assert "skipping registration" in result.stdout
    assert saved and "password: saved" in saved
    print("PASS B: valid matching credentials are authenticated and reused")

    result, calls, saved = run_case(
        script, username="agent-new", saved_username="agent-old"
    )
    assert result and result.returncode == 0
    assert count(calls, "lapi status") == 0 and count(calls, "lapi register") == 1
    assert saved and "login: agent-new" in saved
    print("PASS C: mismatched credentials use fresh registration")

    result, calls, _ = run_case(
        script,
        username="agent-retained",
        saved_username="agent-retained",
        status_rc=1,
        register_rc=22,
    )
    assert result and result.returncode == 22
    assert count(calls, "lapi status") == 1 and count(calls, "lapi register") == 1
    assert "register_credentials=absent" in calls
    print("PASS D: rejected credentials are removed before fail-closed registration")

    result, calls, _ = run_case(
        script, username="agent-duplicate", register_rc=22
    )
    assert result and result.returncode == 22
    assert count(calls, "lapi status") == 0 and count(calls, "lapi register") == 1
    print("PASS E: duplicate registration without usable credentials remains fatal")

    result, calls, _ = run_case(
        script, username="agent-offline", nc_down=True, timeout=0.2
    )
    assert result is None and not any(call.startswith("lapi ") for call in calls)
    print("PASS F: unavailable LAPI remains in the wait loop")

    result, calls, saved = run_case(script, username="agent-new-pod")
    assert result and result.returncode == 0
    assert count(calls, "lapi register") == 1
    assert saved and "login: agent-new-pod" in saved
    print("PASS G: a new Pod identity registers normally")

    result, calls, _ = run_case(
        script, username="agent-save-failure", cp_fail_save=True
    )
    assert result and result.returncode == 23
    assert count(calls, "lapi register") == 1
    print("PASS: credential persistence errors remain fatal")

    print("PASS: Agent Deployment, Agent DaemonSet, and AppSec Deployment share one script")


if __name__ == "__main__":
    main()
