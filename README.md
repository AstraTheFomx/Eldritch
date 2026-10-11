# Eldritch

Executor UI framework plus game scripts.

Run in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AstraTheFomx/Eldritch/main/EldritchLoader.lua?rev=1"))()
```

The loader picks `games/<PlaceId> - <Name>/main.lua` for the current game and falls back to `games/universal/main.lua`.

Layout:

- `EldritchLib.lua` - interface library
- `EldritchBase.lua` - module framework (categories, modules, shared heartbeat)
- `EldritchLoader.lua` - game picker
- `games/universal/main.lua` - universal modules, returns `Base`
- `games/<PlaceId> - <Name>/main.lua` - per-game extensions

Per-game files load universal, then add a category, modules, and `Base:Step(fn)` hooks.

Bump every `?rev=` query after pushing an update or executors will run stale cached copies.
