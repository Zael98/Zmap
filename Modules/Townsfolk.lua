-- Townsfolk: vendors, trainers, innkeepers, bankers, auctioneers, stable masters, spirit healers and
-- mailboxes. The NPC data (Modules/Npcs.lua) brings those friendly to you; besides, the ones you use are
-- remembered where you met them (and sent to your guild's Zmap users), so what the data lacks (Forever's
-- changes, mailboxes) is learned too.
local _, ns = ...
local L, Geo, Comm = ns.L, ns.Geo, ns.Comm

local ICONS = {
    vendor = "Interface\\Minimap\\Tracking\\Food",
    repair = "Interface\\Minimap\\Tracking\\Repair",
    trainer = "Interface\\Minimap\\Tracking\\Class",
    profession = "Interface\\Minimap\\Tracking\\Profession",
    innkeeper = "Interface\\Minimap\\Tracking\\Innkeeper",
    banker = "Interface\\Minimap\\Tracking\\Banker",
    auctioneer = "Interface\\Minimap\\Tracking\\Auctioneer",
    stable = "Interface\\Minimap\\Tracking\\StableMaster",
    spirit = "Interface\\RaidFrame\\Raid-Icon-Rez",
    mailbox = "Interface\\Minimap\\Tracking\\Mailbox",
}
local BINDER_ICON = 132052   -- the innkeeper's "make this inn your home" gossip option
local MAX_PINS = 300

local P = ns.Pins.New("townsfolk", { level = 25, size = 16, option = "townsfolk", minZoom = 6, cull = true })

-- the NPC's title line ("Weapon Merchant"), if its tooltip has one
local function Subtitle(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    local line = ok and data and data.lines and data.lines[2]
    local text = line and line.leftText
    if not text or (issecretvalue and issecretvalue(text)) then return end
    if text:find(LEVEL, 1, true) or text:find("%d") then return end   -- the level line: no title
    return text
end

local function NpcID(guid)
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
end

-- a find: true if it is new
local function Record(kind, mapID, x, y, name, sub, npc, by)
    local key = npc and (kind .. ":" .. npc) or ("%s:%d:%d:%d"):format(kind, mapID, math.floor(x * 300), math.floor(y * 300))
    local old = ns.db.folk[key]
    if old and not (npc and old.m ~= mapID) then
        old.t = time()
        if not by then old.m, old.x, old.y = mapID, x, y end
        P:Update()
        return false
    end
    ns.db.folk[key] = { kind = kind, m = mapID, x = x, y = y, name = name, sub = sub, t = time(), by = by }
    P:Update()
    return true, key
end

local function Met(kind, unit)
    if IsInInstance() then return end
    local _, _, mapID, x, y = Geo.UnitPosition("player")
    if not mapID then return end
    local name, sub, npc
    if unit then
        name = UnitName(unit)
        if not name or (issecretvalue and issecretvalue(name)) then return end
        sub = Subtitle(unit)
        npc = NpcID(UnitGUID(unit))
    end
    name = name or L["FOLK_" .. kind]
    local new = Record(kind, mapID, x, y, name, sub, npc)
    if new and ns.Opt("shareFinds") then
        Comm.Send("T", "GUILD", nil, kind, mapID, ("%.4f"):format(x), ("%.4f"):format(y), name, sub or "", npc or "")
    end
end

local T = Enum and Enum.PlayerInteractionType or {}
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if kind == T.Merchant then
        Met(CanMerchantRepair and CanMerchantRepair() and "repair" or "vendor", "npc")
    elseif kind == T.Trainer then
        Met(IsTradeskillTrainer and IsTradeskillTrainer() and "profession" or "trainer", "npc")
    elseif kind == T.Banker then
        Met("banker", "npc")
    elseif kind == T.Binder then
        Met("innkeeper", "npc")
    elseif kind == T.Auctioneer then
        Met("auctioneer", "npc")
    elseif kind == T.StableMaster then
        Met("stable", "npc")
    elseif kind == T.SpiritHealer then
        Met("spirit", "npc")
    elseif kind == T.MailInfo then
        Met("mailbox")
    end
end)

-- innkeepers open their gossip first: their "make this inn your home" option gives them away
ns.On("GOSSIP_SHOW", function()
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then return end
    for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
        if o.icon == BINDER_ICON then
            Met("innkeeper", "npc")
            return
        end
    end
end)

Comm.On("T", function(sender, channel, kind, m, x, y, name, sub, npc)
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if channel ~= "GUILD" or not ICONS[kind] or not (m and x and y and Geo.Kind(m)) then return end
    Record(kind, m, x, y, name ~= "" and name or L["FOLK_" .. kind], sub ~= "" and sub or nil, tonumber(npc), Ambiguate(sender, "short"))
end)

function P:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    local count = 0
    local function Pin(kind, m, x, y)
        local u, v = Geo.ToWorld(m, x, y)
        if not u or u < u0 or u > u1 or v < v0 or v > v1 or count >= MAX_PINS or not ICONS[kind] then return end
        count = count + 1
        local pin = self:Acquire()
        pin.icon:SetTexture(ICONS[kind])
        pin.m, pin.x, pin.y, pin.npc, pin.folk, pin.key = m, x, y, nil, nil, nil
        self:Place(pin, u, v)
        return pin
    end
    for _, f in ipairs(ns.Npcs.Townsfolk()) do
        local pin = Pin(f.kind, f.m, f.x, f.y)
        if pin then pin.npc = f.id end
    end
    for key, f in pairs(ns.db.folk) do
        local npc = tonumber(key:match(":(%d+)$"))
        if not (npc and ns.NPCS and ns.NPCS[npc]) then   -- (the data shows it already)
            local pin = Pin(f.kind, f.m, f.x, f.y)
            if pin then pin.folk, pin.key = f, key end
        end
    end
end

function P:Tooltip(pin, tip)
    if pin.npc then
        ns.Npcs.Tooltip(pin, tip)
        return
    end
    local f = pin.folk
    tip:SetText(f.name or "?", 1, 1, 1)
    if f.sub then tip:AddLine(f.sub, 1, 0.82, 0) end
    tip:AddLine(L["FOLK_" .. f.kind], 0.7, 0.7, 0.7)
    if f.by then tip:AddLine(L.FOUND_BY:format(f.by), 0.6, 0.8, 1) end
    tip:AddLine(L.NODE_HINT, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "RightButton" and IsShiftKeyDown() and pin.key then
        ns.db.folk[pin.key] = nil
        P:Update()
    elseif button == "LeftButton" and IsControlKeyDown() then
        local name = pin.npc and ns.Npcs.Name(pin.npc) or pin.folk.name
        ns.Waypoints.Add(pin.m, pin.x, pin.y, name, { navigate = true, temp = true })
    end
end

-- for the search
function ns.FolkList() return ns.db.folk end
ns.FOLK_ICONS = ICONS
