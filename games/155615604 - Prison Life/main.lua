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

local Combat = Base:CreateCategory("Combat")
Combat.Tab:AddSubsection("Guns")

local combatStatus = Combat.Tab:AddLabel("Idle")

local gunLinks = { Shoot = nil, Bullet = nil }

local function resolveGuns(status)
    if gunLinks.Bullet ~= nil then return true end
    if type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
        if status ~= nil then status:Set("debug API missing") end
        return false
    end
    local home = nil
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg ~= nil then
            home = pg:WaitForChild("Home", 5)
        end
    end)
    if home == nil then
        if status ~= nil then status:Set("Home GUI missing") end
        return false
    end
    local area = nil
    pcall(function() area = home.hud.ActionArea end)
    if area == nil then
        if status ~= nil then status:Set("ActionArea missing") end
        return false
    end
    local conns = {}
    pcall(function() conns = getconnections(area.InputBegan) end)
    for _, c in ipairs(conns) do
        local fn = c.Function
        if type(fn) == "function" then
            local ok, shoot = pcall(debug.getupvalue, fn, 2)
            if ok and type(shoot) == "function" then
                gunLinks.Shoot = shoot
                break
            end
        end
    end
    if gunLinks.Shoot == nil then
        if status ~= nil then status:Set("Shoot fn missing") end
        return false
    end
    local okB, bullet = pcall(debug.getupvalue, gunLinks.Shoot, 16)
    if okB and type(bullet) == "function" then
        gunLinks.Bullet = bullet
    end
    if gunLinks.Bullet == nil then
        if status ~= nil then status:Set("Bullet fn missing") end
        return false
    end
    return true
end

local function gunData()
    if gunLinks.Shoot == nil then return nil end
    local ok, data = pcall(debug.getupvalue, gunLinks.Shoot, 10)
    if ok and type(data) == "table" then return data end
    return nil
end

local function combatTarget(player, model)
    if player == LocalPlayer then return false end
    if model == nil or model.Parent == nil then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid == nil or humanoid.Health <= 0 then return false end
    local shielded = false
    pcall(function()
        shielded = model:FindFirstChildWhichIsA("ForceField") ~= nil
    end)
    if shielded then return false end
    local myTeam = teamName(LocalPlayer)
    local theirTeam = teamName(player)
    if myTeam ~= "" and myTeam == theirTeam then return false end
    return true
end

local function playerFromHit(hit)
    local node = hit
    while node ~= nil do
        local owner = nil
        pcall(function() owner = Players:GetPlayerFromCharacter(node) end)
        if owner ~= nil then return owner end
        if node == workspace then return nil end
        node = node.Parent
    end
    return nil
end

