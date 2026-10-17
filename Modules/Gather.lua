-- Herbs and ore: every node you gather is remembered where it was (and sent to your guild's Zmap users),
-- so the map learns where things grow. Nothing to download and nothing to go stale: what you see is what
-- you and your guild have found in this game.
local _, ns = ...
local L, Geo, Comm = ns.L, ns.Geo, ns.Comm

local SPELLS = { [2366] = "herb", [2575] = "ore" }   -- Herb Gathering, Mining (every rank has the same name)
local ICONS = { herb = "Interface\\Icons\\INV_Misc_Herb_01", ore = "Interface\\Icons\\INV_Ore_Copper_01" }
local OPTION = { herb = "herbs", ore = "ore" }
local SAME = 0.008       -- two finds of the same name this close (share of the zone) are one node
local MAX_PINS = 400

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

function P:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    local count = 0
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
                        pin.node, pin.mapID, pin.index = n, mapID, i
                        self:Place(pin, u, v)
                    end
                end
            end
        end
    end
end

function P:Tooltip(pin, tip)
    local n = pin.node
    tip:SetText(n.name, 1, 1, 1)
    tip:AddLine(n.kind == "herb" and L.HERB or L.ORE, 0.7, 0.7, 0.7)
    if n.n and n.n > 0 then tip:AddLine(L.GATHERED_TIMES:format(n.n), 1, 0.82, 0) end
    if n.by then tip:AddLine(L.FOUND_BY:format(n.by), 0.6, 0.8, 1) end
    tip:AddLine(L.NODE_HINT, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "RightButton" and IsShiftKeyDown() then
        table.remove(ns.db.nodes[pin.mapID], pin.index)
        P:Update()
    end
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

ns.commands.borrarnodos = function()
    ns.Confirm(L.CLEAR_NODES_CONFIRM, function()
        wipe(ns.db.nodes)
        P:Update()
    end)
end
ns.commands.clearnodes = ns.commands.borrarnodos
