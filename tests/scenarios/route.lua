-- How to get there: on foot nearby, by flight further away, by boat to another continent; the arrow leads leg
-- by leg.
START()
STATE.player.wx, STATE.player.wy = -8840, 480      -- at Stormwind's flight master
STATE.player.level = 30
OPEN()
local function Modes()
    local r = ZNS.Route.Current()
    if not r then return "none" end
    local out = {}
    for _, leg in ipairs(r.legs) do out[#out + 1] = leg.mode end
    return table.concat(out, ",")
end
local gu, gv = ZNS.Geo.ToWorld(1429, 0.42, 0.65)
ZNS.Route.To(gu, gv, "Villadorada")
OUT("goldshire: " .. Modes())
local iu, iv = ZNS.Geo.FromYards(0, -4821, -1155)
ZNS.Route.To(iu, iv, "Forjaz")
OUT("ironforge: " .. Modes() .. ", arrow " .. tostring(ZNS.Arrow.Target() and ZNS.Arrow.Target().name))
local du, dv = ZNS.Geo.FromYards(1, 9950, 2280)   -- Darnassus
ZNS.Route.To(du, dv, "Darnassus")
local r = ZNS.Route.Current()
OUT(("darnassus: %s, %s"):format(Modes(), r and ZNS.Duration(r.seconds) or "-"))
-- the first leg's end reached: the next
local first = r.legs[1]
STATE.player.wx, STATE.player.wy = first.to.x, first.to.y
ZNS.Route.Check()
OUT(("step after reaching the first: %d, panel rows %d"):format(ZNS.Route.Current().step, #r.legs))
ZNS.Route.Clear()
OUT("cleared: " .. tostring(ZNS.Route.Current() == nil and ZNS.Arrow.Target() == nil))
OUT("errors " .. #STATE.errors)
