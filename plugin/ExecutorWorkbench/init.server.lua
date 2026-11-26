--!nocheck
-- Executor Workbench: Studio plugin host.
-- Two execution paths, because they are different execution contexts:
--   * Server/Edit: a fresh ModuleScript in ServerStorage, required and called. No LocalPlayer here.
--   * Client: a LocalScript placed in StarterPlayer.StarterPlayerScripts. LocalPlayer and the
--     character only exist HERE, during a playtest (F5/Play).
-- Client-only snippets are staged in Edit mode; their verdict is read from Client Output.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StudioService = game:GetService("StudioService")

local okBar, button = pcall(function()
	local toolbar = plugin:CreateToolbar("Executor Workbench")
	return toolbar:CreateButton("Workbench", "Open the workbench", "")
end)
if not okBar then
	button = nil
end

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 540, 440, 360, 260)
local widget = plugin:CreateDockWidgetPluginGui("ExecutorWorkbench", info)
widget.Title = "Executor Workbench"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
root.BorderSizePixel = 0
root.Parent = widget

local code = Instance.new("TextBox")
code.Size = UDim2.new(1, -16, 0.42, -16)
code.Position = UDim2.new(0, 8, 0, 8)
code.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
code.TextColor3 = Color3.fromRGB(220, 220, 230)
code.Font = Enum.Font.Code
code.TextSize = 14
code.MultiLine = true
code.ClearTextOnFocus = false
code.TextXAlignment = Enum.TextXAlignment.Left
code.TextYAlignment = Enum.TextYAlignment.Top
code.Text = ""
code.Parent = root

local function mkButton(text, x, w)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, w, 0, 28)
	b.Position = UDim2.new(0, x, 0.42, 4)
	b.BackgroundColor3 = Color3.fromRGB(58, 58, 66)
	b.TextColor3 = Color3.fromRGB(235, 235, 240)
	b.Font = Enum.Font.Code
	b.TextSize = 14
	b.Text = text
	b.Parent = root
	return b
end

local runBtn = mkButton("Run", 8, 80)
local importBtn = mkButton("Import", 96, 80)
local clearBtn = mkButton("Clear", 184, 80)
local autoBtn = mkButton("Auto", 272, 80)

local outputScroll = Instance.new("ScrollingFrame")
outputScroll.Size = UDim2.new(1, -16, 0.58, -56)
outputScroll.Position = UDim2.new(0, 8, 0.42, 40)
outputScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
outputScroll.BorderSizePixel = 0
outputScroll.ScrollBarThickness = 8
outputScroll.ScrollingDirection = Enum.ScrollingDirection.Y
outputScroll.CanvasSize = UDim2.fromOffset(0, 0)
outputScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
outputScroll.Parent = root

local out = Instance.new("TextBox")
out.Size = UDim2.new(1, -8, 0, 0)
out.AutomaticSize = Enum.AutomaticSize.Y
out.BackgroundTransparency = 1
out.TextColor3 = Color3.fromRGB(190, 215, 190)
out.Font = Enum.Font.Code
out.TextSize = 13
out.TextWrapped = true
out.MultiLine = true
out.TextEditable = false
out.ClearTextOnFocus = false
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextYAlignment = Enum.TextYAlignment.Top
out.Text = ""
out.Parent = outputScroll

-- Follow new output; older entries remain accessible by scrolling.
outputScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
	outputScroll.CanvasPosition = Vector2.new(0, math.max(0, outputScroll.AbsoluteCanvasSize.Y - outputScroll.AbsoluteWindowSize.Y))
end)

-- ---------------------------------------------------------------- output channels
local history = {}
local counter = 0
local activeAutoRun = nil

local function stamp()
	return os.date("%H:%M:%S")
end

-- channel: print | warn | error | info | run | ok | pending
local function append(channel, text)
	table.insert(history, "[" .. stamp() .. "][" .. channel .. "] " .. tostring(text))
	if #history > 600 then
		table.remove(history, 1)
	end
	out.Text = table.concat(history, "\n")
