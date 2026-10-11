local BASE_URL = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/EldritchBase.lua?rev=2"
local LOADER_URL = ""

local Base = loadstring(game:HttpGet(BASE_URL))()
Base:Start("Eldritch")

local Services = Base.Services
local Entity = Base.Entity
local LocalPlayer = Base.LocalPlayer
local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local Lighting = Services.Lighting
local TeleportService = Services.TeleportService
local HttpService = Services.HttpService
local CoreGui = Services.CoreGui
local VirtualUser = Services.VirtualUser

local Blatant = Base.Categories.Blatant
local Legit = Base.Categories.Legit
local Render = Base.Categories.Render
local Utility = Base.Categories.Utility
local World = Base.Categories.World

local Shared = { teamCheck = false, sprintOn = false, sprintMult = 1.75 }
local keys = {}
local function clampNumber(value, low, high, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number then return fallback end
    return math.clamp(number, low, high)
end

local function getSpawnCFrame()
    local spawn = nil
    pcall(function() spawn = workspace:FindFirstChildOfClass("SpawnLocation") end)
    if spawn ~= nil then
        return spawn.CFrame + Vector3.new(0, 5, 0)
    end
    return CFrame.new(0, 50, 0)
end

local speedValue, speedRevert, speedMethod = 16, 16, "WalkSpeed"
local jumpValue, jumpRevert = 50, 50
local gravValue, gravRevert = 196.2, 196.2
local fovValue = 70
local clockValue = 12

pcall(function()
    local humanoid = Entity.Humanoid()
    if humanoid ~= nil then
        local ws = humanoid.WalkSpeed
        if type(ws) == "number" and ws == ws and ws > 0 then
            speedValue = math.floor(ws + 0.5)
            speedRevert = speedValue
        end
        local jp = humanoid.JumpPower
        if type(jp) == "number" and jp == jp and jp >= 0 then
            jumpValue = math.floor(jp + 0.5)
            jumpRevert = jumpValue
        end
    end
    local gravity = workspace.Gravity
    if type(gravity) == "number" and gravity == gravity then
        gravValue = gravity
        gravRevert = gravity
    end
    local camera = Entity.Camera()
    if camera ~= nil then
        local fov = camera.FieldOfView
        if type(fov) == "number" and fov == fov then
            fovValue = math.floor(fov + 0.5)
        end
    end
    if Lighting ~= nil then
        clockValue = Lighting.ClockTime
    end
end)

local ESP, NameTags, Tracers, espCount, tracerStatus = nil, nil, nil, nil, nil
local clickTP = false
local espRoot, removeHighlight, syncESP, watchPlayer = nil, nil, nil, nil
local removeNameTag, updateTagText, ensureNameTag, watchNameTag, syncNameTags = nil, nil, nil, nil, nil
local clearTracers, syncTracers, findPlayer, snapshotLighting, disableFullbright = nil, nil, nil, nil, nil

Blatant.Tab:AddSubsection("Movement")

local Speed = Blatant:CreateModule({
    Name = "Speed",
    Function = function(on)
        if not on then
            local humanoid = Entity.Humanoid()
            if humanoid ~= nil then
                pcall(function() humanoid.WalkSpeed = speedRevert end)
            end
            if speedMethod ~= "WalkSpeed" then
                local root = Entity.Root()
                if root ~= nil then
                    pcall(function()
                        local velocity = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
                    end)
                end
            end
        end
    end,
})
Speed:CreateDropdown("Method", {"WalkSpeed", "Velocity", "CFrame"}, "WalkSpeed", function(v)
    speedMethod = tostring(v)
end)
Speed:CreateSlider("Speed", 1, 150, speedValue, function(v)
    speedValue = math.floor(v + 0.5)
end)
Base:Step(function(dt)
    if not Speed.Enabled then return end
    local humanoid = Entity.Humanoid()
    if humanoid == nil then return end
    local effective = speedValue
    if Shared.sprintOn and keys.LeftShift and humanoid.MoveDirection.Magnitude > 0.1 then
        effective = effective * Shared.sprintMult
    end
    if speedMethod == "Velocity" then
        local root = Entity.Root()
        if root == nil then return end
        local direction = humanoid.MoveDirection
        if direction.Magnitude < 0.1 then return end
        pcall(function()
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(direction.X * effective, velocity.Y, direction.Z * effective)
        end)
    elseif speedMethod == "CFrame" then
        local root = Entity.Root()
        if root == nil then return end
        local direction = humanoid.MoveDirection
        if direction.Magnitude < 0.1 then return end
        pcall(function()
            root.CFrame = root.CFrame + direction * effective * dt
        end)
    else
        pcall(function() humanoid.WalkSpeed = effective end)
    end
end)

local Sprint = Blatant:CreateModule({
    Name = "Sprint",
    Function = function(on)
        Shared.sprintOn = (on == true)
    end,
})
Sprint:CreateSlider("Boost %", 100, 400, 175, function(v)
    Shared.sprintMult = math.floor(v + 0.5) / 100
end)

local flySpeed, flyVertical, flyMethod = 50, 50, "Velocity"
local Fly = Blatant:CreateModule({
    Name = "Fly",
    Function = function(on)
        if not on then
            local humanoid = Entity.Humanoid()
            if humanoid ~= nil then
                pcall(function()
                    humanoid.PlatformStand = false
                    humanoid.AutoRotate = true
                end)
            end
            local root = Entity.Root()
            if root ~= nil then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.new()
                    root.AssemblyAngularVelocity = Vector3.new()
                end)
            end
        end
    end,
})
Fly:CreateDropdown("Method", {"Velocity", "CFrame"}, "Velocity", function(v)
    flyMethod = tostring(v)
end)
Fly:CreateSlider("Speed", 1, 150, 50, function(v)
    flySpeed = math.floor(v + 0.5)
end)
Fly:CreateSlider("Vertical", 1, 150, 50, function(v)
    flyVertical = math.floor(v + 0.5)
end)
Base:Step(function(dt)
    if not Fly.Enabled then return end
    local humanoid = Entity.Humanoid()
    local root = Entity.Root()
    local camera = Entity.Camera()
    if humanoid == nil or root == nil or camera == nil then return end
    pcall(function()
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local flat = Vector3.new()
        if keys.W then flat = flat + look end
        if keys.S then flat = flat - look end
        if keys.D then flat = flat + right end
        if keys.A then flat = flat - right end
        flat = Vector3.new(flat.X, 0, flat.Z)
        if flat.Magnitude > 0.001 then
            flat = flat.Unit * flySpeed
        else
            flat = Vector3.new()
        end
        local lift = (keys.Space and flyVertical or 0) + ((keys.Q or keys.LeftControl) and -flyVertical or 0)
        if flyMethod == "CFrame" then
            root.CFrame = root.CFrame + (flat + Vector3.new(0, lift, 0)) * dt
            root.AssemblyLinearVelocity = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        else
            root.AssemblyLinearVelocity = Vector3.new(flat.X, lift ~= 0 and lift or 2.25, flat.Z)
            root.AssemblyAngularVelocity = Vector3.new()
        end
    end)
end)

local ljPower, ljMethod, ljAuto, ljAir = 50, "Velocity", true, 0
local LongJump = Blatant:CreateModule({
    Name = "LongJump",
    Function = function(on)
        if on then ljAir = 0 end
    end,
})
LongJump:CreateDropdown("Mode", {"Velocity", "CFrame"}, "Velocity", function(v)
    ljMethod = tostring(v)
end)
LongJump:CreateSlider("Power", 1, 150, 50, function(v)
    ljPower = math.floor(v + 0.5)
end)
LongJump:CreateToggle("Auto Disable", true, function(v)
    ljAuto = (v == true)
end)
Base:Step(function(dt)
    if not LongJump.Enabled then return end
    if not Entity.Alive() then ljAir = 0 return end
    local humanoid = Entity.Humanoid()
    local root = Entity.Root()
    if humanoid == nil or root == nil then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        ljAir = 0
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    else
        ljAir = ljAir + dt
        if ljAuto and ljAir > 0.15 then
            LongJump:SetEnabled(false)
            return
        end
    end
    local direction = humanoid.MoveDirection * ljPower
    if direction.Magnitude < 0.1 then return end
    if ljMethod == "CFrame" then
        pcall(function() root.CFrame = root.CFrame + direction * dt end)
    else
        pcall(function()
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(direction.X, velocity.Y, direction.Z)
        end)
    end
end)

local hjHeight = 50
local HighJump = Blatant:CreateModule({
    Name = "HighJump",
    Function = function(on)
        if on then
            HighJump:Clean(UserInputService.JumpRequest:Connect(function()
                if not HighJump.Enabled then return end
                local root = Entity.Root()
                if root == nil then return end
                pcall(function()
                    root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, hjHeight, 0)
                end)
            end))
        end
    end,
})
HighJump:CreateSlider("Height", 1, 200, 50, function(v)
    hjHeight = math.floor(v + 0.5)
end)

local jesusPlatform = nil
local Jesus = Blatant:CreateModule({
    Name = "Jesus",
    Function = function(on)
        if on then
            jesusPlatform = Instance.new("Part")
            jesusPlatform.Name = "EldritchJesus"
            jesusPlatform.Size = Vector3.new(8, 1, 8)
            jesusPlatform.Transparency = 1
            jesusPlatform.Anchored = true
            jesusPlatform.CanCollide = true
            jesusPlatform.CanQuery = false
            Jesus:Clean(jesusPlatform)
            jesusPlatform.Parent = workspace
        else
            if jesusPlatform ~= nil then
                Base.Window:Untrack(jesusPlatform)
                pcall(function() jesusPlatform:Destroy() end)
                jesusPlatform = nil
            end
        end
    end,
})
Base:Step(function()
    if not Jesus.Enabled or jesusPlatform == nil then return end
    local root = Entity.Root()
    if root == nil then return end
    local hit = nil
    pcall(function()
        hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0))
    end)
    if hit ~= nil and hit.Material == Enum.Material.Water then
        pcall(function()
            jesusPlatform.CFrame = CFrame.new(hit.Position.X, hit.Position.Y + 0.5, hit.Position.Z)
        end)
    else
        pcall(function() jesusPlatform.CFrame = CFrame.new(0, -1000, 0) end)
    end
end)

local spiderRate = 20
local Spider = Blatant:CreateModule({
    Name = "Spider",
    Function = function(on)
    end,
})
Spider:CreateSlider("Climb Rate", 5, 50, 20, function(v)
    spiderRate = math.floor(v + 0.5)
end)
Base:Step(function()
    if not Spider.Enabled or not Entity.Alive() then return end
    local humanoid = Entity.Humanoid()
    local root = Entity.Root()
    if humanoid == nil or root == nil then return end
    if humanoid.MoveDirection.Magnitude < 0.1 then return end
    local hit = false
    pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { humanoid.Parent }
        hit = workspace:Raycast(root.Position, root.CFrame.LookVector * 2.5, params) ~= nil
    end)
    if hit then
        pcall(function()
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, spiderRate, velocity.Z)
        end)
    end
end)

local Noclip = Blatant:CreateModule({
    Name = "Noclip",
    Function = function(on)
        if not on then
            local character = Entity.Character()
            if character ~= nil then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part.CanCollide = true end)
                    end
                end
            end
        end
    end,
})
Base:Step(function()
    if not Noclip.Enabled then return end
    local character = Entity.Character()
    if character == nil then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false end)
        end
    end
end)

local swimSpeed = 30
local Swim = Blatant:CreateModule({
    Name = "Swim",
    Function = function(on)
    end,
})
Swim:CreateSlider("Swim Speed", 5, 150, 30, function(v)
    swimSpeed = math.floor(v + 0.5)
end)
Base:Step(function()
    if not Swim.Enabled then return end
    local humanoid = Entity.Humanoid()
    local root = Entity.Root()
    if humanoid == nil or root == nil then return end
    local state = nil
    pcall(function() state = humanoid:GetState() end)
    if state ~= Enum.HumanoidStateType.Swimming then
        local under = nil
        pcall(function()
            under = workspace:Raycast(root.Position, Vector3.new(0, -4, 0))
        end)
        if under == nil or under.Material ~= Enum.Material.Water then return end
        if humanoid.MoveDirection.Magnitude < 0.1 then return end
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Swimming) end)
        return
    end
    local direction = humanoid.MoveDirection * swimSpeed
    if direction.Magnitude < 0.1 then return end
    pcall(function()
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(direction.X, velocity.Y, direction.Z)
    end)
end)

local voidHeight = -50
Blatant.Tab:AddSubsection("Protection")

local AntiVoid = Blatant:CreateModule({
    Name = "AntiVoid",
    Function = function(on)
    end,
})
AntiVoid:CreateSlider("Void Height", -500, 0, -50, function(v)
    voidHeight = math.floor(v + 0.5)
end)
Base:Step(function()
    if not AntiVoid.Enabled then return end
    local character = Entity.Character()
    if character == nil then return end
    local root = Entity.Root(character)
    if root == nil or root.Position.Y >= voidHeight then return end
    pcall(function()
        character:PivotTo(getSpawnCFrame())
        root.AssemblyLinearVelocity = Vector3.new()
    end)
end)

local AntiFling = Blatant:CreateModule({
    Name = "AntiFling",
    Function = function(on)
    end,
})
Base:Step(function()
    if not AntiFling.Enabled then return end
    local root = Entity.Root()
    if root == nil then return end
    pcall(function()
        local velocity = root.AssemblyLinearVelocity
        if velocity.Magnitude > 100 then
            root.AssemblyLinearVelocity = velocity.Unit * 100
        end
    end)
end)

local fovLive = fovValue
Legit.Tab:AddSubsection("View")

local FOV = Legit:CreateModule({
    Name = "FOV",
    Function = function(on)
        local camera = Entity.Camera()
        if camera == nil then return end
        if on then
            pcall(function() camera.FieldOfView = fovLive end)
        else
            pcall(function() camera.FieldOfView = fovValue end)
        end
    end,
})
FOV:CreateSlider("Field of View", 30, 120, fovValue, function(v)
    fovLive = math.floor(v + 0.5)
    if FOV.Enabled then
        local camera = Entity.Camera()
        if camera ~= nil then
            pcall(function() camera.FieldOfView = fovLive end)
        end
    end
end)

local clockLive = clockValue
local Clock = Legit:CreateModule({
    Name = "Clock",
    Function = function(on)
        if Lighting == nil then return end
        if on then
            pcall(function() Lighting.ClockTime = clockLive end)
        else
            pcall(function() Lighting.ClockTime = clockValue end)
        end
    end,
})
Clock:CreateSlider("Time", 0, 24, clockValue, function(v)
    clockLive = v
    if Clock.Enabled and Lighting ~= nil then
        pcall(function() Lighting.ClockTime = v end)
    end
end)

local Speedmeter = Legit:CreateModule({
    Name = "Speedmeter",
    Function = function(on)
    end,
})
local speedmeterLabel = Speedmeter:CreateLabel("0 studs/s")

local espFolder = nil
Render.Tab:AddSubsection("Player")

ESP = Render:CreateModule({
    Name = "ESP",
    Function = function(on)
        if on then
            local root = espRoot()
            if root == nil then
                ESP:SetEnabled(false)
                return
            end
            if espFolder ~= nil then
                Base.Window:Untrack(espFolder)
                pcall(function() espFolder:Destroy() end)
            end
            espFolder = Instance.new("Folder")
            espFolder.Name = "EldritchESP_" .. tostring(math.random(1000, 9999))
            ESP:Clean(espFolder)
            espFolder.Parent = root
            for _, player in ipairs(Players:GetPlayers()) do
                watchPlayer(player)
            end
            syncESP()
        else
            if espFolder ~= nil then
                Base.Window:Untrack(espFolder)
                pcall(function() espFolder:Destroy() end)
                espFolder = nil
            end
            if espCount ~= nil then espCount:Set("Tracked: 0") end
        end
    end,
})
ESP:CreateToggle("Team Check", false, function(v)
    Shared.teamCheck = (v == true)
end)
espCount = ESP:CreateLabel("Tracked: 0")

local nameTags = {}
NameTags = Render:CreateModule({
    Name = "NameTags",
    Function = function(on)
        if on then
            for _, player in ipairs(Players:GetPlayers()) do
                watchNameTag(player)
            end
            syncNameTags()
        else
            for _, player in ipairs(Players:GetPlayers()) do
                removeNameTag(player)
            end
            for name, _ in pairs(nameTags) do
                removeNameTag({ Name = name })
            end
        end
    end,
})

local tracerLines = {}
Tracers = Render:CreateModule({
    Name = "Tracers",
    Function = function(on)
        if on then
            if type(Drawing) ~= "table" then
                if tracerStatus ~= nil then tracerStatus:Set("Unsupported executor") end
                Tracers:SetEnabled(false)
                return
            end
            Tracers:Clean(function()
                clearTracers()
            end)
        else
            clearTracers()
        end
    end,
})
tracerStatus = Tracers:CreateLabel("Ready")

Render.Tab:AddSubsection("World")

local Fullbright = Render:CreateModule({
    Name = "Fullbright",
    Function = function(on)
        if on then
            snapshotLighting()
            if Lighting == nil then return end
            pcall(function()
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Brightness = 2
                Lighting.GlobalShadows = false
                Lighting.FogStart = 0
                Lighting.FogEnd = 100000
            end)
        else
            disableFullbright()
        end
    end,
})

local points = {}
local wpNames = { "" }
local Waypoints = Render:CreateModule({
    Name = "Waypoints",
    Function = function(on)
    end,
})
local wpStatus = Waypoints:CreateLabel("Points: 0")
local wpPick = Waypoints:CreateDropdown("Point", { "" }, "", function(v)
end)
Waypoints:CreateButton("Add Waypoint", function()
    local root = Entity.Root()
    if root == nil then
        wpStatus:Set("No character")
        return
    end
    table.insert(points, root.CFrame)
    table.clear(wpNames)
    for i in ipairs(points) do
        table.insert(wpNames, "Point " .. tostring(i))
    end
    wpPick.Api:SetOptions(wpNames)
    wpStatus:Set("Points: " .. tostring(#points))
end)
Waypoints:CreateButton("Go To", function()
    if not Waypoints.Enabled then
        wpStatus:Set("Enable Waypoints")
        return
    end
    local index = tonumber(string.match(tostring(wpPick.Value), "Point (%d+)"))
    local frame = index and points[index] or nil
    local character = Entity.Character()
    if frame == nil or character == nil then
        wpStatus:Set("Invalid point")
        return
    end
    pcall(function() character:PivotTo(frame) end)
    wpStatus:Set("Teleported")
end)
Waypoints:CreateButton("Clear", function()
    table.clear(points)
    table.clear(wpNames)
    table.insert(wpNames, "")
    wpPick.Api:SetOptions(wpNames)
    wpStatus:Set("Points: 0")
end)

Utility.Tab:AddSubsection("Player")

local InfJump = Utility:CreateModule({
    Name = "InfiniteJump",
    Function = function(on)
        if on then
            InfJump:Clean(UserInputService.JumpRequest:Connect(function()
                if not InfJump.Enabled then return end
                local humanoid = Entity.Humanoid()
                if humanoid == nil then return end
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end))
        end
    end,
})

local tpStatus = nil
local Teleport = Utility:CreateModule({
    Name = "Teleport",
    Function = function(on)
        clickTP = (on == true)
    end,
})
tpStatus = Teleport:CreateLabel("Idle")
Teleport:CreateButton("Teleport to Spawn", function()
    local character = Entity.Character()
    if character == nil then
        tpStatus:Set("No character")
        return
    end
    local root = Entity.Root(character)
    pcall(function()
        character:PivotTo(getSpawnCFrame())
        if root ~= nil then
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end)
    tpStatus:Set("Teleported to spawn")
end)
local tpTarget = Teleport:CreateInput("Player Name", "", function(v)
end)
Teleport:CreateButton("Teleport to Player", function()
    local target = findPlayer(tpTarget.Value)
    if target == nil then
        tpStatus:Set("Player not found")
        return
    end
    local character = Entity.Character()
    local troot = Entity.Root(target.Character)
    if character == nil or troot == nil then
        tpStatus:Set("Teleport failed")
        return
    end
    local root = Entity.Root(character)
    pcall(function()
        character:PivotTo(troot.CFrame + Vector3.new(0, 0, 5))
        if root ~= nil then
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end)
    tpStatus:Set("Teleported to " .. target.Name)
end)

local sessionInfo = nil
local sessionStatus = nil
Utility.Tab:AddSubsection("Session")

local AutoRejoin = Utility:CreateModule({
    Name = "AutoRejoin",
    Function = function(on)
        if on then
            if LOADER_URL ~= "" and type(queue_on_teleport) == "function" then
                pcall(function()
                    queue_on_teleport("loadstring(game:HttpGet(\"" .. LOADER_URL .. "\"))()")
                end)
            end
            if TeleportService ~= nil then
                AutoRejoin:Clean(TeleportService.TeleportInitFailed:Connect(function()
                    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                end))
            end
        end
    end,
})
sessionInfo = AutoRejoin:CreateLabel("FPS: ...")
sessionStatus = AutoRejoin:CreateLabel("Idle")
AutoRejoin:CreateButton("Rejoin Server", function()
    local ok = pcall(function()
        if TeleportService == nil then error("teleport unavailable") end
        if game.JobId ~= nil and game.JobId ~= "" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
    sessionStatus:Set(ok and "Rejoining..." or "Rejoin failed")
end)
AutoRejoin:CreateButton("Server Hop", function()
    sessionStatus:Set("Searching...")
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
    if not ok then sessionStatus:Set("Server hop failed") end
end)
AutoRejoin:CreateButton("Copy JobId", function()
    if type(setclipboard) == "function" then
        local ok = pcall(function() setclipboard(game.JobId) end)
        sessionStatus:Set(ok and "JobId copied" or "Copy failed")
    else
        sessionStatus:Set("Copy unavailable")
    end
end)
AutoRejoin:CreateButton("Copy PlaceId", function()
    if type(setclipboard) == "function" then
        local ok = pcall(function() setclipboard(tostring(game.PlaceId)) end)
        sessionStatus:Set(ok and "PlaceId copied" or "Copy failed")
    else
        sessionStatus:Set("Copy unavailable")
    end
end)

local AntiAFK = Utility:CreateModule({
    Name = "AntiAFK",
    Function = function(on)
        if on then
            if VirtualUser == nil then
                AntiAFK:SetEnabled(false)
                sessionStatus:Set("Anti-AFK unavailable")
                return
            end
            AntiAFK:Clean(LocalPlayer.Idled:Connect(function()
                if not AntiAFK.Enabled then return end
                local camera = Entity.Camera()
                if camera == nil then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:Button2Down(Vector2.new(), camera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(), camera.CFrame)
                end)
            end))
            sessionStatus:Set("Anti-AFK on")
        else
            sessionStatus:Set("Anti-AFK off")
        end
    end,
})

Utility.Tab:AddSubsection("Interface")

local Panic = Utility:CreateModule({
    Name = "Panic",
    Button = true,
    Function = function()
        Base.Window:Destroy()
    end,
})
Utility.Tab:AddButton("Hide UI (RightShift)", function()
    Base.Window:SetVisible(false)
end)
Utility.Tab:AddLabel("Build: u3")

local gravSnap = gravRevert
World.Tab:AddSubsection("Environment")

local Gravity = World:CreateModule({
    Name = "Gravity",
    Function = function(on)
        if not on then
            pcall(function() workspace.Gravity = gravSnap end)
        end
    end,
})
Gravity:CreateSlider("Gravity", 0, 500, gravValue, function(v)
    gravValue = v
end)
Base:Step(function()
    if not Gravity.Enabled then return end
    pcall(function() workspace.Gravity = gravValue end)
end)

local xrayTargets = {}
local xrayTouched = {}
local function parseTargets(v)
    table.clear(xrayTargets)
    for name in string.gmatch(tostring(v), "([^,]+)") do
        table.insert(xrayTargets, (string.gsub(name, "^%s*(.-)%s*$", "%1")))
    end
end
local function applyXray(part)
    if #xrayTargets == 0 then return end
    for _, name in ipairs(xrayTargets) do
        if part.Name == name and xrayTouched[part] == nil then
            xrayTouched[part] = true
            pcall(function() part.LocalTransparencyModifier = 0.5 end)
            return
        end
    end
end
local function rescanXray()
    for part in pairs(xrayTouched) do
        pcall(function() part.LocalTransparencyModifier = 0 end)
    end
    table.clear(xrayTouched)
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") then applyXray(part) end
    end
end
parseTargets("Chest,Ore")
local Xray = World:CreateModule({
    Name = "Xray",
    Function = function(on)
        if on then
            Xray:Clean(workspace.DescendantAdded:Connect(function(part)
                if part:IsA("BasePart") then applyXray(part) end
            end))
            rescanXray()
        else
            for part in pairs(xrayTouched) do
                pcall(function() part.LocalTransparencyModifier = 0 end)
            end
            table.clear(xrayTouched)
        end
    end,
})
Xray:CreateInput("Targets", "Chest,Ore", function(v)
    parseTargets(v)
    if Xray.Enabled then rescanXray() end
end)

local promptSaved = {}
local function fastPrompt(prompt)
    if promptSaved[prompt] == nil then
        promptSaved[prompt] = prompt.HoldDuration
    end
    pcall(function() prompt.HoldDuration = 0 end)
end
local FastPrompt = World:CreateModule({
    Name = "FastProxPrompt",
    Function = function(on)
        if on then
            FastPrompt:Clean(workspace.DescendantAdded:Connect(function(part)
                if part:IsA("ProximityPrompt") then fastPrompt(part) end
            end))
            for _, part in ipairs(workspace:GetDescendants()) do
                if part:IsA("ProximityPrompt") then fastPrompt(part) end
            end
        else
            for prompt, hold in pairs(promptSaved) do
                pcall(function() prompt.HoldDuration = hold end)
            end
            table.clear(promptSaved)
        end
    end,
})

local lightSnap = nil
snapshotLighting = function()
    if lightSnap ~= nil or Lighting == nil then return end
    local snap = {}
    pcall(function()
        snap.Ambient = Lighting.Ambient
        snap.OutdoorAmbient = Lighting.OutdoorAmbient
        snap.Brightness = Lighting.Brightness
        snap.GlobalShadows = Lighting.GlobalShadows
        snap.FogStart = Lighting.FogStart
        snap.FogEnd = Lighting.FogEnd
    end)
    lightSnap = snap
end
disableFullbright = function()
    if Lighting == nil or lightSnap == nil then return end
    pcall(function()
        if lightSnap.Ambient ~= nil then Lighting.Ambient = lightSnap.Ambient end
        if lightSnap.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = lightSnap.OutdoorAmbient end
        if lightSnap.Brightness ~= nil then Lighting.Brightness = lightSnap.Brightness end
        if lightSnap.GlobalShadows ~= nil then Lighting.GlobalShadows = lightSnap.GlobalShadows end
        if lightSnap.FogStart ~= nil then Lighting.FogStart = lightSnap.FogStart end
        if lightSnap.FogEnd ~= nil then Lighting.FogEnd = lightSnap.FogEnd end
    end)
end

local espRootCache = nil
espRoot = function()
    local parent = nil
    pcall(function()
        if type(gethui) == "function" then parent = gethui() end
    end)
    if parent ~= nil then return parent end
    if CoreGui ~= nil then return CoreGui end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

removeHighlight = function(player)
    if espFolder == nil or espFolder.Parent == nil then return end
    local existing = espFolder:FindFirstChild(player.Name)
    if existing ~= nil then
        pcall(function() existing:Destroy() end)
    end
end

syncESP = function()
    if not ESP.Enabled then return end
    if espFolder == nil or espFolder.Parent == nil then return end
    for i = #espConns, 1, -1 do
        local conn = espConns[i]
        local alive = false
        pcall(function() alive = conn.Connected end)
        if not alive then
            Base.Window:Untrack(conn)
            table.remove(espConns, i)
        end
    end
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LocalPlayer and model ~= nil and model.Parent ~= nil then
            local blocked = Shared.teamCheck and myTeam ~= nil and player.Team == myTeam
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

local espConns = {}

watchPlayer = function(player)
    if player == LocalPlayer then return end
    table.insert(espConns, ESP:Clean(player.CharacterAdded:Connect(function()
        task.defer(syncESP)
    end)))
end

removeNameTag = function(player)
    local tag = nameTags[player.Name]
    if tag == nil then return end
    nameTags[player.Name] = nil
    Base.Window:Untrack(tag)
    pcall(function() tag:Destroy() end)
end

updateTagText = function(tag, player)
    if tag == nil or tag.Parent == nil then return end
    local label = tag:FindFirstChild("Text")
    if label == nil then return end
    local text = player.Name
    local myRoot = Entity.Root()
    local theirRoot = Entity.Root(player.Character)
    if myRoot ~= nil and theirRoot ~= nil then
        local distance = (myRoot.Position - theirRoot.Position).Magnitude
        text = text .. " [" .. tostring(math.floor(distance + 0.5)) .. "m]"
    end
    pcall(function() label.Text = text end)
end

ensureNameTag = function(player, model)
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
        nameTags[player.Name] = NameTags:Clean(gui)
    end
    local tag = nameTags[player.Name]
    if tag ~= nil then
        updateTagText(tag, player)
    end
end

local nameConns = {}

watchNameTag = function(player)
    if player == LocalPlayer then return end
    table.insert(nameConns, NameTags:Clean(player.CharacterAdded:Connect(function(model)
        task.defer(function()
            if NameTags.Enabled and model ~= nil then
                ensureNameTag(player, model)
            end
        end)
    end)))
end

syncNameTags = function()
    if not NameTags.Enabled then return end
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LocalPlayer and model ~= nil and model.Parent ~= nil then
            local blocked = Shared.teamCheck and myTeam ~= nil and player.Team == myTeam
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

clearTracers = function()
    for name, line in pairs(tracerLines) do
        pcall(function() line:Remove() end)
        tracerLines[name] = nil
    end
end

syncTracers = function()
    if not Tracers.Enabled then return end
    if type(Drawing) ~= "table" then return end
    local camera = Entity.Camera()
    if camera == nil then return end
    local viewport = camera.ViewportSize
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        local troot = Entity.Root(model)
        local blocked = Shared.teamCheck and myTeam ~= nil and player.Team == myTeam
        if player == LocalPlayer or model == nil or troot == nil or blocked then
            local line = tracerLines[player.Name]
            if line ~= nil then
                pcall(function() line.Visible = false end)
            end
        else
            local position, onScreen = camera:WorldToViewportPoint(troot.Position)
            local line = tracerLines[player.Name]
            if line == nil then
                local ok, fresh = pcall(function()
                    local drawn = Drawing.new("Line")
                    drawn.Thickness = 1
                    drawn.Color = Color3.fromRGB(255, 122, 197)
                    return drawn
                end)
                if ok and fresh ~= nil then
                    line = fresh
                    tracerLines[player.Name] = line
                end
            end
            if line ~= nil then
                pcall(function()
                    line.Visible = onScreen
                    line.From = Vector2.new(viewport.X / 2, viewport.Y)
                    line.To = Vector2.new(position.X, position.Y)
                end)
            end
        end
    end
    for name, line in pairs(tracerLines) do
        if Players:FindFirstChild(name) == nil then
            pcall(function() line:Remove() end)
            tracerLines[name] = nil
        end
    end
end

findPlayer = function(query)
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

Base.Window:Track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() ~= nil then return end
    if input.KeyCode ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown then
        keys[input.KeyCode.Name] = true
    end
    if clickTP and (keys.LeftControl or keys.RightControl) and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local camera = Entity.Camera()
        local character = Entity.Character()
        if camera ~= nil and character ~= nil then
            local pointer = UserInputService:GetMouseLocation()
            local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character }
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
            if hit ~= nil then
                local root = Entity.Root(character)
                pcall(function()
                    character:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 5, 0)))
                    if root ~= nil then
                        root.AssemblyLinearVelocity = Vector3.new()
                    end
                end)
                tpStatus:Set("Teleported")
            else
                tpStatus:Set("Teleport failed")
            end
        end
    end
end))

Base.Window:Track(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown then
        keys[input.KeyCode.Name] = false
    end
end))

Base.Window:Track(Players.PlayerAdded:Connect(function(player)
    if ESP.Enabled then
        watchPlayer(player)
        task.defer(syncESP)
    end
    if NameTags.Enabled then
        watchNameTag(player)
        task.defer(syncNameTags)
    end
end))

Base.Window:Track(Players.PlayerRemoving:Connect(function(player)
    if ESP.Enabled then
        removeHighlight(player)
    end
    if NameTags.Enabled then
        removeNameTag(player)
    end
end))

local fpsValue = 60
local slowAcc = 0

Base.Window:Track(RunService.Heartbeat:Connect(function(dt)
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 or dt > 1 then
        dt = 0.016
    end
    fpsValue = fpsValue * 0.9 + (1 / dt) * 0.1
    for _, fn in ipairs(Base.Steps) do
        pcall(fn, dt)
    end
    if Tracers.Enabled then
        pcall(syncTracers)
    end
    slowAcc = slowAcc + dt
    if slowAcc >= 0.5 then
        slowAcc = 0
        if ESP.Enabled then
            pcall(syncESP)
            if espFolder ~= nil and espFolder.Parent ~= nil then
                espCount:Set("Tracked: " .. tostring(#espFolder:GetChildren()))
            end
        end
        if NameTags.Enabled then
            pcall(syncNameTags)
        end
        if Speedmeter.Enabled then
            local root = Entity.Root()
            local rate = 0
            if root ~= nil then
                pcall(function()
                    local velocity = root.AssemblyLinearVelocity
                    rate = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                end)
            end
            speedmeterLabel:Set(tostring(math.floor(rate + 0.5)) .. " studs/s")
        end
        local total = 0
        pcall(function() total = #Players:GetPlayers() end)
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
        sessionInfo:Set("FPS: " .. tostring(math.floor(fpsValue + 0.5)) .. "  Ping: " .. tostring(ping) .. "ms  Players: " .. tostring(total))
    end
end))

Base.Window:SelectTab("Blatant")

return Base
