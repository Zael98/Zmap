-- Every NPC Warcraft DB knows in Forever (Data/Npcs.lua, from tools/build_npcs.py): to find anyone by name
-- (the search marks every place they stand), the townsfolk you can use near you (Townsfolk.lua) and the
-- rares. The data's names are English: Zmap learns each NPC's name in your client's language when you see
-- it (nameplates, the mouse, your target) and, a few a second in the background, by asking the game.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local N = {}
ns.Npcs = N

local NPCS = ns.NPCS or {}
-- the data's service flags, bit by bit (tools/build_npcs.py's SERVICES)
local SERVICES = { "innkeeper", "vendor", "repair", "trainer", "flight", "banker", "auctioneer", "stable", "spirit",
    "battlemaster", "guildbank", "mailbox" }
local PROFESSION_WORDS = { "alchemy", "blacksmith", "enchant", "engineer", "herbalis", "leatherwork", "mining",
    "skinning", "tailor", "cook", "first aid", "fishing" }
local IsSecret = issecretvalue or function() return false end

-- N.OnLearn(id), when set (the search), hears of each name learned
local function Has(flags, i) return math.floor(flags / 2 ^ (i - 1)) % 2 == 1 end

function N.Services(id)
    local d = NPCS[id]
    local out = {}
    if d then
        for i, s in ipairs(SERVICES) do
            if Has(d[3], i) then out[#out + 1] = s end
        end
    end
    return out
end

--------------------------------------------------------------------------------------------------------------
-- Names in the client's language
--------------------------------------------------------------------------------------------------------------

local function Book(field)
    local locale = GetLocale()
    ns.db[field] = ns.db[field] or {}
    ns.db[field][locale] = ns.db[field][locale] or {}
    return ns.db[field][locale]
end

local ENGLISH = { enUS = true, enGB = true }

-- an NPC the data does not place, seen close by in game (by you or a guildmate): { n, t, m, x, y, by }
local function Seen(id) return ns.db and ns.db.seen and ns.db.seen[id] end

function N.Name(id)
    local d = NPCS[id]
    local learned = ns.db and ns.db.npcNames and ns.db.npcNames[GetLocale()]
    local seen = Seen(id)
    return (learned and learned[id]) or (d and d[1]) or (seen and seen.n) or "?"
end

-- its title as the game shows it, else the data's, put in the client's language where we know how
function N.Title(id)
    local d = NPCS[id]
    local learned = ns.db and ns.db.npcTitles and ns.db.npcTitles[GetLocale()]
    local seen = Seen(id)
    if not d and seen then return seen.t or "" end
    local t = (learned and learned[id]) or (d and d[2]) or ""
    if t == "" or (learned and learned[id]) or ENGLISH[GetLocale()] then return t end
    return ns.TranslateTitle(t)
end

local function Learn(id, name, title)
    if not (id and NPCS[id]) or not name or name == "" or IsSecret(name) then return end
    local names, titles = Book("npcNames"), Book("npcTitles")
    local newTitle = title and title ~= "" and not IsSecret(title) and titles[id] ~= title
    if names[id] == name and not newTitle then return end
    names[id] = name
    if newTitle then titles[id] = title end
    if N.OnLearn then N.OnLearn(id) end
end

local function NpcID(guid)
    if not guid or IsSecret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
end

-- the title line of a unit's (or a link's) tooltip, if it has one
local function TitleOf(data)
    local line = data and data.lines and data.lines[2]
    local text = line and line.leftText
    if not text or IsSecret(text) or text:find(LEVEL, 1, true) or text:find("%d") then return end
    return text
end

local function LearnUnit(unit, withTitle)
    if ENGLISH[GetLocale()] or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local id = NpcID(UnitGUID(unit))
    if not id or not NPCS[id] then return end
    local title
    if withTitle and C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        title = ok and TitleOf(data)
    end
    Learn(id, UnitName(unit), title)
end
N.LearnUnit = LearnUnit

-- NPCs the data does not place (Warcraft DB lacks many, high-level zones most): where you see them close by,
-- your target within ~28 yards, is remembered and sent to your guild's Zmap users, so the search finds them
local function Remember(id, name, title, m, x, y, by)
    ns.db.seen = ns.db.seen or {}
    local old = ns.db.seen[id]
    if old and by and not old.by then return false end   -- (your own sighting beats a guildmate's)
    ns.db.seen[id] = { n = name, t = title, m = m, x = x, y = y, by = by }
    return not old
end

local function SeeTarget()
    if not UnitExists("target") or UnitIsPlayer("target") then return end
    local id = NpcID(UnitGUID("target"))
    if not id or NPCS[id] or IsInInstance() then return end
    local ok, near = pcall(CheckInteractDistance, "target", 4)   -- (out of combat only)
    if not (ok and near) then return end
    local name = UnitName("target")
    if not name or IsSecret(name) then return end
    local _, _, m, x, y = Geo.UnitPosition("player")
    if not m then return end
    local title
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok2, data = pcall(C_TooltipInfo.GetUnit, "target")
        title = ok2 and TitleOf(data) or nil
    end
    if Remember(id, name, title, m, x, y) and ns.Opt("shareFinds") then
        ns.Comm.Send("S", "GUILD", nil, id, m, ("%.4f"):format(x), ("%.4f"):format(y), name, title or "")
    end
end

ns.Comm.On("S", function(sender, channel, id, m, x, y, name, title)
    id, m, x, y = tonumber(id), tonumber(m), tonumber(x), tonumber(y)
    if channel ~= "GUILD" or not (id and m and x and y and Geo.Kind(m)) or NPCS[id] or not name or name == "" then return end
    Remember(id, name, title ~= "" and title or nil, m, x, y, Ambiguate(sender, "short"))
end)

ns.On("NAME_PLATE_UNIT_ADDED", function(unit) LearnUnit(unit) end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() LearnUnit("mouseover", true) end)
ns.On("PLAYER_TARGET_CHANGED", function()
    LearnUnit("target", true)
    SeeTarget()
end)

-- for the search: the NPCs seen in game that the data lacks
function N.SeenList() return ns.db.seen or {} end

-- In the background, a few a second: the game answers with names from its cache, or asks the server and
-- has them for the next pass. Two passes over everything, then only what is still missing next session.
local queue, at, pass
local function Ask()
    if InCombatLockdown() or not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
    local names = Book("npcNames")
    local asked = 0
    while asked < 10 do
        if at > #queue then
            pass = pass + 1
            ns.db.npcAskPass = pass
            if pass > 2 then return true end   -- done for this session
            at = 1
        end
        local id = queue[at]
        at = at + 1
        ns.db.npcAskAt = at
        if not names[id] then
            asked = asked + 1
            local ok, data = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
            local line = ok and data and data.lines and data.lines[1]
            local name = line and line.leftText
            if name and name ~= "" and not IsSecret(name) and not name:find("^%?") then
                Learn(id, name, TitleOf(data))
            end
        end
    end
end

ns.On("PLAYER_LOGIN", function()
    if ENGLISH[GetLocale()] then return end
    queue = {}
    for id in pairs(NPCS) do queue[#queue + 1] = id end
    table.sort(queue)
    at = ns.db.npcAskAt or 1
    pass = ns.db.npcAskPass or 1
    if pass > 2 then   -- a new session: one more pass for what is still missing
        pass, at = 2, 1
    end
    C_Timer.After(30, function()
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            if Ask() and ticker then ticker:Cancel() end
        end)
    end)
end)

--------------------------------------------------------------------------------------------------------------
-- Where they stand
--------------------------------------------------------------------------------------------------------------

-- a data row's spawns from its field `from` on (uiMapID, { coords per thousand }, ...): { { mapID, x, y }, ... }
local function SpawnsOf(d, from, out)
    out = out or {}
    for i = from, #d - 1, 2 do
        local mapID, coords = d[i], d[i + 1]
        if Geo.Kind(mapID) then
            for j = 1, #coords - 1, 2 do out[#out + 1] = { mapID, coords[j] / 1000, coords[j + 1] / 1000 } end
        end
    end
    return out
end

-- { { mapID, x, y }, ... } (x, y: share of that map): the data's, or where it was seen in game
function N.Spawns(id)
    local d = NPCS[id]
    if not d then
        local out, seen = {}, Seen(id)
        if seen and Geo.Kind(seen.m) then out[1] = { seen.m, seen.x, seen.y } end
        return out
    end
    return SpawnsOf(d, 7)
end

-- an object's (Data/Objects.lua: herbs, ore, mailboxes, a quest's chest...) spawns, same form
function N.ObjectSpawns(id)
    local d = ns.OBJECTS and ns.OBJECTS[id]
    return d and SpawnsOf(d, 5) or {}
end

-- the nearest to you on your continent of some spawns (else the first): mapID, x, y
function N.NearestOf(spawns)
    local pu, pv, pm = Geo.UnitPosition("player")
    local best, bd
    for _, s in ipairs(spawns) do
        if pm and Geo.Instance(s[1]) == Geo.Instance(pm) then
            local u, v = Geo.ToWorld(s[1], s[2], s[3])
            local d = (u - pu) ^ 2 + (v - pv) ^ 2
            if not bd or d < bd then best, bd = s, d end
        end
    end
    best = best or spawns[1]
    if best then return best[1], best[2], best[3] end
end

-- the spawn nearest to you on your continent (else the first): mapID, x, y
function N.Nearest(id) return N.NearestOf(N.Spawns(id)) end

-- friendly to your faction (or to both)
function N.Friendly(id)
    local d = NPCS[id]
    if not d then return false end
    local f = UnitFactionGroup("player")
    return d[4]:find(f == "Alliance" and "A" or "H", 1, true) ~= nil
end

function N.Level(id) return NPCS[id] and NPCS[id][5] or "" end
function N.Rare(id) return NPCS[id] and NPCS[id][6] % 2 == 1 end
function N.Elite(id) return NPCS[id] and NPCS[id][6] >= 2 end

-- what kind of townsfolk an NPC is, by its main service (nil: none we show)
local ORDER = { "innkeeper", "banker", "auctioneer", "stable", "spirit", "trainer", "repair", "vendor" }
function N.Kind(id)
    local d = NPCS[id]
    if not d then return end
    for _, kind in ipairs(ORDER) do
        for i, s in ipairs(SERVICES) do
            if s == kind and Has(d[3], i) then
                if kind == "trainer" then
                    local title = d[2]:lower()
                    for _, w in ipairs(PROFESSION_WORDS) do
                        if title:find(w, 1, true) then return "profession" end
                    end
                end
                return kind
            end
        end
    end
end

-- the townsfolk of the data friendly to you: { { id, kind, mapID, x, y }, ... } (built once)
local folk
function N.Townsfolk()
    if folk then return folk end
    folk = {}
    for id in pairs(NPCS) do
        local kind = N.Kind(id)
        if kind and N.Friendly(id) then
            for _, s in ipairs(N.Spawns(id)) do folk[#folk + 1] = { id = id, kind = kind, m = s[1], x = s[2], y = s[3] } end
        end
    end
    return folk
end

-- the services of an NPC, in words: "Innkeeper, Vendor"
function N.ServiceText(id)
    local out = {}
    for _, s in ipairs(N.Services(id)) do out[#out + 1] = L["SERVICE_" .. s] end
    return table.concat(out, ", ")
end

--------------------------------------------------------------------------------------------------------------
-- Rares, and what the search found
--------------------------------------------------------------------------------------------------------------

local rares = ns.Pins.New("rares", { level = 32, size = 20, option = "rares", minZoom = 2.6, cull = true })
local rareList

function rares:Refresh()
    self:ReleaseAll()
    if not rareList then
        rareList = {}
        for id in pairs(NPCS) do
            if N.Rare(id) then
                for _, s in ipairs(N.Spawns(id)) do rareList[#rareList + 1] = { id = id, m = s[1], x = s[2], y = s[3] } end
            end
        end
    end
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    for _, r in ipairs(rareList) do
        local u, v = Geo.ToWorld(r.m, r.x, r.y)
        if u > u0 and u < u1 and v > v0 and v < v1 then
            local pin = self:Acquire()
            pin.icon:SetAtlas(N.Elite(r.id) and "VignetteKillElite" or "VignetteKill")
            pin.npc, pin.m, pin.x, pin.y = r.id, r.m, r.x, r.y
            self:Place(pin, u, v)
        end
    end
end

local function NpcTooltip(pin, tip)
    local id = pin.npc
    tip:SetText(N.Name(id), 1, 1, 1)
    local title = N.Title(id)
    if title ~= "" then tip:AddLine(title, 1, 0.82, 0) end
    local services = N.ServiceText(id)
    if services ~= "" then tip:AddLine(services, 0.7, 0.9, 1, true) end
    local level = N.Level(id)
    local rank = N.Rare(id) and (N.Elite(id) and L.RARE_ELITE or L.RARE) or (N.Elite(id) and L.ELITE or nil)
    if level ~= "" or rank then
        tip:AddLine(((level ~= "" and (LEVEL .. " " .. level) or "") .. (rank and ("  " .. rank) or "")), 0.8, 0.8, 0.8)
    end
    tip:AddLine(("%s  %s"):format(Geo.Name(pin.m), ns.Coords(pin.x, pin.y)), 0.6, 0.6, 0.6)
    local seen = not NPCS[id] and Seen(id)
    if seen and seen.by then tip:AddLine(L.FOUND_BY:format(seen.by), 0.6, 0.8, 1) end
    tip:AddLine(L.CTRL_NAVIGATE, 0.6, 0.6, 0.6)
end
N.Tooltip = NpcTooltip

local function NpcClick(pin, button)
    if button == "LeftButton" and (IsControlKeyDown() or pin.provider.name == "found") then
        ns.Waypoints.Add(pin.m, pin.x, pin.y, N.Name(pin.npc), { navigate = true, temp = true })
    end
end

function rares:Tooltip(pin, tip) NpcTooltip(pin, tip) end
function rares:OnClick(pin, button) NpcClick(pin, button) end

-- the NPC the search went to: a mark on every place it stands, until the next search
local found = ns.Pins.New("found", { level = 96, size = 26 })
local shown   -- the NPC marked

function found:OnCreate(pin)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    pin.ring:SetBlendMode("ADD")
    pin.ring:SetPoint("CENTER")
    pin.ring:SetSize(40, 40)
end

function found:Refresh()
    self:ReleaseAll()
    if not shown then return end
    for _, s in ipairs(N.Spawns(shown)) do
        local u, v = Geo.ToWorld(s[1], s[2], s[3])
        local pin = self:Acquire()
        pin.icon:SetAtlas("Waypoint-MapPin-Tracked")
        pin.icon:SetVertexColor(0.4, 1, 0.5)
        pin.npc, pin.m, pin.x, pin.y = shown, s[1], s[2], s[3]
        self:Place(pin, u, v)
    end
end

function found:Tooltip(pin, tip)
    NpcTooltip(pin, tip)
    tip:AddLine(L.FOUND_HINT, 0.6, 0.6, 0.6)
end

function found:OnClick(pin, button)
    if button == "RightButton" then
        N.Show(nil)
    else
        NpcClick(pin, button)
    end
end

-- mark an NPC (nil: clear the marks)
function N.Show(id)
    shown = id
    found:Update()
end

ns.On("ZMAP_OPTION", function(key) if key == "rares" then rares:Update() end end)
