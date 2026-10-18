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
    stone = "Interface\\Icons\\INV_Misc_StoneTablet_05",
}
local ATLASES = { anvil = "worldquest-icon-blacksmithing", forge = "worldquest-icon-blacksmithing" }
ICONS.anvil, ICONS.forge = "", ""   -- (drawn from ATLASES)

-- Vendors and trainers by what they sell or teach, from their title: the data's (English) or the one learned
-- in game (the client's language, folded). The first match wins; no match keeps the service's icon.
local I = "Interface\\Icons\\"
-- Each also says which type it is (cat: what the layers panel turns on and off; "profession" is a profession
-- trainer, or as a vendor its supplies).
local SPECIALTIES = {
    { I .. "Spell_Holy_SealOfSacrifice", "first aid", "auxilios", cat = "profession", skill = 129 },
    { I .. "Trade_Alchemy", "alchem", "alquim", cat = "profession", skill = 171 },
    { I .. "Trade_BlackSmithing", "blacksmith", "herrer", cat = "profession", skill = 164 },
    { I .. "Trade_Engraving", "enchant", "encant", cat = "profession", skill = 333 },
    { I .. "Trade_Engineering", "engineer", "ingenier", cat = "profession", skill = 202 },
    { I .. "Trade_Herbalism", "herbalis", "herbor", cat = "profession", skill = 182 },
    { I .. "Trade_LeatherWorking", "leatherwork", "peleter", cat = "profession", skill = 165 },
    { I .. "Trade_Mining", "mining", "miner", cat = "profession", skill = 186 },
    { I .. "INV_Misc_Pelt_Wolf_01", "skinn", "desoll", cat = "profession", skill = 393 },
    { I .. "Trade_Tailoring", "tailor", "sastr", cat = "profession", skill = 197 },
    { I .. "Trade_Fishing", "fish", "pesca", cat = "profession", skill = 356 },
    { I .. "INV_Misc_Food_15", "cook", "chef", "cocin", cat = "profession", skill = 185 },
    { I .. "Ability_Hunter_BeastTaming", "pet trainer", "mascota", cat = "trainer", class = "HUNTER" },
    { I .. "Spell_Arcane_PortalIronForge", "portal", cat = "trainer", class = "MAGE" },
    { I .. "Trade_BrewPoison", "poison", "veneno", cat = "reagents" },
    { I .. "INV_Misc_Dust_02", "reagent", "componente", "reactivo", cat = "reagents" },
    { I .. "INV_Weapon_Bow_05", "bowyer", "arquer", "arco", cat = "weapons" },
    { I .. "INV_Weapon_Rifle_01", "gunsmith", "gun ", "arma de fuego", cat = "weapons" },
    { I .. "INV_Ammo_Arrow_02", "ammo", "arrow", "munici", "flecha", cat = "weapons" },
    { I .. "INV_Sword_04", "weapon", "blade", "staff", "sword", "axe", "mace", "armas", "espada", "hacha", "baston", cat = "weapons" },
    { I .. "INV_Chest_Cloth_04", "cloth armor", "clothier", "robe", "tela", "tunica", cat = "armor" },
    { I .. "INV_Chest_Leather_01", "leather armor", "light armor", "cuero", cat = "armor" },
    { I .. "INV_Chest_Plate01", "armor", "shield", "cloak", "armadura", "escudo", "capa", cat = "armor" },
    { I .. "INV_Drink_05", "food", "drink", "bartender", "baker", "butcher", "fruit", "meat", "bread", "wine", "brew",
        "barmaid", "mushroom", "comida", "bebida", "panader", "carnicer", "fruta", "vino", "cervez", "camarer", "seta",
        cat = "food" },
    { I .. "INV_Misc_Bag_07", "bag", "bolsa", cat = "goods" },
    { I .. "INV_Shirt_GuildTabard_01", "tabard", "tabardo", cat = "othervendor" },
    { I .. "INV_Crate_02", "trade goods", "trade supplies", "comercio", cat = "supplies" },
    { I .. "INV_Misc_Bag_08", "general", "provision", "tradesman", "tools", "specialty goods", "odds and ends", "herramienta",
        cat = "goods" },
}
local VENDOR_ICON = I .. "INV_Misc_Coin_01"   -- (a vendor whose title says nothing of what they sell)

-- The types, in the layers panel's order: { cat, its icon (texture, or atlas = true), coords }
local TYPES = {
    { "innkeeper", ICONS.innkeeper }, { "banker", ICONS.banker }, { "auctioneer", ICONS.auctioneer },
    { "stable", ICONS.stable }, { "spirit", ICONS.spirit }, { "repair", ICONS.repair },
    { "trainer", ICONS.trainer }, { "proftrainer", ICONS.profession },
    { "weapons", I .. "INV_Sword_04" }, { "armor", I .. "INV_Chest_Plate01" }, { "food", I .. "INV_Drink_05" },
    { "supplies", I .. "INV_Crate_02" }, { "reagents", I .. "INV_Misc_Dust_02" }, { "goods", I .. "INV_Misc_Bag_08" },
    { "othervendor", VENDOR_ICON },
    { "mailbox", ICONS.mailbox }, { "smith", "worldquest-icon-blacksmithing", atlas = true }, { "stone", ICONS.stone },
}

-- class trainers: the class's round icon
local CLASS_WORDS = {
    WARRIOR = { "warrior", "guerrer" }, HUNTER = { "hunter", "cazador" }, PRIEST = { "priest", "sacerdot" },
    MAGE = { "mage", "mago" }, ROGUE = { "rogue", "picaro" }, WARLOCK = { "warlock", "brujo" },
    DRUID = { "druid", "druida" }, SHAMAN = { "shaman", "chaman" }, PALADIN = { "paladin" },
}
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 },
    DRUID = { 0.75, 1, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
    PRIEST = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local CLASS_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"

local FULL, CROPPED = { 0, 1, 0, 1 }, { 0.08, 0.92, 0.08, 0.92 }   -- (item icons lose their frame)
local looks = {}   -- [kind .. title] = { texture or atlas, coords, atlas?, cat = its type }, worked out once
local TRAINS = { trainer = true, profession = true }

-- how to draw one of the townsfolk, and its type: kind (the service) and title
local function Look(kind, title)
    local key = kind .. "|" .. (title or "")
    local look = looks[key]
    if look then return look end
    if ATLASES[kind] then
        look = { ATLASES[kind], FULL, true, cat = "smith" }
    elseif (TRAINS[kind] or kind == "repair" or kind == "vendor") and title and title ~= "" then
        local t = ns.Fold(title)
        if kind == "trainer" then
            for class, words in pairs(CLASS_WORDS) do
                for _, w in ipairs(words) do
                    if t:find(w, 1, true) then
                        look = { CLASS_TEXTURE, (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or CLASS_COORDS[class], cat = "trainer",
                            class = class }
                    end
                end
            end
        end
        for _, s in ipairs(SPECIALTIES) do
            if look then break end
            for i = 2, #s do
                if t:find(s[i], 1, true) then
                    local cat = s.cat
                    if TRAINS[kind] then
                        cat = (cat == "profession" or kind == "profession") and "proftrainer" or "trainer"
                    elseif cat == "profession" or cat == "trainer" then
                        cat = "supplies"
                    end
                    look = { s[1], CROPPED, cat = cat, skill = s.skill, class = TRAINS[kind] and s.class or nil }
                    break
                end
            end
        end
    end
    if not look then
        if kind == "vendor" then
            look = { VENDOR_ICON, CROPPED, cat = "othervendor" }
        else
            look = { ICONS[kind], FULL, cat = kind == "profession" and "proftrainer" or kind }
        end
    end
    looks[key] = look
    return look
end

-- "only mine": trainers of your class and of your professions. The secondary ones (cooking, first aid,
-- fishing) are anyone's; and while you have fewer than two primary professions, every primary one's trainer
-- shows, to find where to learn them.
local SECONDARY = { [185] = true, [129] = true, [356] = true }
local mine, mineAt = {}, -1
local function MyProfessions()
    if GetTime() - mineAt > 5 then
        mineAt = GetTime()
        wipe(mine)
        local primary = 0
        if GetProfessions and GetProfessionInfo then
            for i, index in ipairs({ GetProfessions() }) do
                local _, _, _, _, _, _, line = GetProfessionInfo(index)
                if line then
                    mine[line] = true
                    if not SECONDARY[line] then primary = primary + 1 end
                end
            end
        end
        mine.room = primary < 2
    end
    return mine
end
local function NotMine(look)
    if not ns.Opt("folkMine") then return false end
    if look.class then return look.class ~= select(2, UnitClass("player")) end
    if look.cat == "proftrainer" and look.skill and not SECONDARY[look.skill] then
        local have = MyProfessions()
        return not have[look.skill] and not have.room
    end
    return false
end

-- the types the player turned off in the layers panel (saved): [cat] = true
local function Hidden() return ns.db.folkHidden or {} end
function ns.FolkTypes() return TYPES end
function ns.FolkTypeShown(cat) return not Hidden()[cat] end
function ns.SetFolkTypeShown(cat, on)
    ns.db.folkHidden = ns.db.folkHidden or {}
    ns.db.folkHidden[cat] = not on or nil
    ns.Fire("ZMAP_OPTION", "folkTypes")
end
-- every type shown?
function ns.AllFolkTypesShown()
    for _, t in ipairs(TYPES) do
        if Hidden()[t[1]] then return false end
    end
    return true
end
-- every type on, or every type off
function ns.SetAllFolkTypes(on)
    ns.db.folkHidden = {}
    if not on then
        for _, t in ipairs(TYPES) do ns.db.folkHidden[t[1]] = true end
    end
    ns.Fire("ZMAP_OPTION", "folkTypes")
end

local function Draw(icon, look)
    if look[3] then icon:SetAtlas(look[1]) else icon:SetTexture(look[1]) end
    local c = look[2]
    icon:SetTexCoord(c[1], c[2], c[3], c[4])
end
-- for the search: the icon of an NPC of the data
function ns.FolkLook(id)
    local kind = ns.Npcs.Kind(id)
    return kind and Look(kind, ns.NPCS[id][2])
end

-- the data's mailboxes, anvils, forges and meeting stones (Data/Objects.lua): { { kind, m, x, y }, ... }
local utilities
local function Utilities()
    if utilities then return utilities end
    utilities = {}
    for id, o in pairs(ns.OBJECTS or {}) do
        if ICONS[o[2]] then
            for _, s in ipairs(ns.Npcs.ObjectSpawns(id)) do
                utilities[#utilities + 1] = { kind = o[2], m = s[1], x = s[2], y = s[3] }
            end
        end
    end
    return utilities
end
local BINDER_ICON = 132052   -- the innkeeper's "make this inn your home" gossip option
local MAX_PINS = 600

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

-- where a spot of the data is on the map, worked out once (f.u false: nowhere)
local function At(f)
    if f.u == nil then
        local u, v = Geo.ToWorld(f.m, f.x, f.y)
        f.u, f.v = u or false, v
    end
    return f.u, f.v
end

-- what is in view: the spots themselves (the data's, those met with their key, the mailboxes and anvils), kept
-- from one refresh to the next (the view zooms through thousands of them: no table is made for each)
local inView, inKey = {}, {}
local npcOf = setmetatable({}, { __mode = "k" })   -- [a find met] = the NPC of its key (false: none)

-- a spot to show: in view, a type shown, yours: its look
local function Wanted(kind, title, u, v, u0, v0, u1, v1, hidden)
    if not u or u < u0 or u > u1 or v < v0 or v > v1 or not ICONS[kind] then return end
    local look = Look(kind, title)
    if hidden[look.cat] or NotMine(look) then return end
    return look
end

function P:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
    local hidden = Hidden()
    -- people first (the data's, then those met that it lacks), mailboxes and anvils after them
    local people = 0
    for _, f in ipairs(ns.Npcs.Townsfolk()) do
        local u, v = At(f)
        if Wanted(f.kind, ns.NPCS[f.id][2], u, v, u0, v0, u1, v1, hidden) then
            people = people + 1
            inView[people], inKey[people] = f, false
        end
    end
    for key, f in pairs(ns.db.folk) do
        if npcOf[f] == nil then npcOf[f] = tonumber(key:match(":(%d+)$")) or false end
        local npc = npcOf[f]
        if not (npc and ns.NPCS and ns.NPCS[npc]) then   -- (the data shows it already)
            local u, v = Geo.ToWorld(f.m, f.x, f.y)
            if Wanted(f.kind, f.sub, u, v, u0, v0, u1, v1, hidden) then
                people = people + 1
                inView[people], inKey[people] = f, key
            end
        end
    end
    local total = people
    for _, o in ipairs(Utilities()) do
        local u, v = At(o)
        if Wanted(o.kind, nil, u, v, u0, v0, u1, v1, hidden) then
            total = total + 1
            inView[total], inKey[total] = o, true
        end
    end
    -- at most MAX_PINS, every k-th of the people, then of the rest as many as there is room for (as Pins.Spread)
    local function Show(first, n, room)
        local step = n > room and n / room or 1
        for k = 1, math.min(n, room) do
            local s = inView[first + math.floor((k - 1) * step)]
            local key = inKey[first + math.floor((k - 1) * step)]
            local pin = self:Acquire()
            local u, v
            if key == true then   -- a mailbox, an anvil...
                u, v = At(s)
                Draw(pin.icon, Look(s.kind))
                pin.npc, pin.folk, pin.key, pin.object = nil, nil, nil, s.kind
            elseif key then       -- met
                u, v = Geo.ToWorld(s.m, s.x, s.y)
                Draw(pin.icon, Look(s.kind, s.sub))
                pin.npc, pin.folk, pin.key, pin.object = nil, s, key, nil
            else                  -- the data's
                u, v = At(s)
                Draw(pin.icon, Look(s.kind, ns.NPCS[s.id][2]))
                pin.npc, pin.folk, pin.key, pin.object = s.id, nil, nil, nil
            end
            pin.m, pin.x, pin.y = s.m, s.x, s.y
            self:Place(pin, u, v)
        end
        return math.min(n, room)
    end
    local shown = Show(1, people, MAX_PINS)
    Show(people + 1, total - people, MAX_PINS - shown)
    for k = total + 1, #inView do inView[k], inKey[k] = nil, nil end   -- (let go of the rest)
end

function P:Tooltip(pin, tip)
    if pin.npc then
        ns.Npcs.Tooltip(pin, tip)
        return
    end
    if pin.object then
        tip:SetText(L["FOLK_" .. pin.object], 1, 1, 1)
        tip:AddLine(("%s  %s"):format(Geo.Name(pin.m), ns.Coords(pin.x, pin.y)), 0.6, 0.6, 0.6)
        tip:AddLine(L.CTRL_NAVIGATE, 0.6, 0.6, 0.6)
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
        local name = pin.npc and ns.Npcs.Name(pin.npc) or pin.object and L["FOLK_" .. pin.object] or pin.folk.name
        ns.Waypoints.Add(pin.m, pin.x, pin.y, name, { navigate = true, temp = true })
    end
end

ns.On("ZMAP_OPTION", function(key) if key == "folkTypes" or key == "folkMine" then P:Update() end end)
ns.On("SKILL_LINES_CHANGED", function() mineAt = -1; P:Update() end)

-- for the search
function ns.FolkList() return ns.db.folk end
ns.FOLK_ICONS = ICONS
