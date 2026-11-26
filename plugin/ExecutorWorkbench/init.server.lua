--!nocheck
-- Executor Workbench: Studio plugin host.
-- Workbench half of the executor: run snippets, keep a shared environment, expose an executor-style API.

local ServerStorage = game:GetService("ServerStorage")
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

local history = {}
local counter = 0

local function append(level, text)
	table.insert(history, "[" .. level .. "] " .. tostring(text))
	if #history > 400 then
		table.remove(history, 1)
	end
	out.Text = table.concat(history, "\n")
end

-- Executor-style shared environment: survives between runs and is visible to every chunk.
local genv = {}
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

local function getFolder()
	local f = ServerStorage:FindFirstChild("WB_Runs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WB_Runs"
		f.Parent = ServerStorage
	end
	return f
end

local API_PREAMBLE = "local getgenv = log.getgenv\n\tlocal getscripts = log.getscripts\n\tlocal getnilinstances = log.getnilinstances\n"

local function run(source)
	counter = counter + 1
	local id = counter
	local started = os.clock()
	append("run", "run #" .. id)

	local module = Instance.new("ModuleScript")
	module.Name = "WB_Run_" .. id
	module.Source = "return function(log)\n\tlocal print = log.print\n\tlocal warn = log.print\n\t" .. API_PREAMBLE .. "\treturn function()\n" .. source .. "\n\tend\nend"
	module.Parent = getFolder()

	local okFactory, factory = pcall(require, module)
	if not okFactory then
		append("error", "require failed: " .. tostring(factory))
		module:Destroy()
		return
	end

	local log = {}
	log.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		append("print", "#" .. id .. " " .. table.concat(parts, " "))
	end
	log.getgenv = genv.getgenv
	log.getscripts = genv.getscripts
	log.getnilinstances = genv.getnilinstances

	local okMake, runner = pcall(factory, log)
	if not okMake then
		append("error", "factory failed: " .. tostring(runner))
		module:Destroy()
		return
	end

	local okRun, errRun = xpcall(runner, function(e)
		return debug.traceback(tostring(e), 2)
	end)

	if okRun then
		append("ok", "#" .. id .. " done in " .. string.format("%.1f", (os.clock() - started) * 1000) .. " ms")
	else
		append("error", tostring(errRun))
	end

	module:Destroy()
end

runBtn.MouseButton1Click:Connect(function()
	local text = code.Text
	if text == "" then
		append("warn", "nothing to run")
		return
	end
	task.spawn(run, text)
end)

importBtn.MouseButton1Click:Connect(function()
	local ok, files = pcall(function()
		return StudioService:PromptImportFileAsync("Import Luau source", false)
	end)
	if not ok or not files or not files[1] then
		append("warn", "import cancelled or unavailable")
		return
	end
	code.Text = files[1]:GetBinaryContents()
	append("info", "imported " .. files[1].Name)
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

append("info", "workbench ready - print, getgenv, getscripts available inside a run")
widget.Enabled = true