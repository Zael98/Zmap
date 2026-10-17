-- A dungeon's own map, over the world map: inside an instance when you open the map, or with a click on its
-- entrance. The game's pictures of it a floor at a time (Data/DungeonMaps.lua: Forever's tables have none, its
-- install has the pictures), its bosses in order beside it (numbered on the map where their place is known),
-- and back to the world map (the button, or a right-click).
local _, ns = ...
local L = ns.L
local D = {}
ns.Dungeon = D

local ART_W, ART_H, TILE = 1002, 668, 256
local LIST_W = 190
local view, art, title, back, list
local tiles, floorButtons, bossPins, bossRows = {}, {}, {}, {}
local current   -- { inst, floor, name }

local function Data(inst) return ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[inst] end

function D.Has(inst) return Data(inst) ~= nil end
function D.IsShown() return view ~= nil and view:IsShown() end

local function Layout()
    if not (view and current) then return end
    local vw, vh = view:GetSize()
    local s = math.min((vw - LIST_W - 16) / ART_W, (vh - 34) / ART_H)
    if not (s > 0) then return end
    art:SetSize(ART_W * s, ART_H * s)
    for i, tex in ipairs(tiles) do
        local row, col = math.floor((i - 1) / 4), (i - 1) % 4
        local w, h = math.min(TILE, ART_W - col * TILE), math.min(TILE, ART_H - row * TILE)
        tex:SetSize(w * s, h * s)
        tex:SetTexCoord(0, w / TILE, 0, h / TILE)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", art, "TOPLEFT", col * TILE * s, -row * TILE * s)
    end
    for _, pin in ipairs(bossPins) do
        if pin:IsShown() then
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", art, "TOPLEFT", pin.x * ART_W * s, -pin.y * ART_H * s)
        end
    end
end

local function BackOnRightClick(_, button) if button == "RightButton" then D.Close() end end

-- the bosses beside the map: on this floor in gold, elsewhere in white (a click goes to their floor), and those
-- whose place is not known in grey
local function PaintList()
    for i, row in ipairs(bossRows) do
        local boss = row:IsShown() and Data(current.inst).bosses[i]
        if boss then
            if boss[2] == 0 then
                row.text:SetTextColor(0.55, 0.55, 0.55)
            elseif boss[2] == current.floor then
                row.text:SetTextColor(1, 0.82, 0)
            else
                row.text:SetTextColor(1, 1, 1)
            end
        end
    end
end

local function ShowFloor(index)
    local d = Data(current.inst)
    local floor = d.floors[index]
    current.floor = index
    for i, fileID in ipairs(floor[1]) do
        tiles[i]:SetTexture(fileID, nil, nil, "TRILINEAR")
        tiles[i]:Show()
    end
    for _, pin in ipairs(bossPins) do pin:Hide() end
    local n = 0
    for i, boss in ipairs(d.bosses) do
        if boss[2] == index then
            n = n + 1
            local pin = bossPins[n]
            if not pin then
                pin = CreateFrame("Button", nil, art)
                pin:SetSize(22, 22)
                pin.icon = pin:CreateTexture(nil, "ARTWORK")
                pin.icon:SetAllPoints()
                pin.icon:SetAtlas("DungeonSkull")
                pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
                pin.label:SetShadowOffset(1, -1)
                pin:SetScript("OnMouseUp", BackOnRightClick)
                bossPins[n] = pin
            end
            pin.x, pin.y = boss[3], boss[4]
            pin.label:SetText(("%d. %s"):format(i, ns.Name(boss[1])))
            pin:Show()
        end
    end
    for i, b in ipairs(floorButtons) do
        if b:IsShown() then
            if i == index then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    local floorName = ns.Name(floor[2])
    title:SetText(current.name .. (#d.floors > 1 and floorName ~= "" and ("  ·  " .. floorName) or ""))
    PaintList()
    Layout()
end

local function Create(viewport)
    view = CreateFrame("Frame", nil, viewport)
    view:SetAllPoints(viewport)
    view:SetFrameLevel(viewport:GetFrameLevel() + 250)   -- (over the layers panel too)
    view:EnableMouse(true)       -- (the world map under it does not take the clicks)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function() end)
    view:SetScript("OnMouseUp", BackOnRightClick)
    view:Hide()
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 1)
    art = CreateFrame("Frame", nil, view)
    art:SetPoint("CENTER", -LIST_W / 2, -14)
    for i = 1, 12 do
        tiles[i] = art:CreateTexture(nil, "ARTWORK")
    end
    title = view:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    back = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
    back:SetSize(130, 22)
    back:SetPoint("TOPRIGHT", -6, -6)
    back:SetText(L.BACK_TO_WORLD)
    back:SetScript("OnClick", function() D.Close() end)
    local hint = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -8, 8)
    hint:SetText(L.DUNGEON_BACK_HINT)
    -- the bosses, down the right side
    list = CreateFrame("Frame", nil, view)
    list:SetPoint("TOPRIGHT", -8, -36)
    list:SetPoint("BOTTOMRIGHT", -8, 26)
    list:SetWidth(LIST_W)
    local head = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetText(L.BOSSES)
    list.head = head
    view:SetScript("OnSizeChanged", Layout)
