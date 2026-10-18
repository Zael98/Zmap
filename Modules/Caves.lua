-- A cave's floors: when the cave you look at has more than one (Fargodeep Mine's lower mines, Blackrock
-- Mountain's depths...), a button for each along the map's bottom; the one shown lit.
local _, ns = ...

local bar, buttons = nil, {}
local shownFor   -- the cave the buttons are for (its first floor)

local function Paint(first)
    local current = ns.Art.CaveFloor(first)
    for _, b in ipairs(buttons) do
        if b:IsShown() then
            if b.id == current then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
end

local function Show(first)
    local floors = first and ns.Art.CaveFloors(first)
    if not floors or #floors < 2 then
        if bar then bar:Hide() end
        shownFor = nil
        return
    end
    if first == shownFor and bar:IsShown() then
        Paint(first)
        return
    end
    shownFor = first
    if not bar then
        local viewport = ns.Map.Frame().viewport
        bar = CreateFrame("Frame", nil, viewport)
        bar:SetHeight(24)
        bar:SetPoint("BOTTOM", 0, 8)
        bar:SetFrameLevel(viewport:GetFrameLevel() + 210)   -- (over the layers panel's level, under the top bar)
    end
    for _, b in ipairs(buttons) do b:Hide() end
    local x = 0
    for i, id in ipairs(floors) do
        local b = buttons[i]
        if not b then
            b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
            b:SetHeight(22)
            buttons[i] = b
        end
        b.id = id
        b:SetText(ns.Name(ns.CAVES[id][10]))
        b:SetWidth(math.min(180, (b:GetFontString() and b:GetFontString():GetStringWidth() or 80) + 24))
        b:ClearAllPoints()
        b:SetPoint("LEFT", bar, "LEFT", x, 0)
        b:SetScript("OnClick", function() ns.Art.SetCaveFloor(first, id) end)
        b:Show()
        x = x + b:GetWidth() + 4
    end
    bar:SetWidth(math.max(1, x - 4))
    bar:Show()
    Paint(first)
end

ns.On("ZMAP_CAVE", function(first) Show(first) end)
ns.On("ZMAP_HIDE", function() if bar then bar:Hide() end shownFor = nil end)

-- for the tests
function ns.CaveButtons()
    local out = {}
    for _, b in ipairs(buttons) do if b:IsShown() and bar:IsShown() then out[#out + 1] = b end end
    return out
end
