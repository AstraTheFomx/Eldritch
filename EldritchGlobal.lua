local EldritchLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/EldritchLib.lua?rev=1"))()
assert(type(EldritchLib) == "table" and type(EldritchLib.CreateWindow) == "function", "EldritchLib failed to load")

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

local Players = getService("Players")
local RunService = getService("RunService")
local UserInputService = getService("UserInputService")
local Lighting = getService("Lighting")
local TeleportService = getService("TeleportService")
local HttpService = getService("HttpService")
local CoreGui = getService("CoreGui")
local VirtualUser = getService("VirtualUser")

if Players == nil or RunService == nil or UserInputService == nil then
    error("EldritchGlobal: required services unavailable")
end

local LocalPlayer = Players.LocalPlayer
if LocalPlayer == nil then
    error("EldritchGlobal: LocalPlayer unavailable")
end

local statsLabel = nil
local playerStatus = nil
local espStatus = nil
local lightStatus = nil
local utilStatus = nil
local serverStatus = nil
local walkToggle = nil
local walkSlider = nil
local walkInput = nil
local jumpSlider = nil
local jumpInput = nil
local flyToggle = nil
local flySlider = nil
local noclipToggle = nil
local infToggle = nil
local gravInput = nil
local fbToggle = nil
local fovSlider = nil
local afkToggle = nil
local methodDrop = nil
local sprintToggle = nil
local sprintSlider = nil
local tpInput = nil
local clickToggle = nil
local voidToggle = nil
local voidSlider = nil
local flingToggle = nil
local nameToggle = nil

local state = {
    walk = { enabled = false, active = false, value = 16, revert = 16, method = "Humanoid" },
    jump = { value = 50, revert = 50, touched = false },
    fly = { enabled = false, active = false, speed = 60 },
    noclip = { enabled = false, active = false },
    infJump = { enabled = false, active = false },
    sprint = { enabled = false, mult = 1.75 },
    antiVoid = { enabled = false, threshold = -50 },
    antiFling = { enabled = false },
    clickTP = { enabled = false },
    gravity = { value = nil, revert = nil },
    fullbright = { enabled = false, active = false, snapshot = nil },
    fov = 70,
    esp = { enabled = false, active = false, teamCheck = true },
    nameESP = { enabled = false, active = false },
    afk = { enabled = false, active = false }
}
local keys = {}

local function clampNumber(value, low, high, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number then return fallback end
    return math.clamp(number, low, high)
end

local function getCharacter()
    local character = LocalPlayer.Character
    if character ~= nil and character.Parent ~= nil then return character end
    return nil
end

local function getHumanoid(character)
    local model = character or getCharacter()
    if model == nil then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid ~= nil and humanoid.Parent ~= nil then return humanoid end
    return nil
end

local function getRoot(character)
    local model = character or getCharacter()
    if model == nil then return nil end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root ~= nil and root.Parent ~= nil then return root end
    return nil
end

local function getCamera()
    local camera = workspace.CurrentCamera
    if camera ~= nil and camera.Parent ~= nil then return camera end
    return nil
end

local function setCollision(model, collide)
    if model == nil then return end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = collide end)
        end
    end
end

local function setWalkEnabled(on)
    state.walk.enabled = (on == true)
    if state.walk.enabled then
        local humanoid = getHumanoid()
        if humanoid ~= nil then
            local current = humanoid.WalkSpeed
            if type(current) == "number" and current == current then
                state.walk.revert = current
            end
        end
        state.walk.active = true
    elseif state.walk.active then
        state.walk.active = false
        local humanoid = getHumanoid()
        if humanoid ~= nil then
            pcall(function() humanoid.WalkSpeed = state.walk.revert end)
        end
        if state.walk.method == "Velocity" then
            local root = getRoot()
            if root ~= nil then
                pcall(function()
                    local velocity = root.AssemblyLinearVelocity
                    root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
                end)
            end
        end
    end
end

local function setJumpValue(value)
    if state.jump.revert == nil then
        state.jump.revert = state.jump.value
    end
    state.jump.value = value
    state.jump.touched = true
end

local function restoreFly()
    local humanoid = getHumanoid()
    if humanoid ~= nil then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end)
    end
    local root = getRoot()
    if root ~= nil then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end)
    end
end

