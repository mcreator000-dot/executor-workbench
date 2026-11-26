# executor-workbench

An executor-style workbench that runs Luau only in environments we own: a Roblox Studio plugin for
our own places, a standalone Luau host, and the bytecode ground truth for a disassembler.

No third-party client, no injection, no anti-cheat work. If a change needs someone else's client to
run, it does not belong in this repo.

## Layout

| path | what it is |
|---|---|
| `plugin/ExecutorWorkbench/init.server.lua` | Studio plugin: dock widget, code box, Run / Import / Clear, output pane. Each run builds a fresh `ModuleScript`, requires it, wraps in `xpcall`. |
| `studio/` | local Studio MCP client and server used to drive the editor from scripts. |
| `vmtest/vmctl.cpp` | standalone Luau host. `--control` compiles `return 42` and calls it; `--file <chunk>` loads and runs compiled bytecode. |
| `luau748/compile14m.cpp` | bytecode compiler that takes the opcode multiplier as `argv[3]`. |
| `luau_upstream/` | **vendored references, read-only** - the files needed from upstream Luau. Not a full tree. |

Vendored from `https://github.com/luau-lang/luau.git` at commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`.

## Goals

1. **Plugin**: documented API surface (persistent globals across runs, require by instance path),
   separate stdout / error / warning channels with timestamps, and Import from disk that reports
   parse errors with line numbers.
2. **Host**: a verified opcode and version table asserted against `Common/include/Luau/Bytecode.h`
   (counts must match and fail loudly on drift), then a disassembler for our own compiled chunks
   that uses that table as its only authority.

## Rule

A capability counts as done only when a run produced observed output. A log line saying it worked
is not evidence.

## Status

- `vmctl`: verified locally. `--control` prints `result=42`; a compiled chunk prints
  `HELLO FROM LUAU 14`.
- Studio plugin: loads in Studio and renders its panel; the run pipeline was verified through the
  Studio MCP `execute_luau` path (`factory_ok=true run_ok=true err=nil`). Clicking Run in the
  widget and the Import button are still unverified.
