-- Your quest log on the map's side, as Blizzard's map has it: the quests under their zone (the headers fold; a
-- right-click on one tracks or untracks all its quests), each with its icon (in progress, or ready to turn in),
-- its level in the colour of how hard it is for you, its tags (elite, group, dungeon), who of your group has it
-- too, its colour on Zmap's map, a box to track it and what is left of it. On top: how full the log is, a search
-- box, the order (by zone, by level, nearest first) and folding every zone at once. Hovering a quest makes its
-- marks stand out on the map; Shift-click links it in the chat. A click shows its details (what it is about,
-- what it asks, who takes it, your group's progress, its rewards with their tooltips) with Back, Go there,
-- Track, Share and Abandon; so does a click on its marks on the map. The top bar's Quests button shows and hides
-- it; the wheel scrolls it. Its size, side, background and the automatic tracking are options.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local QP = {}
ns.QuestPanel = QP

local WIDTH, TOP, BOTTOM, PAD = 300, 58, 34, 8
QP.WIDTH = WIDTH
local GOLD = { 1, 0.82, 0 }
local SORTS = { "zone", "level", "near" }
local panel, view, content, buttons, toolbar
local pools = { header = {}, quest = {}, line = {}, text = {}, reward = {}, link = {} }
local used = {}       -- [kind] = how many of the pool are in use
local scroll = 0      -- pixels scrolled
local shownQuest      -- the quest whose details are shown (nil: the list)

local function G(name, fallback)
    local s = _G[name]
    return type(s) == "string" and s ~= "" and s or fallback
end

local function Height(fs) return fs:GetStringHeight() or 12 end

-- the map to its nearest objective (or who takes it), and the arrow
local function GoTo(id)
    if not ns.QuestMap.GoTo(id) then ns.Print(L.QUEST_NOWHERE) end
end

-- the quest's link in the chat (Shift-click)
local function LinkQuest(id)
    local link = GetQuestLink and GetQuestLink(id)
    if not link then return false end
    if not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
    return true
end

local function SortName(mode)
    if mode == "level" then return L.QUEST_SORT_LEVEL elseif mode == "near" then return L.QUEST_SORT_NEAR end
    return L.QUEST_SORT_ZONE
end

--------------------------------------------------------------------------------------------------------------
-- What the log holds
--------------------------------------------------------------------------------------------------------------

-- the quests of your log in its order: { id, info, header }
local function LogEntries()
    local out, header = {}, ""
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            header = info.title or ""
        elseif info and info.questID and info.questID > 0 and not info.isHidden then
            out[#out + 1] = { id = info.questID, info = info, header = header }
        end
    end
    return out
end

local function MaxQuests()
    local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()
    return (type(max) == "number" and max > 0) and max or (type(MAX_QUESTS) == "number" and MAX_QUESTS) or 25
end

local function LevelOf(id, info)
    local level = info and info.level
    if not level or level == 0 then level = ns.QUESTS and ns.QUESTS[id] and ns.QUESTS[id][2] end
    return level and level > 0 and level or nil
end

local function Level(id, info)
    local level = LevelOf(id, info)
    return level and ("[" .. level .. "] ") or ""
end

-- the colour of how hard it is for you (grey, green, yellow, orange, red), as the map's levels
local function Difficulty(id, info)
    local level = LevelOf(id, info)
    if not level then return GOLD end
    return { ns.LevelColor(level) }
end

-- its tags in the game's words: elite, group, dungeon, raid...
local function Tags(id, info)
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(id)
    local name = tag and tag.tagName ~= "" and tag.tagName
    if not name and info and info.suggestedGroup and info.suggestedGroup > 1 then
        name = L.QUEST_GROUP_TAG:format(info.suggestedGroup)
    end
    return name and (" |cff9fd0ff(" .. name .. ")|r") or ""
end

-- who of your group has it too
local function Mates(id)
    local n = ns.QuestGroup and #ns.QuestGroup.For(id) or 0
    return n > 0 and (" |cff66ccff[+" .. n .. "]|r") or ""
end

-- yards to its next mark (nil: not on your continent, or nowhere known)
local function Yards(id)
    local mark = ns.QuestMap.Next(id)
    local u, v, m = Geo.UnitPosition("player")
    if not (mark and u and mark.m) or Geo.Instance(m) ~= Geo.Instance(mark.m) then return end
    return Geo.Yards(Geo.Instance(m), u, v, mark.u, mark.v)
end

local function Matches(e, query)
    if query == "" then return true end
    if ns.QuestMap.Title(e.id):lower():find(query, 1, true) then return true end
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(e.id) or {}) do
        if o.text and o.text:lower():find(query, 1, true) then return true end
    end
    return false
end

local function Query()
    local text = toolbar and toolbar.search:GetText() or ""
    return (text:gsub("^%s+", ""):gsub("%s+$", "")):lower()
end

--------------------------------------------------------------------------------------------------------------
-- Rows (pooled; laid out down the content, y going down)
--------------------------------------------------------------------------------------------------------------

local function Take(kind, make)
    used[kind] = (used[kind] or 0) + 1
    local row = pools[kind][used[kind]]
    if not row then
        row = make()
        pools[kind][used[kind]] = row
    end
    row:ClearAllPoints()
    row:Show()
    return row
end

local function ReleaseAll()
    for kind, pool in pairs(pools) do
        for _, row in ipairs(pool) do row:Hide() end
        used[kind] = 0
    end
end

local function TextRow()
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

-- a text down the content: font, colour, indent; the y below it
local function Text(y, text, font, color, indent, gap)
    local fs = Take("text", TextRow)
    fs:SetFontObject(font or "GameFontHighlight")
    fs:SetWidth(WIDTH - 2 * PAD - (indent or 0) - 8)
    fs:SetText(text)
    fs:SetTextColor(color and color[1] or 1, color and color[2] or 1, color and color[3] or 1)
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + (indent or 0), -y)
    fs.y = y
    return y + Height(fs) + (gap or 4)
