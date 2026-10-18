-- A gathering route round Elwynn Forest for a herbalist: every stop once, a loop no longer than going nearest
-- first; the arrow from stop to stop; another way taking the arrow ends it; nothing to gather, no route.
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
STATE.player.level = 20
STATE.skills = { herb = 100 }
ADVANCE(6)
OPEN()
local ok = ZNS.GatherRoute.Start(1429)
local r = ZNS.GatherRoute.Current()
local seen, unique = {}, 0
for _, s in ipairs(r.stops) do
    if not seen[s] then seen[s], unique = true, unique + 1 end
end
OUT(("route: %s, stops %d, each once %s, arrow %s"):format(tostring(ok), #r.stops, tostring(unique == #r.stops), ZNS.Arrow.Target().name))
OUT("said: " .. LAST_PRINT())

-- at the first stop: the next
local s = r.stops[1]
STATE.player.wx, STATE.player.wy = ZNS.Geo.ToYards(0, s[1], s[2])
ZNS.GatherRoute.Check()
OUT("after the first: " .. ZNS.Arrow.Target().name)

-- the way somewhere else takes the arrow: the route ends
local gu, gv = ZNS.Geo.ToWorld(1429, 0.42, 0.65)
ZNS.Route.To(gu, gv, "Villadorada")
ZNS.GatherRoute.Check()
OUT("another way: route " .. tostring(ZNS.GatherRoute.Current() ~= nil))
ZNS.Route.Clear()

-- no profession: nothing to gather
STATE.skills = {}
ADVANCE(6)
OUT(("no profession: %s, %s"):format(tostring(ZNS.GatherRoute.Start(1429)), LAST_PRINT()))
OUT("errors " .. #STATE.errors)
