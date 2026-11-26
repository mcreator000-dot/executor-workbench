
local timers = {}
local pendingThread = nil
local testArgs = nil
local startCount = 0
local failStart = false
local guid = 0
local outputs = {}
local function print(...) table.insert(outputs, table.concat({...}, " ")) end
local function warn(...) table.insert(outputs, table.concat({...}, " ")) end
local function signal()
    local s = { callbacks = {} }
    function s:Connect(fn) table.insert(self.callbacks, fn) end
    function s:Fire(...) for _, f in ipairs(self.callbacks) do f(...) end end
    return s
end
local function obj(kind, name)
    local o = { ClassName = kind, Name = name or kind, children = {}, signals = {}, attributes = {},
        MouseButton1Click = signal(), OnServerEvent = signal(), AbsoluteCanvasSize = {Y=200}, AbsoluteWindowSize = {Y=100} }
    function o:GetAttribute(key) return self.attributes[key] end
    function o:SetAttribute(key, value) self.attributes[key] = value end
    function o:IsA(class) return self.ClassName == class end
    function o:GetChildren() local r = {} for _, c in ipairs(self.children) do if not c.destroyed then table.insert(r, c) end end return r end
    function o:FindFirstChild(name) for _, c in ipairs(self:GetChildren()) do if c.Name == name then return c end end end
    function o:WaitForChild(name) local c = self:FindFirstChild(name) assert(c, "missing " .. name) return c end
    function o:Destroy() self.destroyed = true end
    function o:GetPropertyChangedSignal(name)
        if not self.signals[name] then self.signals[name] = signal() end
        return self.signals[name]
    end
    return setmetatable({}, {
        __index = o,
        __newindex = function(_, k, v)
            o[k] = v
            if k == "Parent" and v then table.insert(v.children, o.proxy) end
        end,
    }), o
end
local all = {}
local function instance(kind, name)
    local proxy, state = obj(kind, name)
    state.proxy = proxy
    table.insert(all, proxy)
    return proxy
end
local Instance = { new = function(kind) return instance(kind) end }
local Enum = setmetatable({}, { __index = function() return setmetatable({}, {__index=function(_, key) return key end}) end})
local UDim2 = {new = function(...) return {...} end, fromOffset = function(...) return {...} end, fromScale=function(...) return {...} end}
local Vector2 = {new = function(...) return {...} end}
local Color3 = {fromRGB=function(...) return {...} end}
local DockWidgetPluginGuiInfo = {new=function(...) return {...} end}
local plugin = {}
function plugin:CreateToolbar()
    return {CreateButton=function() return {Click=signal()} end}
end
function plugin:CreateDockWidgetPluginGui() return instance("DockWidgetPluginGui") end
local folder = instance("StarterPlayerScripts", "StarterPlayerScripts")
local starter = instance("StarterPlayer", "StarterPlayer")
folder.Parent = starter
local rs = instance("ReplicatedStorage", "ReplicatedStorage")
local ss = instance("ServerScriptService", "ServerScriptService")
local storage = instance("ServerStorage", "ServerStorage")
local run = { IsStudio=function() return true end, IsEdit=function() return true end }
local http = { GenerateGUID=function() guid += 1 return "guid-" .. guid end }
local testService = {}
function testService:ExecutePlayModeAsync(args)
    startCount += 1
    if failStart then error("test already running - synthetic") end
    testArgs = args
    pendingThread = coroutine.running()
    return coroutine.yield()
end
function testService:GetTestArgs() return testArgs end
local endings = {}
function testService:EndTest(value)
    table.insert(endings, value)
    if pendingThread then
        local thread = pendingThread
        pendingThread = nil
        local ok, err = coroutine.resume(thread, value)
        assert(ok, err)
    end
end
local services = {HttpService=http,RunService=run,ServerStorage=storage,StarterPlayer=starter,
    StudioService={}, ReplicatedStorage=rs, ServerScriptService=ss, StudioTestService=testService}
