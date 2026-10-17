-- A dungeon's own map, over the world map: inside an instance when you open the map, or with a click on its
-- entrance. The game's pictures of it a floor at a time (Data/DungeonMaps.lua: Forever's tables have none, its
-- install has the pictures), its bosses, and back to the world map.
local _, ns = ...
local L = ns.L
local D = {}
ns.Dungeon = D

local ART_W, ART_H, TILE = 1002, 668, 256
local view, art, title, back
local tiles, floorButtons, bossPins = {}, {}, {}
local current   -- { inst, floor, name }

local function Floors(inst) return ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[inst] end

function D.Has(inst) return Floors(inst) ~= nil end
function D.IsShown() return view ~= nil and view:IsShown() end

local function Layout()
    if not (view and current) then return end
    local vw, vh = view:GetSize()
    local s = math.min(vw / ART_W, (vh - 34) / ART_H)
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

local function ShowFloor(index)
    local floors = Floors(current.inst)
    local floor = floors[index]
    current.floor = index
    for i, fileID in ipairs(floor[1]) do
        tiles[i]:SetTexture(fileID, nil, nil, "TRILINEAR")
        tiles[i]:Show()
    end
    for _, pin in ipairs(bossPins) do pin:Hide() end
    for i, boss in ipairs(floor[3]) do
        local pin = bossPins[i]
        if not pin then
            pin = CreateFrame("Button", nil, art)
            pin:SetSize(22, 22)
            pin.icon = pin:CreateTexture(nil, "ARTWORK")
            pin.icon:SetAllPoints()
            pin.icon:SetAtlas("DungeonSkull")
            pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
            pin.label:SetShadowOffset(1, -1)
            pin:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then D.Close() end end)
            bossPins[i] = pin
        end
        pin.x, pin.y = boss[2], boss[3]
        pin.label:SetText(ns.Name(boss[1]))
        pin:Show()
    end
    for i, b in ipairs(floorButtons) do
        if b:IsShown() then
            if i == index then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    local floorName = ns.Name(floor[2])
    title:SetText(current.name .. (#floors > 1 and floorName ~= "" and ("  ·  " .. floorName) or ""))
    Layout()
end

local function Create(viewport)
    view = CreateFrame("Frame", nil, viewport)
    view:SetAllPoints(viewport)
    view:SetFrameLevel(viewport:GetFrameLevel() + 150)
    view:EnableMouse(true)       -- (the world map under it does not take the clicks)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function() end)
    view:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then D.Close() end end)
    view:Hide()
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 1)
    art = CreateFrame("Frame", nil, view)
    art:SetPoint("CENTER", 0, -14)
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
    view:SetScript("OnSizeChanged", Layout)
end

-- open an instance's map (its instance map ID, as GetInstanceInfo gives it); name: what to call it
function D.Open(inst, name)
    local floors = Floors(inst)
    if not floors or not ns.Map.Frame() then return false end
    if not view then Create(ns.Map.Frame().viewport) end
    current = { inst = inst, name = name or "" }
    for i, b in ipairs(floorButtons) do b:Hide() end
    if #floors > 1 then
        local x = 10
        for i, floor in ipairs(floors) do
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
    ShowFloor(1)
    return true
end

function D.Close()
    if view then view:Hide() end
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
