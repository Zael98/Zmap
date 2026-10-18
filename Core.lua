-- Zmap core: saved settings, the event hub every module listens on, slash commands and small helpers.
local ADDON, ns = ...
local L = ns.L

ns.ADDON = ADDON
ns.WORLD = 947   -- Azeroth's map: the whole stitched map lives in its 0..1 coordinates
ns.PREFIX = "|cff4fc3f7Zmap|r: "
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

function ns.Print(msg)
    print(ns.PREFIX .. msg)
end

-- An error in one module is reported (BugSack, the error frame) without stopping the others.
-- the last errors caught, for /zmap diag
ns.errors = {}
local function Note(err)
    table.insert(ns.errors, tostring(err))
    if #ns.errors > 10 then table.remove(ns.errors, 1) end
end

function ns.Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        Note(err)
        geterrorhandler()(err)
    end
    return ok, err
end

-- For what runs every frame (OnUpdate): each distinct error is reported once, not sixty times a second.
local reported = {}
function ns.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and not reported[err] then
            reported[err] = true
            Note(err)
            geterrorhandler()(err)
        end
    end
end

--------------------------------------------------------------------------------------------------------------
-- Events: game events and Zmap's own (ZMAP_*), dispatched to every listener
--------------------------------------------------------------------------------------------------------------

local hub = CreateFrame("Frame")
local listeners = {}

function ns.On(event, fn)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        if not event:find("^ZMAP_") then
            pcall(hub.RegisterEvent, hub, event)   -- (an event this client lacks is simply never heard)
        end
    end
    list[#list + 1] = fn
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do ns.Safe(list[i], ...) end
end

hub:SetScript("OnEvent", function(_, event, ...) ns.Fire(event, ...) end)

-- Runs fn once, `delay` seconds after the last call (bursts of events become one refresh).
function ns.Debounce(delay, fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, function()
            pending = false
            ns.Safe(fn)
        end)
    end
end

--------------------------------------------------------------------------------------------------------------
-- Saved settings
--------------------------------------------------------------------------------------------------------------

ns.DEFAULTS = {
    replaceMap = true,        -- M opens Zmap instead of Blizzard's map
    openOn = "player",        -- "player": on your zone; "last": where you left it
    unexplored = "dim",       -- areas you have not explored: "show", "dim" or "hide"
    minimap = true,           -- the minimap's terrain when zoomed in close
    iconScale = 1,
    fadeMoving = true,        -- the window fades while you move
    fadeAlpha = 0.55,
    -- layers
    labels = true, levels = true, flights = true, dungeons = true, transports = true,
    quests = true, group = true, guild = true, pins = true, herbs = false, ore = false, townsfolk = true, rares = true,
    available = true, trivial = false, objectives = true, objectiveAreas = true, minimapPins = true, harmonize = false, folkMine = true, rareAlert = true, caves = true,
    -- sharing (only with Zmap users of your guild or group)
    shareGuild = true,        -- your position on their map
    shareFinds = true,        -- herbs, ore and townsfolk you find
    -- navigation
    arrow = true,             -- the arrow on screen towards the waypoint
    corpseArrow = true,       -- when you die, the arrow points to your corpse
    flightTimer = true,       -- a timer while you fly
}

local function Merge(dst, defaults)
    for k, v in pairs(defaults) do
        if dst[k] == nil then dst[k] = v end
    end
end

function ns.Opt(key)
    local v = ns.db and ns.db.opt[key]
    if v == nil then return ns.DEFAULTS[key] end
    return v
end

function ns.SetOpt(key, value)
    ns.db.opt[key] = value
    ns.Fire("ZMAP_OPTION", key, value)
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    ZmapDB = type(ZmapDB) == "table" and ZmapDB or {}
    ZmapCharDB = type(ZmapCharDB) == "table" and ZmapCharDB or {}
    local db = ZmapDB
    db.opt = db.opt or {}
    Merge(db.opt, ns.DEFAULTS)
    db.pins = db.pins or {}            -- [id] = { m = uiMapID, x, y, name, note, color, t }
    db.nodes = db.nodes or {}          -- [uiMapID] = { { x, y, kind, name, n (times seen), t, by } }
    db.folk = db.folk or {}            -- [key] = { m, x, y, kind, name, sub, t, by }
    db.flights = db.flights or {}      -- ["from-to"] = seconds, measured
    db.window = db.window or {}
    ns.db = db
    ns.char = ZmapCharDB
    ns.Fire("ZMAP_DB")
end)

ns.On("PLAYER_LOGIN", function()
    if not ns.db.welcomed then
        ns.db.welcomed = true
        ns.Print(L.WELCOME)
    end
end)

--------------------------------------------------------------------------------------------------------------
-- Text helpers
--------------------------------------------------------------------------------------------------------------

-- "Páramos de Poniente" -> "paramos de poniente": what the search compares
local ACCENTS = {
    ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["ã"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e",
    ["ë"] = "e", ["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i", ["ó"] = "o", ["ò"] = "o", ["ô"] = "o",
    ["ö"] = "o", ["õ"] = "o", ["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ñ"] = "n", ["ç"] = "c",
    ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ñ"] = "n", ["Ü"] = "u",
}
function ns.Fold(text)
    return (text:gsub("[\195][\128-\191]", ACCENTS):lower())
end

-- The client's language among the data's (enUS, esES, esMX): the index into the data's name lists.
local LOCALE_INDEX = { esES = 2, esMX = 3, deDE = 4, frFR = 5, ptBR = 6, itIT = 7, ruRU = 8, koKR = 9, zhCN = 10, zhTW = 11 }
function ns.Name(names)
    if not names then return "?" end
    return names[LOCALE_INDEX[GetLocale()] or 1] or names[1]
end

function ns.Coords(x, y)
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

function ns.Duration(seconds)
    seconds = math.floor(seconds + 0.5)
    local floor = math.floor
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(floor(seconds / 3600), floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(floor(seconds / 60), seconds % 60)
end

function ns.ClassColor(classFile)
    local c = classFile and C_ClassColor and C_ClassColor.GetClassColor(classFile)
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

--------------------------------------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------------------------------------

local commands = {}
ns.commands = commands

SLASH_ZMAP1 = "/zmap"
SlashCmdList.ZMAP = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = ns.Fold(cmd or "")
    local fn = commands[cmd]
    if fn then
        fn(rest)
    elseif cmd == "" then
        ns.Map.Toggle()
    else
        ns.Print(L.HELP)
    end
end

commands.help = function() ns.Print(L.HELP) end
commands.ayuda = commands.help

-- the addon compartment (the minimap's addons button)
function Zmap_OnCompartmentClick(_, button)
    if button == "RightButton" then
        ns.OpenOptions()
    else
        ns.Map.Toggle()
    end
end
