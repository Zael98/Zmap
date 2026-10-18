-- The quests you carry, beside the map: each in its colour on the map, its objectives under it (those done in
-- grey; "ready to turn in" once finished). A click on one goes to its nearest objective, or to who takes it,
-- and sets the arrow there. The window's top bar shows and hides it; the wheel scrolls it.
local _, ns = ...
local L = ns.L
local QP = {}
ns.QuestPanel = QP

local ROW, WIDTH, TOP = 15, 250, 28
local panel
local rows = {}
local items = {}    -- what it lists: { text, r, g, b, quest, indent }
local offset = 0    -- the first item shown

local function Collect()
    wipe(items)
    for _, id in ipairs(ns.QuestMap.InLog()) do
        local c = ns.QuestMap.Color(id) or { 1, 1, 1 }
        items[#items + 1] = { ns.QuestMap.Title(id), c[1], c[2], c[3], id, 0 }
        if ns.QuestMap.IsFinished(id) then
            items[#items + 1] = { L.QUEST_READY, 0.4, 1, 0.4, id, 12 }
        else
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                if o.text and o.text ~= "" then
                    local grey = o.finished and 0.5 or 0.9
                    items[#items + 1] = { o.text, grey, grey, grey, id, 12 }
                end
            end
        end
    end
end

local function Visible()
    return math.max(1, math.floor((panel:GetHeight() - TOP - 6) / ROW))
end

local function Paint()
    local shown = Visible()
    offset = math.max(0, math.min(offset, #items - shown))
    for _, row in ipairs(rows) do row:Hide() end
    for k = 1, math.min(shown, #items - offset) do
        local item = items[offset + k]
        local row = rows[k]
        if not row then
            row = CreateFrame("Button", nil, panel)
            row:SetHeight(ROW)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetAllPoints()
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row:SetScript("OnClick", function(self)
                if self.quest and not ns.QuestMap.GoTo(self.quest) then ns.Print(L.QUEST_NOWHERE) end
            end)
            rows[k] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + item[6], -TOP - (k - 1) * ROW)
        row:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
        row.text:SetText(item[1])
        row.text:SetTextColor(item[2], item[3], item[4])
        row.quest = item[5]
        row:Show()
    end
    panel.empty:SetShown(#items == 0)
end

local function Refresh()
    if not (panel and panel:IsShown()) then return end
    Collect()
    local viewport = ns.Map.Frame().viewport
    panel:SetHeight(math.min(TOP + math.max(1, #items) * ROW + 8, viewport:GetHeight() * 0.55))
    panel.title:SetText(L.QUEST_PANEL:format(#ns.QuestMap.InLog()))
    Paint()
end

local function Create()
    local frame = ns.Map.Frame()
    panel = CreateFrame("Frame", nil, frame.viewport, "BackdropTemplate")
    panel:SetPoint("BOTTOMRIGHT", -6, 6)
    panel:SetWidth(WIDTH)
    panel:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        Paint()
    end)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
    panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -9)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() QP.Toggle(false) end)
    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("TOPLEFT", 10, -TOP)
    panel.empty:SetText(L.QUEST_PANEL_EMPTY)
    panel:Hide()
end

-- shown or hidden (nil: the other way round); remembered
function QP.Toggle(show)
    if not ns.Map.Frame() then return end
    if not panel then Create() end
    if show == nil then show = not panel:IsShown() end
    ns.db.questPanel = show
    panel:SetShown(show)
    Refresh()
end

-- for the tests: the lines listed
function QP.Lines()
    local out = {}
    for _, row in ipairs(rows) do
        if row:IsShown() and panel:IsShown() then out[#out + 1] = row.text:GetText() end
    end
    return out, panel and panel:IsShown()
end

ns.On("ZMAP_QUESTS", Refresh)   -- (the quest log changed: QuestMap.lua has taken it in)
ns.On("ZMAP_SHOW", function()
    if ns.db.questPanel then QP.Toggle(true) end
end)
