local GlobalEnv = getgenv and getgenv() or _G

local drawing = drawing or Drawing or (GlobalEnv and (GlobalEnv.Drawing or GlobalEnv.drawing)) or nil
if drawing == nil then
    warn("[EldritchHub] Drawing API not found, ESP/FOV visuals disabled.")
end

if GlobalEnv.AoInjected then return end
GlobalEnv.AoInjected = true

local Fluent
do
    local LastErr
    for attempt = 1, 5 do
        local ok, result = pcall(function()
            local content = game:HttpGet("https://gist.githubusercontent.com/AstraTheFomx/e436d8dff2bdc599d6163137d58f5144/raw/Ui%2520Library.lua")
            local chunk, chunkErr = loadstring(content)
            if not chunk then error(chunkErr) end
            return chunk()
        end)
        if ok then
            Fluent = result
            break
        else
            LastErr = result
            warn(string.format("[EldritchHub] Fluent load attempt %d/5 failed: %s", attempt, tostring(LastErr)))
            if attempt < 5 then task.wait(1) end
        end
    end
    if not Fluent then
        local msg = "[EldritchHub] Failed to load Fluent after 5 attempts: " .. tostring(LastErr)
        warn(msg)
        game:GetService("Players").LocalPlayer:Kick(msg)
        return
    end
end

task.defer(function()
    local LastErr
    for attempt = 1, 5 do
        local ok, err = pcall(function()
            local content = game:HttpGet("https://gist.githubusercontent.com/AstraTheFomx/d888d9e093103aa4c7336186ef1acd3d/raw/Arcane%2520Yield.lua")
            local chunk, chunkErr = loadstring(content)
            if not chunk then error(chunkErr) end
            chunk()
        end)
        if ok then return end
        LastErr = err
        warn(string.format("[EldritchHub] Deferred script load attempt %d/5 failed: %s", attempt, tostring(LastErr)))
        if attempt < 5 then task.wait(1) end
    end
    warn("[EldritchHub] Deferred script failed to load after 5 attempts: " .. tostring(LastErr))
    game:GetService("Players").LocalPlayer:Kick("[EldritchHub] Deferred script failed to load: " .. tostring(LastErr))
end)

local Version = "v3.5.2 [B]"

function CheckFunctionExists(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end
cloneref = CheckFunctionExists("function", cloneref, function(s) return s end)
SafeFirePrompt = CheckFunctionExists("function", fireproximityprompt, function() end)
HookFunction = CheckFunctionExists("function", hookfunction)
DebugGetUpvalue = CheckFunctionExists("function", debug and debug.getupvalue)
HookMetamethod = CheckFunctionExists("function", hookmetamethod)
NewClosure = CheckFunctionExists("function", newcclosure, function(f) return f end)
local drawing = CheckFunctionExists("table", drawing)
if not drawing then
    local dummy
    dummy = setmetatable({}, {
        __index = function() return dummy end,
        __call = function() return dummy end,
        __newindex = function() end,
    })
    drawing = setmetatable({}, {
        __index = function(_, k)
            if k == "new" then return function() return dummy end end
            return dummy
        end,
    })
end

local workspace    = cloneref(game:GetService("Workspace"))
local Lighting     = cloneref(game:GetService("Lighting"))
local Players      = cloneref(game:GetService("Players"))
local Replicated   = cloneref(game:GetService("ReplicatedStorage"))
local UIS          = cloneref(game:GetService("UserInputService"))
local RunService   = cloneref(game:GetService("RunService"))
local StarterGui   = cloneref(game:GetService("StarterGui"))
local VirtualUser  = cloneref(game:GetService("VirtualUser"))
local LocalPlayer   = Players.LocalPlayer

local Character     = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local CurrentCamera = workspace.CurrentCamera
local Map           = workspace:WaitForChild("Map", 15)
if not Map then
    warn("[EldritchHub] Map not found after 15s, teleports/chests/diving disabled.")
end
local DarkSeaFolder = Map and Map:FindFirstChild("SeaContent") and Map.SeaContent:FindFirstChild("DarkSea") or nil
local BoatsFolder   = workspace:FindFirstChild("Boats")
local enemiesFolder = workspace:FindFirstChild("Enemies")

local RS              = Replicated:WaitForChild("RS", 15)
if not RS then
    local msg = "[EldritchHub] RS not found, cannot continue."
    warn(msg)
    game:GetService("Players").LocalPlayer:Kick(msg)
    return
end
local UnloadedIslands = RS:FindFirstChild("UnloadIslands")
local Remotes         = RS:WaitForChild("Remotes", 15)
if not Remotes then
    local msg = "[EldritchHub] Remotes not found, cannot continue."
    warn(msg)
    game:GetService("Players").LocalPlayer:Kick(msg)
    return
end

function SafeRequire(path)
    local ok, mod = pcall(require, path)
    if not ok then warn("[EldritchHub] require failed: " .. tostring(path) .. " err=" .. tostring(mod)) end
    return ok and mod or nil
end

HBEHooked = false

function QOLHookHBE()
    if HBEHooked then return true end
    if not HookFunction or not DebugGetUpvalue then return false end
    local AC = SafeRequire(RS.Modules.AttackClient)
    if not AC or type(AC.AOESpellDamage) ~= "function" then return false end
    local HBE = nil
    for i = 1, 30 do
        local ok, name, val = pcall(DebugGetUpvalue, AC.AOESpellDamage, i)
        if not ok then break end
        if name == "HBE" then HBE = val break end
    end
    if type(HBE) ~= "function" then return false end
    local hooked = pcall(HookFunction, HBE, function() return false end)
    if hooked then HBEHooked = true end
    return HBEHooked
end

local ModulesFolder      = RS:WaitForChild("Modules", 60)
local function WaitModule(parent, name)
    if not parent then return nil end
    for round = 1, 4 do
        local inst = parent:WaitForChild(name, 15)
        if inst then return inst end
        warn(string.format("[EldritchHub] Waiting for module %s (round %d/4)...", name, round))
    end
    return nil
end
local MagicFolder        = WaitModule(ModulesFolder, "Magic")
local MeleeFolder        = WaitModule(ModulesFolder, "Melee")
local MagicModule        = MagicFolder and SafeRequire(MagicFolder) or nil
local SkillTypesModule   = MagicFolder and SafeRequire(WaitModule(MagicFolder, "SkillTypes")) or nil
local MeleeModule        = MeleeFolder and SafeRequire(MeleeFolder) or nil
local TechTypesModule    = MeleeFolder and SafeRequire(WaitModule(MeleeFolder, "TechTypes")) or nil
local BasicModule        = ModulesFolder and SafeRequire(WaitModule(ModulesFolder, "Basic")) or nil
local InventoryModule    = ModulesFolder and SafeRequire(WaitModule(ModulesFolder, "Inventory")) or nil
if not (MagicModule and MeleeModule and BasicModule and InventoryModule) then
    local msg = "[EldritchHub] Game modules failed to load, rejoin and retry."
    warn(msg)
    game:GetService("Players").LocalPlayer:Kick(msg)
    return
end

local RepairHammerRemote = Replicated:FindFirstChild("RS")
    and Replicated.RS:FindFirstChild("Remotes")
    and Replicated.RS.Remotes:FindFirstChild("Boats")
    and Replicated.RS.Remotes.Boats:FindFirstChild("RepairHammer")

local _playerName   = LocalPlayer.Name
local _BoatName     = _playerName .. "Boat"
local _TempBoatName = _playerName .. "TempBoat"


local RarityColors = {
    [0]  = Color3.fromRGB(102, 102, 102),
    [1]  = Color3.fromRGB(160, 160, 160),
    [2]  = Color3.fromRGB(210, 180, 140),
    [3]  = Color3.fromRGB(70,  130, 230),
    [4]  = Color3.fromRGB(220,  50,  50),
    [5]  = Color3.fromRGB(50,  200,  80),
    [10] = Color3.fromRGB(255, 215,   0),
}

local BlockedAggroRemotes = {
    TargetBehavior = true, SetTarget = true, ResetTarget = true, ChangeStatus = true
}

local DamageRemotesSet = {
    DealAttackDamage   = true, DealStrengthDamage = true, DealWeaponDamage  = true,
    DealMagicDamage    = true, DealDamageBoat     = true, DealDamageBoat3   = true,
    DealDamageBoat2    = true, DealDamageBoat1    = true, DealSWDamage      = true,
    RepairHammer       = true, DamageStructure    = true,
}

local SealedNames = {
    ["Bronze Sealed Chest"] = true,
    ["Nimbus Sealed Chest"] = true,
    ["Dark Sealed Chest"]   = true,
}

local BirdTypes = { "Seagull", "Blue Raven", "Raven", "Sparrow", "Eagle" }

local LookingForFightingStyles = {
    "Basic Combat", "Boxing", "Cannon Fist", "Iron Leg",
    "Sailor Style", "Thermo Fist", "Powder Fist", "Vanishing Style",
}

local AllowedEspTypes = { BasePart = true, MeshPart = true, Part = true, Model = true }

local FolderFilter = {
    Herbs = true, Fruits = true, Chests = true,
    Coconuts = true, Seaweed = true, Shells = true,
}


local mFloor   = math.floor
local mHuge    = math.huge
local mRandom  = math.random
local sFmt     = string.format
local Now      = function() return DateTime.now().UnixTimestampMillis / 1000 end

local TeleportDebounce      = false
local StaminaBoostDebounce  = false
local FillDebounce          = false
local LChestDebounce        = false
local FovCircle             = nil
local FovCircleConnection   = nil
local HecatePart            = nil
local InfiniteZoomConnection = nil
local EpicenterLabel        = nil
local EpicenterConnection   = nil
local ChestAuraLabel        = nil
local SilentAimLockLabel    = nil
local SilentAimTargetPart   = nil
local OldAtmosphere         = nil
local NoFogActive           = false
local IslandBuffer          = 500
local SilentMaxDistance     = 1500
local NpcEspMaxDistance     = 2000
local LastAttackTime        = 0
local AttackLingerSecs      = 0.15
local LastTeleportIsland    = nil
local ChestAuraCount        = 0
local OldZoomDistance       = LocalPlayer.CameraMaxZoomDistance
local OldTimeModule         = BasicModule.GetTime
local ChildAddedConnection  = nil
local LastMousePositionX    = 0
local LastMousePositionY    = 0

JD_IS_PREMIUM = true

local FishingType     = "Legit"
local FishingBaitType = "Normal Bait"
local FishingWaterType = "Warm"
local FishingToolName = nil
local FishingTool     = nil
local CachedWaterPart = nil
local CachedWaterType = nil

if not GlobalEnv.AoSessionData then
    GlobalEnv.AoSessionData = {
        GodMode               = false,
        SilentAim             = false,
        SilentAimNPCs         = false,
        SilentAimPlayers      = false,
        SilentAimFOV          = false,
        SilentAimFOVVisible   = true,
        SilentAimWallcheck    = false,
        SilentAimFOVRadius    = 150,
        SilentAimMaxDistance  = 1500,
        Prediction            = true,
        PredictionSpeed       = 150,
        AutoPredictionSpeed   = true,
        SkipPartyMembers      = true,
        SkipFriendlyNPCs      = true,
        SkipForceField        = true,
        SkipBlindTargets      = true,
        EnableDamageMultiplier  = false,
        DamageMultiplier        = 1,
        ChargeMultiplierEnabled = false,
        ChargeMultiplierAmt     = 0,
        BoostBoatSpeed      = false,
        BoatSpeedMultiplier = 1,
        ReduceStamina   = false,
        BlockNPCAggro   = false,
        NPCEspActive    = false,
        NpcEspDistanceCapEnabled = true,
        ChestEspEnabled = false,
        AutoEat         = false,
        ChestAura       = false,
        ChestRadius     = 25,
        GalleonFarm     = false,
        BirdMeatFarm    = false,
        CitizenKillAura   = false,
        CitizenKillRadius = 150,
        AggroRedirect     = false,
        AggroTarget       = "",
        SilentBottleDrinking = false,
        HecateNotifier  = false,
        EpicenterESP    = false,
        AutoFish        = false,
        FishingToolName = nil,
        FishingType     = "Legit",
        FishingBaitType = "Normal Bait",
        UseBaitType     = false,
        UseWaterType    = false,
        FishingWaterType = "Warm",
        ChargeMultiplierAmt2 = 0,
        AutoWash        = false,
        AutoWashDelay   = 5,
        TeleportDelay   = 15,
        ItemEspRadius   = 1000,
        DiveFarmEnabled = false,
        DiveRemoveEnemies = true,
        DiveRemoveDamage = true,
        DiveSkipPlayers = true,
        DivePreferSpots = false,
        DivePreferStructs = false,
        DiveIgnoreLegendary = true,
        DiveSlowMode = false,
        ReagantIsland = "Limestone Key",
        CopperSlot = "Personal",
        CopperIsland = "Tidecliff Isle",
        CopperPlotCFrame = nil,
        QOLInfJump = false,
        QOLCrosshair = false,
        QOLHitSound = false,
        QOLHitSoundId = "",
        QOLHitSoundVol = 10,
        QOLAntiFling = false,
        QOLUnderground = false,
        QOLInvisDip = 200,
        QOLInvisUp = false,
        FOVColor        = Color3.fromRGB(255, 0, 0),
        FOVColorName    = "Red",
        Keybinds = {
            GodMode   = Enum.KeyCode.F1,
            SilentAim = Enum.KeyCode.F2,
            AutoFish  = Enum.KeyCode.F3,
        },
    }
end

local SessionData = GlobalEnv.AoSessionData

SilentMaxDistance = SessionData.SilentAimMaxDistance
FishingType       = SessionData.FishingType
FishingBaitType   = SessionData.FishingBaitType or "Normal Bait"
FishingWaterType  = SessionData.FishingWaterType or "Warm"
FishingToolName   = SessionData.FishingToolName

local Settings = {
    ItemEspRadius          = SessionData.ItemEspRadius,
    DamageMultiplier       = SessionData.DamageMultiplier,
    BoatSpeedMultiplier    = SessionData.BoatSpeedMultiplier,
    RepairMultiplier       = 1,
    ChargeMultiplierAmt2   = 0,
    ChestRadius            = SessionData.ChestRadius,
    ChargeMultiplierEnabled = SessionData.ChargeMultiplierEnabled,
    ChargeMultiplierAmt     = SessionData.ChargeMultiplierAmt,
    EnableDamageMultiplier  = SessionData.EnableDamageMultiplier,
    AttackAsDarkSea         = false,
    GodMode                 = SessionData.GodMode,
    BlockNPCAggro           = SessionData.BlockNPCAggro,
    NoTracking              = false,
    ReduceStamina           = SessionData.ReduceStamina,
    OneTapStructures        = false,
    QuickFillBottles        = false,
    SpawnLightning          = false,
    SilentBottleDrinking    = SessionData.SilentBottleDrinking,
    AutoFish                = SessionData.AutoFish,
    AutoWash                = SessionData.AutoWash,
    HecateNotifier          = SessionData.HecateNotifier,
    EpicenterESP            = SessionData.EpicenterESP,
    BoatESP                 = false,
    BoostBoatSpeed          = SessionData.BoostBoatSpeed,
    AutoEat                 = SessionData.AutoEat,
    IsEating                = false,
    PlayerDamageMulti       = false,
    NPCEspActive            = SessionData.NPCEspActive,
    NpcEspDistanceCapEnabled = SessionData.NpcEspDistanceCapEnabled,
    ChestEspEnabled         = SessionData.ChestEspEnabled,
    SpoofingMagic           = false,
    ChestAura               = SessionData.ChestAura,
    GalleonFarm             = SessionData.GalleonFarm,
    BirdMeatFarm            = SessionData.BirdMeatFarm,
    CitizenKillAura         = SessionData.CitizenKillAura or false,
    CitizenKillRadius       = SessionData.CitizenKillRadius or 150,
    AggroRedirect           = SessionData.AggroRedirect or false,
    AggroTarget             = SessionData.AggroTarget or "",
    SilentAim               = SessionData.SilentAim,
    SilentAimNPCs           = SessionData.SilentAimNPCs,
    SilentAimPlayers        = SessionData.SilentAimPlayers,
    SkipPartyMembers        = SessionData.SkipPartyMembers,
    SkipFriendlyNPCs        = SessionData.SkipFriendlyNPCs,
    BoatAimbot              = false,
    SilentAimFOV            = SessionData.SilentAimFOV,
    SilentAimWallcheck      = SessionData.SilentAimWallcheck or false,
    SilentAimFOVRadius      = SessionData.SilentAimFOVRadius,
    SilentAimFOVVisible     = SessionData.SilentAimFOVVisible,
    DiveFarmEnabled         = SessionData.DiveFarmEnabled or false,
    DiveRemoveEnemies       = (SessionData.DiveRemoveEnemies ~= false),
    DiveRemoveDamage        = (SessionData.DiveRemoveDamage ~= false),
    DiveSkipPlayers         = (SessionData.DiveSkipPlayers ~= false),
    DivePreferSpots         = SessionData.DivePreferSpots or false,
    DivePreferStructs       = SessionData.DivePreferStructs or false,
    DiveIgnoreLegendary     = (SessionData.DiveIgnoreLegendary ~= false),
    DiveSlowMode            = SessionData.DiveSlowMode or false,
    QOLInfJump              = SessionData.QOLInfJump or false,
    QOLCrosshair            = SessionData.QOLCrosshair or false,
    QOLHitSound             = SessionData.QOLHitSound or false,
    QOLAntiFling            = SessionData.QOLAntiFling or false,
    QOLUnderground          = SessionData.QOLUnderground or false,
    QOLInvisUp              = SessionData.QOLInvisUp or false,
    Prediction              = (SessionData.Prediction ~= false),
    PredictionSpeed         = SessionData.PredictionSpeed or 150,
    AutoPredictionSpeed     = (SessionData.AutoPredictionSpeed ~= false),
    SkipForceField          = (SessionData.SkipForceField ~= false),
    SkipBlindTargets        = (SessionData.SkipBlindTargets ~= false),
}

local ModifiedStats = {
    Melee = nil, Melee2 = nil,
    Weapon = nil, Weapon2 = nil, Weapon3 = nil,
    Magic = nil, Magic2 = nil,
    Armor = nil,
    FoodItem = nil,
    SpoofedMagic = nil,
}

local EspData          = { Island = nil, RegisteredItems = {}, RegisteredMap = {} }
local ChestEspData     = {}
local NpcEspData       = {}
local ItemEspNameFilter = {}
local OpenCooldown = setmetatable({}, { __mode = "k" })

local SpoofMagicTable   = { "None" }
local magicTypes        = { "None" }
local meleeTypes        = { "None" }
local weaponTypes       = { "None" }
local itemTypes         = {}
local teleportLocations = {}
local teleportLocationsExtended = {}


for _, folder in pairs(Map:GetChildren()) do
    if folder:FindFirstChild("Center") then
        teleportLocations[#teleportLocations + 1] = folder.Name
        teleportLocationsExtended[#teleportLocationsExtended + 1] = folder.Name
    end
end

teleportLocationsExtended[#teleportLocationsExtended + 1] = "Diving Spots"
teleportLocationsExtended[#teleportLocationsExtended + 1] = "Sealed Chests"
teleportLocationsExtended[#teleportLocationsExtended + 1] = "Dark Sea Islands"

for name, Magic in pairs(MagicModule.Types) do
    if Magic["Type"] == "Base Magic" then
        magicTypes[#magicTypes + 1] = name
    end
    SpoofMagicTable[#SpoofMagicTable + 1] = name
end

for meleeType in pairs(MeleeModule.Types) do
    meleeTypes[#meleeTypes + 1] = meleeType
end

for itemName, itemData in pairs(InventoryModule.Items) do
    if itemData.WeaponType then weaponTypes[#weaponTypes + 1] = itemName end
    if itemData.Type == "Relic" then weaponTypes[#weaponTypes + 1] = itemName end
    if itemData.Type == "Accessory" or itemData.Type == "Chestpiece" or itemData.Type == "Leggings" then
        itemTypes[#itemTypes + 1] = itemName
    end
end

table.sort(itemTypes)
table.sort(weaponTypes)
table.sort(magicTypes)
table.sort(SpoofMagicTable)
table.sort(meleeTypes)
table.sort(teleportLocations)
table.sort(teleportLocationsExtended)

local AllMagicTypes = {}
local SpoofState = {
    Active          = false,
    TargetSlot      = "None",
    ChosenSpoof     = "None",
    ChosenVariation = "None",
    BackupTable     = nil,
    BackupVarsTable = nil,
}


local CloneMagicEntry
local ApplyMagicSpoof
local RestoreMagicSpoof

if JD_IS_PREMIUM then

for name in pairs(MagicModule.Types) do
    AllMagicTypes[#AllMagicTypes + 1] = name
end
table.sort(AllMagicTypes)
table.insert(AllMagicTypes, 1, "None")

CloneMagicEntry = function(entry)
    if type(entry) ~= "table" then return entry end
    local clone = table.clone(entry)
    for k, v in pairs(clone) do
        if type(v) == "table" then
            local inner = table.clone(v)
            for ik, iv in pairs(inner) do
                if type(iv) == "table" then
                    inner[ik] = table.clone(iv)
                end
            end
            clone[k] = inner
        end
    end
    return clone
end

ApplyMagicSpoof = function()
    local target = SpoofState.TargetSlot
    local source = SpoofState.ChosenSpoof
    if target == "None" or source == "None" or target == source then
        Fluent:Notify({ Duration = 5, Title = "Magic Spoof", Content = "Invalid target/source." })
        return false
    end
    local targetEntry = MagicModule.Types[target]
    local sourceEntry = MagicModule.Types[source]
    if not targetEntry or not sourceEntry then
        Fluent:Notify({ Duration = 5, Title = "Magic Spoof", Content = "Magic not found." })
        return false
    end
    SpoofState.BackupTable = CloneMagicEntry(targetEntry)
    for k in pairs(targetEntry) do targetEntry[k] = nil end
    for k, v in pairs(sourceEntry) do
        if k ~= "Name" and k ~= "Type" then
            targetEntry[k] = CloneMagicEntry(v)
        end
    end
    targetEntry.Name = target
    targetEntry.Type = "Base Magic"
    if SpoofState.ChosenVariation ~= "None" then
        local sourceVars = sourceEntry["Variations"]
        if type(sourceVars) == "table" then
            local chosenVar = sourceVars[SpoofState.ChosenVariation]
            if chosenVar then
                local originalVars = SpoofState.BackupTable["Variations"]
                local newVars = {}
                if type(originalVars) == "table" then
                    for vk in pairs(originalVars) do
                        newVars[vk] = CloneMagicEntry(chosenVar)
                    end
                end
                newVars[SpoofState.ChosenVariation] = CloneMagicEntry(chosenVar)
                targetEntry["Variations"] = newVars
            end
        end
    else
        if sourceEntry["Variations"] then
            targetEntry["Variations"] = CloneMagicEntry(sourceEntry["Variations"])
        end
    end
    SpoofState.Active = true
    Settings.SpoofingMagic = true
    return true
end

RestoreMagicSpoof = function()
    local target = SpoofState.TargetSlot
    if not SpoofState.Active or not SpoofState.BackupTable or target == "None" then
        SpoofState.Active = false
        Settings.SpoofingMagic = false
        return
    end
    local targetEntry = MagicModule.Types[target]
    if not targetEntry then
        SpoofState.Active = false
        Settings.SpoofingMagic = false
        return
    end
    for k in pairs(targetEntry) do targetEntry[k] = nil end
    for k, v in pairs(SpoofState.BackupTable) do targetEntry[k] = CloneMagicEntry(v) end
    SpoofState.BackupTable = nil
    SpoofState.Active = false
    Settings.SpoofingMagic = false
end

end


function SafeDraw(className, props)
    if not drawing then return nil end
    local ok, obj = pcall(function() return drawing.new(className) end)
    if not ok or not obj then return nil end
    if props then
        for k, v in props do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

DrawFontsUI = nil
pcall(function() DrawFontsUI = drawing and drawing.Fonts and drawing.Fonts.UI or nil end)

local LockLabel = SafeDraw("Text", {
    Visible = false, Size = 16, Color = Color3.fromRGB(255, 50, 50),
    Outline = true, OutlineColor = Color3.fromRGB(0, 0, 0), Center = true,
})
if LockLabel and DrawFontsUI then pcall(function() LockLabel.Font = DrawFontsUI end) end

local WatermarkLabel = SafeDraw("Text", {
    Visible = true, Size = 14, Color = Color3.fromRGB(255, 255, 255),
    Outline = true, OutlineColor = Color3.fromRGB(0, 0, 0),
    Position = Vector2.new(10, 10),
})
if WatermarkLabel and DrawFontsUI then pcall(function() WatermarkLabel.Font = DrawFontsUI end) end

if drawing then
    SilentAimLockLabel = drawing.new("Text")
    SilentAimLockLabel.Size    = 28
    SilentAimLockLabel.Color   = Color3.fromRGB(255, 50, 50)
    SilentAimLockLabel.Outline = true
    SilentAimLockLabel.Center  = true
    SilentAimLockLabel.Visible = false
    SilentAimLockLabel.Text    = ""
end


function GenerateRandomString()
    local length = mRandom(10, 20)
    local chars  = table.create(length)
    for i = 1, length do
        chars[i] = string.char(mRandom(32, 126))
    end
    return table.concat(chars)
end

function GetRandomBird(birdTable)
    local count = #birdTable
    if count == 0 then return nil end
    return birdTable[mRandom(1, count)]
end

function ToPercentage(value)
    return sFmt("%d%%", mFloor(value / 10000))
end

function DarkenColor3(color, factor)
    return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

function GetItemRarityColor(itemName)
    local itemData = InventoryModule.Items[itemName]
    local rarity   = itemData and itemData.Rarity or 1
    return RarityColors[rarity] or RarityColors[1], rarity
end

function GetPlayerBoat()
    if not BoatsFolder then return nil, nil end
    return BoatsFolder:FindFirstChild(_BoatName),
           BoatsFolder:FindFirstChild(_TempBoatName)
end

function GetClosestBoat()
    local myBoat = GetPlayerBoat()
    if not myBoat or not myBoat:FindFirstChild("Center") then return nil end
    local myPos = myBoat.Center.Position
    local closestTarget, shortestDistance = nil, mHuge
    for i = 1, #BoatsFolder:GetChildren() do
        local boat = BoatsFolder:GetChildren()[i]
        if boat:FindFirstChild("Center") and boat ~= myBoat then
            local distance = (boat.Center.Position - myPos).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestTarget    = boat
            end
        end
    end
    return closestTarget
end

function TweakShip(ship)
    if not ship then return end
    local center = ship:FindFirstChild("Center")
    if not center then return end
    local bodyVelocity = center:FindFirstChild("SailV")
    if bodyVelocity and bodyVelocity.Velocity.Magnitude > 5 then
        local speedVal = (ship.Speed and ship.Speed.Value or 0) * 0.5
        bodyVelocity.Velocity = bodyVelocity.Velocity.Unit * speedVal * Settings.BoatSpeedMultiplier
    end
end

function IsRemoteBlocked(RemoteName)
    return BlockedAggroRemotes[RemoteName] == true
end

function GetNearestPlayer()
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPart then return nil, mHuge, nil end
    local myPos         = myPart.Position
    local myBin         = LocalPlayer:FindFirstChild("bin")
    local myPartyLeader = myBin and myBin:FindFirstChild("PartyLeader")
    local nearestPlayer, nearestHumanoid = nil, nil
    local nearestDistance = mHuge
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        local character = player.Character
        if not character then continue end
        local binFolder = player:FindFirstChild("bin")
        if not binFolder then continue end
        local pvpToggle = binFolder:FindFirstChild("PvP")
        if not pvpToggle or pvpToggle.Value == false then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local partyLeader = binFolder:FindFirstChild("PartyLeader")
        if Settings.SkipPartyMembers and myPartyLeader and partyLeader then
            local myLeader    = myPartyLeader.Value
            local theirLeader = partyLeader.Value
            if myLeader and theirLeader and myLeader == theirLeader then continue end
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local distance = (myPos - hrp.Position).Magnitude
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer   = player
            nearestHumanoid = humanoid
        end
    end
    return nearestPlayer, nearestDistance, nearestHumanoid
end

function GetNearestNPC()
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPart or not enemiesFolder then return nil, mHuge, nil end
    local myPos                          = myPart.Position
    local nearestNPC, nearestHealthObject = nil, nil
    local nearestDistance                 = mHuge
    for _, npc in enemiesFolder:GetChildren() do
        local hrp = npc:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local creatorObj = npc:FindFirstChild("Creator")
        if creatorObj and creatorObj:IsA("ObjectValue") then
            local cv = creatorObj.Value
            if cv == LocalPlayer or cv == myChar or (cv and cv.Name == LocalPlayer.Name) then continue end
        end
        local humanoid = npc:FindFirstChildOfClass("Humanoid")
        local healthObj
        if humanoid then
            if humanoid.Health <= 0 then continue end
            healthObj = humanoid
        else
            local attributes  = npc:FindFirstChild("Attributes")
            local healthValue = attributes and attributes:FindFirstChild("Health")
            if not healthValue or healthValue.Value <= 0 then continue end
            healthObj = healthValue
        end
        local DataFolder = npc:FindFirstChild("Data")
        if DataFolder then
            local RenownType = DataFolder:FindFirstChild("RenownType")
            if RenownType then
                local myData       = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Data")
                local myRenownType = myData and myData:FindFirstChild("RenownType")
                if Settings.SkipFriendlyNPCs and myRenownType
                    and RenownType.Value == "Positive" and myRenownType.Value == "Positive" then
                    continue
                end
            end
        end
        local distance = (myPos - hrp.Position).Magnitude
        if distance < nearestDistance then
            nearestDistance      = distance
            nearestNPC           = npc
            nearestHealthObject  = healthObj
        end
    end
    return nearestNPC, nearestDistance, nearestHealthObject
end

function FovCircleCleanup()
    if FovCircle then
        FovCircle:Remove()
        FovCircle = nil
    end
end

function UpdateFovCircle()
    if FovCircleConnection and FovCircleConnection.Connected then
        FovCircleConnection:Disconnect()
        FovCircleConnection = nil
    end
    FovCircleCleanup()
    if not (Settings.SilentAimFOVVisible and Settings.SilentAimFOV and drawing) then return end
    FovCircle              = drawing.new("Circle")
    FovCircle.Visible      = true
    FovCircle.Radius       = Settings.SilentAimFOVRadius
    FovCircle.Thickness    = 2
    FovCircle.Color        = SessionData.FOVColor
    FovCircle.Filled       = false
    FovCircle.Transparency = 1
    local fovLastRadius = -1
    FovCircleConnection = RunService.RenderStepped:Connect(function()
        if not FovCircle or not Settings.SilentAimFOVVisible or not Settings.SilentAimFOV then
            FovCircleCleanup()
            if FovCircleConnection then
                FovCircleConnection:Disconnect()
                FovCircleConnection = nil
            end
            return
        end
        FovCircle.Position = UIS:GetMouseLocation()
        local r = Settings.SilentAimFOVRadius
        if r ~= fovLastRadius then
            FovCircle.Radius = r
            fovLastRadius    = r
        end
        FovCircle.Visible = true
    end)
end

function IsTargetInFov(targetPart)
    if not Settings.SilentAimFOV or not targetPart then return true end
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    local fcX, fcY = LastMousePositionX, LastMousePositionY
    if fcX <= 0 and fcY <= 0 then
        local sz = CurrentCamera.ViewportSize
        fcX, fcY = sz.X / 2, sz.Y / 2
    end
    local dx = screenPos.X - fcX
    local dy = screenPos.Y - fcY
    return (dx * dx + dy * dy) <= Settings.SilentAimFOVRadius ^ 2
end

function QOLWallcheck(origin, targetPart)
    if not Settings.SilentAimWallcheck then return true end
    if not origin or not targetPart then return false end
    local char = targetPart:FindFirstAncestorOfClass("Model")
    local filter = {}
    if Map then filter[#filter + 1] = Map end
    local boats = workspace:FindFirstChild("Boats")
    if boats then filter[#filter + 1] = boats end
    if char then filter[#filter + 1] = char end
    if #filter == 0 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = filter
    local dir = targetPart.Position - origin
    local ok, hit = pcall(function()
        return workspace:Raycast(origin, dir, params)
    end)
    if not ok or not hit then return true end
    if QOLIsIgnoredHit(hit.Instance) then return true end
    if char and (hit.Instance == char or hit.Instance:IsDescendantOf(char)) then
        return true
    end
    return false
end



QOLFoliageIgnore = {
    Rigging = true, Sail = true, Puddle = true, RubbleEffect = true,
    Leaves = true, Needles = true, Bush = true,
}

function QOLIsIgnoredHit(inst)
    if not inst then return false end
    if QOLFoliageIgnore[inst.Name] then return true end
    if inst:FindFirstChild("SlashTrail") or inst:FindFirstChild("AuraTrail") then return true end
    if inst.Transparency == 1 and inst.CanCollide == false and inst.Anchored == true then return true end
    return false
end



function QOLTargetVisible(origin, targetPart, char)
    if not origin or not targetPart then return false end
    local filter = {}
    if Map then filter[#filter + 1] = Map end
    local boats = workspace:FindFirstChild("Boats")
    if boats then filter[#filter + 1] = boats end
    if char then filter[#filter + 1] = char end
    if #filter == 0 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = filter
    local ok, hit = pcall(function()
        return workspace:Raycast(origin, targetPart.Position - origin, params)
    end)
    if not ok or not hit then return true end
    if QOLIsIgnoredHit(hit.Instance) then return true end
    if char and (hit.Instance == char or hit.Instance:IsDescendantOf(char)) then
        return true
    end
    return false
end






QOLGunTypes = { Pistol = true, ["Multi Pistols"] = true, Rifle = true }
QOLBowTypes = { Bow = true, ["Heavy Bow"] = true }





function QOLIsBeamSkill(char)
    local ok, res = pcall(function()
        if not char then return false end
        local csv = char:FindFirstChild("CurrentSkillValue")
        if not csv or csv.Value == "" then return false end
        local dec = game:GetService("HttpService"):JSONDecode(csv.Value)
        return type(dec) == "table" and (dec[1] == "Beam" or dec[1] == "Ray")
    end)
    return ok and res == true
end




function QOLMeleeSkillMult(char)
    local ok, mult = pcall(function()
        if not (char and TechTypesModule and TechTypesModule.Types and TechTypesModule.Embodiments) then return 1 end
        local csv = char:FindFirstChild("CurrentSkillValue")
        if not csv or csv.Value == "" then return 1 end
        local dec = game:GetService("HttpService"):JSONDecode(csv.Value)
        if type(dec) ~= "table" or type(dec[1]) ~= "string" then return 1 end
        local def = TechTypesModule.Types[dec[1]]
        if not (def and def.Options and def.Options.Embodiment) then return 1 end
        local order = def.Options.Embodiment.Order
        if not order then return 1 end
        local embName = dec[order + 1]
        if not embName or embName == "(None)" then return 1 end
        local emb = TechTypesModule.Embodiments[embName]
        if emb and emb.AddedStats and tonumber(emb.AddedStats.Speed) then
            return emb.AddedStats.Speed
        end
        return 1
    end)
    if ok and tonumber(mult) and mult > 0 then return mult end
    return 1
end






function QOLSkillShapeMult(char)
    local ok, mult = pcall(function()
        if not (char and SkillTypesModule and SkillTypesModule.Types and SkillTypesModule.Shapes) then return 1 end
        local csv = char:FindFirstChild("CurrentSkillValue")
        if not csv or csv.Value == "" then return 1 end
        local dec = game:GetService("HttpService"):JSONDecode(csv.Value)
        if type(dec) ~= "table" or type(dec[1]) ~= "string" then return 1 end
        if dec[1] == "Pulsar" then return 0.5 end
        local def = SkillTypesModule.Types[dec[1]]
        if not (def and def.Options and def.Options.Shape) then return 1 end
        local order = def.Options.Shape.Order
        if not order then return 1 end
        local shapeName = dec[order + 1]
        if not shapeName or shapeName == "(None)" then return 1 end
        local shape = SkillTypesModule.Shapes[shapeName]
        if shape and shape.AddedStats and tonumber(shape.AddedStats.Speed) then
            return shape.AddedStats.Speed
        end
        return 1
    end)
    if ok and tonumber(mult) and mult > 0 then return mult end
    return 1
end





function QOLImbueSpeedMult(tool, char)
    local ok, mult = pcall(function()
        if not (tool and char and MagicModule and MagicModule.Types) then return 1 end
        local slotObj = tool:FindFirstChild("Slot")
        local data = char:FindFirstChild("Data")
        if not (slotObj and data) then return 1 end
        local slotData = data:FindFirstChild(slotObj.Value)
        local magicObj = slotData and slotData:FindFirstChild("Magic")
        if not (magicObj and magicObj.Value ~= "") then return 1 end
        local raw = tostring(magicObj.Value)
        local slash = string.find(raw, "/")
        local name = slash and string.sub(raw, slash + 1) or raw
        local entry = MagicModule.Types[name]
        if entry and tonumber(entry.ImbueSpeed) then return entry.ImbueSpeed end
        return 1
    end)
    if ok and tonumber(mult) and mult > 0 then return mult end
    return 1
end





function QOLStatSpeedFactor(useDex)
    local ok, result = pcall(function()
        if not (BasicModule and InventoryModule) then return 1 end
        local char = LocalPlayer.Character
        if not char then return 1 end
        local stats = InventoryModule.GetFigureStats(char)
        if not stats then return 1 end
        local lvl = BasicModule.GetLevel(char)
        local eff, val
        if useDex then
            eff = 0.55
            val = stats.Dexterity or 0
        else
            eff = 0.8
            val = stats.Range or 0
        end
        if not val or val == 0 then return 1 end
        return 1 + BasicModule.LinearStatRescale(val, lvl)
            * BasicModule.PercentageStatMultiplier * eff
    end)
    if ok and tonumber(result) and result >= 1 then return result end
    return 1
end

function QOLResolvePredictionSpeed()
    local fallback = tonumber(Settings.PredictionSpeed) or 150
    if not Settings.AutoPredictionSpeed then return fallback end
    local char = LocalPlayer.Character
    if not char then return fallback end
    if QOLIsBeamSkill(char) then return math.huge end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local ivObj = tool:FindFirstChild("ItemValue")
        if ivObj and InventoryModule then
            local ok, lib = pcall(function()
                local _, l = InventoryModule.GetItemValueInfo(ivObj.Value)
                return l
            end)
            if ok and lib then
                local imb = QOLImbueSpeedMult(tool, char)
                if lib.Type == "Relic" then return 250 * QOLStatSpeedFactor(true) * imb end
                if lib.WeaponType then
                    if QOLGunTypes[lib.WeaponType] then return 2000 * QOLStatSpeedFactor(true) * imb end
                    if QOLBowTypes[lib.WeaponType] then return 600 * QOLStatSpeedFactor(true) * imb end
                    return 250 * QOLStatSpeedFactor(true) * imb
                end
            end
        else
            if MeleeModule and MeleeModule.Types[tool.Name] then
                if tool.Name == "Cannon Fist" then return 180 * QOLMeleeSkillMult(char) end
                return 800 * QOLMeleeSkillMult(char)
            end
        end
        return fallback
    end
    local data = char:FindFirstChild("Data")
    local m1 = data and data:FindFirstChild("Magic1")
    if m1 and MagicModule and MagicModule.Types then
        local raw = tostring(m1.Value or "")
        local slash = string.find(raw, "/")
        local name = slash and string.sub(raw, slash + 1) or raw
        local entry = MagicModule.Types[name]
        if entry and tonumber(entry.Speed) then
            return 150 * entry.Speed * QOLStatSpeedFactor(false) * QOLSkillShapeMult(char)
        end
    end
    return fallback
end




function QOLSkipTarget(model, hrp, origin)
    if not model or not hrp then return true end
    if Settings.SkipForceField and model:FindFirstChild("ForceField") then return true end
    if Settings.SkipBlindTargets then
        local attrs = model:FindFirstChild("Attributes")
        local los = attrs and attrs:FindFirstChild("LineOfSightDamage")
        if los then
            local maxR = (attrs:FindFirstChild("DragonTier") and 2500 or 500)
            if origin and (hrp.Position - origin).Magnitude > maxR then return true end
            if origin and not QOLTargetVisible(origin, hrp, model) then return true end
        end
    end
    return false
end


function NewMarker(Object, color, name)
    if not Object then return end
    local marker   = Replicated.RS.Objects.QuestMarker:Clone()
    local markerUI = marker:WaitForChild("UI", 5)
    if not markerUI then return marker end
    local markerDistance = markerUI:WaitForChild("Distance", 5)
    if not markerDistance then return marker end
    if name then
        local markerName           = markerDistance:Clone()
        markerName.Name            = "Name"
        markerName.AnchorPoint     = Vector2.new(0, 1)
        markerName.Position        = UDim2.fromScale(0, 0.25)
        markerName.Text            = name
        markerName.Parent          = markerUI
    end
    marker.Name        = "NpcMarker_" .. Object.Parent.Name
    marker.CFrame      = Object.CFrame
    marker.Anchored    = true
    marker.CanCollide  = false
    marker.Parent      = Object
    markerUI.Icon.ImageColor3 = color
    markerDistance.Visible    = false
    markerUI.Enabled          = true
    markerUI.Adornee          = Object
    return marker
end

function UnregisterItemEsp(part)
    local record = EspData.RegisteredMap[part]
    if not record then return end
    if record.gui and record.gui.Parent then record.gui:Destroy() end
    if record.conns then
        for _, c in pairs(record.conns) do if c and c.Connected then c:Disconnect() end end
    end
    EspData.RegisteredMap[part] = nil
end

function RegisterItemEsp(part, itemType, ActionColor, chestName)
    if not part then return end
    if not (AllowedEspTypes[part.ClassName] or part:IsA("Model")) then return end
    if part.Transparency and part.Transparency >= 1 then return end
    if EspData.RegisteredMap[part] then return end
    local parentPart = part:IsA("Model") and (part.PrimaryPart or part:FindFirstChildOfClass("BasePart")) or part
    if not parentPart then return end
    local name
    if chestName then
        name = chestName
    elseif part:FindFirstChildOfClass("ProximityPrompt") then
        name = part:FindFirstChildOfClass("ProximityPrompt").ObjectText
    elseif (itemType or ""):lower() == "model" then
        name = part.Parent and part.Parent.Name or part.Name
    else
        name = part.Name
    end
    if not chestName then
        local hasFilter = next(ItemEspNameFilter) ~= nil
        if hasFilter and not ItemEspNameFilter[name] then return end
    end
    local rarityColor   = GetItemRarityColor(name)
    local itemData      = InventoryModule.Items[name]
    local color         = itemData and rarityColor or (ActionColor and ActionColor.Value or rarityColor)
    local marker = NewMarker(parentPart, color, name)
    local conns  = {}
    conns[#conns + 1] = parentPart.Destroying:Connect(function() UnregisterItemEsp(part) end)
    conns[#conns + 1] = parentPart:GetPropertyChangedSignal("Transparency"):Connect(function()
        if parentPart.Transparency >= 1 then UnregisterItemEsp(part) end
    end)
    EspData.RegisteredMap[part] = { gui = marker, conns = conns, isChest = chestName ~= nil }
end

function ScanIslandItems(MapRef, CharacterRef, RegisterItemEspFn, OnlyFolders)
    local root = CharacterRef:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local myPos        = root.Position
    local radius       = Settings.ItemEspRadius
    local radiusSq     = radius * radius
    local islandRejectSq = (radius + IslandBuffer) ^ 2
    local function tryRegister(part, className)
        if not part or not part:IsA("BasePart") then return end
        local diff = myPos - part.Position
        if (diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z) <= radiusSq then
            RegisterItemEspFn(part, className or part.ClassName, nil, nil)
        end
    end
    local function scanFilteredFolder(folder)
        if folder.Name == "Chests" then return end
        if not FolderFilter[folder.Name] then return end
        if OnlyFolders and folder.Name ~= OnlyFolders then return end
        for i = 1, #folder:GetChildren() do
            local item = folder:GetChildren()[i]
            tryRegister(item, item.ClassName)
        end
    end
    for _, island in MapRef:GetChildren() do
        local center = island:FindFirstChild("Center")
        if center then
            local diff = myPos - center.Position
            if (diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z) > islandRejectSq then continue end
        end
        for _, folder in island:GetChildren() do
            scanFilteredFolder(folder)
        end
    end
    local SeaContent = MapRef:FindFirstChild("SeaContent")
    if SeaContent then
        for _, model in SeaContent:GetChildren() do
            if model.Name == "DivingSpot" or model.Name == "UWStructure" then
                for _, folder in model:GetChildren() do
                    if folder.Name == "Details" then
                        for _, herb in folder:GetChildren() do
                            if herb:FindFirstChildOfClass("ProximityPrompt") then
                                tryRegister(herb, herb.ClassName)
                            end
                        end
                    end
                end
            end
        end
    end
    local darkSea = SeaContent and SeaContent:FindFirstChild("DarkSea")
    if darkSea then
        for _, model in darkSea:GetChildren() do
            for _, folder in model:GetChildren() do
                scanFilteredFolder(folder)
            end
        end
    end
end

function ClearChestEsp()
    local toRemove = {}
    for part in pairs(ChestEspData) do toRemove[#toRemove + 1] = part end
    for i = 1, #toRemove do
        local part   = toRemove[i]
        local record = ChestEspData[part]
        if record then
            if record.gui and record.gui.Parent then record.gui:Destroy() end
            if record.conns then
                for _, c in ipairs(record.conns) do if c and c.Connected then c:Disconnect() end end
            end
        end
        ChestEspData[part] = nil
    end
end

function ScanChestEsp()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    local myPos    = Character.HumanoidRootPart.Position
    local radiusSq = Settings.ItemEspRadius * Settings.ItemEspRadius
    local function handleChest(chestModel)
        if not chestModel:IsA("Model") then return end
        local base = chestModel:FindFirstChild("Base")
        if not base or not base:IsA("BasePart") then return end
        if base.Transparency >= 1 then return end
        local prompt = base:FindFirstChild("Prompt")
        if not prompt then return end
        if ChestEspData[base] then return end
        local diff = myPos - base.Position
        if (diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z) > radiusSq then return end
        local actionColor = prompt:FindFirstChild("ActionColor")
        local color       = actionColor and actionColor.Value or Color3.fromRGB(255, 255, 255)
        local marker = NewMarker(base, color, chestModel.Name)
        local conns  = {}
        conns[#conns + 1] = base.Destroying:Connect(function()
            local record = ChestEspData[base]
            if record then
                if record.gui and record.gui.Parent then record.gui:Destroy() end
                if record.conns then
                    for _, c in pairs(record.conns) do if c and c.Connected then c:Disconnect() end end
                end
                ChestEspData[base] = nil
            end
        end)
        conns[#conns + 1] = base:GetPropertyChangedSignal("Transparency"):Connect(function()
            if base.Transparency >= 1 then
                local record = ChestEspData[base]
                if record then
                    if record.gui and record.gui.Parent then record.gui:Destroy() end
                    for _, c in pairs(record.conns) do if c and c.Connected then c:Disconnect() end end
                    ChestEspData[base] = nil
                end
            end
        end)
        ChestEspData[base] = { gui = marker, conns = conns }
    end
    for _, island in ipairs(Map:GetChildren()) do
        local chestsFolder = island:FindFirstChild("Chests")
        if chestsFolder then
            for _, chest in ipairs(chestsFolder:GetChildren()) do handleChest(chest) end
        end
    end
    local SeaContent = Map:FindFirstChild("SeaContent")
    if SeaContent then
        for _, model in ipairs(SeaContent:GetChildren()) do
            local chestsFolder = model:FindFirstChild("Chests")
            if chestsFolder then
                for _, chest in ipairs(chestsFolder:GetChildren()) do handleChest(chest) end
            end
        end
    end
    if Settings.SealedChestEsp then
        local tempFolder = Map:FindFirstChild("Temporary")
        if tempFolder then
            for _, sealed in ipairs(tempFolder:GetChildren()) do
                if SealedNames[sealed.Name] and sealed:FindFirstChildOfClass("ProximityPrompt") then
                    if not ChestEspData[sealed] then
                        local marker = NewMarker(sealed, Color3.fromRGB(255, 215, 0), sealed.Name)
                        ChestEspData[sealed] = { gui = marker, conns = {} }
                    end
                end
            end
        end
    end
    if DarkSeaFolder then
        for _, model in ipairs(DarkSeaFolder:GetChildren()) do
            local chestsFolder = model:FindFirstChild("Chests")
            if chestsFolder then
                for _, chest in ipairs(chestsFolder:GetChildren()) do handleChest(chest) end
            end
        end
    end
end

function OpenChest(Chest)
    if not Chest or not Chest:IsA("Model") then return end
    if OpenCooldown[Chest] and Now() - OpenCooldown[Chest] < 3 then return end
    local base = Chest:FindFirstChild("Base")
    if not base then return end
    local ProximityPrompt = base:FindFirstChildOfClass("ProximityPrompt")
    if not ProximityPrompt then return end
    if base.Transparency >= 0.3 then return end
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    if (Character.HumanoidRootPart.Position - base.Position).Magnitude > Settings.ChestRadius then return end
    OpenCooldown[Chest] = Now()
    SafeFirePrompt(ProximityPrompt)
end

function CollectChestsFromFolder(folder, output)
    if not folder then return end
    for _, chest in ipairs(folder:GetChildren()) do
        if chest:FindFirstChild("Base") or chest:FindFirstChildOfClass("ProximityPrompt") then
            output[#output + 1] = chest
        end
    end
end

local CachedChestParts   = {}
local ChestCacheDebounce = false

function BuildChestCache()
    if ChestCacheDebounce then return end
    ChestCacheDebounce = true
    task.spawn(function()
        local newCache = {}
        for _, island in ipairs(Map:GetChildren()) do
            CollectChestsFromFolder(island:FindFirstChild("Chests"), newCache)
        end
        local SeaContent = Map:FindFirstChild("SeaContent")
        if SeaContent then
            for _, model in ipairs(SeaContent:GetChildren()) do
                CollectChestsFromFolder(model:FindFirstChild("Chests"), newCache)
            end
        end
        local tempFolder = Map:FindFirstChild("Temporary")
        if tempFolder then
            for _, sealed in ipairs(tempFolder:GetChildren()) do
                if SealedNames[sealed.Name] and sealed:FindFirstChildOfClass("ProximityPrompt") then
                    newCache[#newCache + 1] = sealed
                end
            end
        end
        if DarkSeaFolder then
            for _, model in ipairs(DarkSeaFolder:GetChildren()) do
                CollectChestsFromFolder(model:FindFirstChild("Chests"), newCache)
            end
        end
        CachedChestParts = newCache
        task.delay(1, function() ChestCacheDebounce = false end)
    end)
end

function GrabLegendaryChests()
    local Count            = 0
    local FirstChestPrimary = nil
    local AskedTeleport    = false
    local function ScanContainer(container)
        for _, v in container:GetDescendants() do
            if not v:IsA("ProximityPrompt") then continue end
            local text = v.ObjectText
            if text == "" then continue end
            if not string.find(text:lower(), "legendary chest", 1, true) then continue end
            local model = v.Parent and v.Parent.Parent
            if not model or model.Name == "Items" or model:FindFirstChild("Open") then continue end
            Count += 1
            if not model:FindFirstChildWhichIsA("Highlight") then
                local highlight              = Instance.new("Highlight")
                highlight.Name              = "LegendaryHighlight " .. Count .. " " .. mRandom(-1000, 1000)
                highlight.Adornee          = model
                highlight.FillTransparency  = 0.6
                highlight.OutlineTransparency = 0
                highlight.Parent           = model
            end
            if not FirstChestPrimary then
                FirstChestPrimary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
    ScanContainer(Map)
    ScanContainer(UnloadedIslands)
    StarterGui:SetCore("SendNotification", {
        Title    = "Legendary chests found:",
        Text     = "Amount: " .. Count,
        Duration = 5,
    })
    if Count > 0 and FirstChestPrimary and not AskedTeleport then
        AskedTeleport = true
        local TeleportPromptHandler = Instance.new("BindableFunction")
        TeleportPromptHandler.OnInvoke = function(choice)
            if choice == "Yes" then
                local hrp = Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = FirstChestPrimary.CFrame + Vector3.new(0, 1000, 0) end
            end
            TeleportPromptHandler:Destroy()
        end
        StarterGui:SetCore("SendNotification", {
            Title    = "Teleport?",
            Text     = "Teleport to first legendary chest?",
            Duration = 10,
            Button1  = "Yes",
            Button2  = "No",
            Callback = TeleportPromptHandler,
        })
    end
    LChestDebounce = false
end

function ClearNpcEsp()
    local toRemove = {}
    for model in pairs(NpcEspData) do toRemove[#toRemove + 1] = model end
    for i = 1, #toRemove do
        local model = toRemove[i]
        local data  = NpcEspData[model]
        if data then
            if data.conns then
                for _, c in ipairs(data.conns) do if c and c.Connected then c:Disconnect() end end
            end
            if data.gui and data.gui.Parent then data.gui:Destroy() end
        end
        NpcEspData[model] = nil
    end
end

function CreateNpcEspForModel(Model)
    if not Model or not Model:FindFirstChildOfClass("Humanoid") then return end
    if NpcEspData[Model] then return end
    if Settings.NpcEspDistanceCapEnabled then
        local myChar = LocalPlayer.Character
        local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local npcRoot = Model:FindFirstChild("HumanoidRootPart")
        if myPart and npcRoot then
            if (myPart.Position - npcRoot.Position).Magnitude > NpcEspMaxDistance then return end
        end
    end
    local humanoid   = Model:FindFirstChildOfClass("Humanoid")
    local adorneePart = Model:FindFirstChild("HumanoidRootPart")
    if not adorneePart then
        for _, part in ipairs(Model:GetChildren()) do
            if part:IsA("BasePart") then adorneePart = part; break end
        end
    end
    if not adorneePart then return end
    local nameText  = sFmt("%s | %.0f/%.0f", Model.Name, humanoid.Health, humanoid.MaxHealth)
    local marker    = NewMarker(adorneePart, Color3.fromRGB(255, 0, 0), nameText)
    local connections = {}
    connections[#connections + 1] = humanoid.HealthChanged:Connect(function()
        if marker and marker:FindFirstChild("UI") then
            local nameLabel = marker.UI:FindFirstChild("Name")
            if nameLabel then
                nameLabel.Text = sFmt("%s | %.0f/%.0f", Model.Name, humanoid.Health, humanoid.MaxHealth)
            end
        end
    end)
    local function cleanupEsp()
        for _, c in ipairs(connections) do if c and c.Connected then c:Disconnect() end end
        if marker then marker:Destroy() end
        NpcEspData[Model] = nil
    end
    connections[#connections + 1] = humanoid.Died:Connect(cleanupEsp)
    connections[#connections + 1] = Model.AncestryChanged:Connect(function()
        if not Model:IsDescendantOf(game.Workspace) then cleanupEsp() end
    end)
    NpcEspData[Model] = { gui = marker, conns = connections }
end

function RefreshNpcEsp()
    if not Settings.NPCEspActive then return end
    ClearNpcEsp()
    for _, model in pairs(enemiesFolder:GetChildren()) do
        if model:FindFirstChildOfClass("Humanoid") then CreateNpcEspForModel(model) end
    end
end

function EnableEpicenterEsp(enabled)
    if EpicenterConnection then
        EpicenterConnection:Disconnect()
        EpicenterConnection = nil
    end
    if EpicenterLabel then
        EpicenterLabel:Remove()
        EpicenterLabel = nil
    end
    if not enabled or not drawing then return end
    local epicenter  = Map:FindFirstChild("The Epicenter")
    local centerPart = epicenter and epicenter:FindFirstChild("Center")
    if not centerPart then return end
    EpicenterLabel              = drawing.new("Text")
    EpicenterLabel.Visible      = true
    EpicenterLabel.Size         = 14
    EpicenterLabel.Font         = Drawing.Fonts.UI
    EpicenterLabel.Color        = Color3.fromRGB(255, 100, 0)
    EpicenterLabel.Outline      = true
    EpicenterLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    EpicenterLabel.Center       = true
    local epicenterLastUpdate = 0
    EpicenterConnection = RunService.RenderStepped:Connect(function()
        if not centerPart or not centerPart.Parent then
            EnableEpicenterEsp(false)
            return
        end
        local now = Now()
        if now - epicenterLastUpdate < 0.1 then return end
        epicenterLastUpdate = now
        local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(centerPart.Position)
        if onScreen then
            local distance = (Character.HumanoidRootPart.Position - centerPart.Position).Magnitude
            EpicenterLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 40)
            EpicenterLabel.Text     = sFmt("Epicenter\n%.0f m", distance)
            EpicenterLabel.Visible  = true
        else
            EpicenterLabel.Visible = false
        end
    end)
end


local FishClockActive      = false
FishClockConns = {}

function FindFirstWaterPart(targetTemp)
    local function scanContainer(container)
        if not container then return nil end
        for _, v in container:GetDescendants() do
            if v.Name == "Water" and v:IsA("BasePart") then
                local tempVal = v:FindFirstChild("Temp")
                if tempVal and tempVal.Value == targetTemp then return v end
            end
        end
        return nil
    end
    return scanContainer(Map) or scanContainer(UnloadedIslands)
end

function FindAnyWaterPart()
    local function scanContainer(container)
        if not container then return nil end
        for _, v in container:GetDescendants() do
            if v.Name == "Water" and v:IsA("BasePart") then return v end
        end
        return nil
    end
    return scanContainer(Map) or scanContainer(UnloadedIslands)
end

QOLMadeBobber = false

function QOLFishingBait()
    local want = (SessionData.UseBaitType and FishingBaitType) or "Normal Bait"
    local valid = { ["Normal Bait"] = true, ["Giant Bait"] = true, ["Swarm Bait"] = true, ["Magic Bait"] = true }
    if not valid[want] then want = "Normal Bait" end
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("BaitGui")
        if gui and gui:FindFirstChild("Bait") then gui.Bait.Value = want end
    end)
    return want
end

function QOLEnsureFishState(waterPart)
    if not Character then return end
    if not Character:FindFirstChild("BobberVal") then
        local ok, bv = pcall(function()
            local o = Instance.new("ObjectValue")
            o.Name = "BobberVal"
            o.Value = waterPart
            o.Parent = Character
            return o
        end)
        if ok and bv then QOLMadeBobber = true end
    end
end

function QOLBeginReelState()
    if not Character then return end
    if not Character:FindFirstChild("ReelCD") then
        pcall(function()
            local rc = Instance.new("BoolValue")
            rc.Name = "ReelCD"
            rc.Parent = Character
        end)
    end
end

function QOLClearFishState()
    if not Character then
        QOLMadeBobber = false
        return
    end
    if QOLMadeBobber then
        local bv = Character:FindFirstChild("BobberVal")
        if bv then pcall(function() bv:Destroy() end) end
        QOLMadeBobber = false
    end
    local rc = Character:FindFirstChild("ReelCD")
    if rc then pcall(function() rc:Destroy() end) end
end

function GetSilentFishArgs()
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    local CharPos = (hrp and hrp.Position) or Vector3.new(0, 398.7853088378906, 0)
    local fallbackPos = Vector3.new(CharPos.X, 398.7853088378906, CharPos.Z)
    if CachedWaterType ~= FishingWaterType then
        CachedWaterPart = nil
        CachedWaterType = FishingWaterType
    end
    if not CachedWaterPart or not CachedWaterPart.Parent then
        if SessionData.UseWaterType then
            CachedWaterPart = FindFirstWaterPart(FishingWaterType)
        else
            CachedWaterPart = FindFirstWaterPart(FishingWaterType) or FindAnyWaterPart()
        end
    end
    if CachedWaterPart then
        local ok, surf = pcall(function()
            return CachedWaterPart.Position.Y + CachedWaterPart.Size.Y / 2
        end)
        local y = (ok and surf) or 398.7853088378906
        return CachedWaterPart, Vector3.new(CharPos.X, y, CharPos.Z)
    end
    return nil, fallbackPos
end

function SetupFishClockTracker()
    for _, c in FishClockConns do pcall(function() c:Disconnect() end) end
    table.clear(FishClockConns)
    FishClockActive = false
    local containers = { Character, LocalPlayer.Backpack, LocalPlayer:FindFirstChild("PlayerGui") }
    for _, container in containers do
        if container then
            if container:FindFirstChild("FishClock") then FishClockActive = true end
            FishClockConns[#FishClockConns + 1] = container.ChildAdded:Connect(function(child)
                if child.Name == "FishClock" then FishClockActive = true end
            end)
            FishClockConns[#FishClockConns + 1] = container.ChildRemoved:Connect(function(child)
                if child.Name == "FishClock" then FishClockActive = false end
            end)
        end
    end
end

_reelRunning = false
function SetupFishingListener()
    if ChildAddedConnection then ChildAddedConnection:Disconnect() end
    if not Character then return end
    ChildAddedConnection = Character.ChildAdded:Connect(function(child)
        if not Settings.AutoFish or child.Name ~= "FishBiteGoal" or not FishingTool then return end
        if _reelRunning then return end
        _reelRunning = true
        if FishingType == "Silent" then
            task.spawn(function()
                QOLBeginReelState()
                local start = Now()
                while child.Parent == Character and Settings.AutoFish and (Now() - start) < 15 do
                    if not FishingTool or FishingTool.Parent ~= Character then break end
                    pcall(function() Remotes.Misc.FishState:FireServer("Reel") end)
                    task.wait(0.25)
                end
                FishClockActive = false
                QOLClearFishState()
                _reelRunning = false
            end)
        else
            task.spawn(function()
                QOLBeginReelState()
                local start = Now()
                while child.Parent == Character and Settings.AutoFish and (Now() - start) < 15 do
                    if not FishingTool or FishingTool.Parent ~= Character then break end
                    pcall(function()
                        Remotes.Misc.ToolAction:FireServer(FishingTool, nil, nil,
                            SessionData.UseBaitType and FishingBaitType or "Normal Bait")
                    end)
                    task.wait(0.25)
                end
                local hum = Character and Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Parent and Settings.AutoFish then
                    hum:UnequipTools()
                    task.wait(0.4)
                    if FishingTool and Settings.AutoFish then
                        hum:EquipTool(FishingTool)
                        task.delay(1, function()
                            if FishingTool and FishingTool.Parent and Settings.AutoFish then
                                pcall(function()
                                    Remotes.Misc.ToolAction:FireServer(FishingTool, nil, nil,
                                        SessionData.UseBaitType and FishingBaitType or "Normal Bait")
                                end)
                            end
                        end)
                    end
                end
                QOLClearFishState()
                _reelRunning = false
            end)
        end
    end)
end

function GrabFightingStyleMoveset()
    local searchLocations = { Character, LocalPlayer.Backpack }
    for _, container in ipairs(searchLocations) do
        if container then
            for _, Tool in ipairs(container:GetChildren()) do
                if Tool:IsA("Tool") and table.find(LookingForFightingStyles, Tool.Name) then
                    return Tool
                end
            end
        end
    end
    return nil
end


local KeybindWaiting = nil

function ApplyKeybindAction(keyCode)
    for action, bound in pairs(SessionData.Keybinds) do
        if bound == keyCode then
            if action == "GodMode" then
                Settings.GodMode    = not Settings.GodMode
                SessionData.GodMode = Settings.GodMode
                Fluent:Notify({ Duration = 5, Title = "Keybind", Content = "GodMode: " .. tostring(Settings.GodMode) })
            elseif action == "SilentAim" then
                Settings.SilentAim    = not Settings.SilentAim
                SessionData.SilentAim = Settings.SilentAim
                if not Settings.SilentAim and SilentAimLockLabel then SilentAimLockLabel.Visible = false end
                Fluent:Notify({ Duration = 5, Title = "Keybind", Content = "SilentAim: " .. tostring(Settings.SilentAim) })
            elseif action == "AutoFish" then
                if FishingTool then
                    Settings.AutoFish    = not Settings.AutoFish
                    SessionData.AutoFish = Settings.AutoFish
                    Fluent:Notify({ Duration = 5, Title = "Keybind", Content = "AutoFish: " .. tostring(Settings.AutoFish) })
                end
            end
        end
    end
end


local ConfigFolder    = "EldritchHub"
local ConfigExt       = ".json"

function EnsureConfigFolder()
    if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
end

function uiSet(id, value)
    if not Fluent then return end
    local element
    if type(Fluent.GetElement) == "function" then
        local ok, el = pcall(function() return Fluent:GetElement(id) end)
        if ok then element = el end
    end
    if not element and Fluent.Options then
        element = Fluent.Options[id]
    end
    if element then pcall(function() element:SetValue(value) end) end
end

function SerializeConfig()
    local data = {
        godMode               = Settings.GodMode,
        silentAim             = Settings.SilentAim,
        silentAimNPCs         = Settings.SilentAimNPCs,
        silentAimPlayers      = Settings.SilentAimPlayers,
        skipPartyMembers      = Settings.SkipPartyMembers,
        skipFriendlyNPCs      = Settings.SkipFriendlyNPCs,
        prediction            = Settings.Prediction,
        predictionSpeed       = Settings.PredictionSpeed,
        autoPredictionSpeed   = Settings.AutoPredictionSpeed,
        skipForceField        = Settings.SkipForceField,
        skipBlindTargets      = Settings.SkipBlindTargets,
        fovCheck              = Settings.SilentAimFOV,
        wallcheck             = Settings.SilentAimWallcheck,
        showFOVCircle         = Settings.SilentAimFOVVisible,
        fovRadius             = Settings.SilentAimFOVRadius,
        maxLockDistance       = SilentMaxDistance,
        enableDamageMulti     = Settings.EnableDamageMultiplier,
        damageMultiplier      = Settings.DamageMultiplier,
        chargeMultiEnabled    = Settings.ChargeMultiplierEnabled,
        chargeMultiAmt        = Settings.ChargeMultiplierAmt,
        boostBoatSpeed        = Settings.BoostBoatSpeed,
        boatSpeedMultiplier   = Settings.BoatSpeedMultiplier,
        reduceStamina         = Settings.ReduceStamina,
        BlockNPCAggro         = Settings.BlockNPCAggro,
        npcEspActive          = Settings.NPCEspActive,
        npcEspDistanceCap     = Settings.NpcEspDistanceCapEnabled,
        chestEspEnabled       = Settings.ChestEspEnabled,
        autoEat               = Settings.AutoEat,
        chestAura             = Settings.ChestAura,
        chestRadius           = Settings.ChestRadius,
        galleonFarm           = Settings.GalleonFarm,
        birdMeatFarm          = Settings.BirdMeatFarm,
        citizenKillAura       = Settings.CitizenKillAura,
        citizenKillRadius     = Settings.CitizenKillRadius,
        aggroRedirect         = Settings.AggroRedirect,
        aggroTarget           = Settings.AggroTarget,
        silentBottleDrinking  = Settings.SilentBottleDrinking,
        hecateNotifier        = Settings.HecateNotifier,
        epicenterESP          = Settings.EpicenterESP,
        autoFish              = Settings.AutoFish,
        FishingType           = FishingType,
        FishingBaitType       = FishingBaitType,
        FishingWaterType      = FishingWaterType,
        FishingToolName       = FishingToolName or "",
        useBaitType           = SessionData.UseBaitType,
        useWaterType          = SessionData.UseWaterType,
        autoWash              = Settings.AutoWash,
        autoWashDelay         = SessionData.AutoWashDelay,
        teleportDelay         = SessionData.TeleportDelay,
        itemEspRadius         = Settings.ItemEspRadius,
        diveFarmEnabled       = Settings.DiveFarmEnabled,
        diveRemoveEnemies     = Settings.DiveRemoveEnemies,
        diveRemoveDamage      = Settings.DiveRemoveDamage,
        diveSkipPlayers       = Settings.DiveSkipPlayers,
        divePreferSpots       = Settings.DivePreferSpots,
        divePreferStructs     = Settings.DivePreferStructs,
        diveIgnoreLegendary   = Settings.DiveIgnoreLegendary,
        diveSlowMode          = Settings.DiveSlowMode,
        reagantIsland         = SessionData.ReagantIsland,
        copperSlot            = SessionData.CopperSlot,
        copperIsland          = SessionData.CopperIsland,
        qolInfJump            = Settings.QOLInfJump,
        qolCrosshair          = Settings.QOLCrosshair,
        qolHitSound           = Settings.QOLHitSound,
        qolHitSoundId         = SessionData.QOLHitSoundId,
        qolHitSoundVol        = SessionData.QOLHitSoundVol,
        qolAntiFling          = Settings.QOLAntiFling,
        qolUnderground        = Settings.QOLUnderground,
        qolInvisDip           = SessionData.QOLInvisDip,
        qolInvisUp            = Settings.QOLInvisUp,
        FOVColorName          = SessionData.FOVColorName,
        FOVColorR             = SessionData.FOVColor.R * 255,
        FOVColorG             = SessionData.FOVColor.G * 255,
        FOVColorB             = SessionData.FOVColor.B * 255,
        Keybinds              = (function()
            local t = {}
            for action, kc in pairs(SessionData.Keybinds) do
                t[action] = tostring(kc.Name)
            end
            return t
        end)(),
    }
    return game:GetService("HttpService"):JSONEncode(data)
end

function DeserializeConfig(raw)
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

function ApplyLoadedConfig(data)
    if type(data.godMode)              == "boolean" then Settings.GodMode = data.godMode; SessionData.GodMode = data.godMode; uiSet("Godmode1", data.godMode) end
    if type(data.silentAim)            == "boolean" then Settings.SilentAim = data.silentAim; SessionData.SilentAim = data.silentAim; uiSet("SilentAim2", data.silentAim) end
    if type(data.silentAimNPCs)        == "boolean" then Settings.SilentAimNPCs = data.silentAimNPCs; SessionData.SilentAimNPCs = data.silentAimNPCs; uiSet("TargetNPCs3", data.silentAimNPCs) end
    if type(data.silentAimPlayers)     == "boolean" then Settings.SilentAimPlayers = data.silentAimPlayers; SessionData.SilentAimPlayers = data.silentAimPlayers; uiSet("TargetPlayers4", data.silentAimPlayers) end
    if type(data.skipPartyMembers)     == "boolean" then Settings.SkipPartyMembers = data.skipPartyMembers; SessionData.SkipPartyMembers = data.skipPartyMembers; uiSet("SkipPartyMembers5", data.skipPartyMembers) end
    if type(data.skipFriendlyNPCs)     == "boolean" then Settings.SkipFriendlyNPCs = data.skipFriendlyNPCs; SessionData.SkipFriendlyNPCs = data.skipFriendlyNPCs; uiSet("SkipFriendlyNPCs6", data.skipFriendlyNPCs) end
    if type(data.prediction)           == "boolean" then Settings.Prediction = data.prediction; SessionData.Prediction = data.prediction; uiSet("Prediction7", data.prediction) end
    if type(data.predictionSpeed)       == "number" then Settings.PredictionSpeed = data.predictionSpeed; SessionData.PredictionSpeed = data.predictionSpeed; uiSet("PredictionSpeed104", data.predictionSpeed) end
    if type(data.autoPredictionSpeed)   == "boolean" then Settings.AutoPredictionSpeed = data.autoPredictionSpeed; SessionData.AutoPredictionSpeed = data.autoPredictionSpeed; uiSet("AutoPredictionSpeed111", data.autoPredictionSpeed) end
    if type(data.skipForceField)        == "boolean" then Settings.SkipForceField = data.skipForceField; SessionData.SkipForceField = data.skipForceField; uiSet("SkipForceField105", data.skipForceField) end
    if type(data.skipBlindTargets)      == "boolean" then Settings.SkipBlindTargets = data.skipBlindTargets; SessionData.SkipBlindTargets = data.skipBlindTargets; uiSet("SkipBlindTargets106", data.skipBlindTargets) end
    if type(data.fovCheck)             == "boolean" then Settings.SilentAimFOV = data.fovCheck; SessionData.SilentAimFOV = data.fovCheck; uiSet("FOVCheck8", data.fovCheck) end
    if type(data.wallcheck)            == "boolean" then Settings.SilentAimWallcheck = data.wallcheck; SessionData.SilentAimWallcheck = data.wallcheck; uiSet("SilentAimWallcheck70", data.wallcheck) end
    if type(data.showFOVCircle)        == "boolean" then Settings.SilentAimFOVVisible = data.showFOVCircle; SessionData.SilentAimFOVVisible = data.showFOVCircle; uiSet("ShowFOVCircle9", data.showFOVCircle) end
    if type(data.enableDamageMulti)    == "boolean" then Settings.EnableDamageMultiplier = data.enableDamageMulti; SessionData.EnableDamageMultiplier = data.enableDamageMulti; uiSet("Enabledamagemultiplier23", data.enableDamageMulti) end
    if type(data.boostBoatSpeed)       == "boolean" then Settings.BoostBoatSpeed = data.boostBoatSpeed; SessionData.BoostBoatSpeed = data.boostBoatSpeed; uiSet("Boostboatspeed24", data.boostBoatSpeed) end
    if type(data.reduceStamina)        == "boolean" then Settings.ReduceStamina = data.reduceStamina; SessionData.ReduceStamina = data.reduceStamina; uiSet("Reducedstaminaconsumption13", data.reduceStamina) end
    if type(data.BlockNPCAggro)        == "boolean" then Settings.BlockNPCAggro = data.BlockNPCAggro; SessionData.BlockNPCAggro = data.BlockNPCAggro; uiSet("NoNPCAggro11", data.BlockNPCAggro) end
    if type(data.npcEspActive)         == "boolean" then Settings.NPCEspActive = data.npcEspActive; SessionData.NPCEspActive = data.npcEspActive; uiSet("NPCEsp12", data.npcEspActive) end
    if type(data.chestEspEnabled)      == "boolean" then Settings.ChestEspEnabled = data.chestEspEnabled; SessionData.ChestEspEnabled = data.chestEspEnabled; uiSet("ChestEsp91", data.chestEspEnabled) end
    if type(data.autoEat)              == "boolean" then Settings.AutoEat = data.autoEat; SessionData.AutoEat = data.autoEat; uiSet("Toggleautoeat25", data.autoEat) end
    if type(data.chestAura)            == "boolean" then Settings.ChestAura = data.chestAura; SessionData.ChestAura = data.chestAura; uiSet("ChestAura27", data.chestAura) end
    if type(data.galleonFarm)          == "boolean" then Settings.GalleonFarm = data.galleonFarm; SessionData.GalleonFarm = data.galleonFarm; uiSet("Drachmafarm26", data.galleonFarm) end
    if type(data.birdMeatFarm)         == "boolean" then Settings.BirdMeatFarm = data.birdMeatFarm; SessionData.BirdMeatFarm = data.birdMeatFarm; uiSet("BirdMeatFarm67", data.birdMeatFarm) end
    if type(data.citizenKillAura)       == "boolean" then Settings.CitizenKillAura = data.citizenKillAura; SessionData.CitizenKillAura = data.citizenKillAura; uiSet("CitizenKillAura107", data.citizenKillAura) end
    if type(data.citizenKillRadius)     == "number" then Settings.CitizenKillRadius = data.citizenKillRadius; SessionData.CitizenKillRadius = data.citizenKillRadius; uiSet("CitizenKillRadius108", data.citizenKillRadius) end
    if type(data.aggroRedirect)         == "boolean" then Settings.AggroRedirect = data.aggroRedirect; SessionData.AggroRedirect = data.aggroRedirect; uiSet("AggroRedirect109", data.aggroRedirect) end
    if type(data.aggroTarget)           == "string" then Settings.AggroTarget = data.aggroTarget; SessionData.AggroTarget = data.aggroTarget; uiSet("AggroTarget110", data.aggroTarget) end
    if type(data.silentBottleDrinking) == "boolean" then Settings.SilentBottleDrinking = data.silentBottleDrinking; SessionData.SilentBottleDrinking = data.silentBottleDrinking; uiSet("DrinkBottlesSilently14", data.silentBottleDrinking) end
    if type(data.hecateNotifier)       == "boolean" then Settings.HecateNotifier = data.hecateNotifier; SessionData.HecateNotifier = data.hecateNotifier; uiSet("Hecateessencenotifier31", data.hecateNotifier) end
    if type(data.epicenterESP)         == "boolean" then Settings.EpicenterESP = data.epicenterESP; SessionData.EpicenterESP = data.epicenterESP; uiSet("EpicenterESP32", data.epicenterESP) end
    if type(data.autoFish)             == "boolean" then Settings.AutoFish = data.autoFish; SessionData.AutoFish = data.autoFish; uiSet("Toggleautofish28", data.autoFish) end
    if type(data.autoWash)             == "boolean" then Settings.AutoWash = data.autoWash; SessionData.AutoWash = data.autoWash; uiSet("Toggleautowashbin30", data.autoWash) end
    if type(data.npcEspDistanceCap)    == "boolean" then Settings.NpcEspDistanceCapEnabled = data.npcEspDistanceCap; SessionData.NpcEspDistanceCapEnabled = data.npcEspDistanceCap; uiSet("NPCEspDisableDistanceCap90", not data.npcEspDistanceCap) end
    if type(data.fovRadius)           == "number" then Settings.SilentAimFOVRadius = data.fovRadius; SessionData.SilentAimFOVRadius = data.fovRadius; uiSet("FOVRadius35", data.fovRadius) end
    if type(data.maxLockDistance)     == "number" then SilentMaxDistance = data.maxLockDistance; SessionData.SilentAimMaxDistance = data.maxLockDistance; uiSet("MaxLockDistance34", data.maxLockDistance) end
    if type(data.damageMultiplier)    == "number" then Settings.DamageMultiplier = data.damageMultiplier; SessionData.DamageMultiplier = data.damageMultiplier; uiSet("DamageMultiplier73", tostring(data.damageMultiplier)) end
    if type(data.chargeMultiAmt)      == "number" then Settings.ChargeMultiplierAmt = data.chargeMultiAmt; SessionData.ChargeMultiplierAmt = data.chargeMultiAmt; uiSet("ChargeMultiplierAmt95", tostring(data.chargeMultiAmt)) end
    if type(data.boatSpeedMultiplier) == "number" then Settings.BoatSpeedMultiplier = data.boatSpeedMultiplier; SessionData.BoatSpeedMultiplier = data.boatSpeedMultiplier; uiSet("Boatspeedmultiplier74", tostring(data.boatSpeedMultiplier)) end
    if type(data.chestRadius)         == "number" then Settings.ChestRadius = data.chestRadius; SessionData.ChestRadius = data.chestRadius; uiSet("ChestRadius38", data.chestRadius) end
    if type(data.autoWashDelay)       == "number" then SessionData.AutoWashDelay = data.autoWashDelay; uiSet("AutoWashIntervals39", data.autoWashDelay) end
    if type(data.teleportDelay)       == "number" then SessionData.TeleportDelay = data.teleportDelay; Settings.TeleportDelay = data.teleportDelay; uiSet("TeleportAnchorDelays40", data.teleportDelay) end
    if type(data.itemEspRadius)       == "number" then Settings.ItemEspRadius = data.itemEspRadius; SessionData.ItemEspRadius = data.itemEspRadius; uiSet("ItemESPRange37", data.itemEspRadius) end
    DiveSuppressFarmKill = true
    if type(data.diveFarmEnabled)     == "boolean" then Settings.DiveFarmEnabled = data.diveFarmEnabled; SessionData.DiveFarmEnabled = data.diveFarmEnabled; uiSet("DiveFarmEnabled60", data.diveFarmEnabled) end
    DiveSuppressFarmKill = false
    DiveSuppressRemovePrompt = true
    if type(data.diveRemoveEnemies)   == "boolean" then Settings.DiveRemoveEnemies = data.diveRemoveEnemies; SessionData.DiveRemoveEnemies = data.diveRemoveEnemies; uiSet("DiveRemoveEnemies61", data.diveRemoveEnemies) end
    DiveSuppressRemovePrompt = false
    if type(data.diveRemoveDamage)    == "boolean" then Settings.DiveRemoveDamage = data.diveRemoveDamage; SessionData.DiveRemoveDamage = data.diveRemoveDamage; uiSet("DiveRemoveDamage62", data.diveRemoveDamage) end
    if type(data.diveSkipPlayers)     == "boolean" then Settings.DiveSkipPlayers = data.diveSkipPlayers; SessionData.DiveSkipPlayers = data.diveSkipPlayers; uiSet("DiveSkipPlayers63", data.diveSkipPlayers) end
    if type(data.divePreferSpots)     == "boolean" then Settings.DivePreferSpots = data.divePreferSpots; SessionData.DivePreferSpots = data.divePreferSpots; uiSet("DivePreferSpots80", data.divePreferSpots) end
    if type(data.divePreferStructs)   == "boolean" then Settings.DivePreferStructs = data.divePreferStructs; SessionData.DivePreferStructs = data.divePreferStructs; uiSet("DivePreferStructs81", data.divePreferStructs) end
    if type(data.diveIgnoreLegendary) == "boolean" then Settings.DiveIgnoreLegendary = data.diveIgnoreLegendary; SessionData.DiveIgnoreLegendary = data.diveIgnoreLegendary; uiSet("DiveIgnoreLegendary82", data.diveIgnoreLegendary) end
    if type(data.diveSlowMode)        == "boolean" then Settings.DiveSlowMode = data.diveSlowMode; SessionData.DiveSlowMode = data.diveSlowMode; uiSet("DiveSlowMode83", data.diveSlowMode) end
    if type(data.reagantIsland)       == "string" and data.reagantIsland ~= "" then SessionData.ReagantIsland = data.reagantIsland; uiSet("ReagantIsland64", data.reagantIsland) end
    if type(data.copperSlot)          == "string" and data.copperSlot ~= "" then SessionData.CopperSlot = data.copperSlot; uiSet("CopperSlot65", data.copperSlot) end
    if type(data.copperIsland)        == "string" and data.copperIsland ~= "" then SessionData.CopperIsland = data.copperIsland; uiSet("CopperIsland66", data.copperIsland) end
    if type(data.qolInfJump)          == "boolean" then Settings.QOLInfJump = data.qolInfJump; SessionData.QOLInfJump = data.qolInfJump; uiSet("QOLInfJump68", data.qolInfJump) end
    if type(data.qolCrosshair)        == "boolean" then Settings.QOLCrosshair = data.qolCrosshair; SessionData.QOLCrosshair = data.qolCrosshair; uiSet("QOLCrosshair69", data.qolCrosshair) end
    if type(data.qolHitSound)         == "boolean" then Settings.QOLHitSound = data.qolHitSound; SessionData.QOLHitSound = data.qolHitSound; uiSet("QOLHitSound72", data.qolHitSound) end
    if type(data.qolHitSoundId)       == "string" then SessionData.QOLHitSoundId = data.qolHitSoundId; uiSet("QOLHitSoundId73", data.qolHitSoundId) end
    if type(data.qolHitSoundVol)      == "number" then SessionData.QOLHitSoundVol = data.qolHitSoundVol; uiSet("QOLHitSoundVol74", data.qolHitSoundVol) end
    if type(data.qolAntiFling)        == "boolean" then Settings.QOLAntiFling = data.qolAntiFling; SessionData.QOLAntiFling = data.qolAntiFling; uiSet("QOLAntiFling77", data.qolAntiFling) end
    if type(data.qolUnderground)      == "boolean" then Settings.QOLUnderground = data.qolUnderground; SessionData.QOLUnderground = data.qolUnderground; uiSet("QOLUnderground78", data.qolUnderground) end
    if type(data.qolInvisDip)         == "number" then SessionData.QOLInvisDip = data.qolInvisDip; uiSet("QOLInvisDip72", data.qolInvisDip) end
    if type(data.qolInvisUp)          == "boolean" then Settings.QOLInvisUp = data.qolInvisUp; SessionData.QOLInvisUp = data.qolInvisUp; uiSet("QOLInvisUp70", data.qolInvisUp) end
    if type(data.FishingType)     == "string" then FishingType = data.FishingType; SessionData.FishingType = data.FishingType; uiSet("FishingType51", data.FishingType) end
    if type(data.FishingBaitType) == "string" then FishingBaitType = data.FishingBaitType; SessionData.FishingBaitType = data.FishingBaitType; uiSet("FishingBaitType56", data.FishingBaitType) end
    if type(data.useBaitType)     == "boolean" then SessionData.UseBaitType = data.useBaitType; uiSet("UseBaitType57", data.useBaitType) end
    if type(data.useWaterType)    == "boolean" then SessionData.UseWaterType = data.useWaterType; uiSet("UseWaterType58", data.useWaterType) end
    if type(data.FishingWaterType) == "string" then FishingWaterType = data.FishingWaterType; SessionData.FishingWaterType = data.FishingWaterType; uiSet("FishingWaterType59", data.FishingWaterType) end
    if type(data.FishingToolName) == "string" and data.FishingToolName ~= "" then
        FishingToolName = data.FishingToolName
        SessionData.FishingToolName = data.FishingToolName
        FishingTool = LocalPlayer.Backpack:FindFirstChild(FishingToolName) or Character:FindFirstChild(FishingToolName)
    end
    if type(data.FOVColorName) == "string" then uiSet("FOVCircleColour41", data.FOVColorName); SessionData.FOVColorName = data.FOVColorName end
    if type(data.FOVColorR) == "number" then
        local col = Color3.fromRGB(data.FOVColorR, data.FOVColorG or 0, data.FOVColorB or 0)
        SessionData.FOVColor = col
        if FovCircle then FovCircle.Color = col end
    end
    if type(data.Keybinds) == "table" then
        for action, keyName in pairs(data.Keybinds) do
            local ok2, kc = pcall(function() return Enum.KeyCode[keyName] end)
            if ok2 and kc then SessionData.Keybinds[action] = kc end
        end
    end
    Settings.SilentAimFOVRadius  = Settings.SilentAimFOVRadius
    Settings.DamageMultiplier    = Settings.DamageMultiplier
    Settings.ChargeMultiplierAmt = Settings.ChargeMultiplierAmt
    Settings.BoatSpeedMultiplier = Settings.BoatSpeedMultiplier
    Settings.ChestRadius         = Settings.ChestRadius
    Settings.ItemEspRadius       = Settings.ItemEspRadius
end

function ActivateLoadedConfig()
    UpdateFovCircle()
    if Settings.NPCEspActive then
        RefreshNpcEsp()
    else
        ClearNpcEsp()
    end
    EnableEpicenterEsp(Settings.EpicenterESP)
    if Settings.ChestAura and drawing and not ChestAuraLabel then
        ChestAuraLabel          = drawing.new("Text")
        ChestAuraLabel.Size     = 16
        ChestAuraLabel.Color    = Color3.fromRGB(255, 215, 0)
        ChestAuraLabel.Outline  = true
        ChestAuraLabel.Position = Vector2.new(10, 80)
        ChestAuraLabel.Text     = "Chests opened: 0"
        ChestAuraLabel.Visible  = true
    elseif not Settings.ChestAura and ChestAuraLabel then
        ChestAuraLabel:Remove()
        ChestAuraLabel = nil
    end
    if Settings.AutoFish and FishingTool then
        if FishingType == "Silent" then
            local waterPart, waterPos = GetSilentFishArgs()
            if waterPart and not FishBiteInProgress() then
                QOLEnsureFishState(waterPart)
                Remotes.Misc.FishClock:FireServer(FishingTool, waterPart, waterPos, QOLFishingBait())
            end
        else
            local hum = Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:UnequipTools()
                task.wait(0.2)
                hum:EquipTool(FishingTool)
            end
        end
    end
    if Settings.DiveFarmEnabled then
        task.spawn(function()
            task.wait(1)
            if Settings.DiveFarmEnabled then StartDiveFarm() end
        end)
    end
end

function GetConfigList()
    EnsureConfigFolder()
    local files = listfiles(ConfigFolder)
    local names = {}
    for i = 1, #files do
        local path = files[i]
        local name = path:match("[^/\\]+$")
        if name and name:sub(-#ConfigExt) == ConfigExt then
            names[#names + 1] = name:sub(1, -#ConfigExt - 1)
        end
    end
    if #names == 0 then names[1] = "No configs found" end
    return names
end

local SelectedConfig = nil
local ConfigDropdown = nil

function RefreshConfigDropdown()
    if not ConfigDropdown then return end
    local newList = GetConfigList()
    pcall(function() ConfigDropdown:SetValues(newList) end)
end

local ConfigNameInput = "default"


local TeleportBind = Instance.new("BindableFunction")
TeleportBind.OnInvoke = function()
    if HecatePart then
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = HecatePart.CFrame end
    end
end

local Scheduler = {
    buckets = {
        [0.1] = {}, [0.5] = {}, [1] = {}, [5] = {}, [15] = {},
    },
    nearestBucket = function(Self, interval)
        if interval <= 0.1 then return 0.1 end
        if interval <= 0.5 then return 0.5 end
        if interval <= 1   then return 1   end
        if interval <= 5   then return 5   end
        return 15
    end,
    add = function(Self, name, interval, fn)
        local b = Self:nearestBucket(interval)
        Self.buckets[b][name] = { interval = interval, fn = fn, nextRun = Now() + interval }
    end,
    remove = function(Self, name)
        for _, tbl in Self.buckets do tbl[name] = nil end
    end,
}

function FishBiteInProgress()
    return Character and Character:FindFirstChild("FishBiteGoal") ~= nil
end

Scheduler:add("FishingTaskLegit", 10, function()
    if Settings.AutoFish and FishingType == "Legit" and FishingTool and FishingTool.Parent == Character then
        if not FishClockActive and not FishBiteInProgress() then
            Remotes.Misc.ToolAction:FireServer(FishingTool, nil, nil,
                SessionData.UseBaitType and FishingBaitType or "Normal Bait")
        end
    end
end)

Scheduler:add("FishingTaskSilent", 1, function()
    if Settings.AutoFish and FishingType == "Silent" and FishingTool and not FishClockActive and not FishBiteInProgress() then
        local waterPart, waterPos = GetSilentFishArgs()
        if waterPart then
            QOLEnsureFishState(waterPart)
            Remotes.Misc.FishClock:FireServer(FishingTool, waterPart, waterPos, QOLFishingBait())
        end
    end
end)

Scheduler:add("ChestAura", 2, function()
    if not Settings.ChestAura then return end
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local rootPos = hrp.Position
    local radius  = (tonumber(Settings.ChestRadius) or 25) + 10
    local radiusSq = radius * radius
    for i = 1, #CachedChestParts do
        local chest = CachedChestParts[i]
        if chest and chest.Parent then
            local base = chest:FindFirstChild("Base")
            if base then
                local d = rootPos - base.Position
                if (d.X * d.X + d.Y * d.Y + d.Z * d.Z) <= radiusSq then
                local before = OpenCooldown[chest]
                OpenChest(chest)
                if OpenCooldown[chest] ~= before then
                    ChestAuraCount += 1
                    if ChestAuraLabel then
                        ChestAuraLabel.Text = "Chests opened: " .. ChestAuraCount
                    end
                end
                end
            end
        end
    end
end)

Scheduler:add("AutoEat", 10, function()
    if not Settings.AutoEat or not ModifiedStats.FoodItem then return end
    local Tool = LocalPlayer.Backpack:FindFirstChild(ModifiedStats.FoodItem)
    if Tool then Remotes.Misc.ToolAction:FireServer(Tool) end
end)

Scheduler:add("AutoWash", 1, function()
    if not Settings.AutoWash then return end
    local now = Now()
    if not Scheduler._lastWash or now - Scheduler._lastWash >= SessionData.AutoWashDelay then
        Scheduler._lastWash = now
        Remotes.Boats.Wash:FireServer()
    end
end)

Scheduler:add("HecateNotifier", 5, function()
    if not Settings.HecateNotifier or not DarkSeaFolder then return end
    for _, child in pairs(DarkSeaFolder:GetChildren()) do
        if child.Name == "Island" and child:FindFirstChild("HecateEssence") then
            StarterGui:SetCore("SendNotification", {
                Title    = "Hecate found!",
                Text     = "Click the button below to teleport.",
                Duration = 5,
                Button1  = "Teleport",
                Callback = TeleportBind,
            })
            HecatePart = child:FindFirstChild("HecateEssence")
            break
        end
    end
end)

DrachmaBusy, BirdBusy = false, false
Scheduler:add("Drachma Farm", 2.5, function()
    if Settings.GalleonFarm and not DrachmaBusy then
        DrachmaBusy = true
        task.wait(math.random(0, 80) / 100)
        pcall(function() Remotes.Combat.CitizenKillCredit:FireServer("Thief") end)
        DrachmaBusy = false
    end
end)

Scheduler:add("BirdMeat Farm", 2.5, function()
    if Settings.BirdMeatFarm and not BirdBusy then
        BirdBusy = true
        task.wait(math.random(0, 80) / 100)
        pcall(function() Remotes.Misc.BirdKill:FireServer(GetRandomBird(BirdTypes) or "Seagull") end)
        BirdBusy = false
    end
end)



function QOLCitizenCredit(citizen)
    local hrp = citizen:FindFirstChild("HumanoidRootPart")
    local data = citizen:FindFirstChild("Data")
    if data and citizen:FindFirstChild("Guard")
        and data:FindFirstChild("JLN") and data:FindFirstChild("CharacterData") and hrp then
        pcall(function()
            Remotes.Combat.CitizenKillCredit:FireServer(data.JLN.Value, data.CharacterData.Value, hrp.CFrame)
        end)
    elseif citizen:FindFirstChild("Thief") and citizen:FindFirstChild("Robbed") then
        pcall(function() Remotes.Combat.CitizenKillCredit:FireServer("Thief") end)
    else
        pcall(function() Remotes.Combat.CitizenKillCredit:FireServer() end)
    end
end

Scheduler:add("CitizenKillAura", 1, function()
    if not Settings.CitizenKillAura then return end
    local citizens = workspace:FindFirstChild("Citizens")
    if not citizens then return end
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPart then return end
    local myPos = myPart.Position
    local radius = tonumber(Settings.CitizenKillRadius) or 150
    for _, v in citizens:GetChildren() do
        local hum = v:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if (hrp.Position - myPos).Magnitude > radius then continue end
        pcall(function() hum.Health = 0 end)
        QOLCitizenCredit(v)
    end
end)

AggroRedirectCD = AggroRedirectCD or {}





Scheduler:add("AggroRedirect", 2, function()
    if not Settings.AggroRedirect then return end
    if not enemiesFolder then return end
    local name = Settings.AggroTarget
    if not name or name == "" then return end
    if name == LocalPlayer.Name then return end
    local victim = Players:FindFirstChild(name)
    local vChar = victim and victim.Character
    local vHrp = vChar and vChar:FindFirstChild("HumanoidRootPart")
    if not vHrp then return end
    local npcFolder = Remotes:FindFirstChild("NPC")
    local actionRemote = npcFolder and npcFolder:FindFirstChild("ActionTrigger")
    if not actionRemote then return end
    local now = Now()
    for npc, ts in pairs(AggroRedirectCD) do
        if (now - ts) > 60 then AggroRedirectCD[npc] = nil end
    end
    for _, v in enemiesFolder:GetChildren() do
        if v == vChar then continue end
        if v.Name == "Shark" then continue end
        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local attrs = v:FindFirstChild("Attributes")
        local party = attrs and attrs:FindFirstChild("Party")
        local behavior = attrs and attrs:FindFirstChild("Behavior")
        if not party or party.Value == "" then continue end
        if not behavior or behavior.Value ~= "PassiveAggressive" then continue end
        local maxR = 100
        local mr = attrs:FindFirstChild("MaxRange")
        if mr and tonumber(mr.Value) then maxR = mr.Value end
        if (hrp.Position - vHrp.Position).Magnitude > maxR then continue end
        if not QOLTargetVisible(vHrp.Position, hrp, v) then continue end
        if AggroRedirectCD[v] and (now - AggroRedirectCD[v]) < 10 then continue end
        AggroRedirectCD[v] = now
        pcall(function() actionRemote:FireServer(vChar, v, "PassiveAggressive") end)
    end
end)

Scheduler:add("QOLAntiFling", 1, function()
    if not Settings.QOLAntiFling then return end
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, plr in Players:GetPlayers() do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local ok2, hrp2 = pcall(function() return char:FindFirstChild("HumanoidRootPart") end)
        if not (ok2 and hrp2) then continue end
        if (hrp2.Position - root.Position).Magnitude > 120 then continue end
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
                if ok and vel and vel.Magnitude > 250 then
                    pcall(function() part.AssemblyLinearVelocity = Vector3.zero end)
                end
            end
        end
    end
end)

Scheduler:add("UnloadPlayers", 1, function()
    local unloadList = RS.UnloadPlayers:GetChildren()
    if #unloadList == 0 then return end
    for i = 1, #unloadList do
        unloadList[i].Parent = workspace
    end
end)

Scheduler:add("RebuildChestCache", 15, function()
    if not (Settings.ChestAura or Settings.ChestEspEnabled) then return end
    BuildChestCache()
end)





function QOLEspPosition(key)
    local ok, pos = pcall(function()
        if not key then return nil end
        if key:IsA("Model") then
            local pp = key.PrimaryPart or key:FindFirstChildOfClass("BasePart")
            return pp and pp.Position or nil
        end
        if key:IsA("BasePart") then return key.Position end
        return nil
    end)
    if ok then return pos end
    return nil
end

function QOLTrimEspRegistry(reg, cap, removeFn, myPos)
    local count = 0
    for _ in pairs(reg) do count = count + 1 end
    if count <= cap then return end
    local scored = {}
    for key in pairs(reg) do
        local pos = QOLEspPosition(key)
        local d = pos and (pos - myPos).Magnitude or mHuge
        scored[#scored + 1] = { key = key, dist = d }
    end
    table.sort(scored, function(a, b) return a.dist > b.dist end)
    for i = cap + 1, #scored do
        pcall(removeFn, scored[i].key)
    end
end

Scheduler:add("CullDistantEsp", 30, function()
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPart then return end
    local myPos = myPart.Position
    QOLTrimEspRegistry(EspData.RegisteredMap, 2000, UnregisterItemEsp, myPos)
    QOLTrimEspRegistry(ChestEspData, 1000, function(base)
        local record = ChestEspData[base]
        if record then
            if record.gui and record.gui.Parent then record.gui:Destroy() end
            if record.conns then
                for _, c in pairs(record.conns) do if c and c.Connected then c:Disconnect() end end
            end
            ChestEspData[base] = nil
        end
    end, myPos)
    QOLTrimEspRegistry(NpcEspData, 500, function(model)
        local data = NpcEspData[model]
        if data then
            if data.conns then
                for _, c in ipairs(data.conns) do if c and c.Connected then c:Disconnect() end end
            end
            if data.gui and data.gui.Parent then data.gui:Destroy() end
            NpcEspData[model] = nil
        end
    end, myPos)
end)

local bucketTick = { [0.1] = 0.1, [0.5] = 0.1, [1] = 0.2, [5] = 0.5, [15] = 1 }

for bucketInterval in pairs(Scheduler.buckets) do
    task.spawn(function()
        while true do
            local now = Now()
            for _, t in pairs(Scheduler.buckets[bucketInterval]) do
                if t and t.nextRun <= now then
                    task.spawn(t.fn)
                    t.nextRun = now + t.interval
                end
            end
            task.wait(bucketTick[bucketInterval] or 0.2)
        end
    end)
end


DiveTweenService = cloneref(game:GetService("TweenService"))
DiveFLYING = false
DiveBV = nil
DiveBG = nil
DiveRunning = false
DiveRecovering = false
DiveLoopRunning = false
DiveAirConn = nil
DiveEnemyWatchConn = nil
DiveWhirlWatchConn = nil
DiveNoclipConn = nil
DiveDeathConn = nil
DiveRespawnConn = nil
DivePlayerWatchConn = nil
DivePlayersNearby = false
DiveDetailsStash = {}
DiveStatusPara = nil
DiveEnemiesRemoved = false
DiveConfirmOpen = false
DiveSuppressRemovePrompt = false

function DiveGetChar()
    return LocalPlayer.Character
end

function DiveGetRoot(char)
    char = char or DiveGetChar()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
end

function DiveSetStatus(text)
    if DiveStatusPara then
        pcall(function() DiveStatusPara:SetDesc(text) end)
    end
end

DiveFlyGen = 0
function DiveStartFly()
    local char = DiveGetChar()
    if not char or DiveFLYING then return end
    local root = DiveGetRoot(char)
    if not root then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    DiveFLYING = true
    DiveFlyGen += 1
    local gen = DiveFlyGen
    DiveBG = Instance.new("BodyGyro")
    DiveBV = Instance.new("BodyVelocity")
    DiveBG.P = 9e4
    DiveBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    DiveBG.CFrame = root.CFrame
    DiveBG.Parent = root
    DiveBV.Velocity = Vector3.zero
    DiveBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    DiveBV.Parent = root
    humanoid.PlatformStand = true
    task.spawn(function()
        repeat
            task.wait()
            if gen ~= DiveFlyGen then break end
            local r = DiveGetRoot()
            if r and DiveBG then
                pcall(function() DiveBG.CFrame = workspace.CurrentCamera.CFrame end)
            end
        until not DiveFLYING or gen ~= DiveFlyGen
    end)
end

function DiveStopFly()
    DiveFLYING = false
    DiveFlyGen += 1
    if DiveBG then pcall(function() DiveBG:Destroy() end); DiveBG = nil end
    if DiveBV then pcall(function() DiveBV:Destroy() end); DiveBV = nil end
    for _, plr in { LocalPlayer } do
        local c = plr.Character
        if c then
            local humanoid = c:FindFirstChildOfClass("Humanoid")
            if humanoid then pcall(function() humanoid.PlatformStand = false end) end
        end
    end
end

function DiveTweenToPosition(targetCFrame, duration)
    local root = DiveGetRoot()
    if not root then return false end
    DiveStartFly()
    root = DiveGetRoot()
    if not root then return false end
    local ok, tween = pcall(function()
        return DiveTweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCFrame })
    end)
    if not ok or not tween then return false end
    tween:Play()
    local done = false
    local conn = tween.Completed:Connect(function() done = true end)
    local elapsed = 0
    local timeout = duration + 3
    while not done and elapsed < timeout do
        task.wait(0.1)
        elapsed += 0.1
        if not DiveGetRoot() or not DiveRunning then
            pcall(function() tween:Cancel() end)
            pcall(function() tween:Destroy() end)
            pcall(function() conn:Disconnect() end)
            return false
        end
    end
    pcall(function() if not done then tween:Cancel() end end)
    pcall(function() tween:Destroy() end)
    pcall(function() conn:Disconnect() end)
    return done
end

function DiveTeleportToPosition(targetCFrame)
    local root = DiveGetRoot()
    if not root then return false end
    root.CFrame = targetCFrame
    return true
end

function DiveTweenAboveModel(model)
    local root = DiveGetRoot()
    if not root then return end
    local ok, pos = pcall(function() return model:GetPivot().Position end)
    if not ok then return end
    local target = CFrame.new(pos.X, 1200, pos.Z)
    local distance = (root.Position - target.Position).Magnitude
    local duration = math.clamp(distance / 500, 1, 10) * DivePaceMult()
    DiveTweenToPosition(target, duration)
end

function DiveTweenToChest(base)
    local root = DiveGetRoot()
    if not root then return end
    local distance = (root.Position - base.Position).Magnitude
    local duration = math.clamp(distance / 80, 0.15, 2) * DivePaceMult()
    DiveTweenToPosition(CFrame.new(base.Position), duration)
end

function DiveTeleportUpForAir()
    local root = DiveGetRoot()
    if not root then return end
    local pos = root.Position
    DiveTeleportToPosition(CFrame.new(pos.X, 1200, pos.Z))
end

function DiveTweenToSky()
    DiveTweenToPosition(CFrame.new(0, 2000, 0), 3)
end

function DiveFirePrompt(part)
    local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        pcall(function() fireproximityprompt(prompt) end)
    end
end

function DiveArePlayersNearby(position, radius)
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - position).Magnitude <= radius then
                return true
            end
        end
    end
    return false
end

function DiveStartPlayerWatch()
    if DivePlayerWatchConn then DivePlayerWatchConn:Disconnect(); DivePlayerWatchConn = nil end
    local last = 0
    DivePlayerWatchConn = RunService.Heartbeat:Connect(function()
        if not DiveRunning then return end
        local now = Now()
        if now - last < 1 then return end
        last = now
        if not Settings.DiveSkipPlayers then DivePlayersNearby = false; return end
        local root = DiveGetRoot()
        if not root then DivePlayersNearby = false; return end
        local nearby = DiveArePlayersNearby(root.Position, 1000)
        if nearby and not DivePlayersNearby then
            DiveSetStatus("Players nearby, holding...")
        end
        DivePlayersNearby = nearby
    end)
end

function DiveMonitorAir()
    if DiveAirConn then DiveAirConn:Disconnect(); DiveAirConn = nil end
    local char = DiveGetChar()
    if not char then return end
    local bin = char:FindFirstChild("bin") or LocalPlayer:FindFirstChild("bin")
    if not bin then DiveRecovering = false; return end
    local air = bin:FindFirstChild("Air")
    if not air then DiveRecovering = false; return end
    DiveAirConn = air:GetPropertyChangedSignal("Value"):Connect(function()
        if not DiveRecovering and air.Value < 10 then
            DiveRecovering = true
            DiveSetStatus("Low air, recovering...")
            DiveTeleportUpForAir()
            task.spawn(function()
                task.wait(10)
                DiveRecovering = false
            end)
        end
    end)
end

function DiveStashDetails(structure)
    if not structure or not structure.Parent then return end
    local detailsFolder = structure:FindFirstChild("Details")
    if detailsFolder and not DiveDetailsStash[structure] then
        DiveDetailsStash[structure] = detailsFolder
        pcall(function() detailsFolder.Parent = Replicated end)
    end
end

function DiveRestoreDetails(structure)
    local details = DiveDetailsStash[structure]
    if details then
        if structure and structure.Parent then
            pcall(function() details.Parent = structure end)
        else
            pcall(function() details.Parent = Replicated end)
        end
        DiveDetailsStash[structure] = nil
    end
end

function DiveRestoreAllDetails()
    for model, details in DiveDetailsStash do
        if model and model.Parent then
            pcall(function() details.Parent = model end)
        else
            pcall(function() details.Parent = Replicated end)
        end
    end
    table.clear(DiveDetailsStash)
end

function DiveWaitRecovering(timeout)
    timeout = timeout or 45
    local elapsed = 0
    while DiveRecovering and DiveRunning and elapsed < timeout do
        task.wait(0.5)
        elapsed += 0.5
    end
    if DiveRecovering and elapsed >= timeout then
        DiveRecovering = false
        DiveMonitorAir()
    end
end

function DivePaceMult()
    if Settings.DiveSlowMode then return 2 end
    return 1
end

function DiveIsLegendaryChest(model)
    local ok, res = pcall(function()
        if not model then return false end
        for _, d in model:GetDescendants() do
            if d:IsA("ProximityPrompt") then
                local text = d.ObjectText
                if text ~= "" and string.find(text:lower(), "legendary chest", 1, true) then
                    return true
                end
            end
        end
        return false
    end)
    return ok and res == true
end

function DiveGetValidChests(chestsFolder)
    local valid = {}
    for _, v in chestsFolder:GetChildren() do
        if v:IsA("Model") then
            local base = v:FindFirstChild("Base")
            if base and base.Transparency ~= 1 then
                if not Settings.DiveIgnoreLegendary or not DiveIsLegendaryChest(v) then
                    table.insert(valid, v)
                end
            end
        end
    end
    return valid
end

function DiveGetNearestChestIndex(tbl)
    local root = DiveGetRoot()
    local currentPos = root and root.Position or Vector3.zero
    local nearestIndex = 1
    local nearestDist = math.huge
    for idx, chest in tbl do
        local base = chest:FindFirstChild("Base")
        if base then
            local dist = (currentPos - base.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestIndex = idx
            end
        end
    end
    return nearestIndex
end

function DiveCollectChests(chests)
    local remaining = table.clone(chests)
    if #remaining == 0 then return end
    local firstIndex = DiveGetNearestChestIndex(remaining)
    local firstChest = remaining[firstIndex]
    table.remove(remaining, firstIndex)
    local firstBase = firstChest and firstChest:FindFirstChild("Base")
    if firstBase then
        local aboveFirst = CFrame.new(firstBase.Position.X, 410, firstBase.Position.Z)
        local r0 = DiveGetRoot()
        if r0 then
            local dropDist = (r0.Position - aboveFirst.Position).Magnitude
            DiveTweenToPosition(aboveFirst, math.clamp(dropDist / 300, 2, 12) * DivePaceMult())
        end
        if not DiveRunning then return end
        task.wait(1)
        if not DiveRunning then return end
        task.wait(0.5)
        if not DiveRunning then return end
        DiveTweenToChest(firstBase)
        DiveFirePrompt(firstBase)
        task.wait(0.3)
    end
    while #remaining > 0 and DiveRunning do
        if DivePlayersNearby then break end
        DiveWaitRecovering(45)
        if not DiveRunning then break end
        local nearestIndex = DiveGetNearestChestIndex(remaining)
        local chest = remaining[nearestIndex]
        table.remove(remaining, nearestIndex)
        local base = chest and chest:FindFirstChild("Base")
        if base then
            DiveTweenToChest(base)
            DiveFirePrompt(base)
            local hold = 0.3
            local prompt = base:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt and tonumber(prompt.HoldDuration) then
                hold = math.clamp(prompt.HoldDuration + 0.2, 0.3, 5)
            end
            if Settings.DiveSlowMode then hold = hold + 1.5 end
            task.wait(hold)
        end
    end
end

function DiveWaitForChests(structure, timeout)
    timeout = math.min(timeout or 8, 8)
    local existing = structure:FindFirstChild("Chests")
    if existing then return existing end
    local found = nil
    local conn
    conn = structure.ChildAdded:Connect(function(child)
        if child.Name == "Chests" then found = child end
    end)
    local elapsed = 0
    while not found and elapsed < timeout do
        task.wait(0.5)
        elapsed += 0.5
        if not DiveRunning then break end
        found = found or structure:FindFirstChild("Chests")
    end
    pcall(function() conn:Disconnect() end)
    return found
end

function DiveMainLoop()
    if DiveLoopRunning then return end
    DiveLoopRunning = true
    DiveRunning = true
    DiveSetStatus("Running...")
    while DiveRunning do
        local outerOk, outerErr = pcall(function()
            local seaContent = Map and Map:FindFirstChild("SeaContent")
            if not seaContent then
                DiveSetStatus("SeaContent not found. Waiting...")
                task.wait(5)
                return
            end
            local remaining = {}
            for _, structure in seaContent:GetChildren() do
                if structure:IsA("Model")
                    and (structure.Name == "DivingSpot" or structure.Name == "UWStructure")
                then
                    table.insert(remaining, structure)
                end
            end
            if #remaining == 0 then
                DiveSetStatus("No diving spots found. Waiting...")
                task.wait(5)
                return
            end
            while #remaining > 0 and DiveRunning do
                local root = DiveGetRoot()
                local currentPos = root and root.Position or Vector3.zero
                local pool = remaining
                if Settings.DivePreferSpots or Settings.DivePreferStructs then
                    local want = Settings.DivePreferSpots and "DivingSpot" or "UWStructure"
                    local filtered = {}
                    for _, s in remaining do
                        if s.Name == want then filtered[#filtered + 1] = s end
                    end
                    if #filtered > 0 then pool = filtered end
                end
                local nearest, nearestDist = nil, math.huge
                for _, structure in pool do
                    local ok, pivot = pcall(function() return structure:GetPivot().Position end)
                    if ok then
                        local dist = (currentPos - pivot).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                            nearest = structure
                        end
                    end
                end
                local structure = nearest or pool[1]
                for i, s in remaining do
                    if s == structure then table.remove(remaining, i); break end
                end
                if not structure or not structure.Parent then continue end
                local okPivot, structurePos = pcall(function() return structure:GetPivot().Position end)
                if not okPivot then continue end
                local checkRadius = structure.Name == "UWStructure" and 3000 or 1000
                if Settings.DiveSkipPlayers and DiveArePlayersNearby(structurePos, checkRadius) then
                    DiveSetStatus("Skipped (players nearby): " .. structure.Name)
                    continue
                end
                DiveWaitRecovering(45)
                if not DiveRunning then break end
                local spotOk, spotErr = pcall(function()
                    DiveSetStatus("Farming: " .. structure.Name)
                    DiveTweenAboveModel(structure)
                    if not DiveRunning then return end
                    if DivePlayersNearby then
                        DiveSetStatus("Skipped (players nearby): " .. structure.Name)
                        return
                    end
                    local chestsFolder = DiveWaitForChests(structure, 8)
                    if not DiveRunning then return end
                    if not chestsFolder then
                        warn("[DiveFarm] No Chests folder found for:", structure.Name)
                        return
                    end
                    DiveStashDetails(structure)
                    local r = DiveGetRoot()
                    local travelDist = r and (r.Position - structurePos).Magnitude or 0
                    local chestWaitMax = Settings.DiveSlowMode and 20 or 14
                    local chestWait = math.clamp(8 + travelDist / 1000, 8, chestWaitMax)
                    task.wait(chestWait)
                    if not DiveRunning then DiveRestoreDetails(structure); return end
                    DiveWaitRecovering(45)
                    if not DiveRunning then DiveRestoreDetails(structure); return end
                    if DivePlayersNearby then
                        DiveSetStatus("Skipped (players nearby): " .. structure.Name)
                        DiveRestoreDetails(structure)
                        return
                    end
                    local validChests = DiveGetValidChests(chestsFolder)
                    if #validChests == 0 then
                        warn("[DiveFarm] No valid chests at:", structure.Name)
                        DiveRestoreDetails(structure)
                        return
                    end
                    DiveCollectChests(validChests)
                    if DivePlayersNearby then
                        DiveSetStatus("Skipped (players nearby): " .. structure.Name)
                        DiveRestoreDetails(structure)
                        return
                    end
                    task.wait(1)
                    local missedChests = {}
                    for _, chest in validChests do
                        if chest and chest.Parent then
                            local base = chest:FindFirstChild("Base")
                            if base and base.Transparency ~= 1 and not chest:FindFirstChild("Open") then
                                table.insert(missedChests, chest)
                            end
                        end
                    end
                    if #missedChests > 0 and DiveRunning then
                        DiveCollectChests(missedChests)
                        task.wait(0.5)
                    end
                    if DiveRunning then
                        DiveWaitRecovering(45)
                        if DiveRunning then DiveTeleportUpForAir() end
                    end
                    DiveRestoreDetails(structure)
                end)
                if not spotOk then
                    warn("[DiveFarm] spotErr:", spotErr)
                    DiveRestoreDetails(structure)
                    DiveTeleportUpForAir()
                end
                if Settings.DiveSlowMode then task.wait(8) else task.wait(3) end
            end
            if DiveRunning then
                DiveWaitRecovering(45)
                if DiveRunning then
                    DiveSetStatus("Cycle done. Waiting...")
                    DiveTweenToSky()
                    if Settings.DiveSlowMode then task.wait(45) else task.wait(30) end
                end
            end
        end)
        if not outerOk then
            warn("[DiveFarm] outerErr:", outerErr)
            DiveStopFly()
            DiveRestoreAllDetails()
            task.wait(3)
            local waited = 0
            while DiveRunning and waited < 15 and not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) do
                task.wait(0.5)
                waited += 0.5
            end
            task.wait(2)
        end
        task.wait()
    end
    DiveLoopRunning = false
    DiveSetStatus("Stopped.")
end

function DiveStartEnemyRemoval()
    if not Settings.DiveRemoveEnemies then return end
    local folder = workspace:FindFirstChild("Enemies")
    if folder then
        local ok = pcall(function() folder:Destroy() end)
        if ok and workspace:FindFirstChild("Enemies") == nil then
            DiveEnemiesRemoved = true
        end
    end
    if DiveEnemyWatchConn then DiveEnemyWatchConn:Disconnect(); DiveEnemyWatchConn = nil end
    DiveEnemyWatchConn = workspace.ChildAdded:Connect(function(child)
        if child.Name == "Enemies" then pcall(function() child:Destroy() end) end
    end)
end

function DiveStopEnemyRemoval()
    if DiveEnemyWatchConn then DiveEnemyWatchConn:Disconnect(); DiveEnemyWatchConn = nil end
end

function DiveStartNoclip()
    if DiveNoclipConn then DiveNoclipConn:Disconnect(); DiveNoclipConn = nil end
    DiveNoclipConn = RunService.Stepped:Connect(function()
        if not DiveRunning then return end
        local c = DiveGetChar()
        if c then
            for _, p in c:GetDescendants() do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
            end
        end
    end)
end

function DiveStopNoclip()
    if DiveNoclipConn then DiveNoclipConn:Disconnect(); DiveNoclipConn = nil end
end

function DiveRejoin()
    DiveEnemiesRemoved = false
    local ok, err = pcall(function()
        local teleportService = game:GetService("TeleportService")
        local players = game:GetService("Players")
        teleportService:SetTeleportSetting("File", teleportService:GetTeleportSetting("File") or 1)
        teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, players.LocalPlayer, nil, teleportService:GetLocalPlayerTeleportData() or {}, nil)
    end)
    if not ok then
        Fluent:Notify({ Duration = 5, Title = "Rejoin failed", Content = tostring(err) })
    end
end

function DiveDisconnectFarmConns()
    if DiveAirConn then DiveAirConn:Disconnect(); DiveAirConn = nil end
    if DiveEnemyWatchConn then DiveEnemyWatchConn:Disconnect(); DiveEnemyWatchConn = nil end
    if DiveDeathConn then DiveDeathConn:Disconnect(); DiveDeathConn = nil end
    if DiveRespawnConn then DiveRespawnConn:Disconnect(); DiveRespawnConn = nil end
    if DiveWhirlWatchConn then DiveWhirlWatchConn:Disconnect(); DiveWhirlWatchConn = nil end
    if DiveNoclipConn then DiveNoclipConn:Disconnect(); DiveNoclipConn = nil end
    if DivePlayerWatchConn then DivePlayerWatchConn:Disconnect(); DivePlayerWatchConn = nil end
    DivePlayersNearby = false
end

DiveSuppressFarmKill = false

function DiveStartWhirlpoolRemoval()
    local weather = Map and Map:FindFirstChild("Weather")
    if not weather then return end
    for _, child in weather:GetChildren() do
        if child.Name == "Whirlpool" then pcall(function() child:Destroy() end) end
    end
    if DiveWhirlWatchConn then DiveWhirlWatchConn:Disconnect(); DiveWhirlWatchConn = nil end
    DiveWhirlWatchConn = weather.ChildAdded:Connect(function(child)
        if child.Name == "Whirlpool" then pcall(function() child:Destroy() end) end
    end)
end

function DiveStopWhirlpoolRemoval()
    if DiveWhirlWatchConn then DiveWhirlWatchConn:Disconnect(); DiveWhirlWatchConn = nil end
end

function DiveRemoveDamageRemotes()
    if not Settings.DiveRemoveDamage then return end
    local rsRoot = Replicated:FindFirstChild("RS")
    if rsRoot then
        local remotes = rsRoot:FindFirstChild("Remotes")
        if remotes then
            local misc = remotes:FindFirstChild("Misc")
            if misc then
                local td = misc:FindFirstChild("TouchDamage")
                if td then pcall(function() td:Destroy() end) end
            end
            local combat = remotes:FindFirstChild("Combat")
            if combat then
                local fd = combat:FindFirstChild("FallDamage")
                if fd then pcall(function() fd:Destroy() end) end
            end
        end
    end
end

function StartDiveFarm()
    if DiveRunning or DiveLoopRunning then return end
    if typeof(fireproximityprompt) ~= "function" then
        Fluent:Notify({ Duration = 5, Title = "Dive Farm", Content = "fireproximityprompt missing on this executor." })
        return
    end
    DiveRunning = true
    DiveDisconnectFarmConns()
    Fluent:Notify({ Duration = 5, Title = "Dive Farm", Content = "High ping may get you banned. Started." })
    DiveStartEnemyRemoval()
    DiveStartWhirlpoolRemoval()
    DiveStartNoclip()
    DiveRemoveDamageRemotes()
    DiveMonitorAir()
    DiveStartPlayerWatch()
    local char = DiveGetChar()
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            DiveDeathConn = hum.Died:Connect(function()
                DiveStopEnemyRemoval()
                DiveStopWhirlpoolRemoval()
                DiveStopNoclip()
                if DivePlayerWatchConn then DivePlayerWatchConn:Disconnect(); DivePlayerWatchConn = nil end
                DivePlayersNearby = false
                DiveStopFly()
                DiveRunning = false
                DiveRecovering = false
                DiveLoopRunning = false
                if DiveAirConn then DiveAirConn:Disconnect(); DiveAirConn = nil end
                DiveRestoreAllDetails()
                DiveSetStatus("Died. Farm stopped, re-enable after respawn.")
            end)
        end
    end
    DiveRespawnConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(2)
        if Settings.DiveFarmEnabled then
            DiveStartEnemyRemoval()
            DiveStartWhirlpoolRemoval()
            DiveStartNoclip()
            DiveMonitorAir()
            if not DiveLoopRunning then task.spawn(DiveMainLoop) end
        end
    end)
    task.spawn(function()
        DiveStartFly()
        local root = DiveGetRoot()
        if root then pcall(function() root.CFrame = root.CFrame - Vector3.new(0, 20, 0) end) end
        task.wait(2)
        if DiveRunning and not DiveLoopRunning then task.spawn(DiveMainLoop) end
    end)
end

function StopDiveFarm()
    DiveRunning = false
    DiveRecovering = false
    DiveStopFly()
    DiveDisconnectFarmConns()
    DiveRestoreAllDetails()
    DiveSetStatus("Stopped.")
end


ReagantPara = nil
CopperStatusPara = nil
DefaultCopperCFrame = CFrame.new(13934.6015625, 656.10595703125, -7269.1767578125, -0.9964420199394226, -1.463268972656806e-08, -0.08428122103214264, -1.6910314926121828e-08, 1, 2.631023754418038e-08, 0.08428122103214264, 2.764184792169999e-08, -0.9964420199394226)

function SetCopperStatus(text)
    if CopperStatusPara then pcall(function() CopperStatusPara:SetDesc(text) end) end
end

function CountReagants()
    local islandName = tostring(SessionData.ReagantIsland or "Limestone Key"):gsub("^%s+", ""):gsub("%s+$", "")
    local island = nil
    if Map then
        island = Map:FindFirstChild(islandName)
        if not island then
            local lower = islandName:lower()
            for _, child in Map:GetChildren() do
                if child.Name:lower() == lower then island = child; break end
            end
        end
    end
    if not island then
        Fluent:Notify({ Duration = 5, Title = "Reagant Counter", Content = "Island not found: " .. tostring(islandName) })
        return 0
    end
    local count = 0
    for _, v in island:GetDescendants() do
        if v.Name == "Visual" and (v:IsA("BasePart") or v:IsA("MeshPart") or v:IsA("Model")) then
            count += 1
        end
    end
    if ReagantPara then pcall(function() ReagantPara:SetDesc("Count on " .. island.Name .. ": " .. tostring(count)) end) end
    Fluent:Notify({ Duration = 5, Title = "Reagant Counter", Content = tostring(count) .. " Visuals on " .. island.Name })
    return count
end

_copperRunning = false
function RunCopperShroomFarm()
    if _copperRunning then return end
    _copperRunning = true
    local function done()
        _copperRunning = false
    end
    local slot = SessionData.CopperSlot
    if type(slot) ~= "string" or slot == "" then slot = "Personal" end
    local islandName = tostring(SessionData.CopperIsland or "Tidecliff Isle"):gsub("^%s+", ""):gsub("%s+$", "")
    local island = Map and Map:FindFirstChild(islandName)
    if not island and Map then
        local lower = islandName:lower()
        for _, child in Map:GetChildren() do
            if child.Name:lower() == lower then island = child; break end
        end
    end
    if not island then
        Fluent:Notify({ Duration = 5, Title = "Copper", Content = "Island not loaded: " .. islandName })
        done(); return
    end
    local rsRoot = Replicated:FindFirstChild("RS")
    local remotes = rsRoot and rsRoot:FindFirstChild("Remotes")
    local misc = remotes and remotes:FindFirstChild("Misc")
    local claimSaveLoad = misc and misc:FindFirstChild("ClaimSaveLoad")
    if not claimSaveLoad then
        Fluent:Notify({ Duration = 5, Title = "Copper", Content = "Remotes not found." })
        done(); return
    end
    local targetCFrame = DefaultCopperCFrame
    if typeof(SessionData.CopperPlotCFrame) == "CFrame" then
        targetCFrame = SessionData.CopperPlotCFrame
    end
    task.spawn(function()
        for i = 1, 3 do
            local ok, res = pcall(function()
                return claimSaveLoad:InvokeServer("Load", slot, targetCFrame)
            end)
            if ok then break end
            task.wait(1)
        end
        done()
        Fluent:Notify({ Duration = 5, Title = "Copper", Content = "Plot reloaded (" .. slot .. " @ " .. island.Name .. ")." })
    end)
end


QOLInfJumpConn = nil
QOLCrossParts = {}
QOLCrossConn = nil

function QOLPlayHitSound()
    local id = tostring(SessionData.QOLHitSoundId or "")
    if id == "" then return end
    if tonumber(id) then id = "rbxassetid://" .. id end
    local ok, snd = pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = (tonumber(SessionData.QOLHitSoundVol) or 10) / 10
        s.PlayOnRemove = true
        s.Parent = workspace
        return s
    end)
    if ok and snd then pcall(function() snd:Destroy() end) end
end
QOLHideConn = nil
QOLHideDeathConn = nil

FleetDataPara = nil
BoatsModuleCached = nil

function GetBoatsModule()
    if BoatsModuleCached ~= nil then
        return BoatsModuleCached or nil
    end
    local mods = RS and RS:FindFirstChild("Modules")
    local boatsMod = mods and mods:FindFirstChild("Boats")
    if not boatsMod then
        BoatsModuleCached = false
        return nil
    end
    local ok, mod = pcall(require, boatsMod)
    BoatsModuleCached = (ok and mod) or false
    return BoatsModuleCached or nil
end

function RefreshFleetData()
    local function setText(t)
        if FleetDataPara then pcall(function() FleetDataPara:SetDesc(t) end) end
    end
    local bin = LocalPlayer:FindFirstChild("bin")
    local fleetVal = bin and bin:FindFirstChild("Fleet") and bin.Fleet.Value or nil
    if not fleetVal or fleetVal == "" then
        setText("No fleet data (no fleet yet?).")
        return
    end
    local http = game:GetService("HttpService")
    local ok, data = pcall(function() return http:JSONDecode(fleetVal) end)
    if not ok or type(data) ~= "table" then
        setText("Fleet data unreadable.")
        return
    end
    local st = data.Statistics or {}
    local ships = data.Ships or {}
    local nships = 0
    for _ in pairs(ships) do nships += 1 end
    local bmod = GetBoatsModule()
    local rank, power, powerPct, resupply
    if bmod then
        local okr, r = pcall(function() return bmod.GetFleetRank(LocalPlayer) end)
        if okr and r then rank = r end
        local okp, p1, p2 = pcall(function() return bmod.GetFleetPower(LocalPlayer) end)
        if okp and p1 then power, powerPct = p1, p2 end
        local okr2, rc = pcall(function() return bmod.FleetResupplyCost(LocalPlayer) end)
        if okr2 and rc then resupply = rc end
    end
    if not rank then
        rank = 1
        for _, task in { "Fishing", "Harvesting", "Exploring", "Trading", "Conquest" } do
            rank += ((tonumber(st[task .. "Level"]) or 1) - 1)
        end
    end
    if not power then
        local need = { 200, 500, 1000, 2000, 5000, 10000, 20000 }
        local pw = tonumber(st.Power) or 0
        power = 1
        for i, v in ipairs(need) do
            if pw >= v then power = i + 1 end
        end
        powerPct = 0
    end
    local food = tonumber(st.Food) or 100
    local sup = tonumber(st.Supplies) or 100
    local str = tonumber(st.Strength) or 100
    local lines = {
        "Rank " .. tostring(rank) .. " | Power " .. tostring(power) .. " (" .. tostring(math.floor(tonumber(powerPct) or 0)) .. "%)",
        "Food " .. tostring(math.floor(food)) .. " | Supplies " .. tostring(math.floor(sup)) .. " | Strength " .. tostring(math.floor(str)),
        "Ships: " .. tostring(nships) .. " | Risk: " .. tostring(data.RiskLevel or "Safe") .. " | Paused: " .. tostring(data.Paused or false),
    }
    local lv = {}
    for _, task in { "Fishing", "Harvesting", "Exploring", "Trading", "Conquest" } do
        lv[#lv + 1] = task:sub(1, 4) .. " Lv" .. tostring(tonumber(st[task .. "Level"]) or 1)
    end
    lines[#lines + 1] = table.concat(lv, "  ")
    if resupply then
        lines[#lines + 1] = "Resupply: " .. tostring(resupply) .. " drachma"
    end
    setText(table.concat(lines, "\n"))
end

function QOLSetInfJump(v)
    if QOLInfJumpConn then QOLInfJumpConn:Disconnect(); QOLInfJumpConn = nil end
    if not v then return end
    QOLInfJumpConn = UIS.JumpRequest:Connect(function()
        if not Settings.QOLInfJump then return end
        local hum = Character and Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end)
end

function QOLSetCrosshair(v)
    if QOLCrossConn then QOLCrossConn:Disconnect(); QOLCrossConn = nil end
    for _, p in QOLCrossParts do pcall(function() p:Remove() end) end
    table.clear(QOLCrossParts)
    if not v or not drawing then return end
    local function mkLine()
        local l = drawing.new("Line")
        l.Visible = true
        l.Color = Color3.fromRGB(255, 255, 255)
        l.Thickness = 1.5
        l.Transparency = 1
        return l
    end
    for _ = 1, 4 do QOLCrossParts[#QOLCrossParts + 1] = mkLine() end
    QOLCrossConn = RunService.Heartbeat:Connect(function()
        if not Settings.QOLCrosshair then return end
        local ok, mouse = pcall(function() return UIS:GetMouseLocation() end)
        local cx, cy
        if ok and mouse then
            cx, cy = mouse.X, mouse.Y
        else
            local vs = CurrentCamera.ViewportSize
            cx, cy = vs.X / 2, vs.Y / 2
        end
        local gap, len = 6, 13
        local pts = {
            { cx - gap - len, cy, cx - gap, cy },
            { cx + gap, cy, cx + gap + len, cy },
            { cx, cy - gap - len, cx, cy - gap },
            { cx, cy + gap, cx, cy + gap + len },
        }
        for i, l in QOLCrossParts do
            local p = pts[i]
            if p then
                l.From = Vector2.new(p[1], p[2])
                l.To = Vector2.new(p[3], p[4])
                l.Visible = true
            end
        end
    end)
end

QOLInvisTrack = nil
QOLInvisOldCF = nil
QOLInvisHBConn = nil
QOLInvisRespConn = nil
QOLInvisGhost = nil
QOLInvisRSKey = "EldritchInvis"

function QOLInvisFXStart()
    QOLInvisFXStop()
    local char = Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not hum or not animator then return end
    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
    local ok, track = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. (isR15 and "18665825805" or "215384594")
        local tr = animator:LoadAnimation(anim)
        tr.Priority = Enum.AnimationPriority.Action4
        tr:Play(0, 0.001, 0)
        anim:Destroy()
        return tr
    end)
    if ok and track then
        QOLInvisTrack = track
        task.delay(0, function()
            pcall(function() track.TimePosition = isR15 and 1.95 or 0.4 end)
        end)
    end
    pcall(function()
        local hl = Instance.new("Highlight")
        hl.Name = "EldritchGhost"
        hl.FillColor = Color3.fromRGB(0, 255, 255)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.75
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char
        QOLInvisGhost = hl
    end)
end

function QOLInvisFXStop()
    if QOLInvisTrack then
        pcall(function() QOLInvisTrack:Stop() end)
        pcall(function() QOLInvisTrack:Destroy() end)
        QOLInvisTrack = nil
    end
    if QOLInvisGhost then
        pcall(function() QOLInvisGhost:Destroy() end)
        QOLInvisGhost = nil
    end
end

function QOLSetUnderground(v)
    if QOLHideConn then QOLHideConn:Disconnect(); QOLHideConn = nil end
    if QOLHideDeathConn then QOLHideDeathConn:Disconnect(); QOLHideDeathConn = nil end
    if QOLInvisHBConn then QOLInvisHBConn:Disconnect(); QOLInvisHBConn = nil end
    if QOLInvisRespConn then QOLInvisRespConn:Disconnect(); QOLInvisRespConn = nil end
    pcall(function() RunService:UnbindFromRenderStep(QOLInvisRSKey) end)
    if not v then
        QOLInvisFXStop()
        local cf = QOLInvisOldCF
        QOLInvisOldCF = nil
        if cf then
            local char = Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame = cf end) end
        end
        return
    end
    local char = Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then
        Fluent:Notify({ Duration = 5, Title = "FE Invisible", Content = "Character not ready." })
        return
    end
    QOLInvisOldCF = nil
    QOLInvisFXStart()
    pcall(function()
        RunService:UnbindFromRenderStep(QOLInvisRSKey)
    end)
    RunService:BindToRenderStep(QOLInvisRSKey, 0, function()
        local c = Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r and QOLInvisOldCF then
            r.CFrame = QOLInvisOldCF
            if QOLInvisTrack then pcall(function() QOLInvisTrack:AdjustWeight(0.001) end) end
        end
    end)
    QOLInvisHBConn = RunService.Heartbeat:Connect(function()
        if not Settings.QOLUnderground then return end
        local c = Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end
        local isR15 = h.RigType == Enum.HumanoidRigType.R15
        QOLInvisOldCF = r.CFrame
        local dist = tonumber(SessionData.QOLInvisDip) or 200
        local dip = r.CFrame - Vector3.new(0, dist, 0)
        if SessionData.QOLInvisUp then
            dip = r.CFrame + Vector3.new(0, dist, 0)
        end
        pcall(function()
            r.CFrame = dip * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
        end)
        if QOLInvisTrack then pcall(function() QOLInvisTrack:AdjustWeight(100) end) end
    end)
    QOLHideDeathConn = hum.Died:Connect(function()
        if QOLInvisHBConn then QOLInvisHBConn:Disconnect(); QOLInvisHBConn = nil end
        pcall(function() RunService:UnbindFromRenderStep(QOLInvisRSKey) end)
        QOLInvisFXStop()
        QOLInvisOldCF = nil
        Fluent:Notify({ Duration = 5, Title = "FE Invisible", Content = "Died, re-enable after respawn." })
    end)
    QOLInvisRespConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        QOLInvisOldCF = nil
        if Settings.QOLUnderground then
            QOLInvisFXStart()
        end
    end)
    Fluent:Notify({ Duration = 5, Title = "FE Invisible", Content = "Invisible. Physics, jumping and falling all work." })
end


local Hook = nil

StarterGui:SetCore("SendNotification", {
        Title    = "hookmetamethod bypass",
        Text     = "Stuff like godmode, no stamina, damage multiplier, etc, will not work until we fully bypass the hooks, please wait a moment.",
        Duration = 15,
})

task.wait()

task.delay(math.random(30,35), function()
    if not HookMetamethod then
        warn("[EldritchHub] hookmetamethod missing, godmode, stamina, damage multi and silent aim redirect disabled.")
        return
    end
    Hook = HookMetamethod(game,"__namecall", NewClosure(function(Self,...)
        local Method = getnamecallmethod()
        local Args = {...}
        local n = select("#", ...)
        local unpackFn = table.unpack or unpack

        if checkcaller() then
            return Hook(Self, unpackFn(Args, 1, n))
        end

        if Method == "Kick" and Self == LocalPlayer then
            return
        end

        if Method == "ViewportPointToRay" then
            if Settings.SilentAim ~= true then
                return Hook(Self, unpackFn(Args, 1, n))
            end
            local stackSource = debug.info(2, "s") or ""
            if stackSource:find("CameraModule") or stackSource:find("Popper") then
                return Hook(Self, unpackFn(Args, 1, n))
            end
            local originalRay = Hook(Self, unpackFn(Args, 1, n))
            if not originalRay then
                return Ray.new(Vector3.new(), Vector3.new(0, 0, 1))
            end
            local targetPart, targetDistance = nil, math.huge
            if Settings.SilentAimPlayers then
                local p, pDist = GetNearestPlayer()
                if p and pDist <= SilentMaxDistance then
                    local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (not Settings.SilentAimFOV or IsTargetInFov(hrp))
                        and QOLWallcheck(originalRay.Origin, hrp)
                        and not QOLSkipTarget(p.Character, hrp, originalRay.Origin) then
                        targetPart = hrp
                        targetDistance = pDist
                    end
                end
            end
            if not targetPart and Settings.SilentAimNPCs then
                local nn, nDist = GetNearestNPC()
                if nn and nDist <= SilentMaxDistance then
                    local hrp = nn:FindFirstChild("HumanoidRootPart")
                    if hrp and (not Settings.SilentAimFOV or IsTargetInFov(hrp))
                        and nDist < targetDistance
                        and QOLWallcheck(originalRay.Origin, hrp)
                        and not QOLSkipTarget(nn, hrp, originalRay.Origin) then
                        targetPart = hrp
                    end
                end
            end
            if targetPart and targetPart.Position then
                SilentAimTargetPart = targetPart
                LastAttackTime = Now()
                local aimPosition = targetPart.Position
                if Settings.Prediction then


                    local anchored = false
                    pcall(function() anchored = targetPart.Anchored end)
                    local velocity = targetPart.AssemblyLinearVelocity or Vector3.new()
                    if not anchored and velocity.Magnitude > 0.1 then
                        local dist = (aimPosition - originalRay.Origin).Magnitude
                        local speed = QOLResolvePredictionSpeed()
                        if speed < 1 then speed = 150 end
                        aimPosition = aimPosition
                            + Vector3.new(velocity.X, 0, velocity.Z) * (dist / speed)
                    end
                end
                local dirToTarget = aimPosition - originalRay.Origin
                if dirToTarget.Magnitude > 0 then
                    return Ray.new(originalRay.Origin, dirToTarget.Unit * originalRay.Direction.Magnitude)
                end
            end
            return originalRay
        end

        if Method == "FireServer" or Method == "InvokeServer" then
            local RemoteName = tostring(Self.Name) or ""

            if Settings.ReduceStamina == true and RemoteName == "StaminaCost" and Args[1] ~= nil then
                return
            end

            if Settings.BlockNPCAggro == true and BlockedAggroRemotes[RemoteName] then
                return
            end

            if Settings.GodMode == true then
                if (RemoteName == "DealAttackDamage" or RemoteName == "DealBossDamage" or RemoteName == "DealMagicDamage") and Args[2] == Character then
                    return
                elseif (RemoteName == "DealWeaponDamage" or RemoteName == "DealStrengthDamage" or RemoteName == "DealSWDamage") and Args[3] == Character then
                    return
                elseif RemoteName == "TouchDamage" or RemoteName == "MiscDamage" or RemoteName == "TakeSideDamage" or RemoteName == "FallDamage" or RemoteName == "DealAnimalDamage" then
                    return
                end
            end

            if Settings.ChargeMultiplierEnabled == true and RemoteName == "DealAttackDamage" then
                if Args[2] ~= Character then
                    Args[6] = Settings.ChargeMultiplierAmt
                    Args[7] = 1
                end
            end

            if Settings.ChargeMultiplierEnabled == true and Args[1] and RemoteName == "DealWeaponDamage" then
                if Args[3] ~= Character then
                    Args[1] = Settings.ChargeMultiplierAmt
                end
            end

            if Settings.ChargeMultiplierEnabled2 == true and RemoteName == "DealStrengthDamage" then
                if Args[3] ~= Character then
                    Args[6] = Settings.ChargeMultiplierAmt2
                end
            end

            if Settings.EnableDamageMultiplier == true and DamageRemotesSet[RemoteName] then
                local isTarget = false
                if RemoteName == "DealAttackDamage" or RemoteName == "DealBossDamage" or RemoteName == "DealMagicDamage" then
                    if Args[2] == Character then isTarget = true end
                elseif RemoteName == "DealWeaponDamage" or RemoteName == "DealStrengthDamage" or RemoteName == "DealSWDamage" then
                    if Args[3] == Character then isTarget = true end
                elseif RemoteName == "TouchDamage" or RemoteName == "MiscDamage" or RemoteName == "TakeSideDamage" or RemoteName == "FallDamage" or RemoteName == "DealAnimalDamage" then
                    if Args[2] == Character or Args[3] == Character then isTarget = true end
                end
                if isTarget then
                    return Hook(Self, unpackFn(Args, 1, n))
                end
                if Settings.QOLHitSound then QOLPlayHitSound() end
                local mult = math.max(1, math.floor(tonumber(Settings.DamageMultiplier) or 1))
                for _ = 1, mult do
                    Hook(Self, unpackFn(Args, 1, n))
                end
                return
            end

            if RemoteName == "FishClock"
                and Settings.AutoFish == true
                and SessionData.UseBaitType
                and FishingType == "Legit"
            then
                Args[4] = FishingBaitType
            end
        end

        return Hook(Self, unpackFn(Args, 1, n))
    end))

    StarterGui:SetCore("SendNotification", {
        Title    = "hookmetamethod bypass",
        Text     = "All hooks bypassed, script should work as expected.",
        Duration = 15,
    })
end)


RunService.Heartbeat:Connect(function()
    if not Settings.BoostBoatSpeed or (tonumber(Settings.BoatSpeedMultiplier) or 1) <= 1 then return end
    local hum = Character and Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then return end
    local Boat, SkyShip = GetPlayerBoat()
    TweakShip(Boat)
    TweakShip(SkyShip)
    local OtherShip = hum.SeatPart.Parent
    if OtherShip and OtherShip ~= Boat and OtherShip ~= SkyShip then
        local center = OtherShip:FindFirstChild("Center")
        local bodyVelocity = center and center:FindFirstChild("SailV")
        local speedObj = OtherShip:FindFirstChild("Speed")
        if bodyVelocity and bodyVelocity.Velocity.Magnitude > 5 then
            local speedVal = (speedObj and speedObj.Value or 0) * 0.5
            bodyVelocity.Velocity = bodyVelocity.Velocity.Unit * speedVal * Settings.BoatSpeedMultiplier
        end
    end
end)

local LastNearestUpdate = 0
local NearestUpdateRate = 0.5

RunService.Heartbeat:Connect(function()
    if not Settings.SilentAimPlayers and not Settings.SilentAimNPCs then
        if WatermarkLabel.Text ~= "" then WatermarkLabel.Text = "" end
        return
    end
    local now = Now()
    if now - LastNearestUpdate < NearestUpdateRate then return end
    LastNearestUpdate = now
    local nearestName = "None"
    local nearestDist = mHuge
    if Settings.SilentAimPlayers then
        local p, pDist = GetNearestPlayer()
        if p and pDist < nearestDist then
            nearestName = p.Name
            nearestDist = pDist
        end
    end
    if Settings.SilentAimNPCs then
        local n, nDist = GetNearestNPC()
        if n and nDist < nearestDist then
            nearestName = n.Name
            nearestDist = nDist
        end
    end
    if nearestDist < mHuge then
        WatermarkLabel.Text = "Target: " .. nearestName .. " | " .. mFloor(nearestDist) .. "m | " .. Version
    else
        WatermarkLabel.Text = ""
    end
end)

RunService.RenderStepped:Connect(function()
    if not Settings.SilentAim then
        if LockLabel.Visible then
            LockLabel.Visible = false
            LockLabel.Text    = ""
        end
        SilentAimTargetPart = nil
        return
    end
    local isAttacking = (Now() - LastAttackTime) <= AttackLingerSecs
    local part        = SilentAimTargetPart
    if isAttacking and part and part.Parent then
        local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(part.Position)
        if onScreen then
            LockLabel.Visible  = true
            LockLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
            LockLabel.Text     = "[LOCKED] " .. (part.Parent.Name or "Target")
        else
            LockLabel.Visible = false
            LockLabel.Text    = ""
        end
    else
        LockLabel.Visible = false
        LockLabel.Text    = ""
        if not isAttacking then SilentAimTargetPart = nil end
    end
end)

UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        LastMousePositionX = input.Position.X
        LastMousePositionY = input.Position.Y
    end
end)

UIS.InputBegan:Connect(function(input, isChatBox)
    if isChatBox then return end
    if input.KeyCode == Enum.KeyCode.Period and Settings.SilentBottleDrinking then
        Remotes.Misc.EmptyBottle:FireServer(true)
    end
    if KeybindWaiting then
        SessionData.Keybinds[KeybindWaiting] = input.KeyCode
        Fluent:Notify({ Duration = 5, Title = "Keybind Set",
            Content = KeybindWaiting .. " -> " .. tostring(input.KeyCode.Name) })
        KeybindWaiting = nil
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    ApplyKeybindAction(input.KeyCode)
end)

LocalPlayer.CharacterAdded:Connect(function(Char)
    Character = Char
    TeleportDebounce = false
    task.delay(1, function()
        local root = Char and Char:FindFirstChild("HumanoidRootPart")
        if root then pcall(function() root.Anchored = false end) end
    end)
    SetupFishClockTracker()
    SetupFishingListener()
    if FishingToolName then
        FishingTool = LocalPlayer.Backpack:FindFirstChild(FishingToolName) or Character:FindFirstChild(FishingToolName)
        if not FishingTool then
            Fluent:Notify({ Duration = 5, Title = "Warning!",
                Content = "Fishing tool not found in backpack. Please reselect the fishing tool." })
        end
    end
end)

task.spawn(function()
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        local viewportSize = CurrentCamera.ViewportSize
        VirtualUser:ClickButton2(Vector2.new(
            viewportSize.X / 2 + mRandom(-100, 100),
            viewportSize.Y / 2 + mRandom(-100, 100)
        ))
    end)
end)

if enemiesFolder then
    enemiesFolder.ChildAdded:Connect(function(child)
        if not child then return end
        if not Settings.NPCEspActive then return end
        task.defer(function()
            local Humanoid = child:WaitForChild("Humanoid", 10)
            if Settings.NPCEspActive and Humanoid then CreateNpcEspForModel(child) end
        end)
    end)
end

_chestCacheDirty = false
function RequestChestCacheRebuild()
    if not (Settings.ChestAura or Settings.ChestEspEnabled) then return end
    if _chestCacheDirty then return end
    _chestCacheDirty = true
    task.delay(5, function()
        _chestCacheDirty = false
        pcall(BuildChestCache)
    end)
end

if Map then
    Map.ChildAdded:Connect(function() RequestChestCacheRebuild() end)
    Map.ChildRemoved:Connect(function() RequestChestCacheRebuild() end)
    if Map:FindFirstChild("SeaContent") then
        Map.SeaContent.ChildAdded:Connect(function() RequestChestCacheRebuild() end)
        Map.SeaContent.ChildRemoved:Connect(function() RequestChestCacheRebuild() end)
    end
end


EldritchUIReady = false

local Window = Fluent:CreateWindow({
    Title      = "Eldritch Hub [B]",
    SubTitle   = tostring(Version),
    TabWidth   = 160,
    Size       = UDim2.fromOffset(580, 460),
    MinimizeKey = Enum.KeyCode.Equals,
    Theme      = "Darker",
})

local MainTab          = Window:AddTab({ Title = "Main",             Icon = "apple" })
local GodmodeSection   = MainTab:AddSection("Godmode")
local DamageSection    = MainTab:AddSection("Damage Exploits")
local SilentAimSection = MainTab:AddSection("Silent Aim")
local NPCSection       = MainTab:AddSection("NPC Exploits")
local NPCAggroSection  = MainTab:AddSection("No NPC Aggro")
local EatSection       = MainTab:AddSection("Auto eat")

GodmodeSection:AddToggle("Godmode1", {
    Title   = "Godmode",
    Default = SessionData.GodMode,
    Callback = function(value)
        Settings.GodMode    = value
        SessionData.GodMode = value
    end,
})

DamageSection:AddToggle("Enabledamagemultiplier23", {
    Title   = "Enable damage multiplier",
    Default = SessionData.EnableDamageMultiplier,
    Callback = function(value)
        Settings.EnableDamageMultiplier    = value
        SessionData.EnableDamageMultiplier = value
    end,
})

DamageSection:AddInput("DamageMultiplier73", {
    Title       = "Damage Multiplier",
    Placeholder = "Amount",
    Default     = tostring(SessionData.DamageMultiplier),
    Callback = function(value)
        local num = tonumber(value)
        if num then Settings.DamageMultiplier = num; SessionData.DamageMultiplier = num end
    end,
    Finished = true,
})

SilentAimSection:AddToggle("SilentAim2", {
    Title   = "Silent Aim",
    Default = SessionData.SilentAim,
    Callback = function(value)
        Settings.SilentAim    = value
        SessionData.SilentAim = value
        if not value and SilentAimLockLabel then SilentAimLockLabel.Visible = false end
    end,
})

SilentAimSection:AddToggle("TargetNPCs3", {
    Title = "Target NPCs", Default = SessionData.SilentAimNPCs,
    Callback = function(v) Settings.SilentAimNPCs = v; SessionData.SilentAimNPCs = v end,
})
SilentAimSection:AddToggle("TargetPlayers4", {
    Title = "Target Players", Default = SessionData.SilentAimPlayers,
    Callback = function(v) Settings.SilentAimPlayers = v; SessionData.SilentAimPlayers = v end,
})
SilentAimSection:AddToggle("SkipPartyMembers5", {
    Title = "Skip Party Members", Default = SessionData.SkipPartyMembers,
    Callback = function(v) Settings.SkipPartyMembers = v; SessionData.SkipPartyMembers = v end,
})
SilentAimSection:AddToggle("SkipFriendlyNPCs6", {
    Title = "Skip Friendly NPCs", Default = SessionData.SkipFriendlyNPCs,
    Callback = function(v) Settings.SkipFriendlyNPCs = v; SessionData.SkipFriendlyNPCs = v end,
})
SilentAimSection:AddToggle("Prediction7", {
    Title = "Prediction", Default = SessionData.Prediction ~= false,
    Callback = function(v) Settings.Prediction = v; SessionData.Prediction = v end,
})
SilentAimSection:AddSlider("PredictionSpeed104", {
    Title   = "Prediction Speed",
    Default = SessionData.PredictionSpeed or 150, Min = 50, Max = 1500, Rounding = 0,
    Callback = function(value)
        Settings.PredictionSpeed    = tonumber(value) or 150
        SessionData.PredictionSpeed = tonumber(value) or 150
    end,
})
SilentAimSection:AddToggle("AutoPredictionSpeed111", {
    Title = "Auto Prediction Speed", Default = SessionData.AutoPredictionSpeed ~= false,
    Callback = function(v) Settings.AutoPredictionSpeed = v; SessionData.AutoPredictionSpeed = v end,
})
SilentAimSection:AddToggle("SkipForceField105", {
    Title = "Skip ForceField Targets", Default = SessionData.SkipForceField ~= false,
    Callback = function(v) Settings.SkipForceField = v; SessionData.SkipForceField = v end,
})
SilentAimSection:AddToggle("SkipBlindTargets106", {
    Title = "Skip Blind Targets (LoS)", Default = SessionData.SkipBlindTargets ~= false,
    Callback = function(v) Settings.SkipBlindTargets = v; SessionData.SkipBlindTargets = v end,
})

SilentAimSection:AddToggle("FOVCheck8", {
    Title   = "FOV Check",
    Default = SessionData.SilentAimFOV,
    Callback = function(value)
        Settings.SilentAimFOV    = value
        SessionData.SilentAimFOV = value
        UpdateFovCircle()
    end,
})
SilentAimSection:AddToggle("ShowFOVCircle9", {
    Title   = "Show FOV Circle",
    Default = SessionData.SilentAimFOVVisible,
    Callback = function(value)
        Settings.SilentAimFOVVisible    = value
        SessionData.SilentAimFOVVisible = value
        UpdateFovCircle()
    end,
})
SilentAimSection:AddToggle("SilentAimWallcheck70", {
    Title   = "Wallcheck",
    Default = SessionData.SilentAimWallcheck or false,
    Callback = function(value)
        Settings.SilentAimWallcheck    = value
        SessionData.SilentAimWallcheck = value
    end,
})
SilentAimSection:AddSlider("MaxLockDistance34", {
    Title    = "Max Lock Distance",
    Default  = SessionData.SilentAimMaxDistance, Min = 100, Max = 3000, Rounding = 0,
    Callback = function(value)
        SilentMaxDistance              = value
        SessionData.SilentAimMaxDistance = value
    end,
})
SilentAimSection:AddSlider("FOVRadius35", {
    Title    = "FOV Radius",
    Default  = SessionData.SilentAimFOVRadius, Min = 50, Max = 500, Rounding = 0,
    Callback = function(value)
        Settings.SilentAimFOVRadius    = value
        SessionData.SilentAimFOVRadius = value
        if FovCircle and Settings.SilentAimFOVVisible and Settings.SilentAimFOV then
            FovCircle.Radius = value
        end
    end,
})
SilentAimSection:AddDropdown("FOVCircleColour41", {
    Title   = "FOV Circle Colour",
    Values  = { "Red", "Green", "Blue", "White", "Cyan" },
    Default = SessionData.FOVColorName or "Red",
    Callback = function(value)
        local colorMap = {
            Red   = Color3.fromRGB(255, 0, 0),
            Green = Color3.fromRGB(0, 255, 0),
            Blue  = Color3.fromRGB(0, 100, 255),
            White = Color3.fromRGB(255, 255, 255),
            Cyan  = Color3.fromRGB(0, 255, 255),
        }
        local chosen         = colorMap[value] or Color3.fromRGB(255, 0, 0)
        SessionData.FOVColor     = chosen
        SessionData.FOVColorName = value
        if FovCircle then FovCircle.Color = chosen end
    end,
})

NPCSection:AddToggle("NPCEsp12", {
    Title   = "NPC Esp",
    Default = SessionData.NPCEspActive,
    Callback = function(value)
        Settings.NPCEspActive    = value
        SessionData.NPCEspActive = value
        if value then RefreshNpcEsp() else ClearNpcEsp() end
    end,
})
NPCSection:AddToggle("NPCEspDisableDistanceCap90", {
    Title   = "Disable NPC ESP Distance Cap",
    Default = not SessionData.NpcEspDistanceCapEnabled,
    Callback = function(value)
        Settings.NpcEspDistanceCapEnabled    = not value
        SessionData.NpcEspDistanceCapEnabled = not value
        RefreshNpcEsp()
    end,
})

NPCAggroSection:AddToggle("NoNPCAggro11", {
    Title   = "No NPC Aggro",
    Default = SessionData.BlockNPCAggro,
    Callback = function(v) Settings.BlockNPCAggro = v; SessionData.BlockNPCAggro = v end,
})
NPCAggroSection:AddToggle("AggroRedirect109", {
    Title   = "Redirect NPC Aggro",
    Default = SessionData.AggroRedirect or false,
    Callback = function(v) Settings.AggroRedirect = v; SessionData.AggroRedirect = v end,
})
NPCAggroSection:AddInput("AggroTarget110", {
    Title       = "Aggro Target (player name)",
    Placeholder = "Exact username",
    Default     = SessionData.AggroTarget or "",
    Callback = function(value)
        Settings.AggroTarget    = tostring(value or "")
        SessionData.AggroTarget = tostring(value or "")
    end,
    Finished = true,
})

EatSection:AddToggle("Toggleautoeat25", {
    Title   = "Toggle auto eat",
    Default = SessionData.AutoEat,
    Callback = function(v) Settings.AutoEat = v; SessionData.AutoEat = v end,
})
EatSection:AddDropdown("FoodItem42", {
    Title    = "Food Item",
    Values   = { "Banana", "Red apple", "Green apple" },
    Callback = function(value) ModifiedStats.FoodItem = value end,
})

local ExploitsTab      = Window:AddTab({ Title = "Exploits",         Icon = "apple" })
local BoatSection      = ExploitsTab:AddSection("Boat Exploits")
local WeaponEXPSection = ExploitsTab:AddSection("Attack Modifiers")
local PlayerSection    = ExploitsTab:AddSection("Player Exploits")

BoatSection:AddToggle("Boostboatspeed24", {
    Title   = "Boost boat speed",
    Default = SessionData.BoostBoatSpeed,
    Callback = function(v) Settings.BoostBoatSpeed = v; SessionData.BoostBoatSpeed = v end,
})
BoatSection:AddInput("Boatspeedmultiplier74", {
    Title       = "Boat speed multiplier",
    Placeholder = "Amount",
    Default     = tostring(SessionData.BoatSpeedMultiplier),
    Callback = function(value)
        local num = tonumber(value)
        if num then Settings.BoatSpeedMultiplier = num; SessionData.BoatSpeedMultiplier = num end
    end,
    Finished = true,
})
BoatSection:AddButton({
    Title    = "Teleport to boat.",
    Callback = function()
        local boat = GetPlayerBoat()
        if not boat then return end
        local humanoid = Character:FindFirstChild("Humanoid")
        if not humanoid then return end
        local SteerSeat = boat:WaitForChild("SteerSeat", 5)
        if SteerSeat then SteerSeat:Sit(humanoid) end
    end,
})

WeaponEXPSection:AddToggle("ChargeMultiplierEnabled94", {
    Title   = "Charge Multiplier",
    Default = SessionData.ChargeMultiplierEnabled,
    Callback = function(v) Settings.ChargeMultiplierEnabled = v; SessionData.ChargeMultiplierEnabled = v end,
})
WeaponEXPSection:AddInput("ChargeMultiplierAmt95", {
    Title    = "Charge Amount",
    Default  = "0",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            num = math.clamp(num, 0, 999)
            Settings.ChargeMultiplierAmt    = num
            SessionData.ChargeMultiplierAmt = num
        end
    end,
    Finished = true,
})
WeaponEXPSection:AddToggle("ChargeMultiplierEnabledS94", {
    Title   = "Strength Charge Multiplier",
    Default = SessionData.ChargeMultiplierEnabled,
    Callback = function(v) Settings.ChargeMultiplierEnabled2 = v; SessionData.ChargeMultiplierEnabled2 = v end,
})
WeaponEXPSection:AddInput("ChargeMultiplierAmtS95", {
    Title    = "Strength Charge Amount",
    Default  = "0",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            num = math.clamp(num, 0, 5)
            Settings.ChargeMultiplierAmt2    = num
            SessionData.ChargeMultiplierAmt2 = num
        end
    end,
    Finished = true,
})

PlayerSection:AddSlider("FOVFieldOfView36", {
    Title    = "FOV (Field Of View)",
    Default  = CurrentCamera.FieldOfView, Min = 70, Max = 120, Rounding = 0,
    Callback = function(value) if tonumber(value) then CurrentCamera.FieldOfView = value end end,
})
PlayerSection:AddToggle("Reducedstaminaconsumption13", {
    Title   = "Reduced stamina consumption",
    Default = SessionData.ReduceStamina,
    Callback = function(v) Settings.ReduceStamina = v; SessionData.ReduceStamina = v end,
})
PlayerSection:AddToggle("DrinkBottlesSilently14", {
    Title   = "Drink Bottles Silently",
    Default = SessionData.SilentBottleDrinking,
    Callback = function(value)
        Settings.SilentBottleDrinking    = value
        SessionData.SilentBottleDrinking = value
        Fluent:Notify({ Duration = 5, Title = "Keybind!", Content = "The default keybind is '.'" })
    end,
})
PlayerSection:AddToggle("Infinitecamerazoom15", {
    Title   = "Infinite camera zoom",
    Default = false,
    Callback = function(value)
        if value then
            if InfiniteZoomConnection then InfiniteZoomConnection:Disconnect() end
            InfiniteZoomConnection = LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
                LocalPlayer.CameraMaxZoomDistance = mHuge
            end)
            LocalPlayer.CameraMaxZoomDistance = mHuge
        elseif InfiniteZoomConnection then
            InfiniteZoomConnection:Disconnect()
            LocalPlayer.CameraMaxZoomDistance = OldZoomDistance
            InfiniteZoomConnection = nil
        end
    end,
})
PlayerSection:AddToggle("Nofog16", {
    Title   = "No fog",
    Default = false,
    Callback = function(value)
        if value == NoFogActive then return end
        NoFogActive = value
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if value then
            if atm then
                OldAtmosphere = {
                    Density = atm.Density, Offset = atm.Offset,
                    Color   = atm.Color,   Decay  = atm.Decay,
                    Glare   = atm.Glare,   Haze   = atm.Haze,
                }
                atm.Density = 0
                atm.Haze    = 0
                atm.Glare   = 0
            end
        else
            if atm and OldAtmosphere then
                atm.Density = OldAtmosphere.Density; atm.Offset = OldAtmosphere.Offset
                atm.Color   = OldAtmosphere.Color;   atm.Decay  = OldAtmosphere.Decay
                atm.Glare   = OldAtmosphere.Glare;   atm.Haze   = OldAtmosphere.Haze
                OldAtmosphere = nil
            end
        end
    end,
})
PlayerSection:AddToggle("Noblur17",            { Title = "No blur",             Default = false, Callback = function(v) local b = Lighting:FindFirstChildOfClass("BlurEffect");           if b then b.Enabled = not v end end })
PlayerSection:AddToggle("Nodepthoffield18",    { Title = "No depth of field",   Default = false, Callback = function(v) local d = Lighting:FindFirstChildOfClass("DepthOfFieldEffect");   if d then d.Enabled = not v end end })
PlayerSection:AddToggle("Nosunrays19",         { Title = "No sun rays",         Default = false, Callback = function(v) local s = Lighting:FindFirstChildOfClass("SunRaysEffect");         if s then s.Enabled = not v end end })
PlayerSection:AddToggle("Nocolorcorrection20", { Title = "No color correction", Default = false, Callback = function(v) local c = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"); if c then c.Enabled = not v end end })
PlayerSection:AddToggle("Nobloom21",           { Title = "No bloom",            Default = false, Callback = function(v) local b = Lighting:FindFirstChildOfClass("BloomEffect");           if b then b.Enabled = not v end end })
_fullbrightOrig = nil
PlayerSection:AddToggle("Fullbright22", {
    Title   = "Full bright",
    Default = false,
    Callback = function(value)
        if value then
            if not _fullbrightOrig then
                _fullbrightOrig = {
                    Brightness = Lighting.Brightness,
                    ClockTime = Lighting.ClockTime,
                    FogEnd = Lighting.FogEnd,
                    GlobalShadows = Lighting.GlobalShadows,
                    Ambient = Lighting.Ambient,
                }
            end
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        else
            if _fullbrightOrig then
                Lighting.Brightness = _fullbrightOrig.Brightness
                Lighting.ClockTime = _fullbrightOrig.ClockTime
                Lighting.FogEnd = _fullbrightOrig.FogEnd
                Lighting.GlobalShadows = _fullbrightOrig.GlobalShadows
                Lighting.Ambient = _fullbrightOrig.Ambient
            else
                Lighting.Brightness = 1
                local ok, t = pcall(function() return BasicModule.GetTime() end)
                Lighting.ClockTime = (ok and tonumber(t)) or 14
                Lighting.FogEnd = 500
                Lighting.GlobalShadows = true
                Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            end
        end
    end,
})
PlayerSection:AddButton({
    Title    = "Stamina boost",
    Callback = function()
        if StaminaBoostDebounce then return end
        StaminaBoostDebounce = true
        Remotes.Combat.StaminaCost:FireServer(-2, "Dodge")
        task.delay(5, function() StaminaBoostDebounce = false end)
    end,
})
PlayerSection:AddButton({
    Title    = "Discover all islands",
    Callback = function()
        for _, island in pairs(Map:GetChildren()) do
            if island:FindFirstChild("Center") then
                Remotes.Misc.UpdateLastSeen:FireServer(island.Name, "")
                task.wait(0.05)
            end
        end
    end,
})
PlayerSection:AddButton({
    Title    = "Change magic.",
    Callback = function()
        local Remote = Remotes.UI:FindFirstChild("HecateEssence")
        if not Remote then
            Fluent:Notify({ Duration = 5, Title = "Error!", Content = "Required object not found.\nServer hop to a new server to fix this issue." })
            return
        end
        Fluent:Notify({ Duration = 5, Title = "Warning!", Content = "This can only be ran once in this server." })
        Remote:FireServer(Remote)
    end,
})
PlayerSection:AddToggle("Toggleinsanity29", {
    Title   = "Toggle insanity",
    Default = true,
    Callback = function(value)
        local temp = LocalPlayer.PlayerScripts
        if temp then
            local insanityScript = temp:FindFirstChild("Insanity")
            if insanityScript then insanityScript.Enabled = not value end
        end
    end,
})

local ItemExploitsTab      = Window:AddTab({ Title = "Item Exploits",    Icon = "apple" })
local ItemsSection         = ItemExploitsTab:AddSection("Item Exploits")
local ChestExploitsSection = ItemExploitsTab:AddSection("Chest Exploits")

do
    local itemEspFilterValues = {}
    for itemName in pairs(InventoryModule.Items) do
        itemEspFilterValues[#itemEspFilterValues + 1] = itemName
    end
    table.sort(itemEspFilterValues)
    ItemsSection:AddDropdown("ItemEspNameFilter55", {
        Title   = "Item Filter (empty = all)",
        Values  = itemEspFilterValues,
        Multi   = true,
        Default = {},
        Callback = function(value)
            ItemEspNameFilter = {}
            for itemName, selected in pairs(value) do
                if selected then ItemEspNameFilter[itemName] = true end
            end
        end,
    })
end

ItemsSection:AddToggle("ChestEsp91", {
    Title   = "Chest ESP",
    Default = SessionData.ChestEspEnabled,
    Callback = function(value)
        Settings.ChestEspEnabled    = value
        SessionData.ChestEspEnabled = value
        if value then task.spawn(ScanChestEsp) else ClearChestEsp() end
    end,
})
ItemsSection:AddToggle("SealedChestEsp93", {
    Title   = "Include Sealed Chests",
    Default = false,
    Callback = function(value)
        Settings.SealedChestEsp = value
        if Settings.ChestEspEnabled then ClearChestEsp(); task.spawn(ScanChestEsp) end
    end,
})
ItemsSection:AddToggle("ItemEspToggle92", {
    Title   = "Item ESP",
    Default = false,
    Callback = function(value)
        if value then
            task.spawn(function() ScanIslandItems(Map, Character, RegisterItemEsp) end)
        else
            for part, record in pairs(EspData.RegisteredMap) do
                if record.gui and record.gui.Parent then record.gui:Destroy() end
                if record.conns then
                    for _, c in pairs(record.conns) do if c and c.Connected then c:Disconnect() end end
                end
                EspData.RegisteredMap[part] = nil
            end
        end
    end,
})
ItemsSection:AddButton({
    Title    = "Quick fill bottles.",
    Callback = function()
        if FillDebounce then return end
        FillDebounce = true
        local humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
            for _ = 1, 5 do
                pcall(function() Remotes.Misc.EmptyBottle:FireServer() end)
                task.wait(0.15)
            end
            task.delay(1, function() FillDebounce = false end)
        else
            FillDebounce = false
        end
    end,
})
ItemsSection:AddSlider("ItemESPRange37", {
    Title    = "Item ESP Range",
    Default  = SessionData.ItemEspRadius, Min = 1000, Max = 10000, Rounding = 0,
    Callback = function(value)
        Settings.ItemEspRadius    = tonumber(value)
        SessionData.ItemEspRadius = tonumber(value)
    end,
})
ItemsSection:AddToggle("Drachmafarm26", {
    Title   = "Drachma farm",
    Default = SessionData.GalleonFarm,
    Callback = function(v) Settings.GalleonFarm = v; SessionData.GalleonFarm = v end,
})
ItemsSection:AddToggle("BirdMeatFarm67", {
    Title   = "Bird meat farm",
    Default = SessionData.BirdMeatFarm,
    Callback = function(v) Settings.BirdMeatFarm = v; SessionData.BirdMeatFarm = v end,
})
ItemsSection:AddToggle("CitizenKillAura107", {
    Title   = "Citizen kill aura",
    Default = SessionData.CitizenKillAura or false,
    Callback = function(v) Settings.CitizenKillAura = v; SessionData.CitizenKillAura = v end,
})
ItemsSection:AddSlider("CitizenKillRadius108", {
    Title   = "Citizen Kill Radius",
    Default = SessionData.CitizenKillRadius or 150, Min = 25, Max = 500, Rounding = 0,
    Callback = function(value)
        Settings.CitizenKillRadius    = tonumber(value) or 150
        SessionData.CitizenKillRadius = tonumber(value) or 150
    end,
})

ChestExploitsSection:AddToggle("ChestAura27", {
    Title   = "Chest Aura",
    Default = SessionData.ChestAura,
    Callback = function(value)
        Settings.ChestAura    = value
        SessionData.ChestAura = value
        if value and drawing then
            if not ChestAuraLabel then
                ChestAuraLabel          = drawing.new("Text")
                ChestAuraLabel.Size     = 16
                ChestAuraLabel.Color    = Color3.fromRGB(255, 215, 0)
                ChestAuraLabel.Outline  = true
                ChestAuraLabel.Position = Vector2.new(10, 80)
                ChestAuraLabel.Text     = "Chests opened: 0"
                ChestAuraLabel.Visible  = true
            end
        elseif not value and ChestAuraLabel then
            ChestAuraLabel:Remove()
            ChestAuraLabel = nil
        end
    end,
})
ChestExploitsSection:AddSlider("ChestRadius38", {
    Title    = "Chest Radius",
    Default  = SessionData.ChestRadius, Min = 1, Max = 50, Rounding = 0,
    Callback = function(value)
        if tonumber(value) then
            Settings.ChestRadius    = tonumber(value)
            SessionData.ChestRadius = tonumber(value)
        end
    end,
})
ChestExploitsSection:AddButton({
    Title    = "Legendary Chest grabber. (laggy)",
    Callback = function()
        if LChestDebounce then return end
        LChestDebounce = true
        GrabLegendaryChests()
    end,
})

local FishingExploitsTab = Window:AddTab({ Title = "Fishing Exploits", Icon = "apple" })
local FishingSection     = FishingExploitsTab:AddSection("Fish Exploits")

FishingSection:AddInput("FishingTool88", {
    Title    = "Fishing Tool",
    Default  = SessionData.FishingToolName or "None",
    Callback = function(value)
        if not value then return end
        FishingToolName             = value
        SessionData.FishingToolName = value
        FishingTool = LocalPlayer.Backpack:FindFirstChild(value) or Character:FindFirstChild(value)
        if FishingTool then Fluent:Notify({ Duration = 5, Title = "Alert!", Content = "Fishing tool found." }) end
    end,
    Finished = true,
})
FishingSection:AddToggle("Toggleautofish28", {
    Title   = "Toggle auto fish",
    Default = SessionData.AutoFish,
    Callback = function(value)
        if not FishingTool then
            Fluent:Notify({ Duration = 5, Title = "Warning!", Content = "Select a fishing tool first." })
            Settings.AutoFish = false
            return
        end
        if value and SessionData.UseWaterType and FishingType ~= "Silent" then
            Fluent:Notify({ Duration = 7, Title = "Water Type Warning",
                Content = "Water Type is enabled but Fishing Type is set to Legit. Water Type only works with Silent fishing it will be ignored." })
        end
        Settings.AutoFish    = value
        SessionData.AutoFish = value
        if value then
            if FishingType == "Silent" then
                local waterPart, waterPos = GetSilentFishArgs()
                if waterPart and FishingTool and not FishBiteInProgress() then
                    QOLEnsureFishState(waterPart)
                    Remotes.Misc.FishClock:FireServer(FishingTool, waterPart, waterPos, QOLFishingBait())
                end
            else
                local hum = Character:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                hum:UnequipTools()
                task.wait(0.2)
                hum:EquipTool(FishingTool)
                task.wait(0.2)
                Remotes.Misc.ToolAction:FireServer(Character:FindFirstChildOfClass("Tool"))
            end
        end
    end,
})
FishingSection:AddDropdown("FishingType51", {
    Title    = "Fishing Type",
    Values   = { "Legit", "Silent" },
    Default  = SessionData.FishingType,
    Callback = function(value) FishingType = value; SessionData.FishingType = value end,
})
FishingSection:AddToggle("UseBaitType57", {
    Title    = "Use Custom Bait",
    Default  = SessionData.UseBaitType or false,
    Callback = function(value) SessionData.UseBaitType = value end,
})
FishingSection:AddDropdown("FishingBaitType56", {
    Title    = "Bait Type",
    Values   = { "Normal Bait", "Magic Bait", "Swarm Bait", "Giant Bait" },
    Default  = SessionData.FishingBaitType or "Normal Bait",
    Callback = function(value)
        FishingBaitType             = value
        SessionData.FishingBaitType = value
    end,
})
FishingSection:AddToggle("UseWaterType58", {
    Title    = "Use Water Type (Silent only)",
    Default  = SessionData.UseWaterType or false,
    Callback = function(value)
        SessionData.UseWaterType = value
        if value and FishingType ~= "Silent" then
            Fluent:Notify({ Duration = 6, Title = "Water Type",
                Content = "Water Type only works with Silent fishing. Switch Fishing Type to Silent to use this feature." })
        end
    end,
})
FishingSection:AddDropdown("FishingWaterType59", {
    Title    = "Water Type",
    Values   = { "Warm", "Cold" },
    Default  = SessionData.FishingWaterType or "Warm",
    Callback = function(value)
        FishingWaterType             = value
        SessionData.FishingWaterType = value
        CachedWaterPart = nil
        CachedWaterType = nil
        if FishingType ~= "Silent" then
            Fluent:Notify({ Duration = 6, Title = "Water Type",
                Content = "Water Type only works with Silent fishing. Switch Fishing Type to Silent to use this feature." })
        end
    end,
})

local ModuleExploitsTab = Window:AddTab({ Title = "Module Exploits",  Icon = "apple" })
local MagicSection      = ModuleExploitsTab:AddSection("Magic Exploits")
local MeleeSection      = ModuleExploitsTab:AddSection("Melee Exploits")
local WeaponsSection    = ModuleExploitsTab:AddSection("Weapon Exploits")
local ArmorSection      = ModuleExploitsTab:AddSection("Armor Exploits")

local SelectedMagics = {}
MagicSection:AddDropdown("Magic43", {
    Title   = "Magic (multi-select)",
    Values  = magicTypes,
    Multi   = true,
    Default = {},
    Callback = function(value)
        SelectedMagics = {}
        for name, selected in pairs(value) do
            if selected and MagicModule.Types[name] and type(MagicModule.Types[name]) == "table" then
                SelectedMagics[#SelectedMagics + 1] = name
            end
        end
        ModifiedStats.Magic  = SelectedMagics[1] or nil
        ModifiedStats.Magic2 = SelectedMagics[2] or nil
    end,
})
MagicSection:AddInput("Size75",      { Title = "Size",        Default = "1", Finished = true, Callback = function(value)
    if #SelectedMagics == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMagics) do if MagicModule.Types[name] then MagicModule.Types[name].Size = num end end
    if num > 75 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: <75"}) end
end })
MagicSection:AddInput("Speed76",     { Title = "Speed",       Default = "1", Finished = true, Callback = function(value)
    if #SelectedMagics == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMagics) do if MagicModule.Types[name] then MagicModule.Types[name].Speed = num end end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: <3"}) end
end })
MagicSection:AddInput("ImbueSpeed77",{ Title = "Imbue Speed", Default = "1", Finished = true, Callback = function(value)
    if #SelectedMagics == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMagics) do if MagicModule.Types[name] then MagicModule.Types[name].ImbueSpeed = num end end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: <3"}) end
end })
MagicSection:AddInput("ImbueSize744",{ Title = "Imbue Size", Default = "1", Finished = true, Callback = function(value)
    if #SelectedMagics == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMagics) do if MagicModule.Types[name] then MagicModule.Types[name].ImbueSize = num end end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: <76"}) end
end })

local SelectedMelees = {}
MeleeSection:AddDropdown("FightingStyle45", {
    Title   = "Fighting Style (multi-select)",
    Values  = meleeTypes,
    Multi   = true,
    Default = {},
    Callback = function(value)
        SelectedMelees = {}
        for name, selected in pairs(value) do
            if selected and MeleeModule.Types[name] and type(MeleeModule.Types[name]) == "table" then
                SelectedMelees[#SelectedMelees + 1] = name
            end
        end
        ModifiedStats.Melee  = SelectedMelees[1] or nil
        ModifiedStats.Melee2 = SelectedMelees[2] or nil
    end,
})
MeleeSection:AddInput("Size78",      { Title = "Size",        Default = "1", Finished = true, Callback = function(value)
    if #SelectedMelees == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMelees) do if MeleeModule.Types[name] then MeleeModule.Types[name].Size = num end end
    if num > 5 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: < 5"}) end
end })
MeleeSection:AddInput("Speed79",     { Title = "Speed",       Default = "1", Finished = true, Callback = function(value)
    if #SelectedMelees == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMelees) do if MeleeModule.Types[name] then MeleeModule.Types[name].Speed = num end end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: < 3"}) end
end })
MeleeSection:AddInput("ImbueSpeed80",{ Title = "Imbue Speed", Default = "1", Finished = true, Callback = function(value)
    if #SelectedMelees == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedMelees) do if MeleeModule.Types[name] then MeleeModule.Types[name].ImbueSpeed = num end end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: < 3"}) end
end })

local SelectedWeapons = {}
WeaponsSection:AddDropdown("Weapon47", {
    Title   = "Weapon (multi-select)",
    Values  = weaponTypes,
    Multi   = true,
    Default = {},
    Callback = function(value)
        SelectedWeapons = {}
        for name, selected in pairs(value) do
            if selected and InventoryModule.Items[name] and type(InventoryModule.Items[name]) == "table" then
                SelectedWeapons[#SelectedWeapons + 1] = name
            end
        end
        ModifiedStats.Weapon  = SelectedWeapons[1] or nil
        ModifiedStats.Weapon2 = SelectedWeapons[2] or nil
        ModifiedStats.Weapon3 = SelectedWeapons[3] or nil
    end,
})
WeaponsSection:AddInput("Size81",  { Title = "Size",  Default = "1", Finished = true, Callback = function(value)
    if #SelectedWeapons == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedWeapons) do
        local item = InventoryModule.Items[name]
        if item and item.Specs and item.Specs["Attack Size"] then item.Specs["Attack Size"].Value = num end
    end
    if num > 75 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: < 75"}) end
end })
WeaponsSection:AddInput("Speed82", { Title = "Speed", Default = "1", Finished = true, Callback = function(value)
    if #SelectedWeapons == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedWeapons) do
        local item = InventoryModule.Items[name]
        if item and item.Specs and item.Specs["Attack Speed"] then item.Specs["Attack Speed"].Value = num end
    end
    if num > 3 then Fluent:Notify({Duration=5,Title="Warning!",Content="This could break your game if you set it too high.\nSuggested value: < 3"}) end
end })
WeaponsSection:AddInput("RangeMultiplier82", { Title = "Range Multiplier", Default = "1", Finished = true, Callback = function(value)
    if #SelectedWeapons == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedWeapons) do
        local item = InventoryModule.Items[name]
        if item and item.Specs and item.Specs["Range Multiplier"] then item.Specs["Range Multiplier"].Value = num end
    end
end })
WeaponsSection:AddInput("ReloadTime82", { Title = "Reload Time", Default = "1", Finished = true, Callback = function(value)
    if #SelectedWeapons == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedWeapons) do
        local item = InventoryModule.Items[name]
        if item and item.Specs and item.Specs["Reload Time"] then item.Specs["Reload Time"].Value = num end
    end
end })

local SelectedArmors = {}
ArmorSection:AddDropdown("Armor50", {
    Title   = "Armor (multi-select)",
    Values  = itemTypes,
    Multi   = true,
    Default = {},
    Callback = function(value)
        SelectedArmors = {}
        for name, selected in pairs(value) do
            if selected and InventoryModule.Items[name] and type(InventoryModule.Items[name]) == "table" then
                SelectedArmors[#SelectedArmors + 1] = name
            end
        end
        ModifiedStats.Armor = SelectedArmors[1] or nil
    end,
})
ArmorSection:AddInput("Size83",      { Title = "Size",       Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Size = num end end
end })
ArmorSection:AddInput("Dexterity84", { Title = "Dexterity",  Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Dexterity = num end end
end })
ArmorSection:AddInput("Range85",     { Title = "Range",      Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Range = num end end
end })
ArmorSection:AddInput("Agility814",     { Title = "Agility",      Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Agility = num end end
end })
ArmorSection:AddInput("Warding86",   { Title = "Warding",    Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Warding = num end end
end })
ArmorSection:AddInput("Insanity87",  { Title = "Insanity",   Default = "1", Finished = true, Callback = function(value)
    if #SelectedArmors == 0 or not tonumber(value) then return end
    local num = tonumber(value)
    for _, name in ipairs(SelectedArmors) do if InventoryModule.Items[name] and InventoryModule.Items[name].Stats then InventoryModule.Items[name].Stats.Insanity = num end end
end })

local MagicSpoofTab, MagicSpoofSection
if JD_IS_PREMIUM then
    MagicSpoofTab     = Window:AddTab({ Title = "Magic Spoof", Icon = "wand" })
    MagicSpoofSection = MagicSpoofTab:AddSection("Magic Spoofer")

    MagicSpoofSection:AddParagraph({
        Title   = "How to use",
        Content = "1. Pick the magic you want to disguise under Spoofed Magic.\n"
               .. "2. Pick what magic to replace it with under Chosen Spoofed Magic.\n"
               .. "3. Enable the toggle below.\n"
               .. "Turn it off to restore your original magic.",
    })

    MagicSpoofSection:AddDropdown("SpoofTargetMagic100", {
        Title    = "Spoofed Magic",
        Values   = AllMagicTypes,
        Callback = function(value)
            if SpoofState.Active then
                RestoreMagicSpoof()
                uiSet("EnableMagicSpoof102", false)
                SpoofState.Active = false
            end
            SpoofState.TargetSlot = (value == "None" or value == nil) and "None" or value
            SpoofState.ChosenVariation = "None"
            pcall(function() SpoofVariationDropdown:SetValue("None") end)
        end,
    })

    local SpoofVariationDropdown

    MagicSpoofSection:AddDropdown("SpoofChosenMagic101", {
        Title    = "Chosen Spoofed Magic",
        Values   = AllMagicTypes,
        Callback = function(value)
            if SpoofState.Active then
                RestoreMagicSpoof()
                uiSet("EnableMagicSpoof102", false)
                SpoofState.Active = false
            end
            SpoofState.ChosenSpoof = (value == "None" or value == nil) and "None" or value
            SpoofState.ChosenVariation = "None"
            local varList = { "None" }
            if value and value ~= "None" then
                local variations = MagicModule.Types[value] and MagicModule.Types[value]["Variations"]
                if type(variations) == "table" then
                    for vk in pairs(variations) do
                        varList[#varList + 1] = tostring(vk)
                    end
                    table.sort(varList, function(a, b)
                        if a == "None" then return true end
                        if b == "None" then return false end
                        return (tonumber(a) or 0) < (tonumber(b) or 0)
                    end)
                end
            end
            pcall(function()
                SpoofVariationDropdown:SetValues(varList)
                SpoofVariationDropdown:SetValue("None")
            end)
        end,
    })

    SpoofVariationDropdown = MagicSpoofSection:AddDropdown("SpoofVariation103", {
        Title    = "Chosen Variation",
        Values   = { "None" },
        Callback = function(value)
            SpoofState.ChosenVariation = (value == "None" or value == nil) and "None" or tostring(value)
            if SpoofState.Active then
                RestoreMagicSpoof()
                local ok = ApplyMagicSpoof()
                if ok then
                    Fluent:Notify({ Duration = 4, Title = "Magic Spoof", Content = "Variation updated." })
                else
                    uiSet("EnableMagicSpoof102", false)
                    SpoofState.Active = false
                end
            end
        end,
    })

    MagicSpoofSection:AddToggle("EnableMagicSpoof102", {
        Title   = "Enable Magic Spoof",
        Default = false,
        Callback = function(value)
            if value then
                local src = SpoofState.ChosenSpoof
                if src ~= "None" and not MagicModule.Types[src] then
                    Fluent:Notify({ Duration = 7, Title = "Magic Spoof Warning",
                        Content = src .. " was not found in this server's MagicModule.\n"
                               .. "The spoof could not be applied." })
                    uiSet("EnableMagicSpoof102", false)
                    return
                end
                local ok = ApplyMagicSpoof()
                if ok then
                    Fluent:Notify({ Duration = 5, Title = "Magic Spoof",
                        Content = "Now spoofing " .. SpoofState.TargetSlot .. " as " .. SpoofState.ChosenSpoof })
                else
                    uiSet("EnableMagicSpoof102", false)
                end
            else
                if SpoofState.Active then
                    RestoreMagicSpoof()
                    Fluent:Notify({ Duration = 5, Title = "Magic Spoof",
                        Content = SpoofState.TargetSlot ~= "None"
                            and (SpoofState.TargetSlot .. " restored to original.")
                            or  "Magic spoof disabled." })
                end
            end
        end,
    })

    local SpoofStatusPara = MagicSpoofSection:AddParagraph({
        Title   = "Current Status",
        Content = "Inactive",
    })

    RunService.Heartbeat:Connect(function()
        if not SpoofStatusPara then return end
        local content
        if SpoofState.Active then
            content = "Active: " .. SpoofState.TargetSlot .. " spoofed as " .. SpoofState.ChosenSpoof
        else
            content = "Inactive"
        end
        pcall(function() SpoofStatusPara:SetDesc(content) end)
    end)

    MagicSpoofSection:AddButton({
        Title    = "Force Restore (emergency)",
        Callback = function()
            if SpoofState.Active then
                RestoreMagicSpoof()
                uiSet("EnableMagicSpoof102", false)
                Fluent:Notify({ Duration = 5, Title = "Magic Spoof", Content = "Force-restored original magic data." })
            else
                Fluent:Notify({ Duration = 5, Title = "Magic Spoof", Content = "No active spoof to restore." })
            end
        end,
    })
end

local DarkSeaTab     = Window:AddTab({ Title = "Dark Sea",    Icon = "apple" })
local DarkSeaSection = DarkSeaTab:AddSection("Dark Sea Exploits")

DarkSeaSection:AddButton({
    Title    = "Disable fog circle",
    Callback = function()
        local tempGui    = LocalPlayer.PlayerGui:FindFirstChild("Temp")
        local darkSeaGui = tempGui and tempGui:FindFirstChild("DarkSea")
        if darkSeaGui then
            local sky1 = darkSeaGui:FindFirstChild("DarkSky1")
            local sky2 = darkSeaGui:FindFirstChild("DarkSky2")
            if sky1 and sky1:FindFirstChildOfClass("SpecialMesh") then sky1:FindFirstChildOfClass("SpecialMesh"):Destroy() end
            if sky2 and sky2:FindFirstChildOfClass("SpecialMesh") then sky2:FindFirstChildOfClass("SpecialMesh"):Destroy() end
        end
        local camSky1 = CurrentCamera:FindFirstChild("DarkSky1")
        local camSky2 = CurrentCamera:FindFirstChild("DarkSky2")
        if camSky1 and camSky1:FindFirstChildOfClass("SpecialMesh") then camSky1:FindFirstChildOfClass("SpecialMesh"):Destroy() end
        if camSky2 and camSky2:FindFirstChildOfClass("SpecialMesh") then camSky2:FindFirstChildOfClass("SpecialMesh"):Destroy() end
    end,
})
DarkSeaSection:AddButton({
    Title    = "Disable dark sea rain",
    Callback = function()
        local overheadFX = workspace.Camera:FindFirstChild("OverheadFX")
        if overheadFX then
            if overheadFX:FindFirstChild("DSRain")  then overheadFX.DSRain.Lifetime  = NumberRange.new(0, 0) end
            if overheadFX:FindFirstChild("DSRain2") then overheadFX.DSRain2.Lifetime = NumberRange.new(0, 0) end
        end
    end,
})
DarkSeaSection:AddToggle("Toggleautowashbin30", {
    Title   = "Toggle auto wash bin",
    Default = SessionData.AutoWash,
    Callback = function(v) Settings.AutoWash = v; SessionData.AutoWash = v end,
})
DarkSeaSection:AddSlider("AutoWashIntervals39", {
    Title    = "Auto Wash Interval (s)",
    Default  = SessionData.AutoWashDelay, Min = 1, Max = 30, Rounding = 0,
    Callback = function(value) SessionData.AutoWashDelay = value end,
})
DarkSeaSection:AddToggle("Hecateessencenotifier31", {
    Title   = "Hecate essence notifier",
    Default = SessionData.HecateNotifier,
    Callback = function(v) Settings.HecateNotifier = v; SessionData.HecateNotifier = v end,
})
DarkSeaSection:AddToggle("EpicenterESP32", {
    Title   = "Epicenter ESP",
    Default = SessionData.EpicenterESP,
    Callback = function(value)
        Settings.EpicenterESP    = value
        SessionData.EpicenterESP = value
        EnableEpicenterEsp(value)
    end,
})

local TeleportsTab    = Window:AddTab({ Title = "Teleports",  Icon = "apple" })
local TeleportSection = TeleportsTab:AddSection("Teleports")

function SafeTeleportTo(centerCFrame)
    local char = LocalPlayer.Character
    local humanoidRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoidRoot then TeleportDebounce = false; return nil, nil end
    humanoidRoot.CFrame = centerCFrame
    humanoidRoot.Anchored = true
    task.delay(SessionData.TeleportDelay or 15, function()
        local curChar = LocalPlayer.Character
        local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
        if curRoot then pcall(function() curRoot.Anchored = false end) end
        if humanoidRoot ~= curRoot then pcall(function() humanoidRoot.Anchored = false end) end
        TeleportDebounce = false
    end)
    return char, humanoidRoot
end

TeleportSection:AddDropdown("Teleports53", {
    Title    = "Teleports",
    Values   = teleportLocations,
    Callback = function(value)
        if TeleportDebounce then return end
        TeleportDebounce = true
        if not Map then TeleportDebounce = false; return end
        local island = Map:FindFirstChild(value)
        local center = island and island:FindFirstChild("Center")
        if not center then TeleportDebounce = false; return end
        LastTeleportIsland = value
        if value == "Harvest Island" then
            local oldPos = center.Position
            center.Position = Vector3.new(7236, 598, 343)
            task.delay(1, function() if center then center.Position = oldPos end end)
        end
        SafeTeleportTo(center.CFrame + (value == "Mount Othrys" and Vector3.new(0, -25000, 0) or Vector3.new(0, 1000, 0)))
    end,
})
TeleportSection:AddSlider("TeleportAnchorDelays40", {
    Title    = "Teleport Anchor Delay (s)",
    Default  = SessionData.TeleportDelay, Min = 3, Max = 30, Rounding = 0,
    Callback = function(value)
        SessionData.TeleportDelay = value
        Settings.TeleportDelay    = value
    end,
})
TeleportSection:AddButton({
    Title    = "Repeat Last Teleport",
    Callback = function()
        if not LastTeleportIsland then
            Fluent:Notify({ Duration = 5, Title = "Info", Content = "No previous teleport recorded." })
            return
        end
        if TeleportDebounce then return end
        TeleportDebounce = true
        if not Map then TeleportDebounce = false; return end
        local island = Map:FindFirstChild(LastTeleportIsland)
        local center = island and island:FindFirstChild("Center")
        if not center then TeleportDebounce = false; return end
        SafeTeleportTo(center.CFrame + Vector3.new(0, 1000, 0))
    end,
})

local DivingTab = Window:AddTab({ Title = "Diving Farm", Icon = "anchor" })
local DivingSection = DivingTab:AddSection("Diving Spot Auto Farm")
DiveStatusPara = DivingSection:AddParagraph({
    Title = "Status",
    Content = "Stopped. Warning: high/unstable ping may get you banned.",
})
DivingSection:AddToggle("DiveFarmEnabled60", {
    Title = "Enable Diving Farm",
    Default = SessionData.DiveFarmEnabled or false,
    Callback = function(v)
        Settings.DiveFarmEnabled = v
        SessionData.DiveFarmEnabled = v
        if not EldritchUIReady then return end
        if v then
            StartDiveFarm()
        else
            local wasRunning = DiveRunning or DiveLoopRunning
            StopDiveFarm()
            if wasRunning and DiveEnemiesRemoved and not DiveSuppressFarmKill then
                Fluent:Notify({ Duration = 8, Title = "Dive Farm", Content = "Farm disabled. The game is BROKEN until you rejoin, rejoining now to fix it..." })
                task.delay(1, function() DiveRejoin() end)
            end
        end
    end,
})
DivingSection:AddParagraph({
    Title = "Remove Enemies, READ THIS",
    Content = "This DESTROYS the Enemies folder and BREAKS THE ENTIRE GAME (not just ESP, enemies, spawns, visuals) until you REJOIN. Turning Diving Farm OFF will auto-rejoin you to fix the game.",
})
DivingSection:AddToggle("DiveRemoveEnemies61", {
    Title = "Remove Enemies folder (BREAKS GAME, REJOIN TO FIX)",
    Default = SessionData.DiveRemoveEnemies ~= false,
    Callback = function(v)
        if DiveSuppressRemovePrompt or not EldritchUIReady then
            Settings.DiveRemoveEnemies = v
            SessionData.DiveRemoveEnemies = v
            return
        end
        if v then
            if not Settings.DiveFarmEnabled then
                Fluent:Notify({ Duration = 5, Title = "Dive Farm", Content = "Enable Diving Farm first, Remove Enemies needs it." })
                DiveSuppressRemovePrompt = true
                pcall(function() uiSet("DiveRemoveEnemies61", false) end)
                DiveSuppressRemovePrompt = false
                return
            end
            if DiveConfirmOpen then return end
            DiveConfirmOpen = true

            Settings.DiveRemoveEnemies = false
            SessionData.DiveRemoveEnemies = false
            DiveSuppressRemovePrompt = true
            pcall(function() uiSet("DiveRemoveEnemies61", false) end)
            DiveSuppressRemovePrompt = false
            local function setEnabledConfirmed()
                DiveConfirmOpen = false
                Settings.DiveRemoveEnemies = true
                SessionData.DiveRemoveEnemies = true
                DiveSuppressRemovePrompt = true
                pcall(function() uiSet("DiveRemoveEnemies61", true) end)
                DiveSuppressRemovePrompt = false
                Fluent:Notify({ Duration = 8, Title = "Dive Farm", Content = "Remove Enemies enabled. This BREAKS THE ENTIRE GAME, you MUST REJOIN to fix it." })
            end
            local function setCancelled()
                DiveConfirmOpen = false
                DiveSuppressRemovePrompt = true
                pcall(function() uiSet("DiveRemoveEnemies61", false) end)
                DiveSuppressRemovePrompt = false
            end
            local ok, _ = pcall(function()
                Window:Dialog({
                    Title = "Warning: Remove Enemies BREAKS THE GAME",
                    Content = "This will DESTROY the Enemies folder and BREAK THE ENTIRE GAME (not just NPC ESP, enemies, spawns, and visuals will stop working). To FIX it you will be REQUIRED TO REJOIN. Do you understand and still want to enable it?",
                    Buttons = {
                        { Title = "I Understand, Enable", Callback = setEnabledConfirmed },
                        { Title = "Cancel", Callback = setCancelled },
                    },
                })
            end)
            if not ok then
                DiveConfirmOpen = false
                StarterGui:SetCore("SendNotification", {
                    Title = "Warning: Remove Enemies BREAKS THE GAME",
                    Text = "This BREAKS THE ENTIRE GAME (not just ESP). You MUST REJOIN to fix it. Enable?",
                    Duration = 10,
                    Button1 = "Enable",
                    Button2 = "Cancel",
                    Callback = function(btn)
                        if btn == "Enable" then
                            setEnabledConfirmed()
                        else
                            setCancelled()
                        end
                    end,
                })
            end
        else
            if DiveConfirmOpen then return end
            Settings.DiveRemoveEnemies = false
            SessionData.DiveRemoveEnemies = false
            Fluent:Notify({ Duration = 5, Title = "Dive Farm", Content = "Remove Enemies disabled. Turn the farm off to rejoin and fully restore the game." })
        end
    end,
})
DivingSection:AddToggle("DiveRemoveDamage62", {
    Title = "Remove Touch/Fall damage",
    Default = SessionData.DiveRemoveDamage ~= false,
    Callback = function(v) Settings.DiveRemoveDamage = v; SessionData.DiveRemoveDamage = v end,
})
DivingSection:AddToggle("DiveSkipPlayers63", {
    Title = "Skip spots with players nearby",
    Default = SessionData.DiveSkipPlayers ~= false,
    Callback = function(v) Settings.DiveSkipPlayers = v; SessionData.DiveSkipPlayers = v end,
})
DivingSection:AddToggle("DivePreferSpots80", {
    Title = "Prioritize Diving Spots",
    Default = SessionData.DivePreferSpots or false,
    Callback = function(v)
        Settings.DivePreferSpots = v
        SessionData.DivePreferSpots = v
        if v and EldritchUIReady then
            Settings.DivePreferStructs = false
            SessionData.DivePreferStructs = false
            uiSet("DivePreferStructs81", false)
        end
    end,
})
DivingSection:AddToggle("DivePreferStructs81", {
    Title = "Prioritize Structures",
    Default = SessionData.DivePreferStructs or false,
    Callback = function(v)
        Settings.DivePreferStructs = v
        SessionData.DivePreferStructs = v
        if v and EldritchUIReady then
            Settings.DivePreferSpots = false
            SessionData.DivePreferSpots = false
            uiSet("DivePreferSpots80", false)
        end
    end,
})
DivingSection:AddToggle("DiveIgnoreLegendary82", {
    Title = "Ignore legendary chests",
    Default = SessionData.DiveIgnoreLegendary ~= false,
    Callback = function(v) Settings.DiveIgnoreLegendary = v; SessionData.DiveIgnoreLegendary = v end,
})
DivingSection:AddToggle("DiveSlowMode83", {
    Title = "Slow mode (safer, slower farm)",
    Default = SessionData.DiveSlowMode or false,
    Callback = function(v) Settings.DiveSlowMode = v; SessionData.DiveSlowMode = v end,
})
DivingSection:AddButton({
    Title = "Teleport up for air now",
    Callback = function() DiveTeleportUpForAir() end,
})
DivingSection:AddButton({
    Title = "Stop fly / unstick",
    Callback = function() DiveStopFly() end,
})

local DupesTab = Window:AddTab({ Title = "Dupes", Icon = "copy" })
local CopperSection = DupesTab:AddSection("Copper Shroom (Tidecliff Isle)")
CopperSection:AddParagraph({
    Title = "How to use",
    Content = "Have Coppershrooms planted and save the slot BEFORE running the dupe.",
})
CopperSection:AddInput("CopperSlot65", {
    Title = "Save Slot",
    Default = SessionData.CopperSlot or "Personal",
    Placeholder = "Personal",
    Callback = function(value)
        if value and value ~= "" then SessionData.CopperSlot = value end
    end,
    Finished = true,
})
CopperSection:AddInput("CopperIsland66", {
    Title = "Island Name",
    Default = SessionData.CopperIsland or "Tidecliff Isle",
    Placeholder = "Tidecliff Isle",
    Callback = function(value)
        if value and value ~= "" then SessionData.CopperIsland = value end
    end,
    Finished = true,
})
CopperSection:AddButton({
    Title = "Run Copper Shroom Farm",
    Callback = function() RunCopperShroomFarm() end,
})
local ReagantSection = DupesTab:AddSection("Reagant Counter")
ReagantPara = ReagantSection:AddParagraph({
    Title = "Reagant Count",
    Content = "Press Count. Counts 'Visual' under island.",
})
ReagantSection:AddInput("ReagantIsland64", {
    Title = "Island Name",
    Default = SessionData.ReagantIsland or "Limestone Key",
    Placeholder = "Limestone Key",
    Callback = function(value)
        if value and value ~= "" then SessionData.ReagantIsland = value end
    end,
    Finished = true,
})
ReagantSection:AddButton({
    Title = "Count Reagants",
    Callback = function() CountReagants() end,
})

local QOLMoveSection = MainTab:AddSection("Movement")
QOLMoveSection:AddToggle("QOLInfJump68", {
    Title = "Infinite Jump",
    Default = SessionData.QOLInfJump or false,
    Callback = function(v)
        Settings.QOLInfJump = v
        SessionData.QOLInfJump = v
        if EldritchUIReady then QOLSetInfJump(v) end
    end,
})
local QOLCamSection = MainTab:AddSection("Camera")
QOLCamSection:AddToggle("QOLCrosshair69", {
    Title = "Crosshair",
    Default = SessionData.QOLCrosshair or false,
    Callback = function(v)
        Settings.QOLCrosshair = v
        SessionData.QOLCrosshair = v
        if EldritchUIReady then QOLSetCrosshair(v) end
    end,
})
local QOLAudioSection = MainTab:AddSection("Audio")
QOLAudioSection:AddToggle("QOLHitSound72", {
    Title = "Hit Sound",
    Default = SessionData.QOLHitSound or false,
    Callback = function(v) Settings.QOLHitSound = v; SessionData.QOLHitSound = v end,
})
QOLAudioSection:AddInput("QOLHitSoundId73", {
    Title = "Sound Asset ID",
    Default = SessionData.QOLHitSoundId or "",
    Placeholder = "rbxassetid://...",
    Callback = function(value) SessionData.QOLHitSoundId = value or "" end,
    Finished = true,
})
QOLAudioSection:AddSlider("QOLHitSoundVol74", {
    Title = "Sound Volume (x0.1)",
    Default = SessionData.QOLHitSoundVol or 10, Min = 0, Max = 20, Rounding = 0,
    Callback = function(value) SessionData.QOLHitSoundVol = value end,
})
local QOLWatchSection = MainTab:AddSection("Watch")
QOLWatchSection:AddToggle("QOLAntiFling77", {
    Title = "Anti Fling",
    Default = SessionData.QOLAntiFling or false,
    Callback = function(v) Settings.QOLAntiFling = v; SessionData.QOLAntiFling = v end,
})
local QOLStealthSection = MainTab:AddSection("Stealth")
QOLStealthSection:AddParagraph({
    Title = "FE Invisible",
    Content = "True desync invisibility. Physics, jumping and falling all work. A ghost glow marks you, visible only to you.",
})
QOLStealthSection:AddToggle("QOLUnderground78", {
    Title = "FE Invisible",
    Default = SessionData.QOLUnderground or false,
    Callback = function(v)
        Settings.QOLUnderground = v
        SessionData.QOLUnderground = v
        if EldritchUIReady then QOLSetUnderground(v) end
    end,
})
QOLStealthSection:AddSlider("QOLInvisDip72", {
    Title = "Dip Distance (studs)",
    Default = SessionData.QOLInvisDip or 200, Min = 8, Max = 500, Rounding = 0,
    Callback = function(value) SessionData.QOLInvisDip = value end,
})
QOLStealthSection:AddToggle("QOLInvisUp70", {
    Title = "Dip Up Instead of Down",
    Default = SessionData.QOLInvisUp or false,
    Callback = function(v)
        Settings.QOLInvisUp = v
        SessionData.QOLInvisUp = v
    end,
})
QOLStealthSection:AddButton({
    Title    = "Destroy head overhead",
    Callback = function()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        local oh = head and head:FindFirstChild("Overhead")
        if oh then pcall(function() oh:Destroy() end) end
    end,
})

local MiscTab        = Window:AddTab({ Title = "Misc",        Icon = "apple" })
local MiscSection    = MiscTab:AddSection("Misc")
local NavySection    = MiscTab:AddSection("Navy Influence")

MiscSection:AddButton({
    Title    = "Quick clear notoriety",
    Callback = function() Remotes.UI.ClearBounty:InvokeServer("ClearNotoriety") end,
})
MiscSection:AddButton({
    Title    = "Quick clear bounty",
    Callback = function() Remotes.UI.ClearBounty:InvokeServer("Clear") end,
})
MiscSection:AddButton({
    Title    = "Quick clear fame",
    Callback = function() Remotes.UI.ClearBounty:InvokeServer("ClearFame") end,
})
local BountyPricePara = MiscSection:AddParagraph({
    Title   = "Clear Prices (Drachma)",
    Content = "Press Refresh.",
})
local function RefreshBountyPrices()
    if not BountyPricePara then return end
    local bounty, fame, noto = nil, nil, nil
    pcall(function() bounty = Remotes.UI.ClearBounty:InvokeServer("GetPrice") end)
    pcall(function() fame = Remotes.UI.ClearBounty:InvokeServer("GetFamePrice") end)
    pcall(function() noto = Remotes.UI.ClearBounty:InvokeServer("GetPriceNotoriety") end)
    local function fmt(v)
        if v == nil or v == false then return "n/a" end
        return tostring(v)
    end
    BountyPricePara:SetDesc("Bounty: " .. fmt(bounty) .. " | Fame: " .. fmt(fame) .. " | Notoriety: " .. fmt(noto))
end
MiscSection:AddButton({
    Title    = "Refresh clear prices",
    Callback = function() RefreshBountyPrices() end,
})
Scheduler:add("BountyPrices", 30, function()
    RefreshBountyPrices()
end)
RefreshBountyPrices()
MiscSection:AddDropdown("AnimationPacks52", {
    Title    = "Animation Packs",
    Values   = { "Coward", "Boss", "Cute", "Lazy", "Fighter", "Assassin", "Sorcerer" },
    Callback = function(value)
        BasicModule.GetAnimationPack = function() return value end
        Fluent:Notify({ Duration = 5, Title = "Warning!", Content = "This won't apply until you reset." })
    end,
})

do
    local NavyInfluence = RS:WaitForChild("NavyInfluence", 10)
    local function FormatNavyInfluence(raw)
        return sFmt("%.1f%%", (raw or 0) / 10000)
    end
    local NavyParagraph = NavySection:AddParagraph({
        Title   = "Navy Influence",
        Content = NavyInfluence and FormatNavyInfluence(NavyInfluence.Value) or "Not found",
    })
    if NavyInfluence then
        NavyInfluence.Changed:Connect(function(newValue)
            if NavyParagraph then NavyParagraph:SetDesc(FormatNavyInfluence(newValue)) end
        end)
    end
end

local FleetSection = MiscTab:AddSection("Fleet")
FleetDataPara = FleetSection:AddParagraph({
    Title   = "Fleet Data",
    Content = "Press Refresh.",
})
FleetSection:AddButton({
    Title    = "Refresh Fleet Data",
    Callback = function() RefreshFleetData() end,
})
Scheduler:add("FleetData", 15, function()
    if FleetDataPara then RefreshFleetData() end
end)
RefreshFleetData()

local SettingTab = Window:AddTab({ Title = "Settings", Icon = "Settings-3" })
local UISettingsSection = SettingTab:AddSection("UI Settings")
UISettingsSection:AddToggle("AlwayShowFrame33", {
    Title   = "Always Show Frame",
    Default = false,
    Callback = function(v) end,
})

local ConfigSection = SettingTab:AddSection("Configs")

ConfigSection:AddInput("ConfigName89", {
    Title    = "Config Name",
    Default  = "default",
    Callback = function(value)
        if value and value ~= "" then ConfigNameInput = value end
    end,
    Finished = true,
})

ConfigSection:AddButton({
    Title    = "Save Config",
    Callback = function()
        EnsureConfigFolder()
        local path    = ConfigFolder .. "/" .. ConfigNameInput .. ConfigExt
        local ok, err = pcall(writefile, path, SerializeConfig())
        if ok then
            RefreshConfigDropdown()
            Fluent:Notify({ Duration = 5, Title = "Config", Content = "Saved: " .. ConfigNameInput })
        else
            Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "Save failed: " .. tostring(err) })
        end
    end,
})

ConfigDropdown = ConfigSection:AddDropdown("SelectConfig54", {
    Title    = "Select Config",
    Values   = GetConfigList(),
    Callback = function(value)
        if value ~= "No configs found" then SelectedConfig = value end
    end,
})

ConfigSection:AddButton({
    Title    = "Refresh List",
    Callback = function()
        RefreshConfigDropdown()
        Fluent:Notify({ Duration = 5, Title = "Config", Content = "Config list refreshed." })
    end,
})

ConfigSection:AddButton({
    Title    = "Load Config",
    Callback = function()
        if not SelectedConfig then
            Fluent:Notify({ Duration = 5, Title = "Config", Content = "Select a config first." })
            return
        end
        local path = ConfigFolder .. "/" .. SelectedConfig .. ConfigExt
        if not isfile(path) then
            Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "File not found: " .. SelectedConfig })
            return
        end
        local ok, raw = pcall(readfile, path)
        if not ok then
            Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "Read failed." })
            return
        end
        local data = DeserializeConfig(raw)
        if not data then
            Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "Invalid config file." })
            return
        end
        ApplyLoadedConfig(data)
        ActivateLoadedConfig()
        Fluent:Notify({ Duration = 5, Title = "Config", Content = "Loaded: " .. SelectedConfig })
    end,
})

ConfigSection:AddButton({
    Title    = "Delete Config",
    Callback = function()
        if not SelectedConfig then
            Fluent:Notify({ Duration = 5, Title = "Config", Content = "Select a config first." })
            return
        end
        local path = ConfigFolder .. "/" .. SelectedConfig .. ConfigExt
        if isfile(path) then
            local ok = pcall(delfile, path)
            if ok then
                Fluent:Notify({ Duration = 5, Title = "Config", Content = "Deleted: " .. SelectedConfig })
                SelectedConfig = nil
                RefreshConfigDropdown()
            else
                Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "Delete failed." })
            end
        else
            Fluent:Notify({ Duration = 5, Title = "Config Error", Content = "File not found." })
        end
    end,
})

local ThemeTab = Window:AddTab({ Title = "Themes",   Icon = "paintbrush" })
ThemeTab:AddSection("UI Themes"):AddDropdown("SelectTheme", {
    Title   = "Select Theme",
    Default = "Darker",
    Values  = { "Dark", "Darker", "Light", "Aqua", "Amethyst", "Rose" },
    Callback = function(v) Fluent:SetTheme(v) end,
})

Fluent:SetTheme("Darker")

pcall(function() Window:SelectTab(1) end)

BuildChestCache()
SetupFishClockTracker()
SetupFishingListener()

EldritchUIReady = true

task.spawn(function()
    task.wait(5)
    pcall(QOLHookHBE)
end)
