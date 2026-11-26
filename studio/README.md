# Executor Workbench (Studio plugin)

The workbench half of the executor project. Studio plugin that hosts the run/console loop so the
executor API and UI can be developed without touching the live client.

## Install

1. Copy this whole `ExecutorWorkbench` folder to:
   `%LOCALAPPDATA%\Roblox\Plugins\ExecutorWorkbench`
   (Studio also reads plugin folders from the Plugins directory; a folder with `init.server.lua` is a valid plugin.)
2. Restart Studio. A "Workbench" button appears on the Plugins toolbar.
3. Click it to toggle the dock widget.

## Use

- Paste Luau in the top box, press **Run**.
- Output appears in the lower box, one line per event: `[run]`, `[print]`, `[ok]`, `[error]`.
- Each run creates a fresh `ModuleScript` under `ServerStorage.WB_Runs`, requires it, calls it, reports the
  result, then destroys it. A fresh module matters because `require` caches per module instance.

## Settings you may need

- Setting `ModuleScript.Source` from a plugin requires Studio's **Allow Script Injection**
  (File > Studio Settings > Security). If it is off, the run reports that and stops.
- The workbench runs in **edit mode**, not in a playtest. For player-view behaviour use a separate
  playtest LocalScript runner; this plugin is deliberately not that.

## Why this exists

Injection into the live client is blocked (loader pages unreadable, image encrypted). The API and UI
goals do not need the client, so they are developed here. The UI is meant to be the same UI the
injected module will host, behind a thin host adapter.