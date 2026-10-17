-- The stitched map art, all of it the game's own textures (loaded by file ID), on the canvas in world units.
-- Bottom to top, and the zoom (1 = Azeroth's map filling the window) where each comes in:
--   world      Azeroth's map; muted once the continents are in (~2), it stays under everything
--   continents each continent's map, frame faded off, as Blizzard's continent map; muted once the zones
--              are in (~3.5), so its big lettering does not show through the gaps
--   zones      every zone's own map: its base art twice, through a wide soft "halo" mask (its mountains and
--              coasts, under every zone's land) and a tight "core" mask (its land), then its exploration
--              overlays on top, through the core mask too (Media/Masks: tools/build_data.py cuts them from
--              the overlays; where two zones' rectangles share land, their cores cross-fade)
--   terrain    the minimap's tiles, the real ground from above, when zoomed in close
--   cities     each capital's own map, faded round, once it is big enough on screen to read
-- Zones and cities are built the first time they come into view, and hidden out of it.
local _, ns = ...
local Geo = ns.Geo
local Art = {}
ns.Art = Art

local W, H = Geo.W, Geo.H
local ART_W, ART_H, TILE = 1002, 668, 256
local MASKS = ns.MEDIA .. "Masks\\"
local MAX_TILES = 90            -- minimap tiles at once (more means we are too far out for them anyway)
local DIM = { 0.78, 0.76, 0.72 } -- unexplored overlays, when dimmed (with some of their colour taken out)
local DIM_DESAT = 0.35
local SEAM = 1 + 1 / 256         -- terrain tiles overlap by a hair, so no seam shows between them

local worldFrame, contFrame, zoneRoot, terrainRoot, cityRoot
local zones, cities = {}, {}
local terrain, terrainPool = {}, {}   -- [tile key] = texture in use; spare textures

local function Smooth(a, b, x)
    local t = math.max(0, math.min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
end
Art.Smooth = Smooth

local function Layer(parent, level)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel(level)
    return f
end

-- A map's art: 1002 x 668 pixels in 256 px tiles, row by row, over its rectangle. The last column and
-- row are cut to the art's edge (their files run past it).
local function Tiles(parent, mapID, layer, sublevel, mask)
    local l, r, t, b = Geo.Rect(mapID)
    local sx, sy = (r - l) * W / ART_W, (b - t) * H / ART_H
    local ox, oy = l * W, t * H
    local list = {}
    for i, fileID in ipairs(ns.MAPS[mapID][5]) do
        local row, col = math.floor((i - 1) / 4), (i - 1) % 4
        local x0, y0 = col * TILE, row * TILE
        local w, h = math.min(TILE, ART_W - x0), math.min(TILE, ART_H - y0)
        if w > 0 and h > 0 then
            local tex = parent:CreateTexture(nil, layer, nil, sublevel)
            tex:SetTexture(fileID, nil, nil, "TRILINEAR")
            tex:SetTexCoord(0, w / TILE, 0, h / TILE)
            tex:SetSize(w * sx, h * sy)
            tex:SetPoint("TOPLEFT", parent, "TOPLEFT", ox + x0 * sx, -(oy + y0 * sy))
            if tex.SetSnapToPixelGrid then
                tex:SetSnapToPixelGrid(false)
                tex:SetTexelSnappingBias(0)
            end
            if mask then tex:AddMaskTexture(mask) end
            list[#list + 1] = tex
        end
    end
    return list
end

-- A mask stretched over a map's rectangle.
local function Mask(parent, mapID, file)
    local l, r, t, b = Geo.Rect(mapID)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASKS .. file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize((r - l) * W, (b - t) * H)
    mask:SetPoint("TOPLEFT", parent, "TOPLEFT", l * W, -t * H)
    return mask
end

-- The power of two a texture file is padded to (the exploration overlays' last tiles: 16 px at least).
local function FileSize(px)
    local s = 16
    while s < px do s = s * 2 end
    return s
end

-- A zone's exploration overlays, tiled as Blizzard's map tiles them; through the zone's core mask too, so
-- they fade at its frame and cross-fade with a neighbour's where both paint the same strip of land.
local function Overlays(parent, mapID, mask)
    local l, r, t, b = Geo.Rect(mapID)
    local sx, sy = (r - l) * W / ART_W, (b - t) * H / ART_H
    local ox, oy = l * W, t * H
    local out = {}
    for _, o in ipairs(ns.MAPS[mapID][7] or {}) do
        local ow, oh, x, y = o[1], o[2], o[3], o[4]
        local cols, rows = math.ceil(ow / TILE), math.ceil(oh / TILE)
        local entry = { first = o[6], areas = o[5], tex = {}, x = x, y = y, w = ow, h = oh }
        for j = 1, rows do
            local ph = j < rows and TILE or (oh - TILE * (rows - 1))
            local fh = j < rows and TILE or FileSize(ph)
            for k = 1, cols do
                local pw = k < cols and TILE or (ow - TILE * (cols - 1))
                local fw = k < cols and TILE or FileSize(pw)
                local fileID = o[5 + (j - 1) * cols + k]
                if fileID then
                    local tex = parent:CreateTexture(nil, "ARTWORK", nil, 1)
                    tex:SetTexture(fileID, nil, nil, "TRILINEAR")
                    tex:SetTexCoord(0, pw / fw, 0, ph / fh)
                    tex:SetSize(pw * sx, ph * sy)
                    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", ox + (x + TILE * (k - 1)) * sx, -(oy + (y + TILE * (j - 1)) * sy))
                    if mask then tex:AddMaskTexture(mask) end
                    entry.tex[#entry.tex + 1] = tex
                end
            end
        end
        out[#out + 1] = entry
    end
    return out
end

-- the zone's tint towards the zones' common colour (Data/Maps.lua's TINTS), with the option on
local WHITE = { 1, 1, 1 }
function Art.Tint(mapID)
    return ns.Opt("harmonize") and ns.TINTS and ns.TINTS[mapID] or WHITE
end

--------------------------------------------------------------------------------------------------------------
-- Exploration: overlays you have explored are drawn as they are; the rest shown, dimmed or hidden
--------------------------------------------------------------------------------------------------------------

function Art.ApplyExplored(mapID)
    local z = zones[mapID]
    if not z then return end
    local explored
    local info = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures(mapID)
    if info then
        explored = {}
        for _, e in ipairs(info) do
            if e.fileDataIDs and e.fileDataIDs[1] then explored[e.fileDataIDs[1]] = true end
        end
    end
    local mode = ns.Opt("unexplored")
    local t = Art.Tint(mapID)
    for _, tex in ipairs(z.base) do tex:SetVertexColor(t[1], t[2], t[3]) end
    for _, o in ipairs(z.overlays) do
        local seen = not explored or explored[o.first] == true
        o.explored = seen
        for _, tex in ipairs(o.tex) do
            if seen or mode == "show" then
                tex:SetVertexColor(t[1], t[2], t[3])
                if tex.SetDesaturation then tex:SetDesaturation(0) end
                tex:SetDrawLayer("ARTWORK", seen and 1 or 0)
                tex:Show()
            elseif mode == "dim" then
                tex:SetVertexColor(DIM[1] * t[1], DIM[2] * t[2], DIM[3] * t[3])
                if tex.SetDesaturation then tex:SetDesaturation(DIM_DESAT) end
                tex:SetDrawLayer("ARTWORK", 0)
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------------------------------------

local function BuildZone(mapID)
    local base = zoneRoot:GetFrameLevel()
    local z = {}
    z.halo = Layer(zoneRoot, base + 1)
    z.core = Layer(zoneRoot, base + 2)
    z.over = Layer(zoneRoot, base + 3)
    z.base = Tiles(z.halo, mapID, "BORDER", 0, Mask(z.halo, mapID, mapID .. "h"))
    for _, tex in ipairs(Tiles(z.core, mapID, "BORDER", 0, Mask(z.core, mapID, mapID .. "c"))) do z.base[#z.base + 1] = tex end
    z.overlays = Overlays(z.over, mapID, Mask(z.over, mapID, mapID .. "c"))
    zones[mapID] = z
    Art.ApplyExplored(mapID)
    return z
end

local function BuildCity(mapID)
    local f = Layer(cityRoot, cityRoot:GetFrameLevel() + 1)
    Tiles(f, mapID, "ARTWORK", 0, Mask(f, mapID, "city"))
    cities[mapID] = f
    return f
end

function Art.Init(canvas)
    local base = canvas:GetFrameLevel()
    worldFrame = Layer(canvas, base + 1)
    contFrame = Layer(canvas, base + 2)
    zoneRoot = Layer(canvas, base + 3)          -- its zones' halos, cores and overlays: + 1, + 2, + 3
    terrainRoot = Layer(canvas, base + 8)
    cityRoot = Layer(canvas, base + 9)          -- its cities: + 1
    Tiles(worldFrame, ns.WORLD, "BACKGROUND", 0)
    for id, d in pairs(ns.MAPS) do
        if d[1] == "continent" then
            Tiles(contFrame, id, "BACKGROUND", 0, Mask(contFrame, id, "frame"))
        end
    end
    Art.levelTop = base + 11                    -- above the art: lines and pins
end

--------------------------------------------------------------------------------------------------------------
-- Following the view
--------------------------------------------------------------------------------------------------------------

local function Overlaps(mapID, left, top, right, bottom)
    local l, r, t, b = Geo.Rect(mapID)
    return l * W < right and r * W > left and t * H < bottom and b * H > top
end

local function UpdateTerrain(left, top, right, bottom, alpha)
    local wanted = {}
    if alpha > 0.01 then
        local count = 0
        for instance in pairs(ns.WORLD_TRANSFORM) do
            local tiles = ns.MINIMAP[instance]
            if tiles then
                local wxa, wya = Geo.ToYards(instance, left / W, top / H)
                local wxb, wyb = Geo.ToYards(instance, right / W, bottom / H)
                local adt = Geo.ADT
                local tx0 = math.max(0, math.floor(32 - math.max(wya, wyb) / adt))
                local tx1 = math.min(63, math.floor(32 - math.min(wya, wyb) / adt))
                local ty0 = math.max(0, math.floor(32 - math.max(wxa, wxb) / adt))
                local ty1 = math.min(63, math.floor(32 - math.min(wxa, wxb) / adt))
                if (tx1 - tx0 + 1) * (ty1 - ty0 + 1) <= MAX_TILES then
                    local du, dv = Geo.TileSize(instance)
                    for ty = ty0, ty1 do
                        for tx = tx0, tx1 do
                            local fileID = tiles[ty * 64 + tx]
                            if fileID and count < MAX_TILES then
                                count = count + 1
                                local u, v = Geo.FromYards(instance, (32 - ty) * adt, (32 - tx) * adt)
                                wanted[instance * 4096 + ty * 64 + tx] = { u, v, du, dv, fileID }
                            end
                        end
                    end
                end
            end
        end
    end
    for key, tex in pairs(terrain) do
        if not wanted[key] then
            tex:Hide()
            terrain[key] = nil
            terrainPool[#terrainPool + 1] = tex
        end
    end
    for key, p in pairs(wanted) do
        if not terrain[key] then
            local tex = table.remove(terrainPool) or terrainRoot:CreateTexture(nil, "ARTWORK")
            tex:SetTexture(p[5], nil, nil, "TRILINEAR")
            tex:SetSize(p[3] * W * SEAM, p[4] * H * SEAM)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", terrainRoot, "TOPLEFT", p[1] * W, -p[2] * H)
            tex:Show()
            terrain[key] = tex
        end
    end
    terrainRoot:SetAlpha(alpha)
    terrainRoot:SetShown(alpha > 0.01)
end

-- for /zmap diag: zones and cities built, terrain tiles in use
function Art.Stats()
    local z, c, t = 0, 0, 0
    for _ in pairs(zones) do z = z + 1 end
    for _ in pairs(cities) do c = c + 1 end
    for _ in pairs(terrain) do t = t + 1 end
    return z, c, t
end

function Art.Update()
    if not worldFrame then return end
    local left, top, right, bottom = ns.Map.ViewRect()
    local z, k = ns.Map.Zoom(), ns.Map.K()
    -- a margin around the view, so panning finds the next zone already there
    local mx, my = (right - left) * 0.25, (bottom - top) * 0.25
    left, top, right, bottom = left - mx, top - my, right + mx, bottom + my

    -- the world's map until the continents' are in; the continent's as Blizzard's continent map until the
    -- zones come in, then muted (its lettering would show through the gaps)
    local worldA = 1 - 0.65 * Smooth(1.5, 2.3, z)   -- (it stays under everything, muted: nowhere is left empty)
    local contA = Smooth(1.1, 1.6, z) * (1 - 0.75 * Smooth(2.8, 3.8, z))
    local zoneA = Smooth(2.6, 3.6, z)
    worldFrame:SetAlpha(worldA)
    contFrame:SetAlpha(contA)
    contFrame:SetShown(contA > 0.01)
    zoneRoot:SetAlpha(zoneA)
    zoneRoot:SetShown(zoneA > 0.01)
    if zoneA > 0.01 then
        for id, d in pairs(ns.MAPS) do
            if d[1] == "zone" then
                local seen = Overlaps(id, left, top, right, bottom)
                local zz = zones[id]
                if seen and not zz then zz = BuildZone(id) end
                if zz then
                    zz.halo:SetShown(seen)
                    zz.core:SetShown(seen)
                    zz.over:SetShown(seen)
                end
            end
        end
    end
    -- cities: once their own map is a few hundred pixels across on screen
    for id, d in pairs(ns.MAPS) do
        if d[1] == "city" then
            local l, r = Geo.Rect(id)
            local a = Smooth(260, 480, (r - l) * W * k) * zoneA
            local seen = a > 0.01 and Overlaps(id, left, top, right, bottom)
            local f = cities[id]
            if seen and not f then f = BuildCity(id) end
            if f then
                f:SetAlpha(a)
                f:SetShown(seen)
            end
        end
    end
    local terrainA = ns.Opt("minimap") and Smooth(11, 18, z) or 0
    UpdateTerrain(left, top, right, bottom, terrainA)
end

-- the zoom at which the minimap's terrain is fully in (for the options' text)
Art.TERRAIN_ZOOM = 18

ns.On("ZMAP_VIEW", Art.Update)

ns.On("MAP_EXPLORATION_UPDATED", function()
    for id in pairs(zones) do Art.ApplyExplored(id) end
end)

ns.On("ZMAP_OPTION", function(key)
    if key == "unexplored" or key == "harmonize" then
        for id in pairs(zones) do Art.ApplyExplored(id) end
    elseif key == "minimap" and ns.Map.IsShown() then
        Art.Update()
    end
end)

ns.On("ZMAP_SHOW", function()
    -- exploration may have changed while the map was closed
    for id in pairs(zones) do Art.ApplyExplored(id) end
end)
