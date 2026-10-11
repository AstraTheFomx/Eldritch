local EldritchBase = {}
EldritchBase.Rev = 1

local LIB_URL = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/EldritchLib.lua?rev=2"

local EldritchLib = loadstring(game:HttpGet(LIB_URL, true))()
assert(type(EldritchLib) == "table" and type(EldritchLib.CreateWindow) == "function", "EldritchBase: interface failed to load")

local cloneref = (typeof and typeof(cloneref) == "function" and cloneref)
    or (type(rawget(_G, "cloneref")) == "function" and rawget(_G, "cloneref"))
    or function(x) return x end

local function getService(name)
    local service = nil
    pcall(function() service = game:GetService(name) end)
    if service == nil then return nil end
    local ok, ref = pcall(function() return cloneref(service) end)
    if ok and ref ~= nil then return ref end
    return service
end

EldritchBase.Services = {
    Players = getService("Players"),
    RunService = getService("RunService"),
    UserInputService = getService("UserInputService"),
    Lighting = getService("Lighting"),
    TeleportService = getService("TeleportService"),
    HttpService = getService("HttpService"),
    CoreGui = getService("CoreGui"),
    VirtualUser = getService("VirtualUser"),
}

local Players = EldritchBase.Services.Players
if Players == nil then error("EldritchBase: Players unavailable") end
if EldritchBase.Services.RunService == nil then error("EldritchBase: RunService unavailable") end
if EldritchBase.Services.UserInputService == nil then error("EldritchBase: UserInputService unavailable") end

EldritchBase.LocalPlayer = Players.LocalPlayer
if EldritchBase.LocalPlayer == nil then error("EldritchBase: LocalPlayer unavailable") end
local LocalPlayer = EldritchBase.LocalPlayer

local Entity = {}

function Entity.Character()
    local character = LocalPlayer.Character
    if character ~= nil and character.Parent ~= nil then return character end
    return nil
end

function Entity.Humanoid(character)
    local model = character or Entity.Character()
    if model == nil then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid ~= nil and humanoid.Parent ~= nil then return humanoid end
    return nil
end

function Entity.Root(character)
    local model = character or Entity.Character()
    if model == nil then return nil end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root ~= nil and root.Parent ~= nil then return root end
    return nil
end

function Entity.Alive()
    local humanoid = Entity.Humanoid()
    return humanoid ~= nil and humanoid.Health > 0
end

function Entity.Camera()
    local camera = workspace.CurrentCamera
    if camera ~= nil and camera.Parent ~= nil then return camera end
    return nil
end

EldritchBase.Entity = Entity

EldritchBase.Modules = {}
EldritchBase.ModulesByName = {}

function EldritchBase.ReleaseOwned(list)
    for _, item in ipairs(list) do
        if EldritchBase.Window ~= nil then
            pcall(function() EldritchBase.Window:Untrack(item) end)
        end
        if typeof(item) == "RBXScriptConnection" then
            pcall(function() item:Disconnect() end)
        end
    end
    table.clear(list)
end

EldritchBase.Steps = {}

function EldritchBase:Step(fn)
    table.insert(self.Steps, fn)
end

local function installFallback(Win)
    local fallbackTasks = {}
    function Win:Track(...)
        for _, item in ipairs({...}) do
            table.insert(fallbackTasks, item)
        end
        return ...
    end
    function Win:Untrack(item)
        for i = #fallbackTasks, 1, -1 do
            if fallbackTasks[i] == item then
                table.remove(fallbackTasks, i)
            end
        end
        return item
    end
    function Win:Cleanup()
        for _, item in ipairs(fallbackTasks) do
            local kind = typeof(item)
            if kind == "RBXScriptConnection" then
                pcall(function() item:Disconnect() end)
            elseif type(item) == "thread" then
                pcall(function() task.cancel(item) end)
            elseif kind == "Instance" then
                pcall(function() item:Destroy() end)
            elseif type(item) == "function" then
                pcall(item)
            end
        end
        table.clear(fallbackTasks)
    end
    local baseDestroy = Win.Destroy
    function Win:Destroy(...)
        pcall(function() self:Cleanup() end)
        return baseDestroy(self, ...)
    end