local function setFlyEnabled(on)
    state.fly.enabled = (on == true)
    if state.fly.enabled then
        state.fly.active = true
    elseif state.fly.active then
        state.fly.active = false
        table.clear(keys)
        restoreFly()
    end
end

local function stepFly(dt)
    if not state.fly.enabled then return end
    local humanoid = getHumanoid()
    local root = getRoot()
    local camera = getCamera()
    if humanoid == nil or root == nil or camera == nil then return end
    pcall(function()
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local move = Vector3.new()
        if keys.W then move = move + look end
        if keys.S then move = move - look end
        if keys.D then move = move + right end
        if keys.A then move = move - right end
        if keys.Space or keys.E then move = move + Vector3.new(0, 1, 0) end
        if keys.Q then move = move - Vector3.new(0, 1, 0) end
        if move.Magnitude > 0.001 then
            move = move.Unit
        else
            move = Vector3.new()
        end
        root.CFrame = root.CFrame + move * state.fly.speed * dt
        root.AssemblyLinearVelocity = Vector3.new()
        root.AssemblyAngularVelocity = Vector3.new()
    end)
end

local function setNoclipEnabled(on)
    state.noclip.enabled = (on == true)
    if state.noclip.enabled then
        state.noclip.active = true
    elseif state.noclip.active then
        state.noclip.active = false
        setCollision(getCharacter(), true)
    end
end

local function snapshotLighting()
    if state.fullbright.snapshot ~= nil or Lighting == nil then return end
    local snap = {}
    pcall(function()
        snap.Ambient = Lighting.Ambient
        snap.OutdoorAmbient = Lighting.OutdoorAmbient
        snap.Brightness = Lighting.Brightness
        snap.GlobalShadows = Lighting.GlobalShadows
        snap.FogStart = Lighting.FogStart
        snap.FogEnd = Lighting.FogEnd
    end)
    state.fullbright.snapshot = snap
end

local function disableFullbright()
    local snap = state.fullbright.snapshot
    if Lighting == nil or snap == nil then return end
    pcall(function()
        if snap.Ambient ~= nil then Lighting.Ambient = snap.Ambient end
        if snap.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = snap.OutdoorAmbient end
        if snap.Brightness ~= nil then Lighting.Brightness = snap.Brightness end
        if snap.GlobalShadows ~= nil then Lighting.GlobalShadows = snap.GlobalShadows end
        if snap.FogStart ~= nil then Lighting.FogStart = snap.FogStart end
        if snap.FogEnd ~= nil then Lighting.FogEnd = snap.FogEnd end
    end)
end

local function setFullbrightEnabled(on)
    state.fullbright.enabled = (on == true)
    if state.fullbright.enabled then
        state.fullbright.active = true
        if Lighting == nil then return end
        snapshotLighting()
        pcall(function()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
            Lighting.GlobalShadows = false
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
        end)
    elseif state.fullbright.active then
        state.fullbright.active = false
        disableFullbright()
    end
end

local function setFov(value)
    state.fov = value
    local camera = getCamera()
    if camera ~= nil then
        pcall(function() camera.FieldOfView = value end)
    end
end

local function setClockTime(value)
    if Lighting == nil then return end
    pcall(function() Lighting.ClockTime = value end)
end

local function setGravity(value)
    if state.gravity.revert == nil then
        local current = nil
        pcall(function() current = workspace.Gravity end)
        if type(current) == "number" and current == current then
            state.gravity.revert = current
        else
            state.gravity.revert = 196.2
        end
    end
    state.gravity.value = value
    pcall(function() workspace.Gravity = value end)
end

local function resetGravity()
    local target = state.gravity.revert
    if target == nil then target = 196.2 end
    state.gravity.value = target
    pcall(function() workspace.Gravity = target end)
    if gravInput ~= nil then
        gravInput:Set(tostring(target))
    end
end

pcall(function()
    local humanoid = getHumanoid()
    if humanoid ~= nil then
        local ws = humanoid.WalkSpeed
        if type(ws) == "number" and ws == ws and ws > 0 then
            state.walk.value = math.floor(ws + 0.5)
            state.walk.revert = state.walk.value
        end
        local jp = humanoid.JumpPower
        if type(jp) == "number" and jp == jp and jp >= 0 then
            state.jump.value = math.floor(jp + 0.5)
            state.jump.revert = state.jump.value
        end
    end
    local gravity = workspace.Gravity
    if type(gravity) == "number" and gravity == gravity then
        state.gravity.value = gravity
        state.gravity.revert = gravity
    end
    local camera = getCamera()
    if camera ~= nil then
        local fov = camera.FieldOfView
        if type(fov) == "number" and fov == fov then
            state.fov = math.floor(fov + 0.5)
        end
    end
end)

local startClock = 12
if Lighting ~= nil then
    pcall(function() startClock = Lighting.ClockTime end)
end

local Win = EldritchLib:CreateWindow({
    Title = "Eldritch",
    ToggleKey = Enum.KeyCode.RightShift
})

if type(Win.Track) ~= "function" then
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

local Player = Win:AddTab("Player")
local Visuals = Win:AddTab("Visuals")
local Utility = Win:AddTab("Utility")
local Misc = Win:AddTab("Misc")

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

local function own(list, item)
    table.insert(list, item)
    return Win:Track(item)
end

local function releaseOwned(list)
    for _, item in ipairs(list) do
        Win:Untrack(item)
        if typeof(item) == "RBXScriptConnection" then
            pcall(function() item:Disconnect() end)
        end
    end
    table.clear(list)
end

local infConns = {}

local function setInfJumpEnabled(on)
    state.infJump.enabled = (on == true)
    if state.infJump.enabled then
        state.infJump.active = true
        if #infConns == 0 then
            own(infConns, UserInputService.JumpRequest:Connect(function()
                if not state.infJump.enabled then return end
                local humanoid = getHumanoid()
                if humanoid == nil then return end
                pcall(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end))
        end
    elseif state.infJump.active then
        state.infJump.active = false
        releaseOwned(infConns)
    end
end

local espFolder = nil
local espConns = {}

local function espRoot()
    local parent = nil
    pcall(function()
        if type(gethui) == "function" then parent = gethui() end
    end)
    if parent ~= nil then return parent end
    if CoreGui ~= nil then return CoreGui end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function removeHighlight(player)
    if espFolder == nil then return end
    if espFolder.Parent == nil then return end
    local existing = espFolder:FindFirstChild(player.Name)
    if existing ~= nil then
        pcall(function() existing:Destroy() end)
    end
end

local function syncESP()
    if not state.esp.enabled then return end
    for i = #espConns, 1, -1 do
        local conn = espConns[i]
        local alive = false
        pcall(function() alive = conn.Connected end)
        if not alive then
            Win:Untrack(conn)
            table.remove(espConns, i)
        end
    end
    if espFolder == nil or espFolder.Parent == nil then return end
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LocalPlayer and model ~= nil and model.Parent ~= nil then
            local blocked = state.esp.teamCheck and myTeam ~= nil and player.Team == myTeam
            if blocked then
                removeHighlight(player)
            else
                local existing = espFolder:FindFirstChild(player.Name)
                if existing == nil then
                    local ok, highlight = pcall(function()
                        local mark = Instance.new("Highlight")
                        mark.Name = player.Name
                        mark.Adornee = model
                        mark.FillColor = Color3.fromRGB(255, 122, 197)
                        mark.FillTransparency = 0.5
                        mark.OutlineColor = Color3.fromRGB(255, 255, 255)
                        mark.OutlineTransparency = 0
                        mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        mark.Parent = espFolder
                        return mark
                    end)
                    if ok then existing = highlight end
                end
                if existing ~= nil and existing.Adornee ~= model then
                    pcall(function() existing.Adornee = model end)
                end
            end
        else
            removeHighlight(player)
        end
    end
    for _, child in ipairs(espFolder:GetChildren()) do
        if Players:FindFirstChild(child.Name) == nil then
            pcall(function() child:Destroy() end)
        end
    end
end

local function watchPlayer(player)
    if player == LocalPlayer then return end
    own(espConns, player.CharacterAdded:Connect(function()
        task.defer(syncESP)
    end))
end

local function buildESP()
    local root = espRoot()
    if root == nil then return false end
    if espFolder ~= nil then
        Win:Untrack(espFolder)
        pcall(function() espFolder:Destroy() end)
    end
    espFolder = Instance.new("Folder")
    espFolder.Name = "EldritchESP_" .. tostring(math.random(1000, 9999))
    Win:Track(espFolder)
    espFolder.Parent = root
    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayer(player)
    end
    syncESP()
    return true
end

local function disableESP()
    releaseOwned(espConns)
    if espFolder ~= nil then
        Win:Untrack(espFolder)
        pcall(function() espFolder:Destroy() end)
        espFolder = nil
    end
end

local function setESPEnabled(on)
    state.esp.enabled = (on == true)
    if state.esp.enabled then
        state.esp.active = true
        if not buildESP() then
            state.esp.enabled = false
            state.esp.active = false
            if espStatus ~= nil then espStatus:Set("ESP unavailable") end
        end
    elseif state.esp.active then
        state.esp.active = false
        disableESP()
        if espStatus ~= nil then espStatus:Set("Tracked: 0") end
    end
end

local afkConns = {}

local function setAfkEnabled(on)
    state.afk.enabled = (on == true)
    if state.afk.enabled then
        if VirtualUser == nil then
            state.afk.enabled = false
            if afkToggle ~= nil then afkToggle:Set(false) end
            if utilStatus ~= nil then utilStatus:Set("Anti-AFK unavailable") end
            return
        end
        state.afk.active = true
        if #afkConns == 0 then
            own(afkConns, LocalPlayer.Idled:Connect(function()
                if not state.afk.enabled then return end
                local camera = getCamera()
                if camera == nil then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:Button2Down(Vector2.new(), camera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(), camera.CFrame)
                end)
            end))
        end
        if utilStatus ~= nil then utilStatus:Set("Anti-AFK on") end
    elseif state.afk.active then
        state.afk.active = false
        releaseOwned(afkConns)
        if utilStatus ~= nil then utilStatus:Set("Anti-AFK off") end
    end
end

local function getSpawnCFrame()
    local spawn = nil
    pcall(function() spawn = workspace:FindFirstChildOfClass("SpawnLocation") end)
    if spawn ~= nil then
        return spawn.CFrame + Vector3.new(0, 5, 0)
    end
    return CFrame.new(0, 50, 0)
end

local function teleportToSpawn()
    local character = getCharacter()
    if character == nil then return false end
    local root = getRoot(character)
    pcall(function()
        character:PivotTo(getSpawnCFrame())
        if root ~= nil then
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end)
    return true
end

local function findPlayer(query)
    if query == nil or query == "" then return nil end
    local q = string.lower(tostring(query))
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and string.sub(string.lower(player.Name), 1, string.len(q)) == q then
            return player
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local display = player.DisplayName
        if player ~= LocalPlayer and type(display) == "string" and string.sub(string.lower(display), 1, string.len(q)) == q then
            return player
        end
    end
    return nil
end

local function teleportToPlayer(query)
    local target = findPlayer(query)
    if target == nil then return false end
    local character = getCharacter()
    local troot = getRoot(target.Character)
    if character == nil or troot == nil then return false end
    local root = getRoot(character)
    pcall(function()
        character:PivotTo(troot.CFrame + Vector3.new(0, 0, 5))
        if root ~= nil then
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end)
    return true
end

local function clickTeleport()
    local camera = getCamera()
    local character = getCharacter()
    if camera == nil or character == nil then return false end
    local pointer = UserInputService:GetMouseLocation()
    local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if hit == nil then return false end
    local root = getRoot(character)
    pcall(function()
        character:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 5, 0)))
        if root ~= nil then
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end)
    return true
end

local nameTags = {}
local nameConns = {}

local function removeNameTag(player)
    local tag = nameTags[player.Name]
    if tag == nil then return end
    nameTags[player.Name] = nil
    Win:Untrack(tag)
    pcall(function() tag:Destroy() end)
end

local function updateTagText(tag, player)
    local label = tag:FindFirstChild("Text")
    if label == nil then return end
    local text = player.Name
    local myRoot = getRoot()
    local theirRoot = getRoot(player.Character)
    if myRoot ~= nil and theirRoot ~= nil then
        local distance = (myRoot.Position - theirRoot.Position).Magnitude
        text = text .. " [" .. tostring(math.floor(distance + 0.5)) .. "m]"
    end
    pcall(function() label.Text = text end)
end

local function ensureNameTag(player, model)
    local head = model:FindFirstChild("Head")
    if head == nil then return end
    local tag = nameTags[player.Name]
    if tag ~= nil and tag.Parent ~= nil and tag.Adornee == head then
        updateTagText(tag, player)
        return
    end
    removeNameTag(player)
    local ok, gui = pcall(function()
        local board = Instance.new("BillboardGui")
        board.Name = "EldritchName"
        board.Adornee = head
        board.Size = UDim2.new(0, 200, 0, 40)
        board.StudsOffset = Vector3.new(0, 2.5)
        board.AlwaysOnTop = true
        board.MaxDistance = 1000
        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 231, 243)
        label.TextStrokeTransparency = 0.5
        label.Text = player.Name
        label.Parent = board
        board.Parent = head
        return board
    end)
    if ok and gui ~= nil then
        nameTags[player.Name] = Win:Track(gui)
        updateTagText(gui, player)
    end
end

local function syncNameTags()
    if not state.nameESP.enabled then return end
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LocalPlayer and model ~= nil and model.Parent ~= nil then
            local blocked = state.esp.teamCheck and myTeam ~= nil and player.Team == myTeam
            if blocked then
                removeNameTag(player)
            else
                ensureNameTag(player, model)
            end
        else
            removeNameTag(player)
        end
    end
    for name, _ in pairs(nameTags) do
        if Players:FindFirstChild(name) == nil then
            removeNameTag({ Name = name })
        end
    end
end

local function watchNameTag(player)
    if player == LocalPlayer then return end
    own(nameConns, player.CharacterAdded:Connect(function(model)
        task.defer(function()
            if state.nameESP.enabled and model ~= nil then
                ensureNameTag(player, model)
            end
        end)
    end))
end

local function setNameESPEnabled(on)
    state.nameESP.enabled = (on == true)
    if state.nameESP.enabled then
        state.nameESP.active = true
        for _, player in ipairs(Players:GetPlayers()) do
            watchNameTag(player)
        end
        syncNameTags()
    elseif state.nameESP.active then
        state.nameESP.active = false
        releaseOwned(nameConns)
        for _, player in ipairs(Players:GetPlayers()) do
            removeNameTag(player)
        end
        for name, _ in pairs(nameTags) do
            removeNameTag({ Name = name })
        end
    end
end

Player:AddSection("Movement")
playerStatus = Player:AddLabel("Ready")

walkToggle = Player:AddToggle("Enable WalkSpeed", false, function(v)
    setWalkEnabled(v)
    if playerStatus ~= nil then
        if v then
            playerStatus:Set("WalkSpeed enforced")
        else
            playerStatus:Set("WalkSpeed restored")
        end
    end
end)

walkInput = Player:AddInput("WalkSpeed:", tostring(state.walk.value), function(v)
    local number = clampNumber(v, 0, 500, nil)
    if number == nil then
        walkInput:Set(tostring(state.walk.value))
        return
    end
    state.walk.value = math.floor(number + 0.5)
    if walkSlider ~= nil then walkSlider:Set(state.walk.value) end
end)

walkSlider = Player:AddSlider("WalkSpeed", 0, 500, state.walk.value, function(v)
    state.walk.value = math.floor(v + 0.5)
    if walkInput ~= nil then walkInput:Set(tostring(state.walk.value)) end
end)

jumpInput = Player:AddInput("JumpPower:", tostring(state.jump.value), function(v)
    local number = clampNumber(v, 0, 500, nil)
    if number == nil then
        jumpInput:Set(tostring(state.jump.value))
        return
    end
    setJumpValue(math.floor(number + 0.5))
    if jumpSlider ~= nil then jumpSlider:Set(state.jump.value) end
end)

jumpSlider = Player:AddSlider("JumpPower", 0, 500, state.jump.value, function(v)
    setJumpValue(math.floor(v + 0.5))
    if jumpInput ~= nil then jumpInput:Set(tostring(state.jump.value)) end
end)

methodDrop = Player:AddDropdown("Speed Method", {"Humanoid", "Velocity"}, "Humanoid", function(v)
    state.walk.method = tostring(v)
end)

flyToggle = Player:AddToggle("Enable Fly", false, function(v)
    setFlyEnabled(v)
    if playerStatus ~= nil then
        if v then
            playerStatus:Set("Fly on: WASD + Space/Q")
        else
            playerStatus:Set("Fly off")
        end
    end
end)