end

-- a line you click (who takes the quest: the arrow there)
local function LinkRow()
    local b = CreateFrame("Button", nil, content)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("TOPLEFT", 0, 0)
    b.text:SetWidth(WIDTH - 2 * PAD - 8)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(true)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return b
end

local function Link(y, text, onClick)
    local b = Take("link", LinkRow)
    b.text:SetText(text)
    b.text:SetTextColor(0.55, 0.85, 1)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    b:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    local h = Height(b.text)
    b:SetHeight(h)
    b.y, b.onClick = y, onClick
    return y + h + 6
end

--------------------------------------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------------------------------------

-- a zone's header, as the layers panel's: its name in gold, a line under it, the + / - that folds its quests
-- (Zmap's own: Blizzard's log keeps listing a folded header's quests); right-click: track or untrack them all
local function HeaderRow()
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(20)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", 6, 1)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetPoint("BOTTOMLEFT", 4, 0)
    b.line:SetPoint("BOTTOMRIGHT", -4, 0)
    b.line:SetHeight(1)
    b.line:SetColorTexture(0.62, 0.55, 0.38, 0.45)
    b.fold = b:CreateTexture(nil, "OVERLAY")
    b.fold:SetSize(14, 14)
    b.fold:SetPoint("RIGHT", -6, 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return QP.HeaderMenu(self, self.title, self.quests) end
        ns.db.questFolded = ns.db.questFolded or {}
        ns.db.questFolded[self.title] = not ns.db.questFolded[self.title] or nil
        QP.Refresh()
    end)
    return b
end

local function QuestRow()
    local b = CreateFrame("Button", nil, content)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.stripe = b:CreateTexture(nil, "ARTWORK")
    b.stripe:SetPoint("TOPLEFT", 0, -2)
    b.stripe:SetSize(3, 16)
    b.poi = b:CreateTexture(nil, "ARTWORK")
    b.poi:SetPoint("TOPLEFT", 6, 0)
    b.poi:SetSize(20, 20)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER", b.poi, "CENTER")
    b.icon:SetSize(14, 14)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("TOPLEFT", 30, -3)
    b.text:SetWidth(WIDTH - 2 * PAD - 54)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(true)
    b.check = CreateFrame("Button", nil, b)
    b.check:SetSize(18, 18)
    b.check:SetPoint("TOPRIGHT", -2, -1)
    b.check.box = b.check:CreateTexture(nil, "ARTWORK")
    b.check.box:SetAllPoints()
    b.check.box:SetAtlas("checkbox-minimal")
    b.check.mark = b.check:CreateTexture(nil, "OVERLAY")
    b.check.mark:SetAllPoints()
    b.check.mark:SetAtlas("checkmark-minimal")
    b.check:SetScript("OnClick", function(self) QP.ToggleWatch(self:GetParent().quest) end)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and LinkQuest(self.quest) then return end
        if button == "RightButton" then QP.Menu(self, self.quest) else QP.Show(self.quest) end
    end)
    -- its marks stand out on the map while the mouse is on it
    b:SetScript("OnEnter", function(self) ns.QuestMap.Highlight(self.quest) end)
    b:SetScript("OnLeave", function() ns.QuestMap.Highlight(nil) end)
    return b
