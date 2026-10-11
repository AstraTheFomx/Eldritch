local UNIVERSAL_URL = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/games/universal/main.lua?rev=4"

local Base = loadstring(game:HttpGet(UNIVERSAL_URL, true))()
local Entity = Base.Entity

local Game = Base:CreateCategory("Example")

local jumpDelay, jumpClock = 0.5, 0
local AutoJump = Game:CreateModule({
    Name = "AutoJump",
    Function = function(on)
        if on then jumpClock = 0 end
    end,
})
AutoJump:CreateSlider("Delay", 0, 2, 0.5, function(v)
    jumpDelay = v
end)
Base:Step(function(dt)
    if not AutoJump.Enabled or not Entity.Alive() then return end
    local humanoid = Entity.Humanoid()
    if humanoid == nil then return end
    if humanoid.FloorMaterial == Enum.Material.Air then
        jumpClock = 0
        return
    end
    jumpClock = jumpClock + dt
    if jumpClock >= jumpDelay and humanoid.MoveDirection.Magnitude > 0.1 then
        jumpClock = 0
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end)

Base.Window:SelectTab("Example")

return Base
