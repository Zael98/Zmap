-- Where things are. The stitched map is Azeroth's map (947): a point on it is (u, v), each 0..1, and the
-- canvas draws it W x H "world units" big. Every zone has its rectangle on it (Data/Maps.lua, from the
-- client's own tables), so a zone's coordinates, the world's yards and the canvas all convert here.
local _, ns = ...
local Geo = {}
ns.Geo = Geo

local W, H = 1002, 668   -- Azeroth's map art, in pixels: the canvas's size in world units
Geo.W, Geo.H = W, H

local MAPS, TRANSFORM = ns.MAPS, ns.WORLD_TRANSFORM
local IsSecret = issecretvalue or function() return false end
local CONTINENTS = { 1415, 1414 }
local ADT = 533 + 1 / 3  -- the world's terrain tiles, in yards

function Geo.Info(mapID) return MAPS[mapID] end

function Geo.Kind(mapID)
    local d = MAPS[mapID]
    return d and d[1]
end

function Geo.Instance(mapID)
    local d = MAPS[mapID]
    return d and d[3]
end

-- l, r, t, b: the map's rectangle on Azeroth's map
function Geo.Rect(mapID)
    local d = MAPS[mapID]
    if not d then return end
    local rect = d[4]
    return rect[1], rect[2], rect[3], rect[4]
end

-- the zone's name in the client's language
function Geo.Name(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if info and info.name and info.name ~= "" then return info.name end
    local d = MAPS[mapID]
    return d and ns.Name(d[6]) or "?"
end

-- the zones and cities on the stitched map, in a fixed order
local stitched
function Geo.Zones()
    if not stitched then
        stitched = {}
        for id, d in pairs(MAPS) do
            if d[1] == "zone" or d[1] == "city" then stitched[#stitched + 1] = id end
        end
        table.sort(stitched)
    end
    return stitched
end

-- a zone's (x, y) -> (u, v)
function Geo.ToWorld(mapID, x, y)
    local l, r, t, b = Geo.Rect(mapID)
    if not l then return end
    return l + (r - l) * x, t + (b - t) * y
end

-- (u, v) -> that zone's (x, y)
function Geo.ToZone(mapID, u, v)
    local l, r, t, b = Geo.Rect(mapID)
    if not l then return end
    return (u - l) / (r - l), (v - t) / (b - t)
end

-- world yards (UnitPosition's x north, y west) on a continent -> (u, v)
function Geo.FromYards(instance, wx, wy)
    local T = TRANSFORM[instance]
    if not T or not wx then return end
    return T[1] + T[2] * wy, T[3] + T[4] * wx
end

-- (u, v) -> world yards on that continent
function Geo.ToYards(instance, u, v)
    local T = TRANSFORM[instance]
    if not T then return end
    return (v - T[3]) / T[4], (u - T[1]) / T[2]
end

-- yards between two points on the same continent
function Geo.Yards(instance, u1, v1, u2, v2)
    local T = TRANSFORM[instance]
    if not T then return end
    local dy, dx = (u2 - u1) / T[2], (v2 - v1) / T[4]
    return math.sqrt(dx * dx + dy * dy)
end

-- the size of a terrain tile on that continent, in (u, v), and the tile under a world point
function Geo.TileSize(instance)
    local T = TRANSFORM[instance]
    return -T[2] * ADT, -T[4] * ADT
end
Geo.ADT = ADT

local function Contains(mapID, u, v)
    local l, r, t, b = Geo.Rect(mapID)
    return l and u >= l and u <= r and v >= t and v <= b
end

-- a zone on an instance of its own (Zephras Isle), placed in a sea of Azeroth's map: the world is its parent
function Geo.IsIsle(mapID)
    local d = MAPS[mapID]
    return d ~= nil and d[1] == "zone" and d[2] == ns.WORLD
end

-- the continents and the isles: every map a position on the stitched map can be on
local lands
function Geo.Lands()
    if not lands then
        lands = { unpack(CONTINENTS) }
        for _, id in ipairs(Geo.Zones()) do
            if Geo.IsIsle(id) then lands[#lands + 1] = id end
        end
    end
    return lands
end

-- The zone under a point of the stitched map: mapID, x, y (its own coordinates). The client knows the
-- zones' true outlines; without it, the smallest zone whose rectangle holds the point.
function Geo.ZoneAt(u, v)
    if C_Map and C_Map.GetMapInfoAtPosition then
        for _, id in ipairs(Geo.Zones()) do
            if Geo.IsIsle(id) and Contains(id, u, v) then
                local x, y = Geo.ToZone(id, u, v)
                return id, x, y
            end
        end
        for _, cont in ipairs(CONTINENTS) do
            if Contains(cont, u, v) then
                local cu, cv = Geo.ToZone(cont, u, v)
                local info = C_Map.GetMapInfoAtPosition(cont, cu, cv)
                local id = info and info.mapID
                if id and id ~= cont and MAPS[id] then
                    local x, y = Geo.ToZone(id, u, v)
                    return id, x, y
                end
            end
        end
        return
    end
    local best, area
    for _, id in ipairs(Geo.Zones()) do
        if MAPS[id][1] == "zone" and Contains(id, u, v) then
            local l, r, t, b = Geo.Rect(id)
            local a = (r - l) * (b - t)
            if not area or a < area then best, area = id, a end
        end
    end
    if best then
        local x, y = Geo.ToZone(best, u, v)
        return best, x, y
    end
end

-- The map a unit is on that the stitched map knows (a city's district or a cave climbs to its zone).
local function KnownMapFor(unit)
    local mapID = C_Map.GetBestMapForUnit(unit)
    for _ = 1, 6 do
        if not mapID or mapID == 0 then return end
        local kind = Geo.Kind(mapID)
        if kind == "zone" or kind == "city" then return mapID end
        if kind then return end   -- the continent or the world itself: no zone position
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
    end
end

-- A unit's place: u, v, mapID, x, y; nothing in an instance or where the game hides it.
function Geo.UnitPosition(unit)
    local mapID = KnownMapFor(unit)
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, unit)
    if not pos then return end
    local x, y = pos.x, pos.y
    if not x or IsSecret(x) or IsSecret(y) or (x == 0 and y == 0) then return end
    local u, v = Geo.ToWorld(mapID, x, y)
    return u, v, mapID, x, y
end

-- The player in yards (for the arrow): x, y, instance
function Geo.PlayerYards()
    local x, y, _, instance = UnitPosition("player")
    if not x or IsSecret(x) or IsSecret(y) then return end
    return x, y, instance
end
