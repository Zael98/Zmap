-- One icon for one thing in one place: the data lists some NPCs at many points side by side (a patrol, the same
-- spot seen again), a smithy's anvils, a mailbox or a herb under two IDs. Townsfolk, quest givers and rares are
-- marked once for a place (Geo.PLACE yards), anvils, forges and mailboxes once of each kind, herbs and veins of a
-- kind once within a few yards; and a rare's places that would overlap on screen at the zoom, once.
START()
local Geo, N = ZNS.Geo, ZNS.Npcs

-- yards between two points { mapID, x, y } (very far: not on the same continent)
local function Yards(a, b)
    local ia = Geo.Instance(a[1])
    if not ia or ia ~= Geo.Instance(b[1]) then return math.huge end
    local ua, va = Geo.ToWorld(a[1], a[2], a[3])
    local ub, vb = Geo.ToWorld(b[1], b[2], b[3])
    return Geo.Yards(ia, ua, va, ub, vb) or math.huge
end
-- pairs of the same thing (same(a, b)) closer than `yards`
local function Twice(list, yards, same)
    local n = 0
    for i = 1, #list do
        for j = i + 1, #list do
            if same(list[i], list[j]) and Yards(list[i], list[j]) < yards then n = n + 1 end
        end
    end
    return n
end
local function SameId(a, b) return a.id == b.id end

-- the townsfolk of the data: no NPC twice in one place
local folk = {}
for _, f in ipairs(N.Townsfolk()) do folk[#folk + 1] = { f.m, f.x, f.y, id = f.id } end
local folkTwice = Twice(folk, Geo.PLACE, SameId)
-- an NPC the data lists at points side by side: fewer places than spawns
local listed, spawns, places
for id in pairs(ZNS.NPCS) do
    local s = N.Spawns(id)
    if not listed and #s > 1 and #s < 40 and Yards(s[1], s[2]) < 10 then listed, spawns, places = id, #s, #N.Places(id) end
end
OUT(("data: townsfolk twice in a place %d; one listed side by side: spawns %d, places %d"):format(folkTwice,
    spawns or 0, places or 0))

OPEN()
local W, H = Geo.W, Geo.H
local function Look(mapID, x, y, zoom)
    local u, v = Geo.ToWorld(mapID, x, y)
    ZNS.Map.GoTo(u, v, zoom)
    FRAMES(120)
end
local function Pins(layer, keep)
    local out = {}
    for _, pin in ipairs(PINS(layer)) do
        if keep(pin) then out[#out + 1] = { pin.m, pin.x, pin.y, id = keep(pin), pin = pin } end
    end
    return out
end

-- Ironforge's Great Forge: its ring of anvils and forges, one icon of each
ZNS.SetOpt("townsfolk", true)
Look(1455, 0.52, 0.42, 25)
local utilities = Pins("townsfolk", function(pin) return pin.object end)
OUT(("great forge: utilities %d, the same kind twice in a place %d"):format(#utilities, Twice(utilities, Geo.PLACE, SameId)))

-- herbs and veins of Elwynn: one of a kind within a few yards (the same node under two IDs)
STATE.skills = { herb = 300, ore = 300 }
EVENT("SKILL_LINES_CHANGED")
ZNS.SetOpt("herbs", true)
ZNS.SetOpt("ore", true)
Look(1429, 0.45, 0.60, 6)
local nodes = Pins("gather", function(pin) return pin.data and pin.data.item end)
OUT(("elwynn nodes: %d, the same kind twice within 8 yd %d"):format(#nodes, Twice(nodes, 8, SameId)))

-- rares across Elwynn: a rare's icons never on top of each other
ZNS.SetOpt("rares", true)
Look(1429, 0.45, 0.60, 12)
local rares, overlap = PINS("rares"), 0
for i = 1, #rares do
    for j = i + 1, #rares do
        local a, b = rares[i], rares[j]
        local ax, ay = SCREEN_OF(a.u, a.v)
        local bx, by = SCREEN_OF(b.u, b.v)
        if a.npc == b.npc and (ax - bx) ^ 2 + (ay - by) ^ 2 < 16 ^ 2 then overlap = overlap + 1 end
    end
end
OUT(("elwynn rares: %d, a rare on top of itself %d"):format(#rares, overlap))
-- closer in, a roaming rare's places part again
Look(1429, 0.45, 0.60, 40)
OUT("errors " .. #STATE.errors)