end

-- the quest's icon: ready to turn in, or in progress (Blizzard's own)
local function SetIcon(row, id)
    if C_QuestLog.IsComplete(id) then
        row.poi:SetTexture(nil)
        row.icon:SetAtlas("UI-QuestIcon-TurnIn-Normal")
        row.icon:SetSize(20, 20)
    else
        row.poi:SetAtlas("UI-QuestPoi-QuestNumber")
        row.icon:SetAtlas("Quest-In-Progress-Icon-yellow")
        row.icon:SetSize(14, 14)
    end
end

local function Quest(y, e, mode)
    local id, info = e.id, e.info
    local q = Take("quest", QuestRow)
    q:SetPoint("TOPLEFT", content, "TOPLEFT", PAD - 4, -y)
    q.y = y
    q:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    q.quest = id
    local away = mode == "near" and e.yards and (" |cff999999" .. L.YARDS:format(math.floor(e.yards + 0.5)) .. "|r") or ""
    q.text:SetText(Level(id, info) .. ns.QuestMap.Title(id) .. Tags(id, info) .. Mates(id) .. away)
    local c = Difficulty(id, info)
    q.text:SetTextColor(c[1], c[2], c[3])
    SetIcon(q, id)
    local color = ns.QuestMap.Color(id)
    q.stripe:SetColorTexture(color and color[1] or 0.5, color and color[2] or 0.5, color and color[3] or 0.5, color and 1 or 0)
    q.check.mark:SetShown(C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil)
    local h = math.max(20, Height(q.text) + 6)
    q:SetHeight(h)
    y = y + h
    -- what is left of it
    if C_QuestLog.IsComplete(id) then
        y = Text(y, "- " .. G("QUEST_WATCH_QUEST_READY", L.QUEST_READY), "GameFontHighlightSmall", { 0.4, 1, 0.4 }, 26)
    else
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
            if o.text and o.text ~= "" and not o.finished then
                y = Text(y, "- " .. o.text, "GameFontHighlightSmall", { 0.85, 0.85, 0.85 }, 26, 2)
            end
        end
    end
    return y + 6
end

local function ShowList()
    local y = 4
    local query, mode = Query(), ns.db.questSort or "zone"
    local entries = LogEntries()
    local shown = {}
    for _, e in ipairs(entries) do
        if Matches(e, query) then shown[#shown + 1] = e end
    end
    if mode == "level" then
        for _, e in ipairs(shown) do e.level = LevelOf(e.id, e.info) or 0 end
        table.sort(shown, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return ns.QuestMap.Title(a.id) < ns.QuestMap.Title(b.id)
        end)
    elseif mode == "near" then
        for _, e in ipairs(shown) do e.yards = Yards(e.id) end
        table.sort(shown, function(a, b)
            if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
            if a.yards and a.yards ~= b.yards then return a.yards < b.yards end
            return ns.QuestMap.Title(a.id) < ns.QuestMap.Title(b.id)
        end)
    end
    local foldedSet = ns.db.questFolded or {}
    local header, folded
    for _, e in ipairs(shown) do
        if mode == "zone" and e.header ~= (header and header.title) then
            header = Take("header", HeaderRow)
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
            header.y = y
            header:SetPoint("RIGHT", content, "RIGHT", -2, 0)
            header.title, header.quests = e.header, {}
            header.text:SetText(e.header)
            folded = foldedSet[e.header] == true and query == ""   -- (a search shows what it finds)
            header.fold:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            y = y + 24
        end
        if header then table.insert(header.quests, e.id) end
        if not (mode == "zone" and folded) then y = Quest(y, e, mode) end
    end
    if #shown == 0 then y = Text(y, #entries == 0 and L.QUEST_PANEL_EMPTY or L.QUEST_NO_MATCH, "GameFontDisable") end
    -- how full the log is: orange near the limit, red at it
    local count, max = #entries, MaxQuests()
    local color = count >= max and "ff4040" or count >= max - 2 and "ff9933" or "ffd100"
    panel.title:SetText(("|cff%s%s|r"):format(color, L.QUEST_PANEL_COUNT:format(count, max)))
    return y
end

--------------------------------------------------------------------------------------------------------------
-- A quest's details
--------------------------------------------------------------------------------------------------------------

local function RewardRow()
    local f = CreateFrame("Frame", nil, content)
    f:SetSize(WIDTH - 2 * PAD - 8, 30)
    f:EnableMouse(true)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(28, 28)
    f.icon:SetPoint("LEFT")
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -1, 1)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.name:SetPoint("RIGHT")
    f.name:SetJustifyH("LEFT")
    -- the item's tooltip (the game compares it with what you wear)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetQuestLogItem then
            GameTooltip:SetQuestLogItem(self.rewardKind, self.index, self.quest)
        else
            GameTooltip:SetText(self.name:GetText() or "")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

local function Reward(y, r, kind, index, id)
    local f = Take("reward", RewardRow)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    f.y = y
    f.icon:SetTexture(r[2])
    f.count:SetText(r[3] and r[3] > 1 and r[3] or "")
    f.name:SetText(r[1] or "")
    f.rewardKind, f.index, f.quest = kind, index, id
    return y + 32
end

-- the game's text of a quest of your log (it reads the selected quest: the selection is put back)
local function QuestText(id)
    local old = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    C_QuestLog.SetSelectedQuest(id)
    local description, objectives = GetQuestLogQuestText()
    local rewards, choices = {}, {}
    for i = 1, (GetNumQuestLogRewards and GetNumQuestLogRewards(id) or 0) do
        local name, texture, count = GetQuestLogRewardInfo(i, id)
        rewards[#rewards + 1] = { name, texture, count }
    end
    for i = 1, (GetNumQuestLogChoices and GetNumQuestLogChoices(id, true) or 0) do
        local name, texture, count = GetQuestLogChoiceInfo(i)
        choices[#choices + 1] = { name, texture, count }
    end
    local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(id) or 0
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(id) or 0
    if old and old ~= 0 then C_QuestLog.SetSelectedQuest(old) end
    return description, objectives, rewards, choices, money, xp
end

local function ShowDetails(id)
    local description, objectives, rewards, choices, money, xp = QuestText(id)
    local info = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo(C_QuestLog.GetLogIndexForQuestID(id) or 0)
    local y = Text(4, Level(id, info) .. ns.QuestMap.Title(id) .. Tags(id, info), "GameFontNormalLarge", Difficulty(id, info), 0, 10)
    if objectives and objectives ~= "" then y = Text(y, objectives, "GameFontHighlight", nil, 0, 8) end
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        if o.text and o.text ~= "" then
            local c = o.finished and { 0.5, 0.5, 0.5 } or { 1, 1, 1 }
            y = Text(y, "- " .. o.text, "GameFontHighlightSmall", c, 6, 2)
        end
    end
    if C_QuestLog.IsComplete(id) then y = Text(y, G("QUEST_WATCH_QUEST_READY", L.QUEST_READY), "GameFontNormal", { 0.4, 1, 0.4 }) end
    -- who takes it (a click: the arrow there)
    local taker = ns.QuestMap.TurnIn(id)
    if taker then
        y = Link(y + 4, L.QUEST_TURN_IN_AT:format(taker.name or "?", Geo.Name(taker.m) or "?"), function()
            ns.QuestMap.GoToTurnIn(id)
        end)
    end
    -- your group's progress on it
    local mates = ns.QuestGroup and ns.QuestGroup.For(id) or {}
    if #mates > 0 then
        y = Text(y + 4, L.QUEST_PARTY, "GameFontNormal", GOLD)
        for _, m in ipairs(mates) do
            if m.ready then
                y = Text(y, L.QUEST_PARTY_READY:format(m.name), "GameFontHighlightSmall", { 0.4, 1, 0.4 }, 6, 2)
            else
                y = Text(y, L.QUEST_PARTY_PROGRESS:format(m.name, m.done or 0, m.total or 0), "GameFontHighlightSmall", nil, 6, 2)
            end
        end
    end
    y = y + 8
    if description and description ~= "" then
        y = Text(y, G("QUEST_DESCRIPTION", "Description"), "GameFontNormal", GOLD)
        y = Text(y, description, "GameFontHighlight", nil, 0, 10)
    end
    if #rewards + #choices > 0 or money > 0 or xp > 0 then
        y = Text(y, G("REWARDS", "Rewards"), "GameFontNormal", GOLD)
        if #choices > 0 then
            y = Text(y, G("REWARD_CHOICES", "You will be able to choose one of these rewards:"), "GameFontHighlightSmall")
            for i, r in ipairs(choices) do y = Reward(y, r, "choice", i, id) end
        end
        if #rewards > 0 then
            y = Text(y, #choices > 0 and G("REWARD_ITEMS", "You will also receive:") or G("REWARD_ITEMS_ONLY", "You will receive:"), "GameFontHighlightSmall")
            for i, r in ipairs(rewards) do y = Reward(y, r, "reward", i, id) end
        end
        if money > 0 then y = Text(y, GetMoneyString and GetMoneyString(money) or tostring(money), "GameFontHighlight") end
        if xp > 0 then y = Text(y, G("EXPERIENCE_COLON", "Experience:") .. " " .. xp, "GameFontHighlight") end
    end
    panel.title:SetText(G("QUEST_LOG", "Quest Log"))
    -- the buttons: back, go there, track, share, abandon
    local watched = C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil
    buttons.track:SetText(watched and G("UNTRACK_QUEST_ABBREV", "Untrack") or G("TRACK_QUEST_ABBREV", "Track"))
    buttons.share:SetEnabled(not C_QuestLog.IsPushableQuest or C_QuestLog.IsPushableQuest(id))
    buttons.abandon:SetEnabled(not C_QuestLog.CanAbandonQuest or C_QuestLog.CanAbandonQuest(id))
    buttons.go:SetEnabled(ns.QuestMap.Next(id) ~= nil)
    return y
end

--------------------------------------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------------------------------------

local function Paint()
    if not (panel and panel:IsShown()) then return end
    ReleaseAll()
    if shownQuest and not (C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(shownQuest)) then
        shownQuest = nil   -- (no longer in the log)
    end
    local total = shownQuest and ShowDetails(shownQuest) or ShowList()
    for _, b in pairs(buttons) do b:SetShown(shownQuest ~= nil) end
    toolbar:SetShown(shownQuest == nil)
    toolbar.sort:SetText(SortName(ns.db.questSort))
    view:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, shownQuest and -30 or -TOP)
    view:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, shownQuest and BOTTOM or 6)
    local room = view:GetHeight() or 0
    scroll = math.max(0, math.min(scroll, total - room))
    content:SetHeight(math.max(total, 1))
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", view, "TOPLEFT", 0, scroll)
    content:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, scroll)
end
QP.Refresh = Paint

local function Button(text, onClick) return ns.Button(panel, text, 50, onClick) end

-- every zone folded, or (all folded already) every zone open
function QP.FoldAll()
    ns.db.questFolded = ns.db.questFolded or {}
    local zones, open = {}, false
    for _, e in ipairs(LogEntries()) do
        if not zones[e.header] then
            zones[e.header] = true
            if not ns.db.questFolded[e.header] then open = true end
        end
    end
    for zone in pairs(zones) do ns.db.questFolded[zone] = open or nil end
    Paint()
end

-- by zone, by level, nearest first (the next one)
function QP.CycleSort()
    local now, nextMode = ns.db.questSort or "zone", SORTS[1]
    for i, mode in ipairs(SORTS) do
        if mode == now then nextMode = SORTS[i % #SORTS + 1] end
    end
    ns.db.questSort = nextMode
    scroll = 0
    Paint()
end

-- where it goes: the map's right side, or its left one beside the layers panel; its background
local function Place()
    if not panel then return end
    local frame = ns.Map.Frame()
    local s = ns.Opt("questScale")
    panel:ClearAllPoints()
    panel.tab:ClearAllPoints()
    if ns.Opt("questSide") == "left" then
        local layers = frame.layersPanel
        local open = layers and layers:IsShown()
        local x = open and (layers:GetWidth() + 12) or 6
        panel:SetPoint("TOPLEFT", frame.viewport, "TOPLEFT", x / s, -6 / s)
        panel:SetPoint("BOTTOMLEFT", frame.viewport, "BOTTOMLEFT", x / s, 6 / s)
        panel.tab:SetPoint("TOPLEFT", frame.viewport, "TOPLEFT", (open and x or 96) / s, -6 / s)
    else
        panel:SetPoint("TOPRIGHT", frame.viewport, "TOPRIGHT", -6 / s, -6 / s)
        panel:SetPoint("BOTTOMRIGHT", frame.viewport, "BOTTOMRIGHT", -6 / s, 6 / s)
        panel.tab:SetPoint("TOPRIGHT", frame.viewport, "TOPRIGHT", -6 / s, -6 / s)
    end
    local alpha = ns.Opt("questAlpha")
    panel:SetBackdropColor(0.05, 0.05, 0.06, alpha)
    panel.tab:SetBackdropColor(0.05, 0.05, 0.06, alpha)
end

local function Create()
    local frame = ns.Map.Frame()
    panel = CreateFrame("Frame", nil, frame.viewport, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        scroll = scroll - delta * 40
        Paint()
    end)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -9)
    -- folded away to a tab at the map's corner, as the layers panel
    local fold = CreateFrame("Button", nil, panel)
    fold:SetSize(22, 22)
    fold:SetPoint("TOPRIGHT", -4, -4)
    fold:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    fold:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    fold:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    fold:SetScript("OnClick", function() QP.Toggle(false) end)
    panel.foldButton = fold
    local tab = CreateFrame("Button", nil, frame.viewport, "BackdropTemplate")
    tab:SetSize(92, 24)
    tab:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
    tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tab:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(16, 16)
    tab.icon:SetPoint("LEFT", 6, 0)
    tab.icon:SetAtlas("QuestNormal")
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 5, 0)
    tab.text:SetText(L.OPT_QUESTS)
    tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    tab:SetScript("OnClick", function() QP.Toggle(true) end)
    tab:Hide()
    panel.tab = tab
    frame.questsTab = tab
    frame.questsPanel = panel
    -- the list's bar: search, order, fold every zone
    toolbar = CreateFrame("Frame", nil, panel)
    toolbar:SetPoint("TOPLEFT", 8, -28)
    toolbar:SetPoint("TOPRIGHT", -8, -28)
    toolbar:SetHeight(22)
    toolbar.search = CreateFrame("EditBox", nil, toolbar, "SearchBoxTemplate")
    toolbar.search:SetSize(150, 20)
    toolbar.search:SetPoint("LEFT", 4, 0)
    toolbar.search:SetAutoFocus(false)
    if toolbar.search.Instructions then toolbar.search.Instructions:SetText(L.QUEST_SEARCH) end
    toolbar.search:HookScript("OnTextChanged", function()
        scroll = 0
        Paint()
    end)
    toolbar.fold = ns.Button(toolbar, "+/-", 30, QP.FoldAll, L.QUEST_FOLD_ALL)
    toolbar.fold:SetPoint("RIGHT", 0, 0)
    toolbar.sort = ns.Button(toolbar, SortName(ns.db.questSort), 76, QP.CycleSort, L.QUEST_SORT_TIP)
    toolbar.sort:SetPoint("RIGHT", toolbar.fold, "LEFT", -4, 0)
    view = CreateFrame("Frame", nil, panel)
    view:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -TOP)
    view:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 6)
    view:SetClipsChildren(true)
    content = CreateFrame("Frame", nil, view)
    content:SetPoint("TOPLEFT")
    content:SetPoint("TOPRIGHT")
    buttons = {
        back = Button(G("BACK", "Back"), function() QP.Show(nil) end),
        go = Button(L.QUEST_GO, function() GoTo(shownQuest) end),
        track = Button("", function() QP.ToggleWatch(shownQuest) end),
        share = Button(G("SHARE_QUEST_ABBREV", "Share"), function() QP.Share(shownQuest) end),
        abandon = Button(G("ABANDON_QUEST_ABBREV", "Abandon"), function() QP.Abandon(shownQuest) end),
    }
    local x, w = 6, (WIDTH - 12 - 4 * 3) / 5
    for _, key in ipairs({ "back", "go", "track", "share", "abandon" }) do
        buttons[key]:SetWidth(w)
        buttons[key]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 8)
        x = x + w + 3
    end
    panel:Hide()
    QP.ApplyScale()
