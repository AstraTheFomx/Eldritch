local EldritchLoader = {}
EldritchLoader.Rev = "?rev=2"

EldritchLoader.Root = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main"

EldritchLoader.Games = {
    [12345678] = "12345678 - ExampleGame",
}

EldritchLoader.Universal = "universal"

local folder = EldritchLoader.Games[game.PlaceId] or EldritchLoader.Universal
local url = EldritchLoader.Root .. "/games/" .. string.gsub(folder, " ", "%%20") .. "/main.lua"
loadstring(game:HttpGet(url .. EldritchLoader.Rev))()

return EldritchLoader
