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

-- There are ~25,000 of them: a zone's are worked out the first time it is looked at, five numbers a node in
-- one flat list (a table per node took ~17 MB); a node's table is made only for what is drawn.
local zones    -- [uiMapID] = { object IDs with nodes there }
local packed = {}   -- [uiMapID] = { u, v, x, y, object, u, v, ... }

local function NodeZones()
    if zones then return zones end
    zones = {}
    for id, o in pairs(ns.OBJECTS or {}) do
        if o[2] == "herb" or o[2] == "ore" then
            for i = 5, #o - 1, 2 do
                local list = zones[o[i]] or {}
                zones[o[i]] = list
                if list[#list] ~= id then list[#list + 1] = id end
            end
        end
    end
    return zones
end

local function Nodes(mapID)
    local p = packed[mapID]
    if p then return p end
    p = {}
    for _, id in ipairs(NodeZones()[mapID] or {}) do
        for _, s in ipairs(ns.Npcs.ObjectSpawns(id)) do
            if s[1] == mapID then
                local u, v = Geo.ToWorld(mapID, s[2], s[3])
                p[#p + 1], p[#p + 2], p[#p + 3], p[#p + 4], p[#p + 5] = u, v, s[2], s[3], id
            end
        end
    end
    packed[mapID] = p
    return p
end

-- one node as a table: { m, u, v, x, y, object, kind, skill, item } (into: a table to fill, kept by its pin)
local function Node(mapID, p, i, into)
    local o = ns.OBJECTS[p[i + 4]]
    local n = into or {}
    n.m, n.u, n.v, n.x, n.y, n.object, n.kind, n.skill, n.item = mapID, p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4], o[2], o[4], o[3]
    return n
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

-- herbs only with Herbalism and ore only with Mining, and their layer on
local function Wanted(kind)
    local option = OPTION[kind]
    if not option then return ns.Opt("herbs") end
    return ns.Opt(option) and Skill(kind) ~= nil
end

-- The kinds of herb and ore (by the item they give, its name if none), the lowest skill each needs, and which of
-- them the map shows: by default those you can gather now; each one turned on or off by itself
-- (ns.db.nodeShown[key]). The layers panel lists them.
local types, typeOf = {}, {}   -- [kind] = { { key, item, name, kind, skill }, ... } by skill; [key] = that type
local typesVersion = 0         -- (what the map shows changed)

local function TypeKey(o) return o[3] and o[3] > 0 and o[3] or o[1] end

local function Types(kind)
    if types[kind] then return types[kind] end
    local list = {}
    for _, o in pairs(ns.OBJECTS or {}) do
        if o[2] == kind then
            local key = TypeKey(o)
            local t = typeOf[key]
            if not t then
                t = { key = key, item = o[3], name = o[1], kind = kind, skill = o[4] }
                typeOf[key] = t
                list[#list + 1] = t
            elseif o[4] < t.skill then
                t.skill = o[4]
            end
        end
    end
    table.sort(list, function(a, b) return a.skill < b.skill or (a.skill == b.skill and a.name < b.name) end)
    types[kind] = list
    return list
end
ns.GatherTypes = Types

function ns.GatherTypeShown(t)
    local shown = ns.db.nodeShown and ns.db.nodeShown[t.key]
    if shown == nil then return (Skill(t.kind) or -1) >= t.skill end
    return shown
end

-- every type of a kind on or off at once (nil: back to those you can gather), or one type
function ns.SetGatherTypeShown(t, shown)
    ns.db.nodeShown = ns.db.nodeShown or {}
    if t.key then
        ns.db.nodeShown[t.key] = shown
    else
        for _, each in ipairs(Types(t.kind)) do ns.db.nodeShown[each.key] = shown end
    end
    typesVersion = typesVersion + 1
    ns.Fire("ZMAP_OPTION", OPTION[t.kind])
end

-- a node of the data the map shows: its profession's layer on, its type shown
local function Shown(o)
    if not Wanted(o[2]) then return false end
    Types(o[2])
    local t = typeOf[TypeKey(o)]
    return t ~= nil and ns.GatherTypeShown(t)
end

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
ns.ItemIcon = ItemIcon

local DATA_MIN_ZOOM = 5   -- the data's nodes: there are thousands, so only from a zone's view in

-- the data's nodes in view: where each is (its zone, its packed list, its place in it), kept from one refresh to
-- the next (thousands of them as the view zooms: none is made a table, only those shown, in their pin's)
local inMap, inList, inAt = {}, {}, {}

function P:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
    local count = 0
    if ns.Map.Zoom() >= DATA_MIN_ZOOM then
        local found = 0
        if Wanted("herb") or Wanted("ore") then
            for mapID in pairs(NodeZones()) do
                local l, r, t, b = Geo.Rect(mapID)
                if l and l < u1 and r > u0 and t < v1 and b > v0 then
                    local p = Nodes(mapID)
                    for i = 1, #p, 5 do
                        local u, v = p[i], p[i + 1]
                        if u > u0 and u < u1 and v > v0 and v < v1 and Shown(ns.OBJECTS[p[i + 4]]) then
                            found = found + 1
                            inMap[found], inList[found], inAt[found] = mapID, p, i
                        end
                    end
                end
            end
        end
        -- at most MAX_PINS of them, every k-th (as Pins.Spread)
        local step = found > MAX_PINS and found / MAX_PINS or 1
        for k = 1, math.min(found, MAX_PINS) do
            local j = math.floor((k - 1) * step) + 1
            count = count + 1
            local pin = self:Acquire()
            local n = Node(inMap[j], inList[j], inAt[j], pin.nodeData)
            pin.nodeData = n
            local mine = Skill(n.kind)
            pin.icon:SetTexture(ItemIcon(n.item, n.kind))
            local reach = mine and mine >= n.skill
            pin.icon:SetDesaturated(not reach)
            pin.icon:SetAlpha(reach and 1 or 0.6)
            pin.data, pin.node, pin.mapID, pin.index = n, nil, n.m, nil
            self:Place(pin, n.u, n.v)
        end
        for k = found + 1, #inMap do inMap[k], inList[k], inAt[k] = nil, nil, nil end   -- (let go of the rest)
    end
    for mapID, list in pairs(ns.db.nodes) do
        local l, r, t, b = Geo.Rect(mapID)
        if l and l < u1 and r > u0 and t < v1 and b > v0 then
            for i, n in ipairs(list) do
                if Wanted(n.kind) then
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

-- the data's herbs and ore of a zone that the map shows and you can gather now (for the minimap): { { u, v, icon } }
local near, nearKey = {}, nil
function ns.GatherNear(mapID)
    local key = ("%s:%s:%s:%s:%s:%d"):format(mapID, tostring(Skill("herb")), tostring(Skill("ore")),
        tostring(ns.Opt("herbs")), tostring(ns.Opt("ore")), typesVersion)
    if key == nearKey then return near end
    nearKey, near = key, {}
    if not (Wanted("herb") or Wanted("ore")) then return near end
    local p = Nodes(mapID)
    for i = 1, #p, 5 do
        local o = ns.OBJECTS[p[i + 4]]
        if Shown(o) and Skill(o[2]) >= o[4] then
            near[#near + 1] = { u = p[i], v = p[i + 1], icon = ItemIcon(o[3], o[2]) }
        end
    end
    return near
end

-- the types of a zone you can gather now, the most there first (for the gathering route): { { type, count } }
function ns.GatherZoneTypes(mapID)
    local counts, out = {}, {}
    local p = Nodes(mapID)
    for i = 1, #p, 5 do
        local o = ns.OBJECTS[p[i + 4]]
        local mine = Skill(o[2])
        if mine and mine >= o[4] then
            Types(o[2])
            local t = typeOf[TypeKey(o)]
            if not counts[t] then
                counts[t] = 0
                out[#out + 1] = t
            end
            counts[t] = counts[t] + 1
        end
    end
    table.sort(out, function(a, b) return counts[a] > counts[b] end)
    for i, t in ipairs(out) do out[i] = { t, counts[t] } end
    return out
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

-- for a gathering route: the nodes of a zone you can gather now ({ u, v } each), of some types ([key] = true) or
-- of every type (the data's and, then, those found too)
function ns.GatherSpots(mapID, keys)
    local out = {}
    local p = Nodes(mapID)
    for i = 1, #p, 5 do
        local o = ns.OBJECTS[p[i + 4]]
        local mine = Skill(o[2])
        if mine and mine >= o[4] and (not keys or keys[TypeKey(o)]) then out[#out + 1] = { p[i], p[i + 1] } end
    end
    for _, n in ipairs(not keys and ns.db.nodes[mapID] or {}) do
        local u, v = Geo.ToWorld(mapID, n.x, n.y)
        if u and Skill(n.kind) then out[#out + 1] = { u, v } end
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
    if key == "herbs" or key == "ore" then P:Update() end
end)
ns.On("SKILL_LINES_CHANGED", function()
    skillsAt = 0
    typesVersion = typesVersion + 1   -- (types you could not gather may be shown now)
    P:Update()
end)

ns.commands.borrarnodos = function()
    ns.Confirm(L.CLEAR_NODES_CONFIRM, function()
        wipe(ns.db.nodes)
        P:Update()
    end)
end
ns.commands.clearnodes = ns.commands.borrarnodos