flySlider = Player:AddSlider("Fly Speed", 1, 300, state.fly.speed, function(v)
    state.fly.speed = math.floor(v + 0.5)
end)

Player:AddSection("Sprint")
sprintToggle = Player:AddToggle("Sprint (Hold Shift)", false, function(v)
    state.sprint.enabled = (v == true)
end)

sprintSlider = Player:AddSlider("Sprint Boost %", 100, 400, 175, function(v)
    state.sprint.mult = math.floor(v + 0.5) / 100
end)

noclipToggle = Player:AddToggle("Noclip", false, function(v)
    setNoclipEnabled(v)
    if playerStatus ~= nil then
        if v then
            playerStatus:Set("Noclip on")
        else
            playerStatus:Set("Noclip off")
        end
    end
end)

infToggle = Player:AddToggle("Infinite Jump", false, function(v)
    setInfJumpEnabled(v)
    if playerStatus ~= nil then
        if v then
            playerStatus:Set("Infinite Jump on")
        else
            playerStatus:Set("Infinite Jump off")
        end
    end
end)

Player:AddSection("Teleport")
Player:AddButton("Teleport to Spawn", function()
    local moved = teleportToSpawn()
    if playerStatus ~= nil then
        if moved then
            playerStatus:Set("Teleported to spawn")
        else
            playerStatus:Set("Teleport failed")
        end
    end
end)

tpInput = Player:AddInput("Player Name:", "", function(v)
end)

Player:AddButton("Teleport to Player", function()
    local target = ""
    if tpInput ~= nil then target = tpInput:Get() end
    local moved = teleportToPlayer(target)
    if playerStatus ~= nil then
        if moved then
            playerStatus:Set("Teleported to " .. target)
        else
            playerStatus:Set("Player not found")
        end
    end
end)

clickToggle = Player:AddToggle("Click TP (Ctrl+Click)", false, function(v)
    state.clickTP.enabled = (v == true)
end)

Player:AddSection("Protection")
voidToggle = Player:AddToggle("Anti-Void", false, function(v)
    state.antiVoid.enabled = (v == true)
end)

voidSlider = Player:AddSlider("Void Height", -500, 0, state.antiVoid.threshold, function(v)
    state.antiVoid.threshold = math.floor(v + 0.5)
end)

flingToggle = Player:AddToggle("Anti-Fling", false, function(v)
    state.antiFling.enabled = (v == true)
end)

gravInput = Player:AddInput("Gravity:", tostring(state.gravity.value or 196.2), function(v)
    local number = clampNumber(v, 0, 500, nil)
    if number == nil then
        gravInput:Set(tostring(state.gravity.value or 196.2))
        return
    end
    setGravity(number)
end)

Player:AddButton("Respawn", function()
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    if humanoid ~= nil then
        pcall(function() humanoid.Health = 0 end)
    elseif character ~= nil then
        pcall(function() character:BreakJoints() end)
    end
end)

Player:AddButton("Reset Movement", function()
    setWalkEnabled(false)
    setFlyEnabled(false)
    setNoclipEnabled(false)
    setInfJumpEnabled(false)
    state.sprint.enabled = false
    state.antiVoid.enabled = false
    state.antiFling.enabled = false
    state.clickTP.enabled = false
    state.jump.touched = false
    local humanoid = getHumanoid()
    if humanoid ~= nil then
        pcall(function()
            humanoid.WalkSpeed = state.walk.revert
            humanoid.JumpPower = state.jump.revert
        end)
    end
    resetGravity()
    if walkToggle ~= nil then walkToggle:Set(false) end
    if flyToggle ~= nil then flyToggle:Set(false) end
    if noclipToggle ~= nil then noclipToggle:Set(false) end
    if infToggle ~= nil then infToggle:Set(false) end
    if sprintToggle ~= nil then sprintToggle:Set(false) end
    if voidToggle ~= nil then voidToggle:Set(false) end
    if flingToggle ~= nil then flingToggle:Set(false) end
    if clickToggle ~= nil then clickToggle:Set(false) end
    if walkSlider ~= nil then walkSlider:Set(state.walk.value) end
    if walkInput ~= nil then walkInput:Set(tostring(state.walk.value)) end
    if jumpSlider ~= nil then jumpSlider:Set(state.jump.value) end
    if jumpInput ~= nil then jumpInput:Set(tostring(state.jump.value)) end
    if playerStatus ~= nil then playerStatus:Set("Movement reset") end
end)

