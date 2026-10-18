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
local zonesShown = 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "MaskTexture" and tostring(w.file):match("%d+c$") and w.parent:IsVisible() then zonesShown = zonesShown + 1 end
end
OUT(("world: world shown %s, zones shown %d"):format(tostring(ZmapFrame:IsVisible()), zonesShown))
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
        if not (zl * W < vr + mx and zr * W > vl - mx and zt * H < vb + my and zb * H > vt - my) then all = false end
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
OUT("ART goldshire", DUMP_ART())

local sl, sr, st, sb = ZNS.Geo.Rect(1453)
Settle((sl + sr) / 2 * W, (st + sb) / 2 * H, ZNS.Map.ZoomFor(1453, 1.2))
local city
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "MaskTexture" and tostring(w.file):match("city$") then city = w.parent end
end
OUT(("city: stormwind alpha %.2f shown %s"):format(city and city.alpha or -1, tostring(city and city:IsVisible())))
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
local caveTex = 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and w.shown and w.masks and w.masks[1] and tostring(w.masks[1].file):find("Caves", 1, true) then caveTex = caveTex + 1 end
end
OUT(("cave: inside %s, zoom %.0f, tiles %d"):format(tostring(cave), ZNS.Map.Zoom(), caveTex))
OUT("ART fargodeep", DUMP_ART())
local cu, cv = ZNS.Geo.FromYards(0, -9780, 160)
ZNS.Map.SetView(cu * W, cv * H, 6)
FRAMES(5)
local shownAfter = 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and w.masks and w.masks[1] and tostring(w.masks[1].file):find("Caves", 1, true) and w.parent.shown and w.parent.alpha > 0.01 then shownAfter = 1 end
end
OUT("cave zoomed out: shown " .. tostring(shownAfter == 1))
STATE.indoors, STATE.instance = false, true
OUT("errors " .. #STATE.errors)