local game = {GetService=function(_, name) assert(services[name], name) return services[name] end}
local task = {}
function task.delay(seconds, fn) table.insert(timers, {seconds=seconds, fn=fn}) end
function task.spawn(fn)
    local thread = coroutine.create(fn)
    local ok, err = coroutine.resume(thread)
    assert(ok, err)
end

local function pluginMain()
-- INSERT_PLUGIN_SOURCE
end
local function runReporter()
-- INSERT_REPORTER_SOURCE
end
pluginMain()

local function findUi(class, text)
    for _, v in ipairs(all) do if v.ClassName == class and v.Text == text then return v end end
    error("missing UI " .. tostring(text))
end
local auto = findUi("TextButton", "Auto")
local runButton = findUi("TextButton", "Run")
local editor = findUi("TextBox", "")
editor.Text = "local p = game.Players.LocalPlayer"
local out
for _, v in ipairs(all) do if v.ClassName == "TextBox" and v.TextEditable == false then out = v end end
assert(out and out.TextWrapped and out.AutomaticSize == "Y")
local old = instance("LocalScript", "WB_Auto_old")
old.Parent = folder
auto.MouseButton1Click:Fire()
assert(startCount == 1 and old.destroyed, "first start/cleanup failed")
local firstArgs = testArgs
assert(firstArgs.timeoutSeconds == 30)
auto.MouseButton1Click:Fire()
runButton.MouseButton1Click:Fire()
assert(startCount == 1 and string.find(out.Text, "still active", 1, true), "busy guard failed")
runReporter()
local report1 = rs:FindFirstChild("WB_TestResult")
report1.OnServerEvent:Fire(nil, "WB_CLIENT_RESULT stale OK")
assert(#endings == 0, "accepted stale marker")
report1.OnServerEvent:Fire(nil, "WB_CLIENT_RESULT " .. firstArgs.runId .. " OK")
assert(#endings == 1 and string.find(out.Text, "client reported WB_CLIENT_RESULT " .. firstArgs.runId .. " OK", 1, true), "success missing")
timers[2].fn()
assert(#endings == 1, "late timeout ended test twice")
local oldRunner = folder:FindFirstChild("WB_Auto_1")
assert(oldRunner)
auto.MouseButton1Click:Fire()
assert(startCount == 2 and oldRunner.destroyed, "second start/cleanup failed")
local secondArgs = testArgs
assert(secondArgs.runId ~= firstArgs.runId)
timers[1].fn()
assert(not string.find(out.Text, "auto run " .. firstArgs.runId .. " is still waiting", 1, true), "old watchdog interfered")
runReporter()
local report2 = rs:FindFirstChild("WB_TestResult")
timers[4].fn()
assert(#endings == 2 and endings[2].status == "timeout", "timeout did not return")
assert(string.find(out.Text, "auto run " .. secondArgs.runId .. " timed out waiting for client", 1, true), "timeout not reported")
report2.OnServerEvent:Fire(nil, "WB_CLIENT_RESULT " .. secondArgs.runId .. " OK")
assert(#endings == 2, "late client ended test twice")
auto.MouseButton1Click:Fire()
local thirdArgs = testArgs
runReporter()
local report3 = rs:FindFirstChild("WB_TestResult")
report3.OnServerEvent:Fire(nil, "WB_CLIENT_RESULT " .. thirdArgs.runId .. " ERR error details")
assert(string.find(out.Text, "[error] client reported WB_CLIENT_RESULT " .. thirdArgs.runId .. " ERR error details", 1, true), "error verdict missing")
failStart = true
auto.MouseButton1Click:Fire()
assert(startCount == 4 and string.find(out.Text, "playtest call failed:", 1, true), "call error missing")
assert(startCount == 4, "unexpected retry")
failStart = false
auto.MouseButton1Click:Fire()
assert(startCount == 5, "busy guard not released after error")
local fifthArgs = testArgs
timers[#timers].fn()
assert(string.find(out.Text, "auto run " .. fifthArgs.runId .. " is still waiting", 1, true), "watchdog notice missing")
auto.MouseButton1Click:Fire()
assert(startCount == 5, "watchdog allowed overlapping auto")
runReporter()
rs:FindFirstChild("WB_TestResult").OnServerEvent:Fire(nil, "WB_CLIENT_RESULT " .. fifthArgs.runId .. " OK")
assert(#endings == 4, "late result not delivered")
testArgs = nil
local timerCount = #timers
runReporter()
rs:FindFirstChild("WB_TestResult").OnServerEvent:Fire(nil, "manual")
assert(#timers == timerCount and outputs[#outputs] == "[Workbench] client verdict: manual", "manual reporter changed")
assert(#endings == 4, "manual reporter ended a test")
_G.print("Mock scheduler: success, stale result, busy, repeated runs, timeout, late result, ERR, error, watchdog and F5 passed")


local function findTrace(needle)
    for index, line in ipairs(outputs) do
        if string.find(line, needle, 1, true) then return index end
    end
end
assert(not findTrace("[WB]") and not storage:GetAttribute("WB_AutoProbeTrace"), "normal Auto emitted probe traces")

editor.Text = ""
storage:SetAttribute("WB_AutoProbe", "A")
local timerStart = #timers
auto.MouseButton1Click:Fire()
local a = testArgs
assert(a.probe == "A" and a.timeoutSeconds == 3 and timers[timerStart + 1].seconds == 8)
assert(findTrace("calling ExecutePlayModeAsync runId=" .. a.runId .. " probe=A"))
local probeRunner = folder:GetChildren()[1]
assert(string.find(probeRunner.Source, "client started runId=" .. a.runId, 1, true))
assert(string.find(probeRunner.Source, "while true do task.wait(1) end", 1, true))
runReporter()
assert(findTrace("server timeout armed runId=" .. a.runId .. " seconds=3"))
assert(timers[timerStart + 2].seconds == 3)
timers[timerStart + 2].fn()
local fired = assert(findTrace("server timeout fired runId=" .. a.runId .. "; calling EndTest"))
local timeoutReturn = "pcall returned ok=true result=timeout runId=" .. a.runId .. " resultRunId=" .. a.runId
local returned = assert(findTrace(timeoutReturn), "probe failed to record the timeout return")
assert(string.find(storage:GetAttribute("WB_AutoProbeTrace"), timeoutReturn, 1, true), "timeout missing from Edit trace")
assert(fired < returned, "timeout trace did not precede the plugin return")
timers[timerStart + 1].fn()
assert(findTrace("watchdog ran runId=" .. a.runId .. " active=false"))

storage:SetAttribute("WB_AutoProbe", "B")
timerStart = #timers
auto.MouseButton1Click:Fire()
local b = testArgs
assert(b.probe == "B" and b.timeoutSeconds == 60 and timers[timerStart + 1].seconds == 3)
assert(string.find(folder:GetChildren()[1].Source, "task.wait(10)", 1, true))
runReporter()
timers[timerStart + 1].fn()
local waiting = assert(findTrace("watchdog ran runId=" .. b.runId .. " active=true"))
local verdict = "WB_CLIENT_RESULT " .. b.runId .. " OK"
rs:FindFirstChild("WB_TestResult").OnServerEvent:Fire(nil, verdict)
local received = assert(findTrace("server verdict received runId=" .. b.runId))
returned = assert(findTrace("pcall returned ok=true result=" .. verdict .. " runId=" .. b.runId .. " resultRunId=" .. b.runId))
assert(waiting < received and received < returned and not findTrace("server timeout fired runId=" .. b.runId))

failStart = true
auto.MouseButton1Click:Fire()
assert(findTrace("pcall returned ok=false result=") and findTrace("test already running - synthetic"),
    "probe failed to log the pcall error")
_G.print("Output probe: normal mode quiet, preset A timeout, preset B watchdog and verdict, launch error")
