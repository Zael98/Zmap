-- Zone names on the map, with their level range coloured by how it compares to yours.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

-- Levels: the client's (C_Map.GetMapLevels) when it has them, else the original game's ranges
-- (warcraft.wiki.gg "Zones by level (original)"); Forever's own zones only have the client's.
local CLASSIC = {
    [1416] = { 30, 40 }, [1417] = { 30, 40 }, [1418] = { 35, 45 }, [1419] = { 45, 55 }, [1420] = { 1, 10 },
    [1421] = { 10, 20 }, [1422] = { 51, 58 }, [1423] = { 53, 60 }, [1424] = { 20, 30 }, [1425] = { 40, 50 },
    [1426] = { 1, 10 }, [1427] = { 43, 50 }, [1428] = { 50, 58 }, [1429] = { 1, 10 }, [1430] = { 55, 60 },
    [1431] = { 18, 30 }, [1432] = { 10, 20 }, [1433] = { 15, 25 }, [1434] = { 30, 45 }, [1435] = { 35, 45 },
    [1436] = { 10, 20 }, [1437] = { 20, 30 }, [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1413] = { 10, 25 },
    [1438] = { 1, 10 }, [1439] = { 10, 20 }, [1440] = { 18, 30 }, [1441] = { 25, 35 }, [1442] = { 15, 27 },
    [1443] = { 30, 40 }, [1444] = { 40, 50 }, [1445] = { 35, 45 }, [1446] = { 40, 50 }, [1447] = { 45, 55 },
    [1448] = { 48, 55 }, [1449] = { 48, 55 }, [1450] = { 55, 60 }, [1451] = { 55, 60 }, [1452] = { 55, 60 },
}

function ns.ZoneLevels(mapID)
    if C_Map.GetMapLevels then
        local lo, hi = C_Map.GetMapLevels(mapID)
        if lo and hi and lo > 0 and hi > 0 then return lo, hi end
    end
    local c = CLASSIC[mapID]
    if c then return c[1], c[2] end
end

-- a level's colour against yours: grey (too low) green yellow orange red
function ns.LevelColor(level)
    local mine = UnitLevel("player") or 1
    local d = level - mine
    if d >= 5 then return 1, 0.1, 0.1 end
    if d >= 3 then return 1, 0.5, 0.25 end
    if d >= -2 then return 1, 0.82, 0 end
    if d >= -8 then return 0.25, 0.75, 0.25 end
    return 0.6, 0.6, 0.6
end

function ns.LevelText(lo, hi)
    if not lo then return "" end
    local r, g, b = ns.LevelColor(lo)
    local text = lo == hi and tostring(lo) or (lo .. "-" .. hi)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

local P = ns.Pins.New("labels", { level = 5, size = 4, option = "labels", minZoom = 1.5, maxZoom = 14, mouse = false })

function P:OnCreate(pin)
    pin.title = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pin.title:SetPoint("CENTER", 0, 4)
    pin.title:SetShadowOffset(1, -1)
    pin.levels = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.levels:SetPoint("TOP", pin.title, "BOTTOM", 0, -1)
    pin.levels:SetShadowOffset(1, -1)
end

function P:Refresh()
    self:ReleaseAll()
    local z = ns.Map.Zoom()
    local showLevels = ns.Opt("levels")
    for _, id in ipairs(Geo.Zones()) do
        local kind = Geo.Kind(id)
        -- cities get their name once they are big enough to find; zones until their map is close up
        local spot = ns.LABELS[id] or { 0.5, 0.5 }
        if kind == "zone" or (kind == "city" and z >= 4) then
            local pin = self:Acquire()
            local u, v = Geo.ToWorld(id, spot[1], spot[2])
            pin.title:SetText(Geo.Name(id))
            pin.title:SetTextColor(1, 0.86, 0.52)
            local lo, hi = ns.ZoneLevels(id)
            pin.levels:SetText(showLevels and lo and ns.LevelText(lo, hi) or "")
            -- a little larger as you zoom in, fainter once the zone's own lettering takes over
            pin.title:SetAlpha(1 - ns.Art.Smooth(8, 14, z))
            pin.levels:SetAlpha(1 - ns.Art.Smooth(8, 14, z))
            self:Place(pin, u, v, kind == "city" and 0.9 or (0.9 + 0.25 * ns.Art.Smooth(2, 6, z)))
        end
    end
end
P.zoomRefresh = true

ns.On("PLAYER_LEVEL_UP", function() P:Update() end)
ns.On("ZMAP_OPTION", function(key) if key == "levels" then P:Update() end end)
