"""Run the UART TX regression with Vivado XSim on Windows."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent
EXPECTED = {
    "tb_almost_compare": r"RESULT saved=32/32 dropped=1/0",
    "tb_arbiter_control": r"RESULT ARBITER_CONTROL writes=13 reads=13 fail=0",
    "tb_ascii_check": r"RESULT ASCII total=417 pass=417 fail=0",
    "tb_double_dabble_check": r"RESULT DD total=512 pass=512 fail=0",
    "tb_frame_check": r"RESULT FRAME total=416 pass=416 fail=0",
    "tb_packetizer_distance": r"RESULT DISTANCE bytes=15 errors=0",
    "tb_packetizer_error_fsm": r"RESULT ERROR bytes=22 errors=0 state=0",
    "tb_packetizer_stall": r"RESULT PACKETIZER STALL errors=0",
    "tb_tx_e2e_auto": (
        r"RESULT E2E normal=20 error=8 packets=28 failed_packets=0 "
        r"expected_bytes=504 received_bytes=504 fail=0"
    ),
    "tb_tx_fifo_flow": r"RESULT TX_FIFO_FLOW bytes=14 errors=0",
}


def passed(name: str, output: str) -> bool:
    failure = re.search(
        r"^\s*(?:TIMEOUT|FAIL\b|FINAL RESULT: FAIL)|"
        r"\b(?:fail|FAIL|errors|failed_packets)=[1-9][0-9]*\b",
        output, re.MULTILINE,
    )
    result = re.search(r"^" + EXPECTED[name] + r"\s*$", output, re.MULTILINE)
    return bool(result) and not failure


def run_tool(bin_dir: Path, name: str, args: list[str], work: Path, log: str) -> str:
    command = subprocess.list2cmdline([str(bin_dir / (name + ".bat")), *args])
    result = subprocess.run(
        command, cwd=work, shell=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=600,
    )
    output = result.stdout.decode("utf-8", errors="replace")
    (work / log).write_text(output, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{name} exited with {result.returncode}. See {work / log}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", help="Testbench names; default: all 10 tests")
    parser.add_argument("--vivado-bin", default=os.environ.get("VIVADO_BIN"))
    args = parser.parse_args()
    unknown = sorted(set(args.tests) - EXPECTED.keys())
    if unknown:
        parser.error("Unknown testbench: " + ", ".join(unknown))
    if os.name != "nt":
        parser.error("This runner supports Windows Vivado batch tools.")
    if args.vivado_bin:
        bin_dir = Path(args.vivado_bin).expanduser().resolve()
    else:
        xvlog = shutil.which("xvlog.bat")
        if not xvlog:
            parser.error("Set VIVADO_BIN or pass --vivado-bin to the Vivado bin directory.")
        bin_dir = Path(xvlog).parent
    for name in ("xvlog", "xelab", "xsim"):
        if not (bin_dir / (name + ".bat")).is_file():
            parser.error(f"Missing tool: {bin_dir / (name + '.bat')}")

    selected = sorted(set(args.tests)) if args.tests else sorted(EXPECTED)
    full_suite = set(selected) == set(EXPECTED)
    sources = sorted((ROOT / "rtl").glob("*.v")) + sorted((ROOT / "tb").glob("*.v"))
    for name in selected:
        if not (ROOT / "tb" / (name + ".v")).is_file():
            parser.error(f"Missing testbench file: {name}.v")
    work = Path(tempfile.mkdtemp(prefix="uart_tx_"))
    print(f"Simulation files and full logs: {work}", flush=True)
    report = {
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "suite": "full" if full_suite else "selected",
        "simulator": "Vivado XSim",
        "input_sha256": {
            str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [*sources, ROOT / "run.py"]
        },
        "tests": [],
    }
    results_dir = ROOT / "results"
    results_dir.mkdir(exist_ok=True)
    stem = "summary" if full_suite else "selected_summary"
    try:
        for source in sources:
            shutil.copy2(source, work / source.name)
        run_tool(bin_dir, "xvlog", [p.name for p in sources], work, "compile.log")
        for name in selected:
            print(f"Running {name}...", flush=True)
            snapshot = name + "_sim"
            run_tool(bin_dir, "xelab", [name, "-debug", "all", "-s", snapshot], work, name + "_elab.log")
            script = "run all\nquit\n"
            if name != "tb_tx_e2e_auto":
                script = f"open_vcd {name}.vcd\nlog_vcd /{name}/*\nrun all\nclose_vcd\nquit\n"
            (work / "run.tcl").write_text(script, encoding="utf-8")
            output = run_tool(bin_dir, "xsim", [snapshot, "-tclbatch", "run.tcl", "-wdb", name + ".wdb"], work, name + ".log")
            lines = [line.strip() for line in output.splitlines() if line.startswith(("RESULT ", "FINAL RESULT:", "TIMEOUT", "FAIL "))]
            ok = passed(name, output)
            report["tests"].append({"name": name, "passed": ok, "result_lines": lines})
            print(f"{'PASS' if ok else 'FAIL'} {name}: {'; '.join(lines)}", flush=True)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        report["execution_error"] = str(exc).replace(str(work), "<simulation-workdir>")
        print(str(exc), file=sys.stderr)

    report["passed"] = len(report["tests"]) == len(selected) and all(t["passed"] for t in report["tests"]) and "execution_error" not in report
    report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
    (results_dir / (stem + ".json")).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = [f"Suite: {report['suite']}", f"Started (UTC): {report['started_at_utc']}", ""]
    for test in report["tests"]:
        summary.extend([test["name"], *test["result_lines"], f"CHECK: {'PASS' if test['passed'] else 'FAIL'}", ""])
    if "execution_error" in report:
        summary.append("Execution error: " + report["execution_error"])
    summary.append("FINAL RESULT: " + ("PASS" if report["passed"] else "FAIL"))
    (results_dir / (stem + ".txt")).write_text("\n".join(summary) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