Visuals:AddSection("ESP")
espStatus = Visuals:AddLabel("Tracked: 0")

Visuals:AddToggle("Enable ESP", false, function(v)
    setESPEnabled(v)
end)

Visuals:AddToggle("Team Check", true, function(v)
    state.esp.teamCheck = (v == true)
end)

nameToggle = Visuals:AddToggle("Name ESP", false, function(v)
    setNameESPEnabled(v)
end)

Visuals:AddSection("Lighting")
lightStatus = Visuals:AddLabel("Lighting default")

fbToggle = Visuals:AddToggle("Fullbright", false, function(v)
    setFullbrightEnabled(v)
    if lightStatus ~= nil then
        if v then
            lightStatus:Set("Fullbright on")
        else
            lightStatus:Set("Lighting restored")
        end
    end
end)

fovSlider = Visuals:AddSlider("Field of View", 30, 120, state.fov, function(v)
    setFov(math.floor(v + 0.5))
end)

Visuals:AddSlider("Clock Time", 0, 24, startClock, function(v)
    setClockTime(v)
end)

Visuals:AddButton("Reset Lighting", function()
    setFullbrightEnabled(false)
    setFov(70)
    if fbToggle ~= nil then fbToggle:Set(false) end
    if fovSlider ~= nil then fovSlider:Set(70) end
    if lightStatus ~= nil then lightStatus:Set("Lighting restored") end
end)

Utility:AddSection("Session")
statsLabel = Utility:AddLabel("FPS: ...  Players: ...")
utilStatus = Utility:AddLabel("Idle")

afkToggle = Utility:AddToggle("Anti-AFK", false, function(v)
    setAfkEnabled(v)
end)

Utility:AddSection("Server")
serverStatus = Utility:AddLabel("Idle")
Utility:AddLabel("Place: " .. tostring(game.PlaceId))
Utility:AddLabel("Job: " .. tostring(game.JobId))

Utility:AddButton("Rejoin Server", function()
    local ok = pcall(function()
        if TeleportService == nil then error("teleport unavailable") end
        if game.JobId ~= nil and game.JobId ~= "" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
    if serverStatus ~= nil then
        if ok then
            serverStatus:Set("Rejoining...")
        else
            serverStatus:Set("Rejoin failed")
        end
    end
end)

Utility:AddButton("Server Hop", function()
    if serverStatus ~= nil then serverStatus:Set("Searching...") end
    local ok = pcall(function()
        if TeleportService == nil then error("teleport unavailable") end
        if HttpService == nil then error("http unavailable") end
        if game.PlaceId == 0 then error("invalid place") end
        local cursor = ""
        local currentJob = game.JobId
        for _ = 1, 3 do
            local extra = ""
            if cursor ~= "" then extra = "&cursor=" .. cursor end
            local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100" .. extra
            local body = game:HttpGet(url)
            local data = HttpService:JSONDecode(body)
            if type(data) ~= "table" then error("bad response") end
            local servers = data.data
            if type(servers) == "table" then
                for _, server in ipairs(servers) do
                    if type(server) == "table" and server.id ~= currentJob and tonumber(server.playing) ~= nil and tonumber(server.maxPlayers) ~= nil and tonumber(server.playing) < tonumber(server.maxPlayers) then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                        return
                    end
                end
            end
            if type(data.nextPageCursor) == "string" then
                cursor = data.nextPageCursor
            else
                cursor = ""
            end
            if cursor == "" then break end
        end
        error("no open servers")
    end)
    if not ok and serverStatus ~= nil then
        serverStatus:Set("Server hop failed")
    end
end)

Utility:AddButton("Copy JobId", function()
    if type(setclipboard) == "function" then
        local ok = pcall(function() setclipboard(game.JobId) end)
        if serverStatus ~= nil then
            if ok then
                serverStatus:Set("JobId copied")
            else
                serverStatus:Set("Copy failed")
            end
        end
    elseif serverStatus ~= nil then
        serverStatus:Set("Copy unavailable")
    end
end)

Utility:AddButton("Copy PlaceId", function()
    if type(setclipboard) == "function" then
        local ok = pcall(function() setclipboard(tostring(game.PlaceId)) end)
        if serverStatus ~= nil then
            if ok then
                serverStatus:Set("PlaceId copied")
            else
                serverStatus:Set("Copy failed")
            end
        end
    elseif serverStatus ~= nil then
        serverStatus:Set("Copy unavailable")
    end
end)

Misc:AddSection("Window")
Misc:AddButton("Hide UI (RightShift to show)", function()
    Win:SetVisible(false)
end)

Misc:AddButton("Unload Script", function()
    Win:Destroy()
end)

Misc:AddLabel("ToggleKey: RightShift")
Misc:AddLabel("Universal build")

Win:Track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() ~= nil then return end
    if input.KeyCode ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown then
        keys[input.KeyCode.Name] = true
    end
    if state.clickTP.enabled and (keys.LeftControl or keys.RightControl) and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local moved = clickTeleport()
        if playerStatus ~= nil then
            if moved then
                playerStatus:Set("Teleported")
            else
                playerStatus:Set("Teleport failed")
            end
        end
    end
end))

