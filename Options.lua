-- Settings: the quick Layers menu on the map, and the full panel (Esc > Options > AddOns > Zmap, or
-- /zmap opciones).
local _, ns = ...
local L = ns.L

local LAYERS = {
    { "labels", "OPT_LABELS" }, { "levels", "OPT_LEVELS" }, { "flights", "OPT_FLIGHTS" }, { "dungeons", "OPT_DUNGEONS" },
    { "transports", "OPT_TRANSPORTS" }, { "quests", "OPT_QUESTS" }, { "group", "OPT_GROUP" }, { "guild", "OPT_GUILD" },
    { "pins", "OPT_PINS" }, { "herbs", "OPT_HERBS" }, { "ore", "OPT_ORE" }, { "townsfolk", "OPT_TOWNSFOLK" },
    { "rares", "OPT_RARES" }, { "minimap", "OPT_MINIMAP" },
}
local UNEXPLORED = { "show", "dim", "hide" }

function ns.LayersMenu(owner)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.LAYERS)
        for _, layer in ipairs(LAYERS) do
            local key = layer[1]
            root:CreateCheckbox(L[layer[2]], function() return ns.Opt(key) end, function() ns.SetOpt(key, not ns.Opt(key)) end)
        end
        local sub = root:CreateButton(L.OPT_UNEXPLORED)
        for _, mode in ipairs(UNEXPLORED) do
            sub:CreateRadio(L["UNEXPLORED_" .. mode], function() return ns.Opt("unexplored") == mode end, function()
                ns.SetOpt("unexplored", mode)
            end)
        end
        root:CreateDivider()
        root:CreateButton(L.MORE_OPTIONS, function() ns.OpenOptions() end)
    end)
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
    for i, layer in ipairs(LAYERS) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        Check(panel, layer[1], L[layer[2]], 16 + col * 200, y - 20 - row * 26)
    end

    y = -410
    Header(panel, L.OPT_SECTION_SHARE, 16, y)
    Check(panel, "shareGuild", L.OPT_SHARE_GUILD, 16, y - 20, L.OPT_SHARE_GUILD_TIP)
    Check(panel, "shareFinds", L.OPT_SHARE_FINDS, 16, y - 46, L.OPT_SHARE_FINDS_TIP)

    y = -500
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
