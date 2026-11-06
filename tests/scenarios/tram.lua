-- The Deeprun Tram: a world of its own (369) the game has no map for, so no place on any map, but its own yards
-- come. The map opens on the ride with you on the line between its doors, as far along it as you are, your arrow
-- turned with the tram and its name below; nothing in the chat. Center works there too. In a real instance,
-- opening the map says nothing in the chat either (its bottom bar does); Center says why it cannot.
START()
STATE.player.faction = "Alliance"
local T = ZNS.TRAM
local su, sv = ZNS.Geo.FromYards(T[1][1], T[1][2], T[1][3])   -- Stormwind's door
local iu, iv = ZNS.Geo.FromYards(T[2][1], T[2][2], T[2][3])   -- Ironforge's door
local a, b = T.inside[1], T.inside[2]
local function Ride(f)   -- 0 at the tram's Stormwind end, 1 at its Ironforge end
    STATE.player.inst = a[1]
    STATE.player.wx, STATE.player.wy = a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end
local function PlayerPin()
    for _, w in ipairs(ALL_WIDGETS) do
        if w.provider and w.icon and w.icon.atlas == "minimaparrow" then return w end
    end
end
local function Near(u, v, tu, tv) return u ~= nil and math.abs(u - tu) < 0.002 and math.abs(v - tv) < 0.002 end
local function Below(text)
    for _, w in ipairs(ALL_WIDGETS) do if w.kind == "FontString" and w.text == text and w:IsVisible() then return true end end
    return false
end

Ride(0.5)
STATE.player.facing = math.atan2(b[3] - a[3], b[2] - a[2])   -- along the tunnel, towards Ironforge
OUT("map position: " .. tostring((ZNS.Geo.UnitPosition("player"))))
local said = #STATE.printed
OPEN()
local pin = PlayerPin()
OUT(("halfway: pin shown %s, between the doors %s"):format(tostring(pin and pin:IsShown()),
    tostring(pin and Near(pin.u, pin.v, (su + iu) / 2, (sv + iv) / 2))))
local vl, vt, vr, vb = ZNS.Map.ViewRect()
local function InView(u, v)
    return u * ZNS.Geo.W >= vl and u * ZNS.Geo.W <= vr and v * ZNS.Geo.H >= vt and v * ZNS.Geo.H <= vb
end
OUT(("opened on the ride: both doors in view %s; chat %d; below %s"):format(tostring(InView(su, sv) and InView(iu, iv)),
    #STATE.printed - said, tostring(Below(ZNS.Name(T.names)))))
local want = math.atan2(T[2][3] - T[1][3], T[2][2] - T[1][2])   -- the way from Stormwind's door to Ironforge's
OUT(("arrow along the line: %s"):format(tostring(math.abs((pin.icon.rotation or 0) - want) < 0.01)))
Ride(1)
FRAMES(2)
OUT(("at the ironforge end: %s"):format(tostring(Near(pin.u, pin.v, iu, iv))))
said = #STATE.printed
OUT(("center: %s, chat %d"):format(tostring(ZNS.Map.CenterOnPlayer(false)), #STATE.printed - said))

-- out of the tram, into a real instance
ZNS.Map.Close()
STATE.player.inst, STATE.player.wx, STATE.player.wy = 0, -9460, 62
STATE.instance = true
said = #STATE.printed
OPEN()
local opening = #STATE.printed - said
said = #STATE.printed
local centered = ZNS.Map.CenterOnPlayer(false)
OUT(("in an instance: opening chat %d; center %s, chat %d"):format(opening, tostring(centered), #STATE.printed - said))
STATE.instance = nil
OUT("errors " .. #STATE.errors)