end

function EldritchBase:Start(title)
    local Win = EldritchLib:CreateWindow({
        Title = title or "Eldritch",
        ToggleKey = Enum.KeyCode.RightShift
    })
    if type(Win.Track) ~= "function" then
        installFallback(Win)
    end
    self.Window = Win
    self.Categories = {}
    for _, name in ipairs({"Blatant", "Legit", "Render", "Utility", "World"}) do
        self:CreateCategory(name)
    end
    if type(getgenv) == "function" then
        pcall(function()
            local prior = getgenv().__ELDRITCH_CLEANUP
            if type(prior) == "function" then
                prior()
            end
            getgenv().__ELDRITCH_CLEANUP = function()
                pcall(function() Win:Destroy() end)
            end
        end)
    end
    return self
end

function EldritchBase:CreateCategory(name)
    local tab = self.Window:AddTab(name)
    local category = { Name = name, Tab = tab }

    function category:CreateModule(def)
        def = def or {}
        local mod = {
            Name = tostring(def.Name or "Module"),
            Enabled = false,
            Options = {},
            Owned = {},
            Error = nil,
        }
        local ui = nil
        if def.Button then
            mod.Button = true
            ui = tab:AddButton(mod.Name, function()
                mod:Activate()
            end)
        else
            ui = tab:AddToggle(mod.Name, false, function(v)
                mod:SetEnabled(v)
            end)
        end
        mod.UI = ui
        table.insert(EldritchBase.Modules, mod)
        EldritchBase.ModulesByName[mod.Name] = mod

        function mod:SetEnabled(v)
            v = (v == true)
            if v == self.Enabled then return end
            self.Enabled = v
            if self.UI ~= nil then self.UI:Set(v) end
            if type(def.Function) == "function" then
                local ok, err = pcall(def.Function, v)
                if not ok then self.Error = tostring(err) end
            end
            if not v then EldritchBase.ReleaseOwned(self.Owned) end
        end

        function mod:Toggle()
            self:SetEnabled(not self.Enabled)
        end

        function mod:Activate()
            if type(def.Function) == "function" then
                local ok, err = pcall(def.Function)
                if not ok then self.Error = tostring(err) end
            end
        end

        function mod:Clean(...)
            for _, item in ipairs({...}) do
                table.insert(self.Owned, item)
            end
            return EldritchBase.Window:Track(...)
        end

        function mod:CreateToggle(name, default, fn)
            local opt = { Value = (default == true) }
            opt.Api = tab:AddToggle(name, default, function(v)
                opt.Value = (v == true)
                if fn then fn(v) end
            end)
            self.Options[name] = opt
            return opt
        end

        function mod:CreateSlider(name, low, high, default, fn)
            local opt = { Value = default }
            opt.Api = tab:AddSlider(name, low, high, default, function(v)
                opt.Value = v
                if fn then fn(v) end
            end)
            self.Options[name] = opt
            return opt
        end

        function mod:CreateDropdown(name, list, default, fn)
            local opt = { Value = default or list[1] }
            opt.Api = tab:AddDropdown(name, list, default, function(v)
                opt.Value = v
                if fn then fn(v) end
            end)
            self.Options[name] = opt
            return opt
        end

        function mod:CreateInput(name, default, fn)
            local opt = { Value = default }
            opt.Api = tab:AddInput(name, default, function(v)
                opt.Value = v
                if fn then fn(v) end
            end)
            self.Options[name] = opt
            return opt
        end

        function mod:CreateButton(name, fn)
            return tab:AddButton(name, fn)
        end

        function mod:CreateLabel(text)
            return tab:AddLabel(text)
        end

        return mod
    end

    self.Categories[name] = category
    return category
end

return EldritchBase