end

-- its size (the option): the whole panel and its tab, text, icons and buttons alike
function QP.ApplyScale()
    if not panel then return end
    local s = ns.Opt("questScale")
    panel:SetScale(s)
    panel.tab:SetScale(s)
    Place()
    Paint()
end

-- how wide it is on the map's right side (the route panel goes on its left); 0 on the left side
function QP.Width()
    if ns.Opt("questSide") == "left" then return 0 end
    return WIDTH * ns.Opt("questScale")
end

ns.On("ZMAP_OPTION", function(key)
    if key == "questScale" or key == "questSide" then
        QP.ApplyScale()
        ns.Fire("ZMAP_PANELS")
    elseif key == "questAlpha" then
        Place()
    end
end)
-- (the layers panel opened or folded: on the left side, the log moves beside it)
ns.On("ZMAP_PANELS", function() if ns.Opt("questSide") == "left" then Place() end end)

-- shown or hidden (nil: the other way round); remembered
function QP.Toggle(show)
    if not ns.Map.Frame() then return end
    if not panel then Create() end
    if show == nil then show = not panel:IsShown() end
    ns.db.questPanel = show
    panel:SetShown(show)
    panel.tab:SetShown(not show)
    Paint()
    ns.Fire("ZMAP_PANELS")
end

function QP.Shown() return panel ~= nil and panel:IsShown() end

-- a quest's details (nil: back to the list), the log opened; the map goes to where it is
function QP.Show(id)
    if not ns.Map.Frame() then return end
    shownQuest, scroll = id, 0
    QP.Toggle(true)
    if id then
        local mark = ns.QuestMap.Next(id)
        if mark then ns.Map.GoTo(mark.u, mark.v, math.max(ns.Map.Zoom(), 6)) end
    end
end

-- the search box's text (the tests)
function QP.Search(text)
    if not toolbar then return end
    toolbar.search:SetText(text or "")
    scroll = 0
    Paint()
end

function QP.ToggleWatch(id)
    if not id then return end
    if C_QuestLog.GetQuestWatchType(id) ~= nil then C_QuestLog.RemoveQuestWatch(id) else C_QuestLog.AddQuestWatch(id) end
    Paint()
end

-- every quest of a zone tracked, or untracked
function QP.WatchAll(quests, on)
    for _, id in ipairs(quests or {}) do
        local watched = C_QuestLog.GetQuestWatchType(id) ~= nil
        if on and not watched then C_QuestLog.AddQuestWatch(id) elseif not on and watched then C_QuestLog.RemoveQuestWatch(id) end
    end
    Paint()
end

-- shared with your group, abandoned: as Blizzard's quest log does it (its own confirmation)
function QP.Share(id)
    if QuestMapQuestOptions_ShareQuest then
        QuestMapQuestOptions_ShareQuest(id)
    else
        QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(id))
    end