end

-- ---------------------------------------------------------------- shared environment
-- Persists across server runs for the life of the plugin. Reloading the plugin resets it.
local genv = {}
genv.version = "workbench-2"

function genv.getgenv()
	return genv
end

function genv.getscripts()
	local found = {}
	for _, d in ipairs(game:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			table.insert(found, d)
		end
	end
	return found
end

function genv.getnilinstances()
	return {}
end

-- require-by-path: "ServerStorage.WB_Runs.Foo" or "game.Workspace.Model.Module".
-- Errors name the exact segment that failed instead of returning nil.
function genv.loadmodule(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	if #parts == 0 then
		error("loadmodule: empty path", 2)
	end
	local node = game
	local i = 1
	if parts[1] == "game" then
		i = 2
	end
	for idx = i, #parts do
		local name = parts[idx]
		local found = nil
		local okService, service = pcall(function()
			return game:GetService(name)
		end)
		if okService and service then
			found = service
		else
			for _, child in ipairs(node:GetChildren()) do
				if child.Name == name then
					found = child
					break
				end
			end
		end
		if not found then
			error("loadmodule: segment '" .. name .. "' not found under " .. node:GetFullName(), 2)
		end
		node = found
	end
	if not node:IsA("ModuleScript") then
		error("loadmodule: " .. node:GetFullName() .. " is a " .. node.ClassName .. ", not a ModuleScript", 2)
	end
	return require(node)
end

-- ---------------------------------------------------------------- server/edit path
local function getFolder()
	local f = ServerStorage:FindFirstChild("WB_Runs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WB_Runs"
		f.Parent = ServerStorage
	end
	return f
end

local PREFIX = "return function()\n"
local SUFFIX = "\nend\n"

local function runLogger(channel, id)
	return function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		append(channel, "#" .. id .. " " .. table.concat(parts, " "))
	end
end

local function runServer(source)
	local id = counter
	local started = os.clock()
	local module = Instance.new("ModuleScript")
	local okRun, errRun = xpcall(function()
		module.Name = "WB_Run_" .. id
		module.Source = PREFIX .. source .. SUFFIX
		module.Parent = getFolder()
		local runner = require(module)
		local defaults = getfenv(runner)
		local env = setmetatable({
			print = runLogger("print", id),
			warn = runLogger("warn", id),
		}, {
			__index = function(_, key)
				local value = rawget(genv, key)
				if value ~= nil then
					return value
				end
				return defaults[key]
			end,
			__newindex = genv,
		})
		setfenv(runner, env)
		runner()
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	module:Destroy()

	if okRun then
		append("ok", string.format("run #%d done in %.1f ms (server)", id, (os.clock() - started) * 1000))
		return true
	end
	append("error", "server run #" .. id .. ": " .. tostring(errRun))
	return false
end

-- ---------------------------------------------------------------- client path
-- LocalPlayer, CharacterAdded and the Humanoid only exist on the client during a playtest, so the
-- snippet is installed as a LocalScript and runs when Play starts. Remove previous manual and
-- automated runners so repeated runs do not execute stale snippets.
local function clearClientScripts()
	local folder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not folder then
		return 0
	end
	local removed = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("LocalScript") and
			(string.sub(child.Name, 1, 10) == "WB_Client_" or string.sub(child.Name, 1, 8) == "WB_Auto_") then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

local CLIENT_PREFIX = [=[
if not game:GetService("RunService"):IsStudio() then
	return
end

local ok, err = xpcall(function()
]=]

local function clientSuffix(marker)
	-- The print/warn pair is the F5 path (read it in Studio Output). The FireServer part only does
	-- anything when the auto-mode handshake staged ReplicatedStorage.WB_TestResult; in F5 mode it is
	-- a no-op, so one script body serves both modes.
	return "\nend, function(e) return debug.traceback(tostring(e), 2) end)\n" ..
		string.format([=[
local marker = %q
local verdict
if ok then
	verdict = marker .. " OK"
	print(verdict)
else
	verdict = marker .. " ERR " .. tostring(err)
	warn(verdict)
end
local report = game:GetService("ReplicatedStorage"):FindFirstChild("WB_TestResult")
if report and report:IsA("RemoteEvent") then
	pcall(function() report:FireServer(verdict) end)
end
]=], marker)
end

local function runClient(source)
	if not RunService:IsEdit() then
		append("error", "stop the playtest and stage the client run in Edit mode")
		return false
	end

	local folder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not folder then
		append("error", "no StarterPlayerScripts in this place")
		return false
	end

	-- A fresh marker also separates results left in Output after a plugin reload.
	local marker = "WB_CLIENT_RESULT " .. HttpService:GenerateGUID(false)
	local removed = clearClientScripts()
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "WB_Client_" .. counter
	clientScript.Source = CLIENT_PREFIX .. source .. clientSuffix(marker)
	clientScript.Parent = folder

	append("pending", "awaiting client result; press F5 (Play), then read Studio Output (Context: Client)")
	append("info", string.format("staged %s (cleared %d previous); search Output for %s", clientScript.Name, removed, marker))
	return true
end

-- ---------------------------------------------------------------- routing
local CLIENT_HINTS = {
	LocalPlayer = true,
	CharacterAdded = true,
	LocalScript = true,
	CurrentCamera = true,
	UserInputService = true,
}

local function needsClient(source)
	local i = 1
	local function skipLong()
		local equals = string.match(source, "^%[(=*)%[", i)
		if not equals then
			return false
		end
		local _, last = string.find(source, "]" .. equals .. "]", i + #equals + 2, true)
		i = last and last + 1 or #source + 1
		return true
	end

	local scan
	local function scanTemplate()
		i += 1
		while i <= #source do
			local c = string.sub(source, i, i)
			i += 1
			if c == "`" then
				return nil
			elseif c == "\\" then
				i += 1
			elseif c == "{" then
				local hint = scan(true)
				if hint then
					return hint
				end
			end
		end
	end

	scan = function(interpolation)
		local depth = 0
		local previous, beforePrevious, thirdPrevious
		local function token(value)
			thirdPrevious, beforePrevious, previous = beforePrevious, previous, value
		end
		while i <= #source do
			local c = string.sub(source, i, i)
			if string.sub(source, i, i + 1) == "--" then
				i += 2
				if not skipLong() then
					i = string.find(source, "[\r\n]", i) or #source + 1
				end
			elseif c == "'" or c == '"' then
				local first = i + 1
				i = first
				while i <= #source and string.sub(source, i, i) ~= c do
					i += string.sub(source, i, i) == "\\" and 2 or 1
				end
				local literal = string.sub(source, first, i - 1)
				if i <= #source and previous == "(" then
					if beforePrevious == "GetService" and thirdPrevious == ":" and literal == "UserInputService" then
						return literal
					elseif beforePrevious == "Instance.new" and literal == "LocalScript" then
						return literal
					end
				end
				i += 1
				token("<string>")
			elseif c == "`" then
				local hint = scanTemplate()
				if hint then
					return hint
				end
				token("<string>")
			elseif c == "[" and skipLong() then
				token("<string>")
			elseif string.match(c, "[%a_]") then
				local name = string.match(source, "^[%a_][%w_]*", i)
				if CLIENT_HINTS[name] then
					return name
				end
				i += #name
				token(name == "new" and previous == "." and beforePrevious == "Instance" and "Instance.new" or name)
			elseif string.match(c, "%d") then
				i += #string.match(source, "^%d[%w_]*", i)
				token("<number>")
			else
				i += 1
				if interpolation then
					if c == "}" and depth == 0 then
						return nil
					elseif c == "}" then
						depth -= 1
					elseif c == "{" then
						depth += 1
					end
				end
				if not string.match(c, "%s") then
					token(c)
				end
			end
		end
		return nil
	end

	return scan(false)
end

-- ---------------------------------------------------------------- automated mode
-- A LocalScript cannot hand a verdict to an edit-mode plugin. The documented indirect route is a
-- plugin-started test: the client FireServer's one string, a server Script reads GetTestArgs() and
-- calls EndTest(result), and ExecutePlayModeAsync returns that result to the waiting plugin.
-- Staged only for auto mode; F5 mode never creates these objects.
-- The deadline starts when the server reporter runs, not when Studio begins launching.
local AUTO_TIMEOUT_SECONDS = 30
local AUTO_WATCHDOG_SECONDS = 45

local SERVER_REPORTER = [==[
if not game:GetService("RunService"):IsStudio() then
	return
end
local service = game:GetService("StudioTestService")
-- Manual F5 has no Workbench test arguments; keep mirroring its reports to Server Output.
local args = service:GetTestArgs()
local testRunId = nil
if type(args) == "table" and args.kind == "WB" and type(args.runId) == "string" then
	testRunId = args.runId
end

local done = false
local function finish(result)
	if done then
		return
	end
	done = true
	local ok, err = pcall(function()
		service:EndTest(result)
	end)
	if not ok then
		warn("Workbench EndTest failed: " .. tostring(err))
	end
end

if testRunId then
	local timeoutSeconds = args.timeoutSeconds
	if type(timeoutSeconds) ~= "number" or timeoutSeconds < 1 or timeoutSeconds > 300 then
		timeoutSeconds = 30
	end
	task.delay(timeoutSeconds, function()
		finish({ runId = testRunId, status = "timeout" })
	end)
end

local report = game:GetService("ReplicatedStorage"):WaitForChild("WB_TestResult")
report.OnServerEvent:Connect(function(_player, message)
	if type(message) ~= "string" then
		return
	end
	if not testRunId then
		print("[Workbench] client verdict: " .. message)
		return
	end

	local marker = "WB_CLIENT_RESULT " .. testRunId
	if message ~= marker .. " OK" and string.sub(message, 1, #marker + 5) ~= marker .. " ERR " then
		return
	end
	finish({ runId = testRunId, message = message })
end)
]==]

local function stageHandshake()
	local okAll, errAll = pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local ss = game:GetService("ServerScriptService")
		local oldEvent = rs:FindFirstChild("WB_TestResult")
		if oldEvent then
			oldEvent:Destroy()
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = "WB_TestResult"
		remote.Parent = rs
		local oldReporter = ss:FindFirstChild("WB_TestReporter")
		if oldReporter then
			oldReporter:Destroy()
		end
		local reporter = Instance.new("Script")
		reporter.Name = "WB_TestReporter"
		reporter.Source = SERVER_REPORTER
		reporter.Parent = ss
	end)
	if not okAll then
		append("error", "handshake staging failed: " .. tostring(errAll))
		return false
	end
	return true
end

local function runAutomated(source)
	if activeAutoRun then
		append("pending", "an Auto run is still active; wait for its result")
		return false
	end
	if not RunService:IsEdit() then
		append("error", "stop the playtest before launching an automated run")
		return false
	end
	if not needsClient(source) then
		append("warn", "auto mode is client-only for now; use Run for server snippets")
		return false
	end
	if not stageHandshake() then
		return false
	end

	local runId = HttpService:GenerateGUID(false)
	local marker = "WB_CLIENT_RESULT " .. runId
	local folder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not folder then
		append("error", "no StarterPlayerScripts in this place")
		return false
	end
	clearClientScripts()
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "WB_Auto_" .. counter
	clientScript.Source = CLIENT_PREFIX .. source .. clientSuffix(marker)
	clientScript.Parent = folder

	local available, service, execute = pcall(function()
		local s = game:GetService("StudioTestService")
		return s, s.ExecutePlayModeAsync
	end)
	if not available or type(execute) ~= "function" then
		append("pending", "StudioTestService unavailable on this Studio build; use Run then F5 and read Output")
		return false
	end

	activeAutoRun = runId
	append("pending", "starting playtest for " .. runId .. " (server deadline: " .. AUTO_TIMEOUT_SECONDS .. "s)")
	task.delay(AUTO_WATCHDOG_SECONDS, function()
		if activeAutoRun == runId then
			append("pending", "auto run " .. runId .. " is still waiting; verdict unconfirmed. Stop the playtest in Studio if needed")
		end
	end)
	task.spawn(function()
		local ok, result = pcall(execute, service, { kind = "WB", runId = runId, timeoutSeconds = AUTO_TIMEOUT_SECONDS })
		activeAutoRun = nil
		if not ok then
			append("error", "playtest call failed: " .. tostring(result))
		elseif result == nil then
			append("pending", "test ended without a result (verdict unconfirmed)")
		elseif type(result) ~= "table" or result.runId ~= runId then
			append("pending", "invalid or mismatched test result (verdict unconfirmed)")
		elseif result.status == "timeout" then
			append("pending", "auto run " .. runId .. " timed out waiting for client (verdict unconfirmed)")
		elseif result.message == marker .. " OK" then
			append("ok", "client reported " .. result.message)
		elseif type(result.message) == "string" and string.sub(result.message, 1, #marker + 5) == marker .. " ERR " then
			append("error", "client reported " .. result.message)
		else
			append("pending", "invalid or mismatched test result (verdict unconfirmed)")
		end
	end)
	return true
end

local function run(source)
	if activeAutoRun then
		append("pending", "an Auto run is still active; wait for its result")
		return false
	end
	counter += 1
	append("run", "run #" .. counter)
	local hint = needsClient(source)
	if hint then
		append("info", "client-only API detected (" .. hint .. ") -> client path")
		return runClient(source)
	end
	return runServer(source)
end

runBtn.MouseButton1Click:Connect(function()
	local text = code.Text
	if text == "" then
		append("warn", "nothing to run")
		return
	end
	local ok, err = pcall(run, text)
	if not ok then
		append("error", "run failed: " .. tostring(err))
	end
end)

importBtn.MouseButton1Click:Connect(function()
	-- PromptImportFileAsync returns ONE File or nil. The old code indexed it as a list, so a
	-- successful pick always looked like a cancellation.
	local ext = { "lua", "luau", "txt" }
	local ok, file = pcall(function()
		return StudioService:PromptImportFileAsync(ext)
	end)
	if not ok then
		ok, file = pcall(function()
			return StudioService:PromptImportFileAsync()
		end)
	end
	if not ok then
		append("error", "import failed: " .. tostring(file))
		return
	end
	if not file then
		append("warn", "import cancelled")
		return
	end
	local okRead, text = pcall(function()
		return file:GetBinaryContents()
	end)
	if not okRead or type(text) ~= "string" then
		append("error", "read failed: " .. tostring(text))
		return
	end
	code.Text = text
	append("info", string.format("imported %s (%d bytes) - syntax is checked on Run", file.Name, #text))
end)


autoBtn.MouseButton1Click:Connect(function()
	local text = code.Text
	if text == "" then
		append("warn", "nothing to run")
		return
	end
	counter += 1
	append("run", "auto #" .. counter)
	local ok, err = pcall(runAutomated, text)
	if not ok then
		append("error", "auto run failed: " .. tostring(err))
	end
end)

clearBtn.MouseButton1Click:Connect(function()
	history = {}
	out.Text = ""
end)

if button then
	button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)
end

widget.Enabled = true
append("info", "workbench ready - server snippets run inline, client snippets (LocalPlayer) are staged for Play")
