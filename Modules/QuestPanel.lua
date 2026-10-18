-- Your quest log on the map's right side, as Blizzard's map has it: the quests under their zone (the headers
-- fold), each with its icon (in progress, or ready to turn in), its colour on Zmap's map, a box to track it and
-- what is left of it. A click on one shows its details (what it is about, what it asks, its rewards) with Back,
-- Go there, Track, Share and Abandon; so does a click on its marks on the map. The top bar's Quests button shows
-- and hides it; the wheel scrolls it. The game's own words where it has them.
local _, ns = ...
local L = ns.L
local QP = {}
ns.QuestPanel = QP

local WIDTH, TOP, BOTTOM, PAD = 300, 30, 34, 8
QP.WIDTH = WIDTH
local GOLD = { 1, 0.82, 0 }
local panel, view, content, buttons
local pools = { header = {}, quest = {}, line = {}, text = {}, reward = {} }
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

--------------------------------------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------------------------------------

-- a zone's header, as the layers panel's: its name in gold, a line under it, the + / - that folds its quests
-- (Zmap's own: Blizzard's log keeps listing a folded header's quests)
local function HeaderRow()
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(20)
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
    b:SetScript("OnClick", function(self)
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
        if button == "RightButton" then QP.Menu(self, self.quest) else QP.Show(self.quest) end
    end)
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

local function Level(id, info)
    local level = info and info.level
    if not level or level == 0 then level = ns.QUESTS and ns.QUESTS[id] and ns.QUESTS[id][2] end
    return level and level > 0 and ("[" .. level .. "] ") or ""
end

local function ShowList()
    local y = 4
    local count, folded = 0, false
    local foldedSet = ns.db.questFolded or {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            local h = Take("header", HeaderRow)
            h:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
            h.y = y
            h:SetPoint("RIGHT", content, "RIGHT", -2, 0)
            h.title = info.title or ""
            h.text:SetText(h.title)
            folded = foldedSet[h.title] == true
            h.folded = folded
            h.fold:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            y = y + 24
        elseif info and info.questID and info.questID > 0 and not info.isHidden and folded then
            count = count + 1
        elseif info and info.questID and info.questID > 0 and not info.isHidden then
            local id = info.questID
            count = count + 1
            local q = Take("quest", QuestRow)
            q:SetPoint("TOPLEFT", content, "TOPLEFT", PAD - 4, -y)
            q.y = y
            q:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
            q.quest = id
            q.text:SetText(Level(id, info) .. ns.QuestMap.Title(id))
            q.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            SetIcon(q, id)
            local c = ns.QuestMap.Color(id)
            q.stripe:SetColorTexture(c and c[1] or 0.5, c and c[2] or 0.5, c and c[3] or 0.5, c and 1 or 0)
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
            y = y + 6
        end
    end
    if count == 0 then y = Text(y, L.QUEST_PANEL_EMPTY, "GameFontDisable") end
    panel.title:SetText(L.QUEST_PANEL:format(count))
    return y
end

--------------------------------------------------------------------------------------------------------------
-- A quest's details
--------------------------------------------------------------------------------------------------------------

local function RewardRow()
    local f = CreateFrame("Frame", nil, content)
    f:SetSize(WIDTH - 2 * PAD - 8, 30)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(28, 28)
    f.icon:SetPoint("LEFT")
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -1, 1)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.name:SetPoint("RIGHT")
    f.name:SetJustifyH("LEFT")
    return f
end

local function Reward(y, name, texture, count)
    local f = Take("reward", RewardRow)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    f.y = y
    f.icon:SetTexture(texture)
    f.count:SetText(count and count > 1 and count or "")
    f.name:SetText(name or "")
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
    local y = Text(4, Level(id, info) .. ns.QuestMap.Title(id), "GameFontNormalLarge", GOLD, 0, 10)
    if objectives and objectives ~= "" then y = Text(y, objectives, "GameFontHighlight", nil, 0, 8) end
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        if o.text and o.text ~= "" then
            local c = o.finished and { 0.5, 0.5, 0.5 } or { 1, 1, 1 }
            y = Text(y, "- " .. o.text, "GameFontHighlightSmall", c, 6, 2)
        end
    end
    if C_QuestLog.IsComplete(id) then y = Text(y, G("QUEST_WATCH_QUEST_READY", L.QUEST_READY), "GameFontNormal", { 0.4, 1, 0.4 }) end
    y = y + 8
    if description and description ~= "" then
        y = Text(y, G("QUEST_DESCRIPTION", "Description"), "GameFontNormal", GOLD)
        y = Text(y, description, "GameFontHighlight", nil, 0, 10)
    end
    if #rewards + #choices > 0 or money > 0 or xp > 0 then
        y = Text(y, G("REWARDS", "Rewards"), "GameFontNormal", GOLD)
        if #choices > 0 then
            y = Text(y, G("REWARD_CHOICES", "You will be able to choose one of these rewards:"), "GameFontHighlightSmall")
            for _, r in ipairs(choices) do y = Reward(y, r[1], r[2], r[3]) end
        end
        if #rewards > 0 then
            y = Text(y, #choices > 0 and G("REWARD_ITEMS", "You will also receive:") or G("REWARD_ITEMS_ONLY", "You will receive:"), "GameFontHighlightSmall")
            for _, r in ipairs(rewards) do y = Reward(y, r[1], r[2], r[3]) end
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

local function Create()
    local frame = ns.Map.Frame()
    panel = CreateFrame("Frame", nil, frame.viewport, "BackdropTemplate")
    panel:SetPoint("TOPRIGHT", -6, -6)
    panel:SetPoint("BOTTOMRIGHT", -6, 6)
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
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -9)
    -- folded away to a tab at the map's top right corner, as the layers panel to its top left
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
    tab:SetPoint("TOPRIGHT", -6, -6)
    tab:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
    tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tab:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
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
end

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

function QP.ToggleWatch(id)
    if not id then return end
    if C_QuestLog.GetQuestWatchType(id) ~= nil then C_QuestLog.RemoveQuestWatch(id) else C_QuestLog.AddQuestWatch(id) end
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
        local watched = C_QuestLog.GetQuestWatchType(id) ~= nil
        root:CreateButton(watched and G("UNTRACK_QUEST", "Untrack Quest") or G("TRACK_QUEST", "Track Quest"), function() QP.ToggleWatch(id) end)
        root:CreateButton(G("SHARE_QUEST", "Share Quest"), function() QP.Share(id) end)
        root:CreateButton(G("ABANDON_QUEST_ABBREV", "Abandon"), function() QP.Abandon(id) end)
    end)
end

-- for the tests: the texts shown, whether it is open, the quest shown
function QP.Lines()
    local out = {}
    if not QP.Shown() then return out, false end
    local items = {}
    for _, kind in ipairs({ "header", "quest", "text", "reward" }) do
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

ns.On("ZMAP_QUESTS", Paint)   -- (the quest log changed: QuestMap.lua has taken it in)
ns.On("QUEST_WATCH_LIST_CHANGED", Paint)
-- on the map from its opening (folded only if you fold it)
ns.On("ZMAP_SHOW", function() QP.Toggle(ns.db.questPanel ~= false) end)