end

function QP.Abandon(id)
    if QuestMapQuestOptions_AbandonQuest then
        QuestMapQuestOptions_AbandonQuest(id)
        return
    end
    local old = C_QuestLog.GetSelectedQuest()
    C_QuestLog.SetSelectedQuest(id)
    C_QuestLog.SetAbandonQuest()
    StaticPopup_Show("ABANDON_QUEST", ns.QuestMap.Title(id))
    C_QuestLog.SetSelectedQuest(old)
end

-- right-click on a quest of the list
function QP.Menu(owner, id)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ns.QuestMap.Title(id))
        root:CreateButton(L.QUEST_GO, function() GoTo(id) end)
        if ns.QuestMap.TurnIn(id) then root:CreateButton(L.QUEST_GO_TURN_IN, function() ns.QuestMap.GoToTurnIn(id) end) end
        local watched = C_QuestLog.GetQuestWatchType(id) ~= nil
        root:CreateButton(watched and G("UNTRACK_QUEST", "Untrack Quest") or G("TRACK_QUEST", "Track Quest"), function() QP.ToggleWatch(id) end)
        if GetQuestLink then root:CreateButton(L.QUEST_LINK, function() LinkQuest(id) end) end
        root:CreateButton(G("SHARE_QUEST", "Share Quest"), function() QP.Share(id) end)
        root:CreateButton(G("ABANDON_QUEST_ABBREV", "Abandon"), function() QP.Abandon(id) end)
    end)
end

-- right-click on a zone: all its quests tracked or untracked
function QP.HeaderMenu(owner, title, quests)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        root:CreateButton(L.QUEST_TRACK_ZONE, function() QP.WatchAll(quests, true) end)
        root:CreateButton(L.QUEST_UNTRACK_ZONE, function() QP.WatchAll(quests, false) end)
    end)
end

-- for the tests: the texts shown, whether it is open, the quest shown
function QP.Lines()
    local out = {}
    if not QP.Shown() then return out, false end
    local items = {}
    for _, kind in ipairs({ "header", "quest", "text", "reward", "link" }) do
        for i = 1, used[kind] or 0 do
            local row = pools[kind][i]
            local fs = kind == "text" and row or kind == "reward" and row.name or row.text
            items[#items + 1] = { row.y, fs:GetText() }
        end
    end
    table.sort(items, function(a, b) return a[1] < b[1] end)
    for _, item in ipairs(items) do out[#out + 1] = item[2] end
    return out, true, shownQuest
end
function QP.Title() return panel and panel.title:GetText() end

--------------------------------------------------------------------------------------------------------------
-- Tracking by itself (options): a quest you take is tracked; one whose objectives are done is no longer
--------------------------------------------------------------------------------------------------------------

ns.On("QUEST_ACCEPTED", function(a, b)
    local id = b or a   -- (Blizzard's mainline: the quest; classic clients: its log index, then the quest)
    if ns.Opt("autoTrack") and type(id) == "number" and C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
end)

local wasDone   -- the quests ready to turn in last time (nil: not looked yet, nothing untracked the first time)
local function Untrack()
    local now = {}
    for _, e in ipairs(LogEntries()) do
        if C_QuestLog.IsComplete(e.id) then now[e.id] = true end
    end
    if wasDone and ns.Opt("autoUntrack") then
        for id in pairs(now) do
            if not wasDone[id] and C_QuestLog.GetQuestWatchType(id) ~= nil then C_QuestLog.RemoveQuestWatch(id) end
        end
    end
    wasDone = now
end
ns.On("QUEST_LOG_UPDATE", ns.Debounce(0.3, Untrack))

ns.On("ZMAP_QUESTS", Paint)   -- (the quest log changed: QuestMap.lua has taken it in; or your group's did)
ns.On("QUEST_WATCH_LIST_CHANGED", Paint)
-- on the map from its opening (folded only if you fold it)
ns.On("ZMAP_SHOW", function() QP.Toggle(ns.db.questPanel ~= false) end)
