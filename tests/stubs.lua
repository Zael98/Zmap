-- WoW API stubs for Zmap's tests (Lua 5.1, run by tests/run.py). Widgets keep what is set on them, so a
-- scenario can open the map, zoom, click and read back what Zmap drew; game state (where the player is,
-- the clock, the cursor) lives in STATE, which the scenarios change.

STATE = {
    time = 1000, cursor = { 960, 540 }, locale = LOCALE or "esES",
    player = { inst = 0, wx = -9050, wy = -50, facing = 0, level = 12, class = "WARRIOR", faction = "Alliance" },
    group = {}, guild = true, combat = false, instance = false, ctrl = false, shift = false, moving = false,
    onTaxi = false, dead = false, ghost = false, explored = "half", printed = {}, errors = {}, sent = {},
    sounds = 0, chat = {}, menus = {}, tooltip = {}, bindings = {}, unknown = {}, timers = {},
}

local unknown = STATE.unknown
local function noop() end

--------------------------------------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------------------------------------

local Widget = {}
local WidgetMT = {}
local created = 0
ALL_WIDGETS = {}

-- methods the stubs do not model are no-ops (and listed in STATE.unknown); fields (Text, Instructions...)
-- stay nil like on a real widget
local VERBS = { "Set", "Get", "Is", "Enable", "Disable", "Register", "Unregister", "Create", "Clear", "Start",
    "Stop", "Add", "Raise", "Lower", "Has", "Highlight", "Lock", "Unlock" }
local EXACT = { Raise = true, Lower = true }
function WidgetMT.__index(t, k)
    local m = Widget[k]
    if m ~= nil then return m end
    if EXACT[k] then return noop end
    if type(k) == "string" then
        for _, verb in ipairs(VERBS) do
            if k:sub(1, #verb) == verb and k:sub(#verb + 1, #verb + 1):match("%u") then
                unknown[k] = (unknown[k] or 0) + 1
                return noop
            end
        end
    end
end

local function New(kind, parent, name)
    created = created + 1
    local w = setmetatable({ kind = kind, parent = parent, name = name, shown = true, alpha = 1, _scale = 1,
        points = {}, scripts = {}, children = {}, regions = {}, _level = parent and (parent._level or 0) + 1 or 0,
        id = created, text = "" }, WidgetMT)
    if parent then
        if kind == "Texture" or kind == "FontString" or kind == "MaskTexture" or kind == "Line" then
            table.insert(parent.regions, w)
        else
            table.insert(parent.children, w)
        end
    end
    if name then _G[name] = w end
    ALL_WIDGETS[#ALL_WIDGETS + 1] = w
    return w
end

function Widget:GetObjectType() return self.kind end
function Widget:GetName() return self.name end
function Widget:GetParent() return self.parent end
function Widget:IsVisible()
    local f = self
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
function Widget:IsShown() return self.shown end
function Widget:Show()
    local was = self:IsVisible()
    self.shown = true
    if not was and self:IsVisible() and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Widget:Hide()
    local was = self:IsVisible()
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:SetAlpha(a) self.alpha = a end
function Widget:GetAlpha() return self.alpha end
function Widget:SetScale(s)
    assert(type(s) == "number" and s > 0, "SetScale: scale must be > 0, got " .. tostring(s))
    self._scale = s
end
function Widget:GetScale() return self._scale end
function Widget:GetEffectiveScale()
    local s, f = 1, self
    while f do
        s = s * (f._scale or 1)
        f = f.parent
    end
    return s
end
function Widget:SetFrameLevel(l) self._level = l end
function Widget:GetFrameLevel() return self._level end
function Widget:SetFrameStrata(s) self.strata = s end
function Widget:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Widget:SetSize(w, h) self.w, self.h = w, h end
function Widget:SetWidth(w) self.w = w end
function Widget:SetHeight(h) self.h = h end
function Widget:SetPoint(point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "table" or type(a) == "string" and _G[a] then
        rel, relPoint, x, y = type(a) == "string" and _G[a] or a, b, c, d
        if type(relPoint) == "number" then relPoint, x, y = point, b, c end
    elseif type(a) == "number" then
        rel, relPoint, x, y = self.parent, point, a, b
    else
        rel, relPoint, x, y = self.parent, point, 0, 0
    end
    self.points[point] = { rel = rel or self.parent, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    self.all = nil
end
function Widget:ClearAllPoints() self.points = {}; self.all = nil end
function Widget:SetAllPoints(rel)
    if type(rel) == "string" then rel = _G[rel] end
    self.points = {}
    self.all = rel or self.parent
end
function Widget:GetPoint(i)
    for p, a in pairs(self.points) do return p, a.rel, a.relPoint, a.x, a.y end
end

-- where a frame is, in screen units: left, top, right, bottom (y up, like WoW)
function Widget:Rect()
    if self == UIParent then return 0, UIParent.h, UIParent.w, 0 end
    if self.all then return self.all:Rect() end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br then
        local l, t = tl.rel:Rect()
        local _, _, r, b = br.rel:Rect()
        return l + tl.x, t + tl.y, r + br.x, b + br.y
    end
    local w, h = self.w or 0, self.h or 0
    local p = self.points.CENTER or self.points.TOPLEFT or self.points.TOP
    if p then
        local l, t, r, b = p.rel:Rect()
        if self.points.CENTER then
            local cx, cy = (l + r) / 2 + p.x, (t + b) / 2 + p.y
            return cx - w / 2, cy + h / 2, cx + w / 2, cy - h / 2
        elseif self.points.TOP then
            local cx = (l + r) / 2 + p.x
            return cx - w / 2, t + p.y, cx + w / 2, t + p.y - h
        end
        return l + p.x, t + p.y, l + p.x + w, t + p.y - h
    end
    return 0, h, w, 0
end
function Widget:GetSize()
    if self.w and not self.all and not (self.points.TOPLEFT and self.points.BOTTOMRIGHT) then return self.w, self.h end
    if STATE.layoutPending then return 0, 0 end   -- (the game lays frames out after they are shown)
    local l, t, r, b = self:Rect()
    return r - l, t - b
end
function Widget:GetWidth() return (self:GetSize()) end
function Widget:GetHeight() return select(2, self:GetSize()) end
function Widget:GetLeft() return (self:Rect()) end
function Widget:GetTop() return select(2, self:Rect()) end
function Widget:SetScript(n, f) self.scripts[n] = f end
function Widget:GetScript(n) return self.scripts[n] end
function Widget:HookScript(n, f)
    local old = self.scripts[n]
    self.scripts[n] = function(...) if old then old(...) end f(...) end
end
function Widget:IsMouseOver() return self.mouseOver == true end
function Widget:RegisterEvent() end
function Widget:CreateTexture(name, layer, template, sub)
    local t = New("Texture", self, name)
    t.layer, t.sublevel = layer or "ARTWORK", sub or 0
    return t
end
function Widget:CreateMaskTexture() return New("MaskTexture", self) end
function Widget:CreateFontString(name, layer, template)
    local fs = New("FontString", self, name)
    fs.template = template
    return fs
end
function Widget:CreateLine(name, layer) local l = New("Line", self, name); l.layer = layer; return l end
-- textures
function Widget:SetTexture(file, wrapH, wrapV, filter) self.file = file; self.atlas = nil end
function Widget:SetAtlas(atlas) self.atlas = atlas; self.file = nil end
function Widget:GetAtlas() return self.atlas end
function Widget:GetTexture() return self.file end
function Widget:SetTexCoord(l, r, t, b) self.tc = { l, r, t, b } end
function Widget:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function Widget:SetColorTexture(r, g, b, a) self.color = { r, g, b, a or 1 }; self.file = "color" end
function Widget:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub or 0 end
function Widget:AddMaskTexture(mask) self.masks = self.masks or {}; table.insert(self.masks, mask) end
function Widget:SetRotation(r) self.rotation = r end
function Widget:SetDesaturation(d) self.desat = d end
function Widget:SetBlendMode(m) self.blend = m end
function Widget:SetStartPoint(_, rel, x, y) self.p1 = { x, y } end
function Widget:SetEndPoint(_, rel, x, y) self.p2 = { x, y } end
function Widget:SetThickness(t) self.thickness = t end
-- text
function Widget:SetText(t) self.text = t ~= nil and tostring(t) or "" end
function Widget:GetText() return self.text end
function Widget:SetFormattedText(f, ...) self.text = f:format(...) end
function Widget:SetTextColor(r, g, b) self.textColor = { r, g, b } end
-- buttons, edit boxes, check buttons, status bars
function Widget:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
function Widget:SetChecked(v) self.checked = v and true or false end
function Widget:GetChecked() return self.checked end
function Widget:SetFocus() self.focus = true; if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
function Widget:ClearFocus() self.focus = false; if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function Widget:HasFocus() return self.focus == true end
function Widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Widget:SetValue(v) self.value = v end
function Widget:GetNumPoints() local n = 0 for _ in pairs(self.points) do n = n + 1 end return n end

-- the edit box sends OnTextChanged like the game does when typed into
function TYPE(box, text)
    box.text = text
    if box.scripts.OnTextChanged then box.scripts.OnTextChanged(box, true) end
end

local TEMPLATES = {
    UICheckButtonTemplate = function(w) w.Text = w:CreateFontString(); w.text = nil end,
    SearchBoxTemplate = function(w) w.Instructions = w:CreateFontString() end,
    -- the game's group frame on a map (Blizzard's mixin over a native frame): what it was told, and its updates
    UnitPositionFrameTemplate = function(w)
        w.pinSizes, w.pinTextures, w.updates = {}, {}, 0
        function w:SetUiMapID(id) self.uiMapID = id end
        function w:GetUiMapID() return self.uiMapID end
        function w:SetNeedsFullUpdate() self.full = true end
        function w:UpdatePlayerPins() self.updates = self.updates + 1; self.full = false end
        function w:UpdateTooltips() end
        function w:SetPinSize(unit, size) self.pinSizes[unit] = size end
        function w:SetPinTexture(unit, texture) self.pinTextures[unit] = texture end
        function w:SetMouseOverUnitExcluded() end
    end,
}

function CreateFrame(kind, name, parent, template)
    local w = New(kind, parent or UIParent, name)
    if parent == nil and UIParent then w.parent = UIParent end
    if template then
        for t in template:gmatch("[^,%s]+") do if TEMPLATES[t] then TEMPLATES[t](w) end end
    end
    if kind == "EditBox" then w.text = "" end
    return w
end

UIParent = New("Frame", nil, "UIParent")
UIParent.w, UIParent.h = 1920, 1080
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
WorldMapFrame:Hide()
function HideUIPanel(f) f:Hide() end
-- a chat link clicked: the game's map opens on a map link
function SetItemRef(link)
    if tostring(link):match("^worldmap:") then WorldMapFrame:Show() end
end
GameTooltip = CreateFrame("Frame", "GameTooltip")
function GameTooltip:SetOwner() STATE.tooltip = {} end
function GameTooltip:SetText(t) STATE.tooltip = { tostring(t) } end
function GameTooltip:AddLine(t) table.insert(STATE.tooltip, tostring(t)) end
function GameTooltip_Hide() GameTooltip:Hide() end

--------------------------------------------------------------------------------------------------------------
-- Game state and plain functions
--------------------------------------------------------------------------------------------------------------

function GetTime() return STATE.time end
function time() return math.floor(STATE.time) end
function GetCursorPosition() return STATE.cursor[1], STATE.cursor[2] end
function GetLocale() return STATE.locale end
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end table.insert(STATE.printed, table.concat(t, " ")) end
function geterrorhandler() return function(e) table.insert(STATE.errors, tostring(e)) end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
function strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return unpack(out)
end
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
function PlaySound() STATE.sounds = STATE.sounds + 1 end
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
OKAY, CANCEL, LEVEL, DEAD = "Aceptar", "Cancelar", "Nivel", "Muerto"
UISpecialFrames = {}
SlashCmdList = SlashCmdList or {}
issecretvalue = nil

function InCombatLockdown() return STATE.combat end
function IsInInstance() return STATE.instance, STATE.instance and (STATE.instanceType or "party") or "none" end
function IsInGuild() return STATE.guild end
function IsInGroup() return #STATE.group > 0 end
function IsInRaid() return false end
function GetNumGroupMembers() return #STATE.group + 1 end
function GetNumSubgroupMembers() return #STATE.group end
function IsControlKeyDown() return STATE.ctrl end
function IsShiftKeyDown() return STATE.shift end
function IsPlayerMoving() return STATE.moving end
function UnitOnTaxi() return STATE.onTaxi end
function UnitIsGhost(u) return u == "player" and STATE.ghost end
function UnitIsDeadOrGhost(u) local m = STATE.group[tonumber((u or ""):match("%d+") or 0)] return m and m.dead or false end
-- other units the scenarios put around: STATE.units[token] = { id = npcID, name = "..." } (nameplates, mouseover)
STATE.units = {}
function UnitName(u)
    if u == "player" then return "Domi" end
    if u == "npc" then return STATE.npc and STATE.npc.name end
    if STATE.units[u] then return STATE.units[u].name end
    local m = STATE.group[tonumber((u or ""):match("%d+") or 0)]
    return m and m.name
end
function UnitGUID(u)
    if u == "npc" and STATE.npc then return "Creature-0-1-0-1-" .. STATE.npc.id .. "-0000" end
    if STATE.units[u] then return "Creature-0-1-0-1-" .. STATE.units[u].id .. "-0000" end
end
function UnitIsPlayer(u) return u == "player" end
function UnitClass(u)
    if u == "player" then return "Guerrero", STATE.player.class, STATE.player.classID or 1 end
    local m = STATE.group[tonumber((u or ""):match("%d+") or 0)]
    return "x", m and m.class or "MAGE"
end
function UnitRace(u) return "Humano", "Human", STATE.player.raceID or 1 end
function UnitLevel(u) return u == "player" and STATE.player.level or 20 end
function UnitFactionGroup() return STATE.player.faction end
function UnitExists(u) return u == "player" or STATE.units[u] ~= nil or STATE.group[tonumber((u or ""):match("%d+") or 0)] ~= nil end
function UnitIsUnit(a, b) return a == b end
function UnitInParty(name) for _, m in ipairs(STATE.group) do if m.name == name then return true end end return false end
function UnitInRaid() return nil end
function Ambiguate(name) return (name:gsub("%-.*", "")) end
function UnitPosition(u)
    if u ~= "player" or STATE.instance then return nil end
    return STATE.player.wx, STATE.player.wy, 0, STATE.player.inst
end
function GetPlayerFacing() return STATE.player.facing end
function CanMerchantRepair() return STATE.npc and STATE.npc.repair end
function IsTradeskillTrainer() return STATE.npc and STATE.npc.profession end
function GetBindingKey(action) if action == "TOGGLEWORLDMAP" then return "M" end end
function SetOverrideBindingClick(owner, prio, key, button) STATE.bindings[key] = button end
function ClearOverrideBindings() wipe(STATE.bindings) end
function ToggleWorldMap() STATE.blizzardMap = true end
function QuestMapFrame_OpenToQuestDetails(id) STATE.openedQuest = id end
function TakeTaxiNode(slot) STATE.tookSlot = slot end

C_Timer = {}
function C_Timer.After(d, fn) table.insert(STATE.timers, { at = STATE.time + d, fn = fn }) end
function C_Timer.NewTicker(d, fn)
    local t = { at = STATE.time + d, fn = fn, every = d }
    function t:Cancel()
        for i, x in ipairs(STATE.timers) do if x == self then table.remove(STATE.timers, i) break end end
        self.every = nil
    end
    table.insert(STATE.timers, t)
    return t
end
function CheckInteractDistance(unit) return STATE.units[unit] ~= nil and STATE.units[unit].near == true end
-- move the clock: due timers run (tickers again and again)
function ADVANCE(seconds)
    local target = STATE.time + seconds
    while true do
        table.sort(STATE.timers, function(a, b) return a.at < b.at end)
        local t = STATE.timers[1]
        if not t or t.at > target then break end
        STATE.time = t.at
        table.remove(STATE.timers, 1)
        if t.every then t.at = t.at + t.every; table.insert(STATE.timers, t) end
        t.fn()
    end
    STATE.time = target
end

C_AddOns = { GetAddOnMetadata = function() return "test" end, IsAddOnLoaded = function() return false end }
C_ClassColor = { GetClassColor = function() return { r = 0.78, g = 0.61, b = 0.43 } end }
-- spells: STATE.spells[id] = true (known), STATE.cooldowns[id] = { start, duration }
C_Spell = {
    GetSpellName = function(id)
        return ({ [2366] = "Recolectar hierbas", [2575] = "Minería", [133] = "Bola de Fuego", [3561] = "Teletransporte: Ventormenta",
            [3562] = "Teletransporte: Forjaz", [556] = "Llamada astral" })[id]
    end,
    IsSpellUsable = function(id) return (STATE.spells or {})[id] == true end,
    GetSpellCooldown = function(id)
        local c = (STATE.cooldowns or {})[id]
        return { startTime = c and c[1] or 0, duration = c and c[2] or 0, isEnabled = true }
    end,
}
function IsSpellKnown(id) return (STATE.spells or {})[id] == true end
-- your hearthstone: STATE.bind (where it takes you), STATE.items[id] = count, STATE.cooldowns[item]
function GetBindLocation() return STATE.bind end
C_Container = { GetItemCooldown = function(id)
    local c = (STATE.cooldowns or {})[id]
    if c then return c[1], c[2], 1 end
    return 0, 0, 1
end }
C_TooltipInfo = {
    GetUnit = function(unit)
        local who = STATE.units[unit]
        if who then return { lines = { { leftText = who.name }, { leftText = who.sub or "Nivel 30" } } } end
        return { lines = { { leftText = "x" }, { leftText = STATE.npc and STATE.npc.sub or "Nivel 30" } } }
    end,
    -- an NPC asked by its link: the game knows the names in STATE.cached (else nothing yet)
    GetHyperlink = function(link)
        STATE.asked = (STATE.asked or 0) + 1
        local id = tonumber(link:match("^unit:Creature%-0%-0%-0%-0%-(%d+)"))
        local name = id and STATE.cached and STATE.cached[id]
        -- (what the client does not have comes back empty; the server's answer is there next time)
        if not name and id and STATE.server and STATE.server[id] then
            STATE.cached = STATE.cached or {}
            STATE.cached[id] = STATE.server[id]
        end
        return { lines = name and { { leftText = name } } or {} }
    end,
}
C_GossipInfo = { GetOptions = function() return STATE.gossip or {} end }
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel, target)
        table.insert(STATE.sent, { prefix = prefix, msg = msg, channel = channel, target = target })
        return 0
    end,
}
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) STATE.superTracked = v end }
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
C_DeathInfo = { GetCorpseMapPosition = function(mapID) local c = STATE.corpse return c and c.map == mapID and { x = c.x, y = c.y } or nil end }

Enum = {
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
    FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 },
    PlayerInteractionType = { Gossip = 3, Merchant = 5, TaxiNode = 6, Trainer = 7, Banker = 8, MailInfo = 17,
        SpiritHealer = 18, Binder = 20, Auctioneer = 21, StableMaster = 22 },
}

ChatFrameUtil = {
    InsertLink = function(text) table.insert(STATE.chat, text) return true end,
    OpenChat = function(text) table.insert(STATE.chat, text) end,
}

-- the right-click menus: the scenario reads what they offer and picks an entry by its text
local Description = {}
Description.__index = Description
local function Desc(text, kind, fn, a, b) return setmetatable({ text = text, kind = kind, fn = fn, a = a, b = b, items = {} }, Description) end
function Description:CreateTitle(t) local d = Desc(t, "title") table.insert(self.items, d) return d end
function Description:CreateButton(t, fn) local d = Desc(t, "button", fn) table.insert(self.items, d) return d end
function Description:CreateCheckbox(t, get, set) local d = Desc(t, "check", set, get) table.insert(self.items, d) return d end
function Description:CreateRadio(t, get, set) local d = Desc(t, "radio", set, get) table.insert(self.items, d) return d end
function Description:CreateDivider() end
MenuUtil = {
    CreateContextMenu = function(owner, gen)
        local root = Desc("root", "root")
        gen(owner, root)
        STATE.menu = root
        table.insert(STATE.menus, root)
        return root
    end,
}
-- pick an entry of the last menu by (part of) its text, following submenus: PICK("Compartir", "Con mi hermandad")
function PICK(...)
    local node = STATE.menu
    for i = 1, select("#", ...) do
        local want = select(i, ...)
        local found
        for _, item in ipairs(node.items) do
            if item.text and item.text:find(want, 1, true) then found = item break end
        end
        assert(found, "menu has no entry '" .. want .. "'")
        node = found
    end
    assert(node.fn, "menu entry has no action")
    node.fn()
end
function MENU_TEXTS(node)
    local out = {}
    for _, item in ipairs((node or STATE.menu).items) do out[#out + 1] = item.text end
    return table.concat(out, " | ")
end

Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return { GetID = function() return 77 end, frame = frame } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) STATE.openedSettings = id end,
}

--------------------------------------------------------------------------------------------------------------
-- The map API, answered from Zmap's own data (ZNS: the addon's namespace, set once it has loaded)
--------------------------------------------------------------------------------------------------------------

local TYPES = { world = 1, continent = 2, zone = 3, city = 3 }
local CONT_OF = { [0] = 1415, [1] = 1414 }

-- the player's (u, v) on Azeroth's map
function PLAYER_UV()
    local T = ZNS.WORLD_TRANSFORM[STATE.player.inst]
    return T[1] + T[2] * STATE.player.wy, T[3] + T[4] * STATE.player.wx
end

-- the smallest zone (not city) of a continent holding a point
local function ZoneHolding(u, v, cont)
    local best, area
    for id, d in pairs(ZNS.MAPS) do
        local r = d[4]
        if d[1] == "zone" and (not cont or d[2] == cont) and u >= r[1] and u <= r[2] and v >= r[3] and v <= r[4] then
            local a = (r[2] - r[1]) * (r[4] - r[3])
            if not area or a < area then best, area = id, a end
        end
    end
    return best
end

C_Map = {}
function C_Map.GetMapInfo(id)
    local d = ZNS.MAPS[id]
    if not d then
        if id == 9999 then return { mapID = 9999, name = "Mazmorra", mapType = 4, parentMapID = 0 } end
        return nil
    end
    local names = d[6]
    return { mapID = id, name = (STATE.locale ~= "enUS" and names[2]) or names[1], mapType = TYPES[d[1]], parentMapID = d[2] }
end
function C_Map.GetBestMapForUnit(unit)
    if unit == "player" then
        if STATE.instance then return 9999 end
        local u, v = PLAYER_UV()
        return ZoneHolding(u, v)
    end
    local m = STATE.group[tonumber((unit or ""):match("%d+") or 0)]
    return m and m.map
end
function C_Map.GetPlayerMapPosition(mapID, unit)
    local d = ZNS.MAPS[mapID]
    if not d then return nil end
    local r = d[4]
    if unit == "player" then
        if STATE.instance then return nil end
        local u, v = PLAYER_UV()
        return { x = (u - r[1]) / (r[2] - r[1]), y = (v - r[3]) / (r[4] - r[3]) }
    end
    local m = STATE.group[tonumber((unit or ""):match("%d+") or 0)]
    if m and m.map == mapID then return { x = m.x, y = m.y } end
end
function C_Map.GetMapInfoAtPosition(cont, x, y)
    local r = ZNS.MAPS[cont][4]
    local id = ZoneHolding(r[1] + (r[2] - r[1]) * x, r[3] + (r[4] - r[3]) * y, cont)
    return C_Map.GetMapInfo(id or cont)
end
function C_Map.GetMapLevels(id) if id == 2548 then return 25, 32 end return 0, 0 end
function C_Map.CanSetUserWaypointOnMap() return true end
function C_Map.SetUserWaypoint(p) STATE.waypoint = p return true end
function C_Map.GetUserWaypoint() return STATE.waypoint end
function C_Map.ClearUserWaypoint() STATE.waypoint = nil end
function C_Map.GetUserWaypointHyperlink()
    local p = STATE.waypoint
    return p and ("|cffffff00|Hworldmap:%d:%d:%d|h[Map Pin Location]|h|r"):format(p.uiMapID, p.position.x * 10000, p.position.y * 10000)
end

C_MapExplorationInfo = {
    GetExploredMapTextures = function(mapID)
        local d = ZNS.MAPS[mapID]
        if not d or not d[7] or STATE.explored == "none" then return {} end
        local out = {}
        for i, o in ipairs(d[7]) do
            if STATE.explored == "all" or i % 2 == 1 then out[#out + 1] = { fileDataIDs = { o[6] } } end
        end
        return out
    end,
}

C_TaxiMap = {
    GetTaxiNodesForMap = function(mapID)
        local out = {}
        for id, n in pairs(ZNS.TAXI_NODES) do
            if CONT_OF[n[1]] == mapID then
                out[#out + 1] = { nodeID = id, name = n[5][2] or n[5][1], isUndiscovered = STATE.undiscovered and STATE.undiscovered[id] or false }
            end
        end
        return out
    end,
    GetAllTaxiNodes = function()
        local out, slot = {}, 0
        for id, n in pairs(ZNS.TAXI_NODES) do
            slot = slot + 1
            out[#out + 1] = { nodeID = id, slotIndex = id, name = n[5][1], state = id == STATE.taxiCurrent and 0 or 1 }
        end
        return out
    end,
}

C_EncounterJournal = {
    GetDungeonEntrancesForMap = function(mapID)
        if mapID == 1437 then
            return { { position = { x = 0.31, y = 0.42 }, name = "Excavation Site: Wetlands", description = "Nueva en Forever", atlasName = "Dungeon", journalInstanceID = 1 } }
        end
        return {}
    end,
}

C_QuestLog = {
    GetQuestsOnMap = function(mapID)
        if mapID == 1429 then
            return { { questID = 101, x = 0.42, y = 0.66, mapID = 1429 }, { questID = 102, x = 0.48, y = 0.42, mapID = 1429 } }
        end
        return {}
    end,
    GetTitleForQuestID = function(id) return ({ [101] = "Lobos en la linde", [102] = "El collar de Fargodeep" })[id] end,
    GetQuestObjectives = function(id) return { { text = "Lobo matado: 3/8", finished = false } } end,
    IsComplete = function(id) return id == 102 or (STATE.finished or {})[id] == true end,
    -- the log: STATE.log = { questID, ... } (default 101 and 102); STATE.completed = { questID, ... }
    GetNumQuestLogEntries = function() return #(STATE.log or { 101, 102 }) end,
    GetInfo = function(i)
        local id = (STATE.log or { 101, 102 })[i]
        return id and { questID = id, isHeader = false, title = "q" .. id }
    end,
    GetAllCompletedQuestIDs = function() return STATE.completed or {} end,
    RequestLoadQuestByID = function() end,
    GetLogIndexForQuestID = function(id) return id - 100 end,
}

function GetQuestGreenRange() return 8 end
-- professions: STATE.skills = { herb = 75, ore = 150 }
function GetProfessions()
    local sk = STATE.skills or {}
    return sk.herb and 1 or nil, sk.ore and 2 or nil
end
function GetProfessionInfo(i)
    local sk = STATE.skills or {}
    if i == 1 then return "Herboristería", 136065, sk.herb, 300, 0, 0, 182 end
    if i == 2 then return "Minería", 136248, sk.ore, 300, 0, 0, 186 end
end
C_Item = {
    GetItemCount = function(id) return (STATE.items or {})[id] or 0 end,
    GetItemNameByID = function(id) return "item" .. id end,
    GetItemIconByID = function(id) return 134000 + id % 100 end,
    RequestLoadItemDataByID = function() end,
}
-- the guild roster: STATE.roster = { { name, level, zone, online, class }, ... }
function GetNumGuildMembers() return #(STATE.roster or {}) end
function GetGuildRosterInfo(i)
    local r = STATE.roster[i]
    return r.name .. "-Forever", "Miembro", 2, r.level, "x", r.zone, "", "", r.online, 0, r.class
end
C_GuildInfo = { GuildRoster = function() STATE.rosterAsked = (STATE.rosterAsked or 0) + 1 end }
function GetInstanceInfo()
    if not STATE.instance then return "Azeroth", "none", 0, "", 5, 0, false, 0 end
    return STATE.instanceName or "Las Minas de la Muerte", STATE.instanceType or "party", 1, "Normal", 5, 0, false, STATE.instanceID or 36
end
-- a battleground's objectives: STATE.pois[uiMapID] = { { id, name, x, y, atlasName | textureIndex }, ... }
C_AreaPoiInfo = {
    GetAreaPOIForMap = function(map)
        local ids = {}
        for _, p in ipairs((STATE.pois or {})[map] or {}) do ids[#ids + 1] = p.id end
        return ids
    end,
    GetAreaPOIInfo = function(map, id)
        for _, p in ipairs((STATE.pois or {})[map] or {}) do
            if p.id == id then
                return { areaPoiID = id, name = p.name, description = p.desc, atlasName = p.atlasName, textureIndex = p.textureIndex,
                    position = { GetXY = function() return p.x, p.y end } }
            end
        end
    end,
}
C_Minimap = { GetPOITextureCoords = function(i) return 0, 0.125, 0, 0.125 end }
-- the flags: STATE.flags = { { x, y, texture } (x nil: not on the map), ... } on STATE.flagMap
function GetNumBattlefieldFlagPositions() return #(STATE.flags or {}) end
C_PvP = {
    GetBattlefieldFlagPosition = function(i, map)
        local f = STATE.flags[i]
        if map ~= STATE.flagMap or not f.x then return nil end
        return f.x, f.y, f.texture
    end,
}
function GetCVar(k) return STATE.cvars and STATE.cvars[k] end
function IsIndoors() return STATE.indoors end
function GetFramerate() return 60 end
function GetBuildInfo() return "1.60.1", "70374", "Oct 1 2026", 16001 end
function GetBindingAction(key) return key == "M" and "CLICK ZmapToggle:LeftButton" or "" end
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage() return collectgarbage("count") end
function UnitClassification(u) return STATE.units[u] and STATE.units[u].class or "normal" end
function UnitIsDead(u) return STATE.units[u] and STATE.units[u].dead or false end
