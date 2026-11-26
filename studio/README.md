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

The pane reports staging because an ordinary F5 playtest has a separate client DataModel.
The client prints its result; the user or external MCP call reads it. The
[LogService plugin report](https://devforum.roblox.com/t/logservice-plugin-doesnt-receive-serverclient-logs-during-live-sessions/4721959)
describes the missing client/server log events in a plugin; no such event is needed by this design.

**Load user plugins on playtest** (`Studio.LoadUserPluginsInRunModes`) controls whether
**user-installed plugins** are loaded in Studio run modes. It is set in Studio Settings, under
Studio. An ordinary Script parented into a place gains no documented plugin status from this
setting. Loading a place-planted Script as a plugin is **unverified**; Roblox documents creating
a Script and saving it as a local plugin as separate steps. See the
[setting reference](https://create.roblox.com/docs/reference/engine/classes/Studio#LoadUserPluginsInRunModes)
and [plugin documentation](https://create.roblox.com/docs/studio/plugins#create-new-plugins).

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

## Studio verification to run

1. Stage `print(game:GetService("Players").LocalPlayer)`. Before F5 the pane should say pending.
   After F5, check for the same marker ending in `OK` in Client Output and through MCP.
2. Stop and stage `local _ = game:GetService("Players").LocalPlayer; error("expected failure")`.
   Check for a different marker, ending in `ERR` with the error text. The pane still records pending.
3. Stop and stage `local x = game:GetService("Players").LocalPlayer; local =`. Verify a client
   syntax error for the staged script and no terminal marker for this GUID.
4. Stop and run `print("edit path")`. The print and success should appear in the pane.


<!-- /coderabbit-ai-generated:v1 -->