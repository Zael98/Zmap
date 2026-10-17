-- Townsfolk: the vendors, trainers, innkeepers, bankers, auctioneers, stable masters, spirit healers and
-- mailboxes you use are remembered where you met them (and sent to your guild's Zmap users), so the map
-- learns each town. Like the herbs: only what someone has really found.
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
    for key, f in pairs(ns.db.folk) do
        local u, v = Geo.ToWorld(f.m, f.x, f.y)
        if u and u > u0 and u < u1 and v > v0 and v < v1 and count < MAX_PINS and ICONS[f.kind] then
            count = count + 1
            local pin = self:Acquire()
            pin.icon:SetTexture(ICONS[f.kind])
            pin.folk, pin.key = f, key
            self:Place(pin, u, v)
        end
    end
end

function P:Tooltip(pin, tip)
    local f = pin.folk
    tip:SetText(f.name or "?", 1, 1, 1)
    if f.sub then tip:AddLine(f.sub, 1, 0.82, 0) end
    tip:AddLine(L["FOLK_" .. f.kind], 0.7, 0.7, 0.7)
    if f.by then tip:AddLine(L.FOUND_BY:format(f.by), 0.6, 0.8, 1) end
    tip:AddLine(L.NODE_HINT, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "RightButton" and IsShiftKeyDown() then
        ns.db.folk[pin.key] = nil
        P:Update()
    elseif button == "LeftButton" and IsControlKeyDown() then
        local f = pin.folk
        ns.Waypoints.Add(f.m, f.x, f.y, f.name, { navigate = true, temp = true })
    end
end

-- for the search
function ns.FolkList() return ns.db.folk end
ns.FOLK_ICONS = ICONS
