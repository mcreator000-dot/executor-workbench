--!nocheck
-- Executor Workbench: Studio plugin host.
-- Two execution paths, because they are different execution contexts:
--   * Server/Edit: a fresh ModuleScript in ServerStorage, required and called. No LocalPlayer here.
--   * Client: a LocalScript placed in StarterPlayer.StarterPlayerScripts. LocalPlayer and the
--     character only exist HERE, during a playtest (F5/Play).
-- Client-only snippets are detected and routed automatically; the pane says which path ran.

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

local out = Instance.new("TextBox")
out.Size = UDim2.new(1, -16, 0.58, -56)
out.Position = UDim2.new(0, 8, 0.42, 40)
out.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
out.TextColor3 = Color3.fromRGB(190, 215, 190)
out.Font = Enum.Font.Code
out.TextSize = 13
out.MultiLine = true
out.TextEditable = false
out.ClearTextOnFocus = false
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextYAlignment = Enum.TextYAlignment.Top
out.Text = ""
out.Parent = root

-- ---------------------------------------------------------------- output channels
local history = {}
local counter = 0

local function stamp()
	return os.date("%H:%M:%S")
end

-- channel: print | warn | error | info | run | ok
local function append(channel, text)
	table.insert(history, "[" .. stamp() .. "][" .. channel .. "] " .. tostring(text))
	if #history > 600 then
		table.remove(history, 1)
	end
	out.Text = table.concat(history, "\n")
end

-- ---------------------------------------------------------------- shared environment
-- Persists for the life of the plugin and is the _ENV of every server-mode snippet, so a global
-- written by one run is readable by the next. Documented reset: plugin reload / Studio restart.
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

local PREFIX = "return function(log)\n\tlocal print = log.print\n\tlocal warn = log.warn\n\treturn function()\n"
local SUFFIX = "\n\tend\nend\n"

local function runServer(source)
	local id = counter
	local started = os.clock()

	local module = Instance.new("ModuleScript")
	module.Name = "WB_Run_" .. id
	module.Source = PREFIX .. source .. SUFFIX
	module.Parent = getFolder()

	local okFactory, factory = pcall(require, module)
	if not okFactory then
		module:Destroy()
		append("error", "compile/require failed: " .. tostring(factory))
		return false
	end

	local log = {}
	log.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		append("print", table.concat(parts, " "))
	end
	log.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		append("warn", table.concat(parts, " "))
	end

	local okMake, runner = pcall(factory, log)
	if not okMake then
		module:Destroy()
		append("error", "factory failed: " .. tostring(runner))
		return false
	end

	-- Globals read and written by the snippet land in genv, so they survive to the next run.
	genv.print = log.print
	genv.warn = log.warn
	local okEnv = pcall(function()
		setfenv(runner, genv)
	end)
	if not okEnv then
		append("warn", "setfenv unavailable; globals are per-run")
	end

	local okRun, errRun = xpcall(runner, function(e)
		return debug.traceback(tostring(e), 2)
	end)

	module:Destroy()

	if okRun then
		append("ok", string.format("run #%d done in %.1f ms (server)", id, (os.clock() - started) * 1000))
		append("info", "WalkSpeed check needs client context; use a client snippet for LocalPlayer")
		return true
	end
	append("error", tostring(errRun))
	return false
end

-- ---------------------------------------------------------------- client path
-- LocalPlayer, CharacterAdded and the Humanoid only exist on the client during a playtest, so the
-- snippet is installed as a LocalScript and runs when Play starts. Previous WB_Client_* scripts are
-- removed first so repeated runs never stack up (that stacking is what breaks a session).
local function clearClientScripts()
	local folder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not folder then
		return 0
	end
	local removed = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("LocalScript") and string.sub(child.Name, 1, 10) == "WB_Client_" then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

local CLIENT_PREFIX = "local ok, err = xpcall(function()\n"
local CLIENT_SUFFIX = "\nend, function(e) return debug.traceback(tostring(e), 2) end)\n" ..
	"if ok then\n\tprint(\"WB_CLIENT_OK\")\nelse\n\twarn(\"WB_CLIENT_ERR \" .. tostring(err))\nend\n"

local function runClient(source)
	local folder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not folder then
		append("error", "no StarterPlayerScripts in this place")
		return false
	end
	local removed = clearClientScripts()

	local script = Instance.new("LocalScript")
	script.Name = "WB_Client_" .. counter
	script.Source = CLIENT_PREFIX .. source .. CLIENT_SUFFIX
	script.Parent = folder

	append("info", string.format("installed %s (cleared %d previous)", script.Name, removed))
	append("info", "press Play (F5); client output appears in Output as WB_CLIENT_OK / WB_CLIENT_ERR")
	return true
end

-- ---------------------------------------------------------------- routing
local CLIENT_HINTS = { "LocalPlayer", "CharacterAdded", "LocalScript", "CurrentCamera", "UserInputService" }

local function needsClient(source)
	for _, hint in ipairs(CLIENT_HINTS) do
		if string.find(source, hint, 1, true) then
			return hint
		end
	end
	return nil
end

local function run(source)
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
append("info", "workbench ready - server snippets run inline, client snippets (LocalPlayer) install and need Play")
