-- A battleground's map: it opens inside one, drawn whole (Alterac Valley's overlays too), your group by the
-- game's own frame, its objectives and the flags; a dungeon's map after it has none of them.
START()
local avOverlays = { [8097530] = true, [8097531] = true, [8097532] = true, [8097533] = true, [8097534] = true,
    [8097535] = true, [8097536] = true, [8097537] = true }

local function Shown(w)
    while w do
        if not w.shown then return false end
        w = w.parent
    end
    return true
end

local function Count(test)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do if test(w) and Shown(w) then n = n + 1 end end
    return n
end

local function UnitsFrame()
    for _, w in ipairs(ALL_WIDGETS) do if w.kind == "UnitPositionFrame" then return w end end
end

STATE.instance, STATE.instanceType, STATE.instanceID, STATE.instanceName = true, "pvp", 30, "Valle de Alterac"
STATE.pois = { [1459] = {
    { id = 1, name = "Torre de la Punta de Hielo", textureIndex = 9, x = 0.45, y = 0.2 },
    { id = 2, name = "Cementerio de Piedrahogar", atlasName = "GraveyardHorde", x = 0.5, y = 0.7 },
} }
STATE.flags, STATE.flagMap = {}, nil
OPEN()
FRAMES(3)
local live = ZNS.Dungeon.Live()
local units = UnitsFrame()
OUT(("alterac: shown %s, overlays %d, objectives %d, group frame %s on %s, updated %s"):format(tostring(ZNS.Dungeon.IsShown()),
    Count(function(w) return w.kind == "Texture" and avOverlays[w.file] end), live and live.pois or -1,
    tostring(live and live.units), tostring(units and units.uiMapID), tostring(units and units.updates > 0)))
local listed = ZNS.Dungeon.Shown()
OUT("alterac bosses listed: " .. #listed)

-- a new objective's state: the map follows
table.insert(STATE.pois[1459], { id = 3, name = "Mina de Hierro Hondo", textureIndex = 5, x = 0.3, y = 0.5 })
EVENT("AREA_POIS_UPDATED")
OUT("alterac objectives after update: " .. ZNS.Dungeon.Live().pois)

-- Warsong Gulch: a flag carried, moving
ZNS.Map.Close()
STATE.instanceID, STATE.instanceName = 489, "Garganta Grito de Guerra"
STATE.flags, STATE.flagMap = { { x = 0.5, y = 0.1, texture = "Interface\\WorldStateFrame\\AllianceFlag" }, { x = nil } }, 1460
OPEN()
FRAMES(3)
live = ZNS.Dungeon.Live()
OUT(("warsong: overlays %d, objectives %d, flags %d, group frame on %s"):format(
    Count(function(w) return w.kind == "Texture" and avOverlays[w.file] end), live.pois, live.flags, tostring(UnitsFrame().uiMapID)))
STATE.flags[2].x, STATE.flags[2].y, STATE.flags[2].texture = 0.6, 0.8, "Interface\\WorldStateFrame\\HordeFlag"
FRAMES(4)
OUT("warsong flags after a pick up: " .. ZNS.Dungeon.Live().flags)

-- a dungeon after it: no live layer
ZNS.Map.Close()
STATE.instanceType, STATE.instanceID, STATE.instanceName = "party", 36, "Las Minas de la Muerte"
OPEN()
FRAMES(3)
OUT(("deadmines: live %s, group frame shown %s, flags shown %d"):format(tostring((ZNS.Dungeon.Live())), tostring(UnitsFrame():IsShown()),
    Count(function(w) return w.kind == "Texture" and tostring(w.file):match("Flag$") end)))
ZNS.Map.Close()
STATE.instance, STATE.instanceType = false, nil
OUT("errors " .. #STATE.errors)
