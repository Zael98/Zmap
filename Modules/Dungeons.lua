-- Dungeon and raid entrances, with the level Forever tunes each one to (coloured against yours). From the
-- client's tables (Data/Places.lua), plus any entrance the game's own map knows that they do not.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("dungeons", { level = 45, size = 24, option = "dungeons", minZoom = 1.3 })
local entrances   -- { u, v, name, level, raid, description }

local function LevelOf(name)
    local key = ns.Fold(name)
    local level = ns.DUNGEON_LEVELS[key]
    if level then return level end
    for k, v in pairs(ns.DUNGEON_LEVELS) do
        if k:find(key, 1, true) or key:find(k, 1, true) then return v end
    end
end

local function Collect()
    entrances = {}
    for _, d in ipairs(ns.DUNGEONS) do
        local u, v = Geo.FromYards(d[2], d[3], d[4])
        if u then
            local level = d[6] > 0 and d[6] or LevelOf(ns.Name(d[7]))
            entrances[#entrances + 1] = { u = u, v = v, name = ns.Name(d[7]), level = level, raid = d[5], inst = d[1] }
        end
    end
    -- the game's own list (Forever's new dungeons may only be there)
    if C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
        for _, mapID in ipairs(Geo.Zones()) do
            local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
            for _, e in ipairs(ok and list or {}) do
                if e.position then
                    local u, v = Geo.ToWorld(mapID, e.position.x, e.position.y)
                    local dup = false
                    for _, have in ipairs(entrances) do
                        if ns.Fold(have.name) == ns.Fold(e.name) or (math.abs(have.u - u) < 0.002 and math.abs(have.v - v) < 0.002) then
                            have.description = have.description or e.description
                            dup = true
                        end
                    end
                    if not dup then
                        entrances[#entrances + 1] = { u = u, v = v, name = e.name, level = LevelOf(e.name),
                            raid = e.atlasName and e.atlasName:lower():find("raid") ~= nil, description = e.description }
                    end
                end
            end
        end
    end
end

function P:Refresh()
    self:ReleaseAll()
    if not entrances then Collect() end
    for _, e in ipairs(entrances) do
        local pin = self:Acquire()
        pin.icon:SetAtlas(e.raid and "Raid" or "Dungeon")
        pin.entry = e
        self:Place(pin, e.u, e.v)
    end
end

function P:Tooltip(pin, tip)
    local e = pin.entry
    tip:SetText(e.name, 1, 1, 1)
    tip:AddLine(e.raid and L.RAID or L.DUNGEON, 0.7, 0.7, 0.7)
    if e.level then tip:AddLine(L.DUNGEON_LEVEL:format(ns.LevelText(e.level, e.level)), 1, 1, 1) end
    if e.description and e.description ~= "" then tip:AddLine(e.description, 1, 0.82, 0, true) end
    if e.inst and ns.Dungeon.Has(e.inst) then tip:AddLine(L.DUNGEON_MAP_HINT, 0.6, 0.6, 0.6) end
    tip:AddLine(L.CTRL_NAVIGATE, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "LeftButton" and IsControlKeyDown() then
        local mapID, x, y = Geo.ZoneAt(pin.entry.u, pin.entry.v)
        if mapID then ns.Waypoints.Add(mapID, x, y, pin.entry.name, { navigate = true, temp = true }) end
    elseif button == "LeftButton" and pin.entry.inst then
        ns.Dungeon.Open(pin.entry.inst, pin.entry.name)
    end
end

-- for the search
function ns.DungeonList()
    if not entrances then Collect() end
    return entrances
end

ns.On("PLAYER_LEVEL_UP", function() P:Update() end)
