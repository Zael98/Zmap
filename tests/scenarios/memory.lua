-- Memory: what Zmap holds once logged in, the search's index once it is used, and the garbage made while walking
-- with the map open and while it is closed (the layers that keep only what is in view refresh only when the view
-- leaves what their last refresh covered).
local function KB()
    collectgarbage("collect")
    collectgarbage("collect")
    return collectgarbage("count")
end

-- garbage made in `seconds` of game (20 frames a second), each frame after step(i)
local function Garbage(seconds, step)
    collectgarbage("collect")
    collectgarbage("stop")
    local c0 = collectgarbage("count")
    for i = 1, seconds * 20 do
        if step then step(i) end
        FRAME(0.05)
    end
    local made = collectgarbage("count") - c0
    collectgarbage("restart")
    return made
end

START()
STATE.player.level = 30
FRAMES(200)   -- (ten seconds in)
OUT(("logged in: %.1f MB"):format(KB() / 1024))
local before = KB()
ZNS.Search.Find("tabernero")
OUT(("search index: %.1f MB"):format((KB() - before) / 1024))
OUT(("map closed, walking: %.0f KB in 10 s"):format(Garbage(10, function() STATE.player.wx = STATE.player.wx + 0.3 end)))
OPEN()
local u, v = ZNS.Geo.ToWorld(1429, 0.42, 0.65)
ZNS.Map.SetView(u * ZNS.Geo.W, v * ZNS.Geo.H, ZNS.Map.ZoomFor(1429) * 1.5)
FRAMES(5)
OUT(("map open, walking: %.0f KB in 10 s"):format(Garbage(10, function() STATE.player.wx = STATE.player.wx + 0.3 end)))
OUT(("map open, panning: %.0f KB in 10 s"):format(Garbage(10, function(i)
    ZNS.Map.SetView(u * ZNS.Geo.W + i * 0.05, v * ZNS.Geo.H, ZNS.Map.ZoomFor(1429) * 1.5)
end)))
-- a minute zooming in and out with the wheel and panning, herbs shown: the second such minute (what the first
-- built, zone art and the like, is kept), all of it garbage
STATE.skills = { herb = 50 }
ADVANCE(6)
ZNS.SetOpt("herbs", true)
local function Minute()
    for _ = 1, 6 do
        for _ = 1, 6 do WHEEL(u, v, 1, 8) end
        for _ = 1, 6 do WHEEL(u, v, -1, 8) end
        for k = 1, 40 do
            ZNS.Map.SetView((u + k * 0.0004) * ZNS.Geo.W, v * ZNS.Geo.H, ZNS.Map.Zoom())
            FRAME(0.05)
        end
    end
end
Minute()
collectgarbage("collect")
collectgarbage("stop")
local c0 = collectgarbage("count")
Minute()
local zooming = collectgarbage("count") - c0
collectgarbage("restart")
OUT(("map open, zooming: %.0f KB a minute"):format(zooming))
ZNS.Map.Close()
OUT("errors " .. #STATE.errors)
