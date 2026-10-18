-- Zephras Isle (the Windshaper Skyborne's start): a zone on an instance of its own, placed in a sea of the
-- stitched map. Your position on it, the map opening there, its quest givers, the airships to it and the way
-- off it, your corpse on it.
START()
STATE.player.inst, STATE.player.wx, STATE.player.wy = 2991, 2600, 1400
STATE.player.faction, STATE.player.level = "Horde", 1
local u, v, m = ZNS.Geo.UnitPosition("player")
local l, r, t, b = ZNS.Geo.Rect(2521)
OUT(("position: zone %s, on the isle %s"):format(tostring(m), tostring(u ~= nil and u >= l and u <= r and v >= t and v <= b)))
OUT("zone at the player: " .. tostring(ZNS.Geo.ZoneAt(u, v)))
OPEN()
local vl, vt, vr, vb = ZNS.Map.ViewRect()
OUT("opened on the isle: " .. tostring(math.abs((vl + vr) / 2 / ZNS.Geo.W - u) < 0.01 and math.abs((vt + vb) / 2 / ZNS.Geo.H - v) < 0.01))
local givers = 0
for _, mark in ipairs(ZNS.QuestMap.Givers()) do if mark.m == 2521 then givers = givers + 1 end end
OUT("quest givers on the isle: " .. givers)
local airships, docks = 0, 0
for _, tr in ipairs(ZNS.TRANSPORTS) do
    if tr[1] == "airship" then
        airships = airships + 1
        for _, d in ipairs(tr[5]) do if d[1] == 2991 then docks = docks + 1 end end
    end
end
OUT(("airships: %d, docks on the isle %d"):format(airships, docks))
local ou, ov = ZNS.Geo.ToWorld(1454, 0.5, 0.5)
ZNS.Route.To(ou, ov, "Orgrimmar")
local modes = {}
for _, leg in ipairs(ZNS.Route.Current() and ZNS.Route.Current().legs or {}) do modes[#modes + 1] = leg.mode end
OUT("route to orgrimmar: " .. table.concat(modes, ","))
ZNS.Route.Clear()
STATE.ghost = true
STATE.corpse = { map = 2521, x = 0.5, y = 0.5 }
EVENT("PLAYER_ALIVE")
local target = ZNS.Arrow.Target()
OUT("corpse on the isle: " .. tostring(target ~= nil and target.corpse == true and target.instance == 2991))
STATE.ghost, STATE.corpse = false, nil
EVENT("PLAYER_UNGHOST")
OUT("errors " .. #STATE.errors)
