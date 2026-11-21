-- DungeonJournal (ForeverDungeonJournal, by Exehn), when it is installed: Zmap opens it on a dungeon's page (its
-- bosses, their loot, its quests), from the dungeon's mark on the map (Shift+click) and from the dungeon's own map.
-- Only through what DungeonJournal offers other code: its namespace (_G.ForeverDungeonJournal_NS), its own name
-- matching (DungeonFromInstanceName, LocalizeDungeonName), ToggleJournal, and OpenSearchResult, which its item search
-- uses to open a dungeon on its bosses. Nothing of DungeonJournal is copied into Zmap.
local _, ns = ...
local J = {}
ns.Journal = J

local function DJ()
    local dj = _G.ForeverDungeonJournal_NS
    if type(dj) == "table" and type(dj.OpenSearchResult) == "function" and type(dj.DB) == "table" then return dj end
end

function J.Available() return DJ() ~= nil end

local function Bare(name)
    return (tostring(name or ""):lower():gsub("^the%s+", ""):gsub("[%s%p]", ""))
end

-- DungeonJournal's page for a dungeon: by its English name (the data's), else the name shown (your language), else the
-- first page of a dungeon with wings (Scarlet Monastery: its Graveyard; Blackrock Spire: its lower part)
function J.Page(englishName, shownName)
    local dj = DJ()
    if not dj then return end
    for _, name in ipairs({ englishName, shownName }) do
        if type(name) == "string" and name ~= "" then
            local ok, page = pcall(dj.DungeonFromInstanceName or function() end, name)
            if ok and page and dj.DB[page] then return page end
        end
    end
    local order = type(dj.ORDER) == "table" and dj.ORDER or {}
    local localize = type(dj.LocalizeDungeonName) == "function" and dj.LocalizeDungeonName or nil
    if shownName and localize then
        local wanted = ns.Fold(shownName)
        for _, page in ipairs(order) do
            local ok, local_ = pcall(localize, page)
            if ok and type(local_) == "string" and ns.Fold(local_) == wanted and dj.DB[page] then return page end
        end
    end
    for _, name in ipairs({ englishName, shownName }) do
        local bare = Bare(name)
        if #bare > 3 then
            for _, page in ipairs(order) do
                if dj.DB[page] and Bare(page):find(bare, 1, true) then return page end
            end
        end
    end
end

-- DungeonJournal open on that page, on its bosses
function J.Open(page)
    local dj = DJ()
    if not (dj and page and dj.DB[page]) then return false end
    local frame = _G.ForeverDungeonJournalFrame
    if not (frame and frame:IsShown()) and type(dj.ToggleJournal) == "function" then pcall(dj.ToggleJournal) end
    return (pcall(dj.OpenSearchResult, { dungeonName = page, kind = "boss" }))
end

-- the data's English name of a dungeon (instance map)
function J.EnglishName(inst)
    for _, d in ipairs(ns.DUNGEONS or {}) do
        if d[1] == inst then return d[7] and d[7][1] end
    end
end
