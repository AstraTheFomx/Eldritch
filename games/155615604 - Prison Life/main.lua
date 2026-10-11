local UNIVERSAL_URL = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/games/universal/main.lua?rev=5"

local Base = loadstring(game:HttpGet(UNIVERSAL_URL, true))()
local Services = Base.Services
local Entity = Base.Entity
local LocalPlayer = Base.LocalPlayer
local Players = Services.Players

local ReplicatedStorage = nil
pcall(function()
    ReplicatedStorage = game:GetService("ReplicatedStorage")
end)

local Prison = Base:CreateCategory("Prison")

local function getRemotes()
    if ReplicatedStorage == nil then return nil end
    local remotes = nil
    pcall(function()
        remotes = ReplicatedStorage:FindFirstChild("Remotes")
    end)
    return remotes
end

local function teamName(player)
    if player == nil then return "" end
    local team = player.Team
    if team == nil then return "" end
    return tostring(team.Name)
end

local function findBackpack()
    local pack = nil
    pcall(function()
        pack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
    end)
    return pack
end

local function equippedToolName()
    local character = Entity.Character()
    if character == nil then return "" end
    local tool = nil
    pcall(function()
        tool = character:FindFirstChildWhichIsA("Tool")
    end)
    if tool == nil then return "" end
    return tostring(tool.Name)
end

local function hasTool(toolName)
    if toolName == "" then return true end
    local pack = findBackpack()
    if pack ~= nil then
        local found = nil
        pcall(function()
            found = pack:FindFirstChild(toolName)
        end)
        if found ~= nil then return true end
    end
    return equippedToolName() == toolName
end

local function parseList(v)
    local out = {}
    for name in string.gmatch(tostring(v), "([^,]+)") do
        table.insert(out, (string.gsub(name, "^%s*(.-)%s*$", "%1")))
    end
    return out
end

local function pressTeamButton(match, label)
    if type(firesignal) ~= "function" then
        return false, "firesignal unavailable"
    end
    local frame = nil
    pcall(function()
        frame = LocalPlayer.PlayerGui:FindFirstChild("TeamsFrame", true)
    end)
    if frame == nil then
        return false, "TeamsFrame not open"
    end
    local found = frame:GetDescendants()
    for _, d in ipairs(found) do
        if d:IsA("TextButton") then
            local text = ""
            pcall(function() text = string.lower(tostring(d.Text)) end)
            if string.find(text, match, 1, true) then
                local ok = pcall(function() firesignal(d.MouseButton1Click) end)
                if ok then return true, "Joined " .. label end
            end
        end
    end
    return false, "No " .. label .. " button"
end

local function arrestable(player, model)
    if player == LocalPlayer then return false end
    if model == nil or model.Parent == nil then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid == nil or humanoid.Health <= 0 then return false end
    local arrested = false
    pcall(function() arrested = model:GetAttribute("Arrested") == true end)
    if arrested then return false end
    local name = teamName(player)
    if name == "Criminals" then return true end
    if name == "Inmates" then
        local hostile = false
        local tased = false
        pcall(function()
            hostile = model:GetAttribute("Hostile") == true
            tased = model:GetAttribute("Tased") == true
        end)
        if hostile and not tased then return false end
        return true
    end
    return false
end

Prison.Tab:AddSubsection("Roles")

local teamStatus = Prison.Tab:AddLabel("Pick a team")
Prison.Tab:AddButton("Become Guard", function()
    local ok, msg = pressTeamButton("guard", "Guards")
    teamStatus:Set(msg)
end)
Prison.Tab:AddButton("Become Inmate", function()
    local ok, msg = pressTeamButton("inmate", "Inmates")
    teamStatus:Set(msg)
end)
Prison.Tab:AddLabel("Criminal needs a prison escape")

Prison.Tab:AddSubsection("Farming")

local arrestRange, arrestHandCheck = 8, false
local arrestAcc, arrestCd = 0, 0
local AutoArrest = Prison:CreateModule({
    Name = "AutoArrest",
    Function = function(on)
        if on then
            arrestAcc = 0
        end
    end,
})
AutoArrest:CreateSlider("Range", 1, 8, 8, function(v)
    arrestRange = math.floor(v + 0.5)
end)
AutoArrest:CreateToggle("Hand Check", false, function(v)
    arrestHandCheck = (v == true)
end)
local arrestStatus = AutoArrest:CreateLabel("Idle")
Base:Step(function(dt)
    if not AutoArrest.Enabled then return end
    arrestCd = arrestCd - dt
    arrestAcc = arrestAcc + dt
    if arrestAcc < 0.1 then return end
    arrestAcc = 0
    if arrestCd > 0 then return end
    local character = Entity.Character()
    local root = Entity.Root(character)
    if character == nil or root == nil then return end
    if arrestHandCheck and equippedToolName() ~= "Handcuffs" then return end
    local best, bestDist = nil, arrestRange
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if arrestable(player, model) then
            local troot = Entity.Root(model)
            if troot ~= nil then
                local dist = (troot.Position - root.Position).Magnitude
                if dist <= bestDist then
                    best, bestDist = player, dist
                end
            end
        end
    end
    if best == nil then return end
    task.spawn(function()
        local remotes = getRemotes()
        if remotes == nil then
            arrestStatus:Set("Remotes missing")
            return
        end
        local target = remotes:FindFirstChild("ArrestPlayer")
        if target == nil then
            arrestStatus:Set("Arrest remote missing")
            return
        end
        local ok, res = pcall(function()
            return target:InvokeServer(best, 1)
        end)
        if ok and res then
            arrestCd = 7
            arrestStatus:Set("Arrested " .. best.Name)
        end
    end)
end)

