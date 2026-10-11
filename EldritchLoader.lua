local EldritchLoader = {}
EldritchLoader.Rev = "?rev=7"

EldritchLoader.Root = "https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main"

EldritchLoader.Games = {
    [12345678] = "12345678 - ExampleGame",
    [155615604] = "155615604 - Prison Life",
}

EldritchLoader.Universal = "universal"

local folder = EldritchLoader.Games[game.PlaceId] or EldritchLoader.Universal
local url = EldritchLoader.Root .. "/games/" .. string.gsub(folder, " ", "%%20") .. "/main.lua"
loadstring(game:HttpGet(url .. EldritchLoader.Rev, true))()

return EldritchLoader