end

-- to the floor where a boss stands (if its place is known)
function D.GoToBoss(i)
    local boss = current and Data(current.inst).bosses[i]
    if boss and boss[2] > 0 then ShowFloor(boss[2]) end
end

local function FillList()
    local bosses = Data(current.inst).bosses
    for _, row in ipairs(bossRows) do row:Hide() end
    for i, boss in ipairs(bosses) do
        local row = bossRows[i]
        if not row then
            row = CreateFrame("Button", nil, list)
            row:SetHeight(16)
            row:SetPoint("RIGHT", list, "RIGHT")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetAllPoints()
            row.text:SetJustifyH("LEFT")
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            bossRows[i] = row
        end
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -18 - (i - 1) * 16)
        row.text:SetText(("%d. %s"):format(i, ns.Name(boss[1])))
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then D.Close() else D.GoToBoss(i) end
        end)
        row:Show()
    end
    list.head:SetShown(#bosses > 0)
end

-- open an instance's map (its instance map ID, as GetInstanceInfo gives it); name: what to call it
function D.Open(inst, name)
    local d = Data(inst)
    if not d or not ns.Map.Frame() then return false end
    if not view then Create(ns.Map.Frame().viewport) end
    current = { inst = inst, name = name or "" }
    for _, b in ipairs(floorButtons) do b:Hide() end
    if #d.floors > 1 then
        local x = 10
        for i, floor in ipairs(d.floors) do
            local b = floorButtons[i]
            if not b then
                b = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
                b:SetHeight(20)
                floorButtons[i] = b
            end
            local label = ns.Name(floor[2])
            b:SetText(label ~= "" and label or tostring(i))
            b:SetWidth(math.min(170, (b:GetFontString() and b:GetFontString():GetStringWidth() or 60) + 24))
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", x, 6)
            x = x + b:GetWidth() + 4
            b:SetScript("OnClick", function() ShowFloor(i) end)
            b:Show()
        end
    end
    view:Show()
    FillList()
    ShowFloor(1)
    return true
end

function D.Close()
    if view then view:Hide() end
end

-- for the tests: the bosses listed, and the numbers on the floor shown
function D.Shown()
    local listed, placed = {}, {}
    for _, row in ipairs(bossRows) do if row:IsShown() then listed[#listed + 1] = row.text:GetText() end end
    for _, pin in ipairs(bossPins) do if pin:IsShown() then placed[#placed + 1] = pin.label:GetText() end end
    return listed, placed, current and current.floor
end

-- inside an instance, the map opens on it
ns.On("ZMAP_SHOW", function()
    if not IsInInstance() then
        D.Close()
        return
    end
    local name, _, _, _, _, _, _, inst = GetInstanceInfo()
    if inst and D.Has(inst) then D.Open(inst, name) end
end)
