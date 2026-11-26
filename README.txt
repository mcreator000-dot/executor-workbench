Bundle contents and why each file is here.

TARGET 1 - Studio plugin for a place we own
  plugin/ExecutorWorkbench/init.server.lua   the whole plugin: dock widget, code box,
                                             Run/Import/Clear, output pane. Each run builds a
                                             fresh ModuleScript, requires it, wraps in xpcall.
  studio/README.md                           install and use notes.
  studio/mc.py, studio/mc_server.py          local MCP client/server used to drive Studio from
                                             scripts (execute_luau, get_console_output, etc.).

TARGET 2 - our own Luau host and the opcode ground truth
  vmtest/vmctl.cpp                           standalone Luau host: --control compiles
                                             "return 42" and calls it; --file <chunk> loads and
                                             runs compiled bytecode. Both verified working.
  luau748/compile14m.cpp                     bytecode compiler that takes the opcode
                                             multiplier as argv[3].
  luau_upstream/Common/include/Luau/Bytecode.h        LBC_VERSION_MIN/MAX, TYPE_VERSION_MAX,
                                                      the LOP_* enum - the authority for our table.
  luau_upstream/Common/include/Luau/BytecodeUtils.h   bytecode disassembler entry points.
  luau_upstream/Bytecode/include/Luau/BytecodeBuilder.h  serialisation side, version gates.
  luau_upstream/Bytecode/src/BytecodeBuilder.cpp       what the compiler actually emits.
  luau_upstream/Compiler/src/Compiler.cpp              compile path, including any opcode
                                                      multiplier applied at emit time.
  luau_upstream/VM/src/lvmload.cpp                     the loader: header parsing, version and
                                                      type checks, error strings.
  luau_upstream/VM/src/lvmexecute.cpp                  opcode dispatch - the only place the
                                                      encoding of an instruction is consumed.

WHAT WE ARE BUILDING (only environments we own)
1. The plugin: documented API surface (getgenv, persistent globals across runs, require by
   instance path), stdout vs error vs warning separation with timestamps, and Import from disk
   that reports parse errors with line numbers.
2. vmctl: a verified opcode/version table asserted against these headers (counts must match and
   fail loudly), and a small disassembler for our own compiled chunks that uses that table.

CONSTRAINTS
- No third-party client, no injection, no anti-cheat work. Studio plugin APIs for our own place,
  and our own host binary.
- A capability counts as done only when a run produced observed output, not when a log said so.