local saFov, saHit, saHead, saRange = 150, 85, 65, 500
local function pickAimTarget(origin)
    if origin == nil or typeof(origin) ~= "Vector3" then return nil end
    if math.random(1, 100) > saHit then return nil end
    local camera = Entity.Camera()
    if camera == nil then return nil end
    local mouse = Services.UserInputService:GetMouseLocation()
    local useHead = math.random(1, 100) <= saHead
    local bestPos, bestDist = nil, saFov
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if combatTarget(player, model) then
            local part = model:FindFirstChild(useHead and "Head" or "HumanoidRootPart")
            if part ~= nil then
                local dist3d = (part.Position - origin).Magnitude
                if dist3d <= saRange then
                    local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d2 = (Vector2.new(pos.X, pos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                        if d2 <= bestDist then
                            bestPos, bestDist = part.Position, d2
                        end
                    end
                end
            end
        end
    end
    return bestPos
end

local oldBullet = nil
local SilentAim = Combat:CreateModule({
    Name = "SilentAim",
    Function = function(on)
        if on then
            if type(hookfunction) ~= "function" then
                combatStatus:Set("hookfunction missing")
                SilentAim:SetEnabled(false)
                return
            end
            if not resolveGuns(combatStatus) then
                SilentAim:SetEnabled(false)
                return
            end
            SilentAim:Clean(function()
                if oldBullet ~= nil then
                    if type(restorefunction) == "function" then
                        pcall(restorefunction, gunLinks.Bullet)
                    else
                        pcall(hookfunction, gunLinks.Bullet, oldBullet)
                    end
                    oldBullet = nil
                end
            end)
            oldBullet = hookfunction(gunLinks.Bullet, function(origin, direction, ...)
                if not SilentAim.Enabled then
                    return oldBullet(origin, direction, ...)
                end
                local point = pickAimTarget(origin)
                if point == nil then
                    return oldBullet(origin, direction, ...)
                end
                local args = table.pack(origin, direction, ...)
                args[2] = point
                return oldBullet(table.unpack(args, 1, args.n))
            end)
            combatStatus:Set("SilentAim hooked")
        else
            if oldBullet ~= nil then
                if type(restorefunction) == "function" then
                    pcall(restorefunction, gunLinks.Bullet)
                else
                    pcall(hookfunction, gunLinks.Bullet, oldBullet)
                end
                oldBullet = nil
            end
            combatStatus:Set("SilentAim off")
        end
    end,
})
SilentAim:CreateSlider("FOV", 50, 500, 150, function(v)
    saFov = math.floor(v + 0.5)
end)
SilentAim:CreateSlider("Hit Chance", 0, 100, 85, function(v)
    saHit = math.floor(v + 0.5)
end)
SilentAim:CreateSlider("Headshot", 0, 100, 65, function(v)
    saHead = math.floor(v + 0.5)
end)
SilentAim:CreateSlider("Range", 50, 1500, 500, function(v)
    saRange = math.floor(v + 0.5)
end)

local tbRange = 500
local vimSvc = nil
local TriggerBot = Combat:CreateModule({
    Name = "TriggerBot",
    Function = function(on)
        if on then
            if vimSvc == nil then
                pcall(function() vimSvc = game:GetService("VirtualInputManager") end)
            end
            if vimSvc == nil then
                combatStatus:Set("VirtualInput missing")
                TriggerBot:SetEnabled(false)
                return
            end
            combatStatus:Set("TriggerBot on")
        else
            combatStatus:Set("TriggerBot off")
        end
    end,
})
TriggerBot:CreateSlider("Range", 50, 1500, 500, function(v)
    tbRange = math.floor(v + 0.5)
end)
local tbAcc = 0
Base:Step(function(dt)
    if not TriggerBot.Enabled or vimSvc == nil then return end
    tbAcc = tbAcc + dt
    if tbAcc < 0.05 then return end
    tbAcc = 0
    if not Entity.Alive() then return end
    local camera = Entity.Camera()
    if camera == nil then return end
    local pointer = Services.UserInputService:GetMouseLocation()
    local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = Entity.Character()
    if character ~= nil then
        params.FilterDescendantsInstances = { character }
    end
    local hit = nil
    pcall(function()
        hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
    end)
    if hit == nil or hit.Instance == nil then return end
    if (hit.Position - ray.Origin).Magnitude > tbRange then return end
    local owner = playerFromHit(hit.Instance)
    if owner == nil then return end
    if not combatTarget(owner, owner.Character) then return end
    pcall(function()
        vimSvc:SendMouseButtonEvent(pointer.X, pointer.Y, 0, true, game, 1)
        vimSvc:SendMouseButtonEvent(pointer.X, pointer.Y, 0, false, game, 1)
    end)
end)

local kaRange, kaMax, kaFace = 12, 3, false
local Killaura = Combat:CreateModule({
    Name = "Killaura",
    Function = function(on)
        if on then
            combatStatus:Set("Killaura on")
        else
            combatStatus:Set("Killaura off")
        end
    end,
})
Killaura:CreateSlider("Range", 1, 12, 12, function(v)
    kaRange = math.floor(v + 0.5)
end)
Killaura:CreateSlider("Max Targets", 1, 5, 3, function(v)
    kaMax = math.floor(v + 0.5)
end)
Killaura:CreateToggle("Face Target", false, function(v)
    kaFace = (v == true)
end)
local kaAcc = 0
Base:Step(function(dt)
    if not Killaura.Enabled then return end
    kaAcc = kaAcc + dt
    if kaAcc < 0.1 then return end
    kaAcc = 0
    if not Entity.Alive() then return end
    local character = Entity.Character()
    local root = Entity.Root(character)
    if character == nil or root == nil then return end
    local melee = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        if rs ~= nil then melee = rs:FindFirstChild("meleeEvent") end
    end)
    if melee == nil then return end
    local scored = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if combatTarget(player, model) then
            local troot = Entity.Root(model)
            if troot ~= nil then
                local delta = troot.Position - root.Position
                local dist = delta.Magnitude
                if dist <= kaRange and dist > 0.5 then
                    local flatFace = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                    local flatDelta = delta * Vector3.new(1, 0, 1)
                    if flatFace.Magnitude > 0.01 and flatDelta.Magnitude > 0.01 then
                        local angle = math.acos(math.clamp(flatFace.Unit:Dot(flatDelta.Unit), -1, 1))
                        if angle <= math.rad(180) then
                            local myTeam = teamName(LocalPlayer)
                            local skip = myTeam == "Guards" and teamName(player) == "Inmates"
                            if skip then
                                local hostile = false
                                pcall(function() hostile = model:GetAttribute("Hostile") == true end)
                                skip = not hostile
                            end
                            if not skip then
                                table.insert(scored, { player = player, dist = dist, root = troot })
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(scored, function(a, b) return a.dist < b.dist end)
    local hitAny = false
    for i = 1, math.min(kaMax, #scored) do
        pcall(function() melee:FireServer(scored[i].player, 1, 1) end)
        hitAny = true
    end
    if hitAny and kaFace and scored[1] ~= nil then
        pcall(function()
            local vec = scored[1].root.Position * Vector3.new(1, 0, 1)
            root.CFrame = CFrame.lookAt(root.Position, Vector3.new(vec.X, root.Position.Y + 0.01, vec.Z))
        end)
    end
end)

local gmSpread, gmRate, gmAuto = true, 100, false
local gmSnap = nil
local applyGunMods = nil
local GunModifications = Combat:CreateModule({
    Name = "GunModifications",
    Function = function(on)
        if on then
            if not resolveGuns(combatStatus) then
                GunModifications:SetEnabled(false)
                return
            end
            applyGunMods()
            combatStatus:Set("Gun mods applied")
        else
            if gmSnap ~= nil then
                local data = gunData()
                if data ~= nil then
                    pcall(function()
                        for k, v in pairs(gmSnap) do
                            data[k] = v
                        end
                    end)
                end
                gmSnap = nil
            end
            combatStatus:Set("Gun mods off")
        end
    end,
})
GunModifications:CreateToggle("No Spread", true, function(v)
    gmSpread = (v == true)
    if GunModifications.Enabled then applyGunMods() end
end)
GunModifications:CreateSlider("Fire Rate %", 1, 300, 100, function(v)
    gmRate = math.floor(v + 0.5)
    if GunModifications.Enabled then applyGunMods() end
end)
GunModifications:CreateToggle("Full Auto", false, function(v)
    gmAuto = (v == true)
    if GunModifications.Enabled then applyGunMods() end
end)
local gmLastTool = ""
local gmAcc = 0
Base:Step(function(dt)
    if not GunModifications.Enabled then return end
    gmAcc = gmAcc + dt
    if gmAcc < 0.5 then return end
    gmAcc = 0
    if equippedToolName() ~= gmLastTool then
        gmLastTool = equippedToolName()
        applyGunMods()
    end
end)

applyGunMods = function()
    local data = gunData()
    if data == nil then return end
    if gmSnap == nil then
        local snap = {}
        pcall(function()
            snap.SpreadRadius = data.SpreadRadius
            snap.FireRate = data.FireRate
            snap.AutoFire = data.AutoFire
        end)
        gmSnap = snap
    end
    pcall(function()
        if gmSpread then data.SpreadRadius = 0 end
        if type(gmSnap.FireRate) == "number" then
            data.FireRate = gmSnap.FireRate * (gmRate / 100)
        end
        if gmAuto then data.AutoFire = true end
    end)
end

Prison.Tab:AddSubsection("Tasers")

local tazeStatus = Prison.Tab:AddLabel("Idle")
local antiTazeOld, antiTazeFn = nil, nil
local AntiTaze = Prison:CreateModule({
    Name = "AntiTaze",
    Function = function(on)
        if on then
            if type(getconnections) ~= "function" or type(hookfunction) ~= "function" then
                tazeStatus:Set("hook API missing")
                AntiTaze:SetEnabled(false)
                return
            end
            local remotes = getRemotes()
            local event = nil
            if remotes ~= nil then
                pcall(function()
                    local guns = remotes.Parent:FindFirstChild("GunRemotes")
                    if guns ~= nil then event = guns:FindFirstChild("PlayerTased") end
                end)
            end
            if event == nil then
                pcall(function()
                    local guns = game:GetService("ReplicatedStorage"):FindFirstChild("GunRemotes")
                    if guns ~= nil then event = guns:FindFirstChild("PlayerTased") end
                end)
            end
            if event == nil then
                tazeStatus:Set("Taser remote missing")
                AntiTaze:SetEnabled(false)
                return
            end
            local conns = {}
            pcall(function() conns = getconnections(event.OnClientEvent) end)
            local fn = nil
            for _, c in ipairs(conns) do
                if type(c.Function) == "function" then
                    fn = c.Function
                    break
                end
            end
            if fn == nil then
                tazeStatus:Set("Taser handler missing")
                AntiTaze:SetEnabled(false)
                return
            end
            antiTazeFn = fn
            antiTazeOld = hookfunction(fn, function()
                pcall(function() LocalPlayer:SetAttribute("BackpackEnabled", false) end)
                local humanoid = Entity.Humanoid()
                if humanoid ~= nil then
                    pcall(function() humanoid:UnequipTools() end)
                end
            end)
            AntiTaze:Clean(function()
                if antiTazeFn ~= nil and antiTazeOld ~= nil then
                    pcall(hookfunction, antiTazeFn, antiTazeOld)
                end
            end)
            tazeStatus:Set("AntiTaze armed")
        else
            if antiTazeFn ~= nil and antiTazeOld ~= nil then
                pcall(hookfunction, antiTazeFn, antiTazeOld)
                antiTazeOld, antiTazeFn = nil, nil
            end
            tazeStatus:Set("AntiTaze off")
        end
    end,
})

local tzRange, tzMoving = 52, true
local tzAcc = 0
local AutoTaze = Prison:CreateModule({
    Name = "AutoTaze",
    Function = function(on)
        if on then
            tazeStatus:Set("AutoTaze on")
        else
            tazeStatus:Set("AutoTaze off")
        end
    end,
})
AutoTaze:CreateSlider("Range", 1, 52, 52, function(v)
    tzRange = math.floor(v + 0.5)
end)
AutoTaze:CreateToggle("Target Check", true, function(v)
    tzMoving = (v == true)
end)
Base:Step(function(dt)
    if not AutoTaze.Enabled then return end
    tzAcc = tzAcc + dt
    if tzAcc < 0.1 then return end
    tzAcc = 0
    if not Entity.Alive() then return end
    local pack = findBackpack()
    local taser = nil
    if pack ~= nil then
        pcall(function() taser = pack:FindFirstChild("Taser") end)
    end
    if taser == nil then return end
    local ammo = 1
    pcall(function() ammo = taser:GetAttribute("CurrentAmmo") or 1 end)
    if ammo <= 0 then return end
    local character = Entity.Character()
    local root = Entity.Root(character)
    if character == nil or root == nil then return end
    if tzMoving then
        local velocity = root.AssemblyLinearVelocity
        if velocity.Magnitude >= 40 then return end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if combatTarget(player, model) then
            local tased, arrested = false, false
            pcall(function()
                tased = model:GetAttribute("Tased") == true
                arrested = model:GetAttribute("Arrested") == true
            end)
            if not tased and not arrested then
                local troot = Entity.Root(model)
                if troot ~= nil and (troot.Position - root.Position).Magnitude <= tzRange then
                    local humanoid = Entity.Humanoid(character)
                    if humanoid ~= nil then
                        pcall(function() humanoid:EquipTool(taser) end)
                    end
                    return
                end
            end
        end
    end
end)

Base.Window:SelectTab("Prison")

return Base
