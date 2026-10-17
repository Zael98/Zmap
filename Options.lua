-- Settings: the layers panel on the map's left side, and the full panel (Esc > Options > AddOns > Zmap, or
-- /zmap opciones).
local _, ns = ...
local L = ns.L

-- what the map shows, by group: { option, its text, icon (texture, or atlas = true), needs = a profession,
--   types = unfolds into the townsfolk's types }
local I = "Interface\\Icons\\"
local LAYERS = {
    { "labels", "OPT_LABELS", I .. "INV_Misc_Note_01", group = "LAYER_GROUP_MAP" },
    { "levels", "OPT_LEVELS", I .. "INV_Misc_Bone_Skull_01", group = "LAYER_GROUP_MAP" },
    { "minimap", "OPT_MINIMAP", I .. "INV_Misc_Spyglass_02", group = "LAYER_GROUP_MAP" },
    { "harmonize", "OPT_HARMONIZE", I .. "INV_Misc_Map_01", group = "LAYER_GROUP_MAP" },
    { "pins", "OPT_PINS", "Waypoint-MapPin-Untracked", atlas = true, group = "LAYER_GROUP_TRAVEL" },
    { "flights", "OPT_FLIGHTS", "TaxiNode_Neutral", atlas = true, group = "LAYER_GROUP_TRAVEL" },
    { "dungeons", "OPT_DUNGEONS", "Dungeon", atlas = true, group = "LAYER_GROUP_TRAVEL" },
    { "transports", "OPT_TRANSPORTS", I .. "INV_HordeZeppelinMount", group = "LAYER_GROUP_TRAVEL" },
    { "quests", "OPT_QUESTS", "QuestTurnin", atlas = true, group = "LAYER_GROUP_QUESTS" },
    { "available", "OPT_AVAILABLE", "QuestNormal", atlas = true, group = "LAYER_GROUP_QUESTS" },
    { "trivial", "OPT_TRIVIAL", "TrivialQuests", atlas = true, group = "LAYER_GROUP_QUESTS" },
    { "objectives", "OPT_OBJECTIVES", "WhiteCircle-RaidBlips", atlas = true, color = { 1, 0.35, 0.3 }, group = "LAYER_GROUP_QUESTS" },
    { "townsfolk", "OPT_TOWNSFOLK", I .. "INV_Misc_Coin_01", types = true, group = "LAYER_GROUP_PEOPLE" },
    { "rares", "OPT_RARES", "VignetteKill", atlas = true, group = "LAYER_GROUP_PEOPLE" },
    { "group", "OPT_GROUP", I .. "INV_Misc_GroupNeedMore", group = "LAYER_GROUP_PEOPLE" },
    { "guild", "OPT_GUILD", I .. "INV_Misc_Tournaments_Banner_Human", group = "LAYER_GROUP_PEOPLE" },
    { "herbs", "OPT_HERBS", I .. "INV_Misc_Herb_01", needs = "herb", group = "LAYER_GROUP_GATHER" },
    { "ore", "OPT_ORE", I .. "INV_Ore_Copper_01", needs = "ore", group = "LAYER_GROUP_GATHER" },
    { "minimapPins", "OPT_MINIMAP_PINS", I .. "INV_Letter_15", group = "LAYER_GROUP_MINIMAP" },
}
local UNEXPLORED = { "show", "dim", "hide" }

-- herbs and ore are only offered to whom has Herbalism or Mining
local function Offered(layer) return not layer.needs or ns.GatherSkill(layer.needs) ~= nil end

--------------------------------------------------------------------------------------------------------------
-- The layers panel: down the map's left side, a click on a layer turns it on or off; folded, a tab
--------------------------------------------------------------------------------------------------------------

local WIDTH, ROW, HEAD, INDENT = 196, 20, 18, 16
local CLASS_ICON = "Interface\\Minimap\\Tracking\\Class"
local side

local function Row(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 6, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    return b
end

local function Look(b, on, color)
    b.icon:SetDesaturated(not on)
    b.icon:SetAlpha(on and 1 or 0.45)
    if color and on then b.icon:SetVertexColor(color[1], color[2], color[3]) else b.icon:SetVertexColor(1, 1, 1) end
    if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.5, 0.5, 0.5) end
end

-- each row as its option stands: on in full colour, off greyed
local function Paint(b)
    if b.layer then
        Look(b, ns.Opt(b.layer[1]), b.layer.color)
    elseif b.option then
        Look(b, ns.Opt(b.option))
    elseif b.isAll then   -- (the townsfolk's "all" row: every type at once)
        Look(b, ns.Opt("townsfolk") and ns.AllFolkTypesShown())
    elseif b.cat then
        Look(b, ns.Opt("townsfolk") and ns.FolkTypeShown(b.cat))
    end
end

-- rows in place (herbs and ore come and go with the professions; the townsfolk's types unfold under them) and
-- as their options stand
local function Layout()
    if not side then return end
    local y = -4
    local function Put(b, indent)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", indent or 0, y)
        b:SetPoint("RIGHT", side.list, "RIGHT")
        b:Show()
        y = y - ROW
        Paint(b)
    end
    local lastGroup
    for _, h in pairs(side.heads) do h:Hide() end
    for _, b in ipairs(side.subs) do b:Hide() end
    for _, b in ipairs(side.rows) do
        local shown = Offered(b.layer)
        b:SetShown(shown)
        if shown then
            local g = b.layer.group
            if g ~= lastGroup then
                if lastGroup == "LAYER_GROUP_MAP" then Put(side.unexplored) end
                lastGroup = g
                local h = side.heads[g]
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 8, y - 4)
                h:Show()
                y = y - HEAD - 2
            end
            Put(b)
            if b.layer.types then
                local open = ns.db.window.folkOpen
                b.fold:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                if open then
                    for _, sub in ipairs(side.subs) do Put(sub, INDENT) end
                end
            end
        end
    end
    y = y - 6
    Put(side.more)
    side.unexplored.text:SetText(L.OPT_UNEXPLORED .. ": " .. L["UNEXPLORED_" .. ns.Opt("unexplored")])
    side.list:SetHeight(-y + 4)
end

local function SetOpen(open)
    ns.db.window.layers = open
    side:SetShown(open)
    side.tab:SetShown(not open)
    if open then Layout() end
end

local function CreateSide(frame)
    local viewport = frame.viewport
    side = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 6, -6)
    side:SetPoint("BOTTOMLEFT", 6, 6)
    side:SetWidth(WIDTH)
    side:SetFrameLevel(viewport:GetFrameLevel() + 200)   -- (over the map's icons, under the top bar)
    side:EnableMouse(true)
    side:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    side:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    side:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)

    local title = side:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText(L.LAYERS)
    local fold = CreateFrame("Button", nil, side)
    fold:SetSize(22, 22)
    fold:SetPoint("TOPRIGHT", -4, -4)
    fold:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    fold:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    fold:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    fold:SetScript("OnClick", function() SetOpen(false) end)
    side.foldButton = fold

    -- the list scrolls with the wheel when the window is too short for it
    local scroll = CreateFrame("ScrollFrame", nil, side)
    scroll:SetPoint("TOPLEFT", 4, -30)
    scroll:SetPoint("BOTTOMRIGHT", -4, 6)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(WIDTH - 8, 10)
    scroll:SetScrollChild(list)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, list:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(most, self:GetVerticalScroll() - delta * ROW * 2)))
    end)
    side.list = list

    side.heads, side.rows, side.subs = {}, {}, {}
    for _, layer in ipairs(LAYERS) do
        if not side.heads[layer.group] then
            local h = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h:SetText(L[layer.group])
            side.heads[layer.group] = h
        end
        local b = Row(list)
        b.layer = layer
        if layer.atlas then b.icon:SetAtlas(layer[3]) else b.icon:SetTexture(layer[3]) end
        b.text:SetText(L[layer[2]])
        if layer.types then
            -- a click unfolds its types, each turned on and off by itself
            b.fold = b:CreateTexture(nil, "OVERLAY")
            b.fold:SetSize(14, 14)
            b.fold:SetPoint("RIGHT", -4, 0)
            b.text:SetPoint("RIGHT", b.fold, "LEFT", -2, 0)
            b:SetScript("OnClick", function()
                ns.db.window.folkOpen = not ns.db.window.folkOpen
                Layout()
            end)
        else
            b:SetScript("OnClick", function(self)
                ns.SetOpt(layer[1], not ns.Opt(layer[1]))
                Paint(self)
            end)
        end
        side.rows[#side.rows + 1] = b
    end

    -- the townsfolk's types: "all" (every type on, or every type off), then one row each
    local all = Row(list)
    all.isAll = true
    all.icon:SetTexture(I .. "INV_Misc_Coin_01")
    all.text:SetText(L.FOLK_ALL)
    all:SetScript("OnClick", function()
        local on = not (ns.Opt("townsfolk") and ns.AllFolkTypesShown())
        ns.SetAllFolkTypes(on)
        if on and not ns.Opt("townsfolk") then ns.SetOpt("townsfolk", true) end
        Layout()
    end)
    side.subs[1] = all
    local only = Row(list)
    only.option = "folkMine"
    only.icon:SetTexture(CLASS_ICON)
    only.text:SetText(L.FOLK_MINE)
    only:SetScript("OnClick", function()
        ns.SetOpt("folkMine", not ns.Opt("folkMine"))
        Layout()
    end)
    side.subs[2] = only
    for _, t in ipairs(ns.FolkTypes()) do
        local b = Row(list)
        b.cat = t[1]
        if t.atlas then b.icon:SetAtlas(t[2]) else b.icon:SetTexture(t[2]) end
        b.text:SetText(L["FOLK_TYPE_" .. t[1]])
        b:SetScript("OnClick", function(self)
            -- (with the layer off, every type looks off: a click asks for this one alone)
            if not ns.Opt("townsfolk") then
                ns.SetAllFolkTypes(false)
                ns.SetFolkTypeShown(self.cat, true)
                ns.SetOpt("townsfolk", true)
            else
                ns.SetFolkTypeShown(self.cat, not ns.FolkTypeShown(self.cat))
            end
            Layout()
        end)
        side.subs[#side.subs + 1] = b
    end

    local unexplored = Row(list)
    unexplored.icon:SetTexture(I .. "INV_Misc_Map_01")
    unexplored:SetScript("OnClick", function()
        local now, nextMode = ns.Opt("unexplored"), UNEXPLORED[1]
        for i, mode in ipairs(UNEXPLORED) do
            if mode == now then nextMode = UNEXPLORED[i % #UNEXPLORED + 1] end
        end
        ns.SetOpt("unexplored", nextMode)
        Layout()
    end)
    side.unexplored = unexplored
    local more = Row(list)
    more.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    more.text:SetText(L.MORE_OPTIONS)
    more:SetScript("OnClick", function() ns.OpenOptions() end)
    side.more = more

    -- folded: a tab at the map's top left corner
    local tab = CreateFrame("Button", nil, viewport, "BackdropTemplate")
    tab:SetSize(84, 24)
    tab:SetPoint("TOPLEFT", 6, -6)
    tab:SetFrameLevel(viewport:GetFrameLevel() + 200)
    tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tab:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    tab:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(16, 16)
    tab.icon:SetPoint("LEFT", 6, 0)
    tab.icon:SetTexture(I .. "INV_Misc_Map_01")
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 5, 0)
    tab.text:SetText(L.LAYERS)
    tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    tab:SetScript("OnClick", function() SetOpen(true) end)
    side.tab = tab
    frame.layersButton = tab
    frame.layersPanel = side

    SetOpen(ns.db.window.layers ~= false)
end

ns.On("ZMAP_CREATED", CreateSide)
ns.On("ZMAP_OPTION", function() if side and side:IsShown() then Layout() end end)
ns.On("SKILL_LINES_CHANGED", function() if side and side:IsShown() then Layout() end end)
ns.On("ZMAP_SHOW", function() if side and side:IsShown() then Layout() end end)

-- for the tests: the texts of the layers the panel offers now
function ns.LayerTexts()
    local out = {}
    for _, b in ipairs(side and side.rows or {}) do
        if b:IsShown() then out[#out + 1] = b.text:GetText() end
    end
    return table.concat(out, " | ")
end

--------------------------------------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------------------------------------

local panel, category
local refreshers = {}

local function Header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Check(parent, key, label, x, y, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(26, 26)
    cb.Text:SetText(label)
    cb.Text:SetFontObject("GameFontHighlight")
    cb:SetScript("OnClick", function(self) ns.SetOpt(key, self:GetChecked() and true or false) end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tip, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    refreshers[#refreshers + 1] = function() cb:SetChecked(ns.Opt(key)) end
    return cb
end

-- a button that steps through choices: "Unexplored areas: Dimmed"
local function Cycle(parent, key, label, choices, names, x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(300, 22)
    b:SetPoint("TOPLEFT", x, y)
    local function Text()
        local v = ns.Opt(key)
        for i, c in ipairs(choices) do
            if c == v then return label .. ": " .. names[i] end
        end
        return label
    end
    b:SetScript("OnClick", function(self)
        local v, nextIndex = ns.Opt(key), 1
        for i, c in ipairs(choices) do
            if c == v then nextIndex = i % #choices + 1 end
        end
        ns.SetOpt(key, choices[nextIndex])
        self:SetText(Text())
    end)
    refreshers[#refreshers + 1] = function() b:SetText(Text()) end
    return b
end

-- a value with - and + : "Icon size 100%"
local function Stepper(parent, key, label, lo, hi, step, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x + 56, y - 4)
    local function Set(v)
        v = math.max(lo, math.min(hi, math.floor(v / step + 0.5) * step))
        ns.SetOpt(key, v)
        fs:SetText(("%s: %d%%"):format(label, math.floor(v * 100 + 0.5)))
    end
    local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minus:SetSize(24, 22)
    minus:SetPoint("TOPLEFT", x, y)
    minus:SetText("-")
    minus:SetScript("OnClick", function() Set(ns.Opt(key) - step) end)
    local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plus:SetSize(24, 22)
    plus:SetPoint("TOPLEFT", x + 26, y)
    plus:SetText("+")
    plus:SetScript("OnClick", function() Set(ns.Opt(key) + step) end)
    refreshers[#refreshers + 1] = function() fs:SetText(("%s: %d%%"):format(label, math.floor(ns.Opt(key) * 100 + 0.5))) end
end

local function Build()
    panel = CreateFrame("Frame")
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff4fc3f7Z|rmap  |cff888888" .. (C_AddOns and C_AddOns.GetAddOnMetadata("Zmap", "Version") or "") .. "|r")
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.OPTIONS_HINT)

    local y = -70
    Header(panel, L.OPT_SECTION_MAP, 16, y)
    Check(panel, "replaceMap", L.OPT_REPLACE, 16, y - 20, L.OPT_REPLACE_TIP)
    Check(panel, "fadeMoving", L.OPT_FADE, 16, y - 46, L.OPT_FADE_TIP)
    Cycle(panel, "openOn", L.OPT_OPEN_ON, { "player", "last" }, { L.OPEN_PLAYER, L.OPEN_LAST }, 20, y - 78)
    Cycle(panel, "unexplored", L.OPT_UNEXPLORED, UNEXPLORED,
        { L.UNEXPLORED_show, L.UNEXPLORED_dim, L.UNEXPLORED_hide }, 20, y - 104)
    Stepper(panel, "iconScale", L.OPT_ICON_SIZE, 0.6, 2, 0.1, 20, y - 132)
    Stepper(panel, "fadeAlpha", L.OPT_FADE_ALPHA, 0.2, 1, 0.05, 20, y - 158)

    y = -260
    Header(panel, L.OPT_SECTION_LAYERS, 16, y)
    -- (laid out each time the panel opens: herbs and ore come and go with the professions)
    local layerChecks = {}
    for i, layer in ipairs(LAYERS) do layerChecks[i] = Check(panel, layer[1], L[layer[2]], 0, 0) end
    refreshers[#refreshers + 1] = function()
        local n = 0
        for i, layer in ipairs(LAYERS) do
            local cb = layerChecks[i]
            cb:SetShown(Offered(layer))
            if Offered(layer) then
                local col, row = n % 3, math.floor(n / 3)
                cb:ClearAllPoints()
                cb:SetPoint("TOPLEFT", 16 + col * 200, -260 - 20 - row * 26)
                n = n + 1
            end
        end
    end

    y = -460 - 26
    Header(panel, L.OPT_SECTION_SHARE, 16, y)
    Check(panel, "shareGuild", L.OPT_SHARE_GUILD, 16, y - 20, L.OPT_SHARE_GUILD_TIP)
    Check(panel, "shareFinds", L.OPT_SHARE_FINDS, 16, y - 46, L.OPT_SHARE_FINDS_TIP)

    y = -576
    Header(panel, L.OPT_SECTION_NAV, 16, y)
    Check(panel, "arrow", L.OPT_ARROW, 16, y - 20, L.OPT_ARROW_TIP)
    Check(panel, "corpseArrow", L.OPT_CORPSE, 16, y - 46)
    Check(panel, "flightTimer", L.OPT_FLIGHT_TIMER, 16, y - 72)

    panel:SetScript("OnShow", function()
        for _, fn in ipairs(refreshers) do fn() end
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "Zmap")
        Settings.RegisterAddOnCategory(category)
    end
end

function ns.OpenOptions()
    if not panel then Build() end
    if category and Settings.OpenToCategory then
        if ns.Map.IsShown() and ns.db.window.full then ns.Map.Close() end   -- (the panel sits under a full-screen map)
        Settings.OpenToCategory(category:GetID())
    end
end

ns.On("PLAYER_LOGIN", function() if not panel then Build() end end)
ns.commands.opciones = ns.OpenOptions
ns.commands.options = ns.OpenOptions
ns.commands.config = ns.OpenOptions
