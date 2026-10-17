-- Flight masters: your faction's, the undiscovered ones, routes and times, a chosen origin, the timer
-- while flying and learning how long the flight took.
START()
STATE.player.wx, STATE.player.wy = -8840, 480      -- at Stormwind's flight master
STATE.undiscovered = { [45] = true }               -- Nethergarde Keep: not discovered yet
OPEN()
local l, r, t, b = ZNS.Geo.Rect(1415)
ZNS.Map.SetView((l + r) / 2 * ZNS.Geo.W, (t + b) / 2 * ZNS.Geo.H, 2.5)
FRAMES(3)
local function Find(id) for _, p in ipairs(PINS("flights")) do if p.id == id then return p end end end
local nodes = PINS("flights")
local ok = true
for _, p in ipairs(nodes) do if ZNS.TAXI_NODES[p.id][4] == "H" then ok = false end end
OUT(("nodes shown %d (alliance and neutral only: %s)"):format(#nodes, tostring(ok)))
OUT("undiscovered icon: " .. tostring(Find(45) and Find(45).icon.atlas))

local secs, hops = ZNS.Flights.Route(2, 6)
OUT(("route Stormwind->Ironforge: %s, hops %d"):format(ZNS.Duration(secs), #hops))
OUT("tooltip: " .. HOVER(Find(6)))
local ifPin = Find(6)
ifPin.scripts.OnEnter(ifPin)
local lines = 0
for _, w in ipairs(ALL_WIDGETS) do if w.kind == "Line" and w.shown then lines = lines + 1 end end
ifPin.scripts.OnLeave(ifPin)
OUT("hover lines: " .. lines)

local men = Find(7)
men.scripts.OnClick(men, "LeftButton")
local tip = HOVER(Find(6))
OUT(("origin chosen: %s, tooltip from it: %s"):format(tostring(Find(7).glow.shown),
    tostring(tip:find(ZNS.Flights.Name(7), 1, true) ~= nil)))
Find(7).scripts.OnClick(Find(7), "RightButton")

-- a flight: Stormwind to Ironforge
STATE.taxiCurrent = 2
TakeTaxiNode(6)
FRAMES(2)
STATE.onTaxi = true
FRAMES(2)
local bar = ZmapFlightBar
OUT(("timer: bar shown %s, text %s"):format(tostring(bar and bar.shown), bar and bar.text.text or "nil"))
STATE.time = STATE.time + 95
FRAME()
STATE.onTaxi = false
FRAME()
OUT(("landed: recorded %s s, bar hidden %s"):format(tostring(ZNS.db.flights["2-6"]), tostring(not bar.shown)))
OUT("speed learned: " .. tostring(ZNS.db.flightSpeed ~= nil and ZNS.db.flightSpeed > 5))
OUT("errors " .. #STATE.errors)