Win:Track(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown then
        keys[input.KeyCode.Name] = false
    end
end))

Win:Track(Players.PlayerAdded:Connect(function(player)
    if state.esp.enabled then
        watchPlayer(player)
        task.defer(syncESP)
    end
    if state.nameESP.enabled then
        watchNameTag(player)
        task.defer(syncNameTags)
    end
end))

Win:Track(Players.PlayerRemoving:Connect(function(player)
    if state.esp.enabled then
        removeHighlight(player)
    end
    if state.nameESP.enabled then
        removeNameTag(player)
    end
end))

local fpsValue = 60
local espAcc = 0
local statAcc = 0

Win:Track(RunService.Heartbeat:Connect(function(dt)
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 or dt > 1 then
        dt = 0.016
    end
    fpsValue = fpsValue * 0.9 + (1 / dt) * 0.1
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    if state.walk.enabled and humanoid ~= nil then
        local effective = state.walk.value
        if state.sprint.enabled and keys.LeftShift and humanoid.MoveDirection.Magnitude > 0.1 then
            effective = effective * state.sprint.mult
        end
        if state.walk.method == "Velocity" then
            local root = getRoot(character)
            if root ~= nil then
                local direction = humanoid.MoveDirection
                if direction.Magnitude > 0.1 then
                    pcall(function()
                        local velocity = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(direction.X * effective, velocity.Y, direction.Z * effective)
                    end)
                end
            end
        else
            pcall(function() humanoid.WalkSpeed = effective end)
        end
    end
    if state.antiVoid.enabled and character ~= nil then
        local root = getRoot(character)
        if root ~= nil and root.Position.Y < state.antiVoid.threshold then
            pcall(function()
                character:PivotTo(getSpawnCFrame())
                root.AssemblyLinearVelocity = Vector3.new()
            end)
        end
    end
    if state.antiFling.enabled then
        local root = getRoot(character)
        if root ~= nil then
            pcall(function()
                local velocity = root.AssemblyLinearVelocity
                if velocity.Magnitude > 100 then
                    root.AssemblyLinearVelocity = velocity.Unit * 100
                end
            end)
        end
    end
    if state.jump.touched and humanoid ~= nil and humanoid.JumpPower ~= state.jump.value then
        pcall(function() humanoid.JumpPower = state.jump.value end)
    end
    if state.noclip.enabled and character ~= nil then
        setCollision(character, false)
    end
    stepFly(dt)
    espAcc = espAcc + dt
    if espAcc >= 0.5 then
        espAcc = 0
        if state.esp.enabled then
            pcall(syncESP)
            if espFolder ~= nil and espFolder.Parent ~= nil and espStatus ~= nil then
                espStatus:Set("Tracked: " .. tostring(#espFolder:GetChildren()))
            end
        end
        if state.nameESP.enabled then
            pcall(syncNameTags)
        end
    end
    statAcc = statAcc + dt
    if statAcc >= 0.5 then
        statAcc = 0
        if statsLabel ~= nil then
            local total = 0
            pcall(function() total = #Players:GetPlayers() end)
            statsLabel:Set("FPS: " .. tostring(math.floor(fpsValue + 0.5)) .. "  Players: " .. tostring(total))
        end
    end
end))

Win:SelectTab("Player")
