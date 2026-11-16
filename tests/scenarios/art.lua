-- The stitched art at each zoom: what is built, what is masked, where the tiles go, the terrain up close,
-- a city's own map, the unexplored areas. Also dumps each view for tools/preview.py.
START()
STATE.instance = true   -- (no position: the view does not follow the player around)
OPEN()
local W, H = ZNS.Geo.W, ZNS.Geo.H

local function Masks(suffix)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "MaskTexture" and tostring(w.file):match("%d+" .. suffix .. "$") then n = n + 1 end
    end
    return n
end

local function Settle(x, y, z)
    ZNS.Map.SetView(x, y, z)
    FRAMES(4)
end

Settle(W / 2, H / 2, 1)
local zonesShown, isleShown = 0, 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "MaskTexture" and tostring(w.file):match("%d+c$") and w.parent:IsVisible() then
        if tostring(w.file):match("2521c$") then isleShown = isleShown + 1 else zonesShown = zonesShown + 1 end
    end
end
OUT(("world: world shown %s, zones shown %d, isle shown %d"):format(tostring(ZmapFrame:IsVisible()), zonesShown, isleShown))
OUT("ART world", DUMP_ART())

local l, r, t, b = ZNS.Geo.Rect(1415)
Settle((l + r) / 2 * W, (t + b) / 2 * H, ZNS.Map.ZoomFor(1415, 1.6))
OUT("ART eastern", DUMP_ART())
-- the zones come in a little closer
local el, er, et, eb = ZNS.Geo.Rect(1433)
Settle((el + er) / 2 * W, (et + eb) / 2 * H, 4)
local vl, vt, vr, vb = ZNS.Map.ViewRect()
local all = true
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "MaskTexture" and tostring(w.file):match("(%d+)c$") then
        local id = tonumber(tostring(w.file):match("(%d+)c$"))
        local zl, zr, zt, zb = ZNS.Geo.Rect(id)
        local mx, my = (vr - vl) * 0.25, (vb - vt) * 0.25
        if not ZNS.Geo.IsIsle(id) and not (zl * W < vr + mx and zr * W > vl - mx and zt * H < vb + my and zb * H > vt - my) then all = false end
    end
end
OUT(("continent: zones built %d, all of them in view %s"):format(Masks("c"), tostring(all)))
OUT("ART region", DUMP_ART())

ZNS.Map.SetView(0, 0, 1)
local ll, rr, tt, bb = ZNS.Geo.Rect(1429)
Settle((ll + rr) / 2 * W, (tt + bb) / 2 * H, ZNS.Map.ZoomFor(1429, 1.3))
local masked = true
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and w.layer == "BORDER" and not w.masks then masked = false end
end
OUT(("zone: halo masks %d core masks %d, every tile masked %s"):format(Masks("h"), Masks("c"), tostring(masked)))
OUT("ART elwynn", DUMP_ART())

-- every zone tile lies within its zone's rectangle
local inside = true
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and w.layer == "BORDER" and w.masks then
        local m = w.masks[1]
        local mp, p = m.points.TOPLEFT, w.points.TOPLEFT
        if p.x < mp.x - 1e-6 or -p.y < -mp.y - 1e-6 or p.x + w.w > mp.x + m.w + 1e-6 or -p.y + w.h > -mp.y + m.h + 1e-6 then
            inside = false
        end
    end
end
OUT("tiles inside rects: " .. tostring(inside))

local u, v = ZNS.Geo.ToWorld(1429, 0.42, 0.66)
Settle(u * W, v * H, 30)
local terrain, alpha = 0, 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and type(w.file) == "number" and w:IsVisible() and w.w and w.h and math.abs(w.w - w.h * (W / H) * 0) >= 0 and w.parent and w.parent._level == ZNS.Map.Canvas()._level + 8 then
        terrain = terrain + 1
        alpha = w.parent.alpha
    end
end
OUT(("close: terrain tiles %d, alpha %.2f"):format(terrain, alpha))
local function TerrainTiles(test)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and type(w.file) == "number" and w.parent and w.parent._level == ZNS.Map.Canvas()._level + 8
            and w.parent.shown and test(w) then n = n + 1 end
    end
    return n
end
STATE.explored = "never"
ZNS.SetOpt("unexplored", "hide")
EVENT("MAP_EXPLORATION_UPDATED")
local terrainShown = TerrainTiles(function(w) return w.shown end)
ZNS.SetOpt("unexplored", "dim")
local terrainDim = TerrainTiles(function(w) return w.shown and w.desat and w.desat > 0 end)
ZNS.SetOpt("unexplored", "show")
OUT(("terrain never visited: hide %d shown, dim %d dimmed, show %d shown"):format(terrainShown, terrainDim,
    TerrainTiles(function(w) return w.shown and not (w.desat and w.desat > 0) end)))
ZNS.SetOpt("unexplored", "dim")
STATE.explored = nil
EVENT("MAP_EXPLORATION_UPDATED")
OUT("ART goldshire", DUMP_ART())

local sl, sr, st, sb = ZNS.Geo.Rect(1453)
Settle((sl + sr) / 2 * W, (st + sb) / 2 * H, ZNS.Map.ZoomFor(1453, 1.2))
local city
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "MaskTexture" and tostring(w.file):match("city$") then city = w.parent end
end
OUT(("city: stormwind alpha %.2f shown %s"):format(city and city.alpha or -1, tostring(city and city:IsVisible())))
local function CityTiles(test)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and w.parent == city and type(w.file) == "number" and test(w) then n = n + 1 end
    end
    return n
end
STATE.explored = "never"
ZNS.SetOpt("unexplored", "hide")
local clientCity = C_Map.GetMapInfoAtPosition
C_Map.GetMapInfoAtPosition = function() return { mapID = 1453 } end   -- (the city itself, as in Forever)
EVENT("MAP_EXPLORATION_UPDATED")
local cityHidden = CityTiles(function(w) return not w.shown end)
local ol, orr, ot, ob = ZNS.Geo.Rect(1454)
local nu, nv = (ol + orr) / 2, ot + (ob - ot) * 0.05   -- (near the city's top: above Durotar's rectangle)
C_Map.GetMapInfoAtPosition = function() return { mapID = 1454 } end
-- (the zone next to it explored, Durotar not: your case on an Alliance character)
local other = ZNS.Geo.ZoneByRect(nu, nv)
local textures = C_MapExplorationInfo.GetExploredMapTextures
C_MapExplorationInfo.GetExploredMapTextures = function(m)
    if m ~= other then return {} end
    local out = {}
    for _, o in ipairs(ZNS.MAPS[m][7] or {}) do out[#out + 1] = { fileDataIDs = { o[6] } } end
    return out
end
EVENT("MAP_EXPLORATION_UPDATED")
OUT(("inside a capital: by its zone's rectangle %s, as the city %s"):format(tostring(other),
    tostring((ZNS.Art.Exploration(nu, nv)))))
C_MapExplorationInfo.GetExploredMapTextures = textures
EVENT("MAP_EXPLORATION_UPDATED")
C_Map.GetMapInfoAtPosition = clientCity
STATE.explored = "all"
EVENT("MAP_EXPLORATION_UPDATED")
OUT(("city never visited: hidden %d; explored: shown %d, hidden %d"):format(cityHidden,
    CityTiles(function(w) return w.shown end), CityTiles(function(w) return not w.shown end)))
STATE.explored = nil
ZNS.SetOpt("unexplored", "dim")
EVENT("MAP_EXPLORATION_UPDATED")
OUT("ART stormwind", DUMP_ART())

local function Overlays(test)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and w.layer == "ARTWORK" and w.parent and w.parent.parent and w.parent.parent._level == ZNS.Map.Canvas()._level + 3 and test(w) then n = n + 1 end
    end
    return n
end
ZNS.SetOpt("unexplored", "hide")
OUT("unexplored hide: hidden " .. Overlays(function(w) return not w.shown end))
STATE.explored = "never"
EVENT("MAP_EXPLORATION_UPDATED")
OUT(("never visited: hidden %d, shown %d"):format(Overlays(function(w) return not w.shown end),
    Overlays(function(w) return w.shown end)))
-- the zones' base (parchment and mountains): hidden too in a zone never visited, shown in one explored in part
local function Bases(test)
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and w.layer == "BORDER" and w.parent and w.parent.parent
            and w.parent.parent._level == ZNS.Map.Canvas()._level + 3 and test(w) then n = n + 1 end
    end
    return n
end
local basesNever = Bases(function(w) return w.shown end)
STATE.explored = nil
EVENT("MAP_EXPLORATION_UPDATED")
OUT(("zone base: never visited shown %d, explored in part shown %d"):format(basesNever, Bases(function(w) return w.shown end)))
STATE.explored = "never"
EVENT("MAP_EXPLORATION_UPDATED")
STATE.explored = nil
EVENT("MAP_EXPLORATION_UPDATED")
-- Searing Gorge never visited, at a spot where the client names no zone (outside the outline it uses for clicks):
-- still unexplored, by the zone's rectangle (before: no data, so its terrain stayed)
STATE.explored = "never"
EVENT("MAP_EXPLORATION_UPDATED")
local gu, gv = ZNS.Geo.ToWorld(1427, 0.8, 0.3)
local clientAt = C_Map.GetMapInfoAtPosition
C_Map.GetMapInfoAtPosition = function() return nil end
OUT(("no zone from the client: %s, by rectangle %s"):format(tostring((ZNS.Geo.ZoneAt(gu, gv))),
    tostring((ZNS.Art.Exploration(gu, gv)))))
C_Map.GetMapInfoAtPosition = clientAt
-- every area of the zone explored by its rectangle, but the game's exact answer at the spot is nothing explored:
-- unseen (the rectangles reach well past an area's land); where the game says explored: seen
STATE.explored = "all"
EVENT("MAP_EXPLORATION_UPDATED")
local exactSeen = false
C_MapExplorationInfo.GetExploredAreaIDsAtPosition = function() return exactSeen and { 1 } or nil end
local made = 0
CreateVector2D = function(x, y)
    made = made + 1
    return { x = x, y = y, SetXY = function(self, a, b) self.x, self.y = a, b end }
end
local outside = ZNS.Art.Exploration(gu, gv)
exactSeen = true
EVENT("MAP_EXPLORATION_UPDATED")
local inside = ZNS.Art.Exploration(gu, gv)
for _ = 1, 50 do ZNS.Art.Exploration(gu, gv) end
OUT(("exact exploration: outside the area's land %s, inside %s, positions made %d"):format(tostring(outside),
    tostring(inside), made))
C_MapExplorationInfo.GetExploredAreaIDsAtPosition = nil
STATE.explored = nil
EVENT("MAP_EXPLORATION_UPDATED")
ZNS.SetOpt("unexplored", "show")
OUT("unexplored show: dimmed " .. Overlays(function(w) return w.shown and w.desat and w.desat > 0 end))
ZNS.SetOpt("unexplored", "dim")

-- more views to look at
local kl, kr, kt, kb = ZNS.Geo.Rect(1414)
Settle((kl + kr) / 2 * W, (kt + kb) / 2 * H, ZNS.Map.ZoomFor(1414, 1.6))
OUT("ART kalimdor", DUMP_ART())
local gl, gr, gt, gb = ZNS.Geo.Rect(2548)
Settle((gl + gr) / 2 * W, (gt + gb) / 2 * H, ZNS.Map.ZoomFor(2548, 0.6))
OUT("ART riverglades", DUMP_ART())
local bl, br, bt, bb = ZNS.Geo.Rect(1413)
Settle((bl + br) / 2 * W, (bt + bb) / 2 * H, 4.2)
OUT("ART barrens", DUMP_ART())
-- a cave: inside Fargodeep Mine the map opens on it, surfaced; zoomed out, it sinks
ZNS.Map.Close()
STATE.instance = false
STATE.player.inst, STATE.player.wx, STATE.player.wy = 0, -9780, 160
STATE.indoors = true
OPEN()
FRAMES(5)
local cave = ZNS.Art.CaveAt(ZNS.Geo.FromYards(0, -9780, 160))
local caveFiles = {}
for _, f in ipairs(ZNS.CAVES[38][7]) do caveFiles[f] = true end
local function CaveShown()
    local n = 0
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and caveFiles[w.file] and w.shown and w.parent.shown and w.parent.alpha > 0.01 then n = n + 1 end
    end
    return n
end
local caveTex = CaveShown()
OUT(("cave: inside %s, zoom %.0f, tiles %d"):format(tostring(cave), ZNS.Map.Zoom(), caveTex))
OUT("ART fargodeep", DUMP_ART())
-- its lower mines: a button each, the other floor shown on a click
local floorButtons = ZNS.CaveButtons()
local labels = {}
for _, b in ipairs(floorButtons) do labels[#labels + 1] = b:GetText() end
floorButtons[2].scripts.OnClick(floorButtons[2])
FRAMES(3)
local lower = {}
for _, f in ipairs(ZNS.CAVES[39][7]) do lower[f] = true end
local lowerShown, upperShown = 0, CaveShown()
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and lower[w.file] and w.shown and w.parent.shown and w.parent.alpha > 0.01 then lowerShown = lowerShown + 1 end
end
OUT(("cave floors: %s; lower shown %d, first hidden %s"):format(table.concat(labels, ", "), lowerShown, tostring(upperShown == 0)))
ZNS.Art.SetCaveFloor(38, 38)
local cu, cv = ZNS.Geo.FromYards(0, -9780, 160)
ZNS.Map.SetView(cu * W, cv * H, 6)
FRAMES(5)
OUT("cave zoomed out: shown " .. tostring(CaveShown() > 0))
STATE.indoors, STATE.instance = false, true
OUT("errors " .. #STATE.errors)