local pickupItems, pickupRange = {}, 12
local pickupAcc = 0
local AutoPickup = Prison:CreateModule({
    Name = "AutoPickup",
    Function = function(on)
    end,
})
AutoPickup:CreateInput("Items", "Remington 870,MP5,AK-47", function(v)
    pickupItems = parseList(v)
end)
AutoPickup:CreateSlider("Range", 1, 30, 12, function(v)
    pickupRange = math.floor(v + 0.5)
end)
local pickupStatus = AutoPickup:CreateLabel("Idle")
pickupItems = parseList("Remington 870,MP5,AK-47")
Base:Step(function(dt)
    if not AutoPickup.Enabled then return end
    pickupAcc = pickupAcc + dt
    if pickupAcc < 0.25 then return end
    pickupAcc = 0
    if not Entity.Alive() then return end
    local character = Entity.Character()
    local root = Entity.Root(character)
    if character == nil or root == nil then return end
    local remotes = getRemotes()
    if remotes == nil then return end
    local giver = remotes:FindFirstChild("GiverPressed")
    if giver == nil then
        pickupStatus:Set("Giver remote missing")
        return
    end
    local taken = 0
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Model" then
            local toolName = nil
            pcall(function() toolName = child:GetAttribute("ToolName") end)
            if type(toolName) == "string" and toolName ~= "" then
                local wanted = #pickupItems == 0
                if not wanted then
                    for _, want in ipairs(pickupItems) do
                        if want == toolName then
                            wanted = true
                            break
                        end
                    end
                end
                if wanted and not hasTool(toolName) then
                    local prime = child.PrimaryPart
                    if prime ~= nil and (prime.Position - root.Position).Magnitude <= pickupRange then
                        pcall(function() giver:FireServer(child) end)
                        taken = taken + 1
                    end
                end
            end
        end
    end
    if taken > 0 then
        pickupStatus:Set("Took " .. tostring(taken))
    end
end)

Prison.Tab:AddSubsection("Intel")

local c4Refs = {}
local c4Folder = nil
local addC4, removeC4 = nil, nil
local C4ESP = Prison:CreateModule({
    Name = "C4 ESP",
    Function = function(on)
        if on then
            if c4Folder ~= nil then
                Base.Window:Untrack(c4Folder)
                pcall(function() c4Folder:Destroy() end)
            end
            c4Folder = Instance.new("Folder")
            c4Folder.Name = "EldritchC4_" .. tostring(math.random(1000, 9999))
            C4ESP:Clean(c4Folder)
            local root = nil
            pcall(function()
                if type(gethui) == "function" then root = gethui() end
            end)
            if root == nil then
                pcall(function() root = game:GetService("CoreGui") end)
            end
            if root == nil then
                C4ESP:SetEnabled(false)
                return
            end
            c4Folder.Parent = root
            local collection = nil
            pcall(function()
                collection = game:GetService("CollectionService")
            end)
            if collection == nil then
                C4ESP:SetEnabled(false)
                return
            end
            C4ESP:Clean(collection:GetInstanceAddedSignal("C4"):Connect(function(c4)
                task.defer(function()
                    if C4ESP.Enabled then addC4(c4) end
                end)
            end))
            C4ESP:Clean(collection:GetInstanceRemovedSignal("C4"):Connect(function(c4)
                removeC4(c4)
            end))
            local tagged = {}
            pcall(function() tagged = collection:GetTagged("C4") end)
            for _, c4 in ipairs(tagged) do
                addC4(c4)
            end
        else
            if c4Folder ~= nil then
                Base.Window:Untrack(c4Folder)
                pcall(function() c4Folder:Destroy() end)
                c4Folder = nil
            end
            for c4, mark in pairs(c4Refs) do
                pcall(function() mark:Destroy() end)
            end
            table.clear(c4Refs)
        end
    end,
})

addC4 = function(c4)
    if c4Refs[c4] ~= nil then return end
    if c4Folder == nil or c4Folder.Parent == nil then return end
    local ok, mark = pcall(function()
        local cham = Instance.new("Highlight")
        cham.Adornee = c4
        cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        cham.FillColor = Color3.fromRGB(255, 80, 80)
        cham.FillTransparency = 0.5
        cham.OutlineColor = Color3.fromRGB(255, 255, 255)
        cham.OutlineTransparency = 0
        cham.Parent = c4Folder
        return cham
    end)
    if ok and mark ~= nil then
        c4Refs[c4] = mark
    end
end

removeC4 = function(c4)
    local mark = c4Refs[c4]
    if mark == nil then return end
    c4Refs[c4] = nil
    pcall(function() mark:Destroy() end)
end

Base.Window:SelectTab("Prison")

return Base
