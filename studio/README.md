<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3d37121b9d391db4dd349c85aa870fa89a96bb63876a313a260d94057bb6e35a -->

# Executor Workbench in Studio

## Install

Create a Script in an owned place, paste `plugin/ExecutorWorkbench/init.server.lua` into it,
and choose **Save as Local Plugin** from the **Plugins** menu. Remove the install-time Script
from the place afterward. Open the dock widget with **Workbench**. See Roblox's
[plugin installation steps](https://create.roblox.com/docs/studio/plugins#create-new-plugins).

## Run a snippet

- In Edit mode, paste Luau and press **Run**. The edit path creates a fresh `ModuleScript`,
  requires it, and reports its output and result in the dock widget.
- A snippet routed to the client path stages a `LocalScript` in
  `StarterPlayer.StarterPlayerScripts`, replacing previous `WB_Client_*` runners. The pane
  reports **awaiting client result** and displays a marker of the form `WB_CLIENT_RESULT <guid>`.
- Press **F5 (Play)** and select **Client** in the [Output context filter](https://create.roblox.com/docs/studio/output).
  Search for the exact marker. The runner prints `OK` when the snippet returns and warns with
  `ERR` and a traceback for a caught runtime error. These replace the old generic client verdicts
  and numeric result IDs. The verdict covers the wrapped call; independent tasks it launches can
  still fail afterward.
- You can also read Output with the existing MCP helper:
  `python -u studio/studio_do.py console "WB_CLIENT_RESULT <guid>"`, using the GUID from the pane.
  The helper filters returned text by substring. Its exit code is about the MCP call; read the
  matching line for the verdict. The MCP response's context metadata is unverified here.
- A missing marker leaves the result unconfirmed. For example, malformed Luau can stop the
  LocalScript before its wrapper runs: check the client syntax error under the staged script name.
  Stage again for a fresh marker before each playtest. If you replay an already staged runner,
  its marker is reused, so look at fresh Output. After stopping, remove the staged runner in
  Explorer when finished; the pane's **Clear** button only clears the pane.

## Why the verdict stays in Output

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0dc17ea73f634b57c91bfca181f1a568012c91751a576c20d7f436b52ca783ee -->

The pane reports staging because an ordinary F5 playtest has a separate client DataModel.
The **Client** filter changes which entries the [Output window](https://create.roblox.com/docs/studio/output)
displays. It does not give the edit plugin access to client logs. The
[LogService plugin report](https://devforum.roblox.com/t/logservice-plugin-doesnt-receive-serverclient-logs-during-live-sessions/4721959)
specifically reports missing `MessageOut` events. The edit plugin's
[`GetLogHistory()`](https://create.roblox.com/docs/reference/engine/classes/LogService#GetLogHistory)
access to the live Client stream is unverified; it is not part of this design.

The external helper uses the [Studio MCP tool `get_console_output`](https://create.roblox.com/docs/studio/mcp#how-the-studio-mcp-server-works),
which is documented to read the Studio output log. It does not call the edit plugin's LogService.
The MCP docs do not specify whether the tool honors the UI context filter or returns source
metadata. Verify the exact `WB_CLIENT_RESULT <guid>` from the staged run while Play is active.
A successful call with no matching line leaves the verdict unconfirmed.

<!-- /coderabbit-ai-generated:v1 -->

**Load user plugins on playtest** (`Studio.LoadUserPluginsInRunModes`) controls whether
**user-installed plugins** are loaded in Studio run modes. It is set in Studio Settings, under
Studio. An ordinary Script parented into a place gains no documented plugin status from this
setting. Loading a place-planted Script as a plugin is **unverified**; Roblox documents creating
a Script and saving it as a local plugin as separate steps. See the
[setting reference](https://create.roblox.com/docs/reference/engine/classes/Studio#LoadUserPluginsInRunModes)
and [plugin documentation](https://create.roblox.com/docs/studio/plugins#create-new-plugins).

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:00ef0c83d5bfe3a994f82511913c8cbc3e00831d8474992777ae6e3bd2bc762d -->

**Yes, a plugin can start a playtest.** Roblox documents
[`StudioTestService:ExecutePlayModeAsync(args)`](https://create.roblox.com/docs/reference/engine/classes/StudioTestService#ExecutePlayModeAsync)
as a `PluginSecurity` API for solo Test (Play Solo). It first appears in Studio
[release 700 (0.700.0.7000935), November 18, 2025](https://robloxapi.github.io/ref/class/StudioTestService.html#member-ExecutePlayModeAsync);
Roblox [announced it on December 4, 2025](https://devforum.roblox.com/t/introducing-studiotestservice/4116257).
It yields until the test ends. In an API-started test, a server Script can call
[`EndTest(result)`](https://create.roblox.com/docs/reference/engine/classes/StudioTestService#EndTest)
and the result is returned to the plugin. That is a documented server-to-caller path for
automated tests; the workbench's F5 flow leaves the session open for inspection and reads
client verdicts through Output. The exact Studio build on the user's machine is unverified here.

For a future automated test button, use **release 700** as the historical minimum and
probe for the method in the plugin before enabling the button. A build number alone
does not verify that the method is callable. Wrap both service and member lookup in a
protected call because an older Studio can reject the lookup. Do not start a test to
check availability.

```luau
local available, service, execute = pcall(function()
    local testService = game:GetService("StudioTestService")
    return testService, testService.ExecutePlayModeAsync
end)
if not available or type(execute) ~= "function" then
    -- Report unavailable and use F5.
    return
end

-- Only when the user requests the test; this yields until the test ends.
local ok, result = pcall(execute, service, args)
if not ok then
    -- Report the error in result.
    return
end
-- A successful nil result can mean the user stopped the session.
```

A missing API cannot start a test. Without a guard, a missing service or member fails at
lookup or invocation; an older build's exact error text is unverified. The F5 path above
does not call the test service.


<!-- /coderabbit-ai-generated:v1 -->

## Studio verification to run

1. Stage `print(game:GetService("Players").LocalPlayer)`. Before F5 the pane should say pending.
   After F5, check for the same marker ending in `OK` in Client Output and through MCP.
2. Stop and stage `local _ = game:GetService("Players").LocalPlayer; error("expected failure")`.
   Check for a different marker, ending in `ERR` with the error text. The pane still records pending.
3. Stop and stage `local x = game:GetService("Players").LocalPlayer; local =`. Verify a client
   syntax error for the staged script and no terminal marker for this GUID.
4. Stop and run `print("edit path")`. The print and success should appear in the pane.


<!-- /coderabbit-ai-generated:v1 -->