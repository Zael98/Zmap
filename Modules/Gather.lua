-- Herbs and ore: every herb and vein of the data (Data/Objects.lua) for the professions you have, from the
-- start; and every node you gather is remembered where it was (and sent to your guild's Zmap users), so what
-- the data lacks (Forever's changes) is learned too.
local _, ns = ...
local L, Geo, Comm = ns.L, ns.Geo, ns.Comm

local SPELLS = { [2366] = "herb", [2575] = "ore" }   -- Herb Gathering, Mining (every rank has the same name)
local ICONS = { herb = "Interface\\Icons\\INV_Misc_Herb_01", ore = "Interface\\Icons\\INV_Ore_Copper_01" }
local OPTION = { herb = "herbs", ore = "ore" }
local SAME = 0.008       -- two finds of the same name this close (share of the zone) are one node
local MAX_PINS = 600

local P = ns.Pins.New("gather", { level = 30, size = 16, minZoom = 3, cull = true })

function P:Shown()
    return (ns.Opt("herbs") or ns.Opt("ore")) and ns.Map.Zoom() >= self.minZoom
end

function P:OnCreate(pin)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- a find: kind, its name, where (by default where you stand), who found it (nil: you). True if it is new.
local function Record(kind, name, mapID, x, y, by)
    if not mapID then
        local _
        _, _, mapID, x, y = Geo.UnitPosition("player")
    end
    if not mapID or not Geo.Kind(mapID) then return false end
    local list = ns.db.nodes[mapID]
    if not list then
        list = {}
        ns.db.nodes[mapID] = list
    end
    for _, n in ipairs(list) do
        if n.name == name and math.abs(n.x - x) < SAME and math.abs(n.y - y) < SAME then
            if not by then n.n = (n.n or 0) + 1 end
            n.t = time()
            P:Update()
            return false
        end
    end
    list[#list + 1] = { x = x, y = y, kind = kind, name = name, n = by and 0 or 1, t = time(), by = by }
    P:Update()
    return true, mapID, x, y
end

local gathering = {}   -- spell name (client language) -> kind
local pending          -- { kind, target, guid }

local function Learn()
    for id, kind in pairs(SPELLS) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if name then gathering[name] = kind end
    end
end

ns.On("PLAYER_LOGIN", Learn)

ns.On("UNIT_SPELLCAST_SENT", function(unit, target, guid, spellID)
    if unit ~= "player" then return end
    if issecretvalue and (issecretvalue(target) or issecretvalue(spellID)) then return end
    local name = C_Spell.GetSpellName(spellID)
    local kind = name and gathering[name]
    if kind and target and target ~= "" then
        pending = { kind = kind, target = target, guid = guid }
    end
end)

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, guid)
    if unit ~= "player" or not pending then return end
    if issecretvalue and issecretvalue(guid) then return end
    if pending.guid ~= guid then return end
    local p = pending
    pending = nil
    local new, mapID, x, y = Record(p.kind, p.target)
    if new and ns.Opt("shareFinds") and not IsInInstance() then
        Comm.Send("N", "GUILD", nil, p.kind, mapID, ("%.4f"):format(x), ("%.4f"):format(y), p.target)
    end
end)

Comm.On("N", function(sender, channel, kind, m, x, y, name)
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if channel ~= "GUILD" or not ICONS[kind] or not (m and x and y) or not name or name == "" then return end
    Record(kind, name, m, x, y, Ambiguate(sender, "short"))
end)

--------------------------------------------------------------------------------------------------------------
-- Every herb and vein of the data (Data/Objects.lua), from the start: those of the professions you have
-- (all of them with the option), the ones your skill does not reach yet greyed
--------------------------------------------------------------------------------------------------------------

local PROFESSION = { herb = 182, ore = 186 }   -- skill lines: Herbalism, Mining
local byZone   -- [uiMapID] = { { u, v, x, y, object, kind, skill, item }, ... }

local function DataNodes()
    if byZone then return byZone end
    byZone = {}
    for id, o in pairs(ns.OBJECTS or {}) do
        if o[2] == "herb" or o[2] == "ore" then
            for _, s in ipairs(ns.Npcs.ObjectSpawns(id)) do
                local u, v = Geo.ToWorld(s[1], s[2], s[3])
                local list = byZone[s[1]] or {}
                byZone[s[1]] = list
                list[#list + 1] = { m = s[1], u = u, v = v, x = s[2], y = s[3], object = id, kind = o[2], skill = o[4], item = o[3] }
            end
        end
    end
    return byZone
end

-- your skill in Herbalism / Mining (nil: you do not have it)
local skills, skillsAt = {}, 0
local function Skill(kind)
    if GetTime() - skillsAt > 5 then
        skillsAt = GetTime()
        wipe(skills)
        if GetProfessions and GetProfessionInfo then
            for _, index in ipairs({ GetProfessions() }) do
                local _, _, level, _, _, _, line = GetProfessionInfo(index)
                if line then skills[line] = level end
            end
        end
    end
    return skills[PROFESSION[kind]]
end
ns.GatherSkill = Skill

-- the item a node gives, by its name in your language when the game has it
local function ItemName(item, fallback)
    local name = item and item > 0 and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
    if not name and item and item > 0 and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
    return name or fallback
end
ns.ItemName = ItemName

local function ItemIcon(item, kind)
    local icon = item and item > 0 and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)
    return icon or ICONS[kind]
end

local DATA_MIN_ZOOM = 5   -- the data's nodes: there are thousands, so only from a zone's view in

function P:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    local count = 0
    if ns.Map.Zoom() >= DATA_MIN_ZOOM then
        local all = ns.Opt("nodesAll")
        local found = {}
        for mapID, list in pairs(DataNodes()) do
            local l, r, t, b = Geo.Rect(mapID)
            if l and l < u1 and r > u0 and t < v1 and b > v0 then
                for _, n in ipairs(list) do
                    if ns.Opt(OPTION[n.kind]) and (all or Skill(n.kind)) and n.u > u0 and n.u < u1 and n.v > v0 and n.v < v1 then
                        found[#found + 1] = n
                    end
                end
            end
        end
        -- more than fit: every k-th, so they thin out evenly rather than end at some zone
        local step = math.max(1, #found / MAX_PINS)
        for i = 1, #found, step do
            local n = found[math.floor(i)]
            count = count + 1
            local mine = Skill(n.kind)
            local pin = self:Acquire()
            pin.icon:SetTexture(ItemIcon(n.item, n.kind))
            local reach = mine and mine >= n.skill
            pin.icon:SetDesaturated(not reach)
            pin.icon:SetAlpha(reach and 1 or 0.6)
            pin.data, pin.node, pin.mapID, pin.index = n, nil, n.m, nil
            self:Place(pin, n.u, n.v)
        end
    end
    for mapID, list in pairs(ns.db.nodes) do
        local l, r, t, b = Geo.Rect(mapID)
        if l and l < u1 and r > u0 and t < v1 and b > v0 then
            for i, n in ipairs(list) do
                if ns.Opt(OPTION[n.kind] or "herbs") then
                    local u, v = Geo.ToWorld(mapID, n.x, n.y)
                    if u > u0 and u < u1 and v > v0 and v < v1 and count < MAX_PINS then
                        count = count + 1
                        local pin = self:Acquire()
                        pin.icon:SetTexture(ICONS[n.kind])
                        pin.icon:SetDesaturated(false)
                        pin.icon:SetAlpha(1)
                        pin.data, pin.node, pin.mapID, pin.index = nil, n, mapID, i
                        self:Place(pin, u, v)
                    end
                end
            end
        end
    end
end

function P:Tooltip(pin, tip)
    if pin.data then
        local d = pin.data
        local o = ns.OBJECTS[d.object]
        tip:SetText(ItemName(d.item, o[1]), 1, 1, 1)
        tip:AddLine(d.kind == "herb" and L.HERB or L.ORE, 0.7, 0.7, 0.7)
        local mine = Skill(d.kind)
        local r, g, b = 0.4, 1, 0.4
        if not mine or mine < d.skill then r, g, b = 1, 0.4, 0.4 end
        tip:AddLine(L.NEEDS_SKILL:format(d.skill, d.kind == "herb" and L.HERBALISM or L.MINING), r, g, b)
        tip:AddLine(("%s  %s"):format(Geo.Name(pin.mapID), ns.Coords(d.x, d.y)), 0.6, 0.6, 0.6)
        tip:AddLine(L.CLICK_NAVIGATE, 0.6, 0.6, 0.6)
        return
    end
    local n = pin.node
    tip:SetText(n.name, 1, 1, 1)
    tip:AddLine(n.kind == "herb" and L.HERB or L.ORE, 0.7, 0.7, 0.7)
    if n.n and n.n > 0 then tip:AddLine(L.GATHERED_TIMES:format(n.n), 1, 0.82, 0) end
    if n.by then tip:AddLine(L.FOUND_BY:format(n.by), 0.6, 0.8, 1) end
    tip:AddLine(L.NODE_HINT, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if pin.data then
        if button == "LeftButton" then
            local d = pin.data
            ns.Waypoints.Add(pin.mapID, d.x, d.y, ItemName(d.item, ns.OBJECTS[d.object][1]), { navigate = true, temp = true })
        end
    elseif button == "RightButton" and IsShiftKeyDown() then
        table.remove(ns.db.nodes[pin.mapID], pin.index)
        P:Update()
    end
end

-- the data's herbs and ore of a zone that you can gather now (for the minimap): { { u, v, icon }, ... }
local near, nearKey = {}, nil
function ns.GatherNear(mapID)
    local key = ("%s:%s:%s:%s:%s:%s"):format(mapID, tostring(Skill("herb")), tostring(Skill("ore")),
        tostring(ns.Opt("herbs")), tostring(ns.Opt("ore")), tostring(ns.Opt("nodesAll")))
    if key == nearKey then return near end
    nearKey, near = key, {}
    local all = ns.Opt("nodesAll")
    for _, n in ipairs(DataNodes()[mapID] or {}) do
        local mine = Skill(n.kind)
        if ns.Opt(OPTION[n.kind]) and (all or (mine and mine >= n.skill)) then
            near[#near + 1] = { u = n.u, v = n.v, icon = ItemIcon(n.item, n.kind) }
        end
    end
    return near
end

-- the herbs and ore of the data, one entry per kind (for the search): { object, kind, item, name }
function ns.NodeKinds()
    local out, seen = {}, {}
    for id, o in pairs(ns.OBJECTS or {}) do
        if (o[2] == "herb" or o[2] == "ore") and not seen[o[3] .. o[1]] then
            seen[o[3] .. o[1]] = true
            out[#out + 1] = { object = id, kind = o[2], item = o[3], name = o[1] }
        end
    end
    return out
end

-- every spawn of a kind of node (the same item: Peacebloom, Copper...): { { mapID, x, y }, ... }
function ns.NodeSpawns(item, name)
    local out = {}
    for id, o in pairs(ns.OBJECTS or {}) do
        if (o[2] == "herb" or o[2] == "ore") and (o[3] == item and item > 0 or o[1] == name) then
            for _, s in ipairs(ns.Npcs.ObjectSpawns(id)) do out[#out + 1] = s end
        end
    end
    return out
end

-- for the search: every kind of node found, by name
function ns.GatherList()
    local out = {}
    for mapID, list in pairs(ns.db.nodes) do
        for _, n in ipairs(list) do out[#out + 1] = { mapID = mapID, node = n } end
    end
    return out
end

ns.On("ZMAP_OPTION", function(key)
    if key == "herbs" or key == "ore" or key == "nodesAll" then P:Update() end
end)
ns.On("SKILL_LINES_CHANGED", function() skillsAt = 0; P:Update() end)

ns.commands.borrarnodos = function()
    ns.Confirm(L.CLEAR_NODES_CONFIRM, function()
        wipe(ns.db.nodes)
        P:Update()
    end)
end
ns.commands.clearnodes = ns.commands.borrarnodos
