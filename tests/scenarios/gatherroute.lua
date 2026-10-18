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
-- chosen in the right-click menu (every kind, or one, the most there first): the bar says what it is and where
-- you are in it; its close button stops it
STATE.skills = { herb = 100 }
ADVANCE(6)
local mu, mv = ZNS.Geo.ToWorld(1429, 0.5, 0.5)
CLICK_MAP(mu, mv, "RightButton")
local entry
for _, item in ipairs(STATE.menu.items) do
    if item.text and item.text:find("Ruta de recolección", 1, true) then entry = item end
end
local kinds = {}
for _, k in ipairs(entry.items) do kinds[#kinds + 1] = k.text end
OUT(("route menu: %d entries, first %s"):format(#kinds, kinds[1]))
entry.items[2].fn()
local chosen = ZNS.GatherRoute.Current()
local bar
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "FontString" and tostring(w.text):find("Ruta de recolección:", 1, true) and w:IsVisible() then bar = w end
end
OUT(("one kind: %s, %d stops; bar %s"):format(chosen.label, #chosen.stops, bar and bar:GetText() or "none"))
bar.parent.close:Click()
OUT(("closed: route %s, bar %s"):format(tostring(ZNS.GatherRoute.Current() ~= nil), tostring(bar.parent:IsShown())))
OUT("errors " .. #STATE.errors)
