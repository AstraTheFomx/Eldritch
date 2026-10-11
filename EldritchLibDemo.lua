local EldritchLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/EldritchLib.lua?rev=2", true))()

local Win = EldritchLib:CreateWindow({
    Title = "Eldritch",
    ToggleKey = Enum.KeyCode.RightShift
})

local Stats = Win:AddTab("Stats")
local Farm = Win:AddTab("Auto Farm")
local Player = Win:AddTab("Player")
local Audio = Win:AddTab("Audio")
local Misc = Win:AddTab("Misc")

Stats:AddSection("Session")
local fpsLabel = Stats:AddLabel("FPS: ...")
local pingLabel = Stats:AddLabel("Ping: ...")
Stats:AddButton("Refresh Stats", function()
    fpsLabel:Set("FPS: " .. tostring(math.random(55, 144)))
    pingLabel:Set("Ping: " .. tostring(math.random(30, 120)) .. "ms")
end)
Stats:AddButton("Reset Stats", function()
    fpsLabel:Set("FPS: ...")
    pingLabel:Set("Ping: ...")
end)

local farming = false
local farmSpeed = 5
local farmTarget = "Wolves"
Farm:AddSection("Farm Controls")
Farm:AddToggle("Enable Auto Farm", false, function(v)
    farming = v
end)
Farm:AddSlider("Farm Speed", 1, 20, 5, function(v)
    farmSpeed = math.floor(v + 0.5)
end)
Farm:AddDropdown("Farm Target", {"Crabs", "Wolves", "Bandits", "Boss"}, "Wolves", function(v)
    farmTarget = v
end)
Farm:AddButton("Stop All", function()
    farming = false
end)

Player:AddSection("Movement")
local lp = game:GetService("Players").LocalPlayer
local wsValue = 35
local wsEnabled = false
local wsRevert = 16
local function applyWs()
    if not wsEnabled then return end
    local c = lp.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = wsValue end
end
local function revertWs()
    local c = lp.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = wsRevert end
end
Player:AddToggle("Enable WalkSpeed", false, function(v)
    wsEnabled = v
    if v then
        local c = lp.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then wsRevert = h.WalkSpeed end
        applyWs()
        task.spawn(function()
            while wsEnabled do
                applyWs()
                task.wait(0.25)
            end
        end)
    else
        revertWs()
    end
end)
Player:AddInput("WalkSpeed:", "35", function(v)
    local n = tonumber(v)
    if n then
        wsValue = n
        applyWs()
    end
end)
Player:AddInput("JumpPower:", "60", function(v)
    local n = tonumber(v)
    local c = lp.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if n and h then h.JumpPower = n end
end)
Player:AddSlider("WalkSpeed Slider", 16, 200, 35, function(v)
    wsValue = math.floor(v + 0.5)
    applyWs()
end)
Player:AddSection("Animation IDs")
local animIds = {}
for _, name in ipairs({"Idle 1:", "Idle 2:", "Walk:", "Run:", "Jump:", "Fall:", "Climb:"}) do
    animIds[name] = "10921144709"
    Player:AddInput(name, "10921144709", function(v)
        animIds[name] = v
    end)
end

Audio:AddSection("Sounds")
local muted = false
local volume = 5
local track = "Lobby"
Audio:AddToggle("Mute All", false, function(v)
    muted = v
end)
Audio:AddSlider("Volume", 0, 10, 5, function(v)
    volume = math.floor(v + 0.5)
end)
Audio:AddDropdown("Track", {"Lobby", "Battle", "Boss", "Off"}, "Lobby", function(v)
    track = v
end)

Misc:AddSection("Window")
Misc:AddButton("Hide UI (RightShift to show)", function()
    Win:SetVisible(false)
end)
local themePick = "Bubblegum"
Misc:AddDropdown("Theme Check", {"Bubblegum", "Dark", "Light"}, "Bubblegum", function(v)
    themePick = v
end)
Misc:AddLabel("ToggleKey: RightShift")

Win:SelectTab("Player")
