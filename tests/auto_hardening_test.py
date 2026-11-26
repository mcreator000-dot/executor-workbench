"""Execute Auto mode with a mock Studio scheduler.

    python tests/auto_hardening_test.py /path/to/luau

Run from the repository root. Real Studio behavior still needs Studio validation.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

if len(sys.argv) != 2:
    raise SystemExit(__doc__)

plugin = Path("plugin/ExecutorWorkbench/init.server.lua").read_text(encoding="utf-8")
template = Path("tests/auto_hardening_harness.luau").read_text(encoding="utf-8")
match = re.search(r"local SERVER_REPORTER = \[==\[\n(.*?)\n\]==\]", plugin, re.S)
if match is None:
    raise SystemExit("could not extract SERVER_REPORTER")
reporter = match.group(1)

with tempfile.TemporaryDirectory(prefix="wb-auto-test-") as directory:
    testfile = Path(directory) / "auto_test.luau"

    def run(current_plugin, current_reporter):
        testfile.write_text(
            template.replace("-- INSERT_PLUGIN_SOURCE", current_plugin, 1).replace(
                "-- INSERT_REPORTER_SOURCE", current_reporter, 1
            ),
            encoding="utf-8",
        )
        return subprocess.run([sys.argv[1], str(testfile)], capture_output=True, text=True)

    result = run(plugin, reporter)
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)
    print(result.stdout.strip())

    # Prove the tests execute the guards, rather than merely parsing them.
    busy = '''	if activeAutoRun then
		append("pending", "an Auto run is still active; wait for its result")
		return false
	end
'''
    assert plugin.count(busy) == 2
    result = run(plugin.replace(busy, "", 1), reporter)
    assert result.returncode != 0 and "busy guard failed" in result.stderr, result.stderr
    print("Mutation rejected: Auto busy guard")

    check = '''	if message ~= marker .. " OK" and string.sub(message, 1, #marker + 5) ~= marker .. " ERR " then
		return
	end
'''
    assert reporter.count(check) == 1
    result = run(plugin, reporter.replace(check, "", 1))
    assert result.returncode != 0 and "accepted stale marker" in result.stderr, result.stderr
    print("Mutation rejected: stale result guard")

    timeout = '		finish({ runId = testRunId, status = "timeout" })'
    assert reporter.count(timeout) == 1
    result = run(plugin, reporter.replace(timeout, '		-- mutated: no timeout', 1))
    assert result.returncode != 0 and "timeout did not return" in result.stderr, result.stderr
    print("Mutation rejected: server timeout")

    # Luau resolves locals lexically, so moving this function earlier can compile
    # but bind needsClient (and stageHandshake) as globals.
    start = plugin.index("local function runAutomated(source)")
    end = plugin.index("\nlocal function run(source)", start)
    run_automated = plugin[start:end]
    moved = plugin[:start] + plugin[end:]
    insert = moved.index("local function needsClient(source)")
    moved = moved[:insert] + run_automated + "\n" + moved[insert:]
    result = run(moved, reporter)
    assert result.returncode != 0 and "first start/cleanup failed" in result.stderr, result.stderr
    print("Mutation rejected: declaration order")
