-- A dungeon's or a battleground's own map, over the world map: inside an instance when you open the map, or with
-- a click on a dungeon's entrance. The game's pictures of it a floor at a time (Data/DungeonMaps.lua: Forever's
-- tables have none of the dungeons', its install has the pictures), a dungeon's bosses in order beside it
-- (numbered on the map where their place is known), and back to the world map (the button, or a right-click).
-- On a battleground, what the game says moves on it: your group (drawn by the game's own frame, which knows where
-- they are even where Lua is not told), its objectives (bases, towers, graveyards, in their owner's colours) and
-- the flags.
local _, ns = ...
local L = ns.L
local D = {}
ns.Dungeon = D

local ART_W, ART_H, TILE = 1002, 668, 256
local LIST_W = 190
local IsSecret = issecretvalue or function() return false end
local view, art, title, back, list
local tiles, overlayTex, floorButtons, bossPins, bossRows = {}, {}, {}, {}, {}
local current   -- { inst, floor, name }
local units     -- the game's group frame (false: this client has none)
local poiPins, flagPins = {}, {}

local function Data(inst) return ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[inst] end

function D.Has(inst) return Data(inst) ~= nil end
function D.IsShown() return view ~= nil and view:IsShown() end

-- the battleground's uiMap, while one is shown
local function LiveMap()
    return view and view:IsShown() and current and Data(current.inst).map
end

-- a pin at its place on the picture (x, y: 0..1 of it)
local function Place(pin)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", art, "TOPLEFT", pin.x * art:GetWidth(), -pin.y * art:GetHeight())
end

local function Layout()
    if not (view and current) then return end
    local listW = #Data(current.inst).bosses > 0 and LIST_W or 0
    local vw, vh = view:GetSize()
    local s = math.min((vw - listW - 16) / ART_W, (vh - 34) / ART_H)
    if not (s > 0) then return end
    art:ClearAllPoints()
    art:SetPoint("CENTER", -listW / 2, -14)
    art:SetSize(ART_W * s, ART_H * s)
    for i, tex in ipairs(tiles) do
        local row, col = math.floor((i - 1) / 4), (i - 1) % 4
        local w, h = math.min(TILE, ART_W - col * TILE), math.min(TILE, ART_H - row * TILE)
        tex:SetSize(w * s, h * s)
        tex:SetTexCoord(0, w / TILE, 0, h / TILE)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", art, "TOPLEFT", col * TILE * s, -row * TILE * s)
    end
    for _, tex in ipairs(overlayTex) do
        if tex:IsShown() then
            tex:SetSize(tex.w * s, tex.h * s)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", art, "TOPLEFT", tex.x * s, -tex.y * s)
        end
    end
    for _, pins in ipairs({ bossPins, poiPins, flagPins }) do
        for _, pin in ipairs(pins) do
            if pin:IsShown() then Place(pin) end
        end
    end
end

local function BackOnRightClick(_, button) if button == "RightButton" then D.Close() end end

local function FileSize(px)
    local s = 16
    while s < px do s = s * 2 end
    return s
end

-- a floor's overlays (a battleground's map is drawn whole), tiled as Blizzard's map tiles them
local function ShowOverlays(overlays)
    for _, tex in ipairs(overlayTex) do tex:Hide() end
    local n = 0
    for _, o in ipairs(overlays or {}) do
        local ow, oh, x, y = o[1], o[2], o[3], o[4]
        local cols, rows = math.ceil(ow / TILE), math.ceil(oh / TILE)
        for j = 1, rows do
            local ph = j < rows and TILE or (oh - TILE * (rows - 1))
            for k = 1, cols do
                local pw = k < cols and TILE or (ow - TILE * (cols - 1))
                local fileID = o[4 + (j - 1) * cols + k]
                if fileID then
                    n = n + 1
                    local tex = overlayTex[n] or art:CreateTexture(nil, "ARTWORK", nil, 1)
                    overlayTex[n] = tex
                    tex:SetTexture(fileID, nil, nil, "TRILINEAR")
                    tex:SetTexCoord(0, pw / (k < cols and TILE or FileSize(pw)), 0, ph / (j < rows and TILE or FileSize(ph)))
                    tex.x, tex.y, tex.w, tex.h = x + TILE * (k - 1), y + TILE * (j - 1), pw, ph
                    tex:Show()
                end
            end
        end
    end
end

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
    ShowOverlays(floor[3])
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

--------------------------------------------------------------------------------------------------------------
-- A battleground's live layer
--------------------------------------------------------------------------------------------------------------

local function PinTooltip(pin)
    if not pin.name then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(pin.name, 1, 1, 1)
    if pin.desc and pin.desc ~= "" then GameTooltip:AddLine(pin.desc, nil, nil, nil, true) end
    GameTooltip:Show()
end

local SIDE_COLOR = { A = { 0.35, 0.65, 1 }, H = { 1, 0.3, 0.25 } }

local function NewPin(size, level)
    local pin = CreateFrame("Button", nil, art)
    pin:SetSize(size, size)
    pin:SetFrameLevel(art:GetFrameLevel() + level)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
    pin.label:SetShadowOffset(1, -1)
    pin:SetScript("OnEnter", PinTooltip)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnMouseUp", BackOnRightClick)
    return pin
end

-- The objectives' states while you are in a battleground, heard with the map closed too (an objective's state
-- is a point of interest of its own): [its name] = { id, since (false: it was so when Zmap first saw it) }
local states, trackedMap = {}, nil
local function TrackObjectives()
    local _, kind, _, _, _, _, _, inst = GetInstanceInfo()
    local d = kind == "pvp" and inst and Data(inst)
    local map = d and d.map
    if map ~= trackedMap then
        wipe(states)
        trackedMap = map
    end
    if not (map and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then return end
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
        local key = info and info.name
        if key and not IsSecret(key) then
            local s = states[key]
            if not s then
                states[key] = { id = id, since = false }
            elseif s.id ~= id then
                s.id, s.since = id, GetTime()
            end
        end
    end
end

-- seconds until an assaulted objective falls (nil: not known, it was assaulted before Zmap saw it change)
local function TimeLeft(d, id, name)
    if C_AreaPoiInfo.GetAreaPOISecondsLeft then
        local s = C_AreaPoiInfo.GetAreaPOISecondsLeft(id)
        if s and not IsSecret(s) and s > 0 then return s end
    end
    local st = states[name]
    if st and st.id == id and st.since and d.capture then
        return math.max(0, d.capture - (GetTime() - st.since))
    end
end

-- the countdowns under the objectives in conflict, in the colour of who assaults
local function UpdateTimers()
    local d = current and Data(current.inst)
    for _, pin in ipairs(poiPins) do
        local left = pin:IsShown() and pin.side and TimeLeft(d, pin.poi, pin.name)
        if left and left > 0 then
            local c = SIDE_COLOR[pin.side]
            pin.label:SetText(("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)))
            pin.label:SetTextColor(c[1], c[2], c[3])
            pin.label:Show()
        else
            pin.label:Hide()
        end
    end
end

-- the objectives: the game's points of interest on the map, their icon showing who holds them
local function UpdatePOIs()
    for _, pin in ipairs(poiPins) do pin:Hide() end
    local map = LiveMap()
    if not (map and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then return end
    local conflicts = Data(current.inst).conflicts or {}
    local n = 0
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
        local x, y
        if info and info.position then x, y = info.position:GetXY() end
        if x and not IsSecret(x) and not IsSecret(y) then
            n = n + 1
            local pin = poiPins[n] or NewPin(20, 2)
            poiPins[n] = pin
            if info.atlasName then
                local atlas = info.atlasName
                if info.textureKit then atlas = (ATLAS_WITH_TEXTURE_KIT_PREFIX or "%s-%s"):format(info.textureKit, atlas) end
                pin.icon:SetAtlas(atlas)
            else
                pin.icon:SetTexture("Interface\\Minimap\\POIIcons")
                local coords = C_Minimap and C_Minimap.GetPOITextureCoords or GetPOITextureCoords
                pin.icon:SetTexCoord(coords(info.textureIndex or 0))
            end
            pin.name, pin.desc, pin.poi, pin.side = info.name, info.description, id, conflicts[id]
            pin.x, pin.y = x, y
            Place(pin)
            pin:Show()
        end
    end
    UpdateTimers()
end

-- who carries a flag: one of your faction's, an enemy (the game shows them as arena units); the enemies' one,
-- one of your group (its aura on them). name, class, or nil
local FLAG_AURAS = { 23333, 23335, 301089, 301091 }   -- Warsong Flag, Silverwing Flag, Horde Flag, Alliance Flag
local function Named(unit)
    local name = UnitName(unit)
    if name and not IsSecret(name) then return name, select(2, UnitClass(unit)) end
end
local function HasFlag(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return false end
    for _, spell in ipairs(FLAG_AURAS) do
        local name = C_Spell.GetSpellName(spell)
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name or "", "HELPFUL")
        if name and ok and aura then return true end
    end
    return false
end
local function Carrier(texture)
    local flag = type(texture) == "string" and (texture:find("Alliance") and "Alliance" or texture:find("Horde") and "Horde")
    if not flag then return end
    if flag == UnitFactionGroup("player") then
        for i = 1, 5 do
            if UnitExists("arena" .. i) then return Named("arena" .. i) end
        end
        return
    end
    if HasFlag("player") then return Named("player") end
    local prefix, count = IsInRaid() and "raid" or "party", IsInRaid() and 40 or 4
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and HasFlag(unit) then return Named(unit) end
    end
end

-- the flags (or what is carried like one), where they are or who carries them
local carrierWait = 0
local function UpdateFlags(elapsed)
    local map = LiveMap()
    local count = map and GetNumBattlefieldFlagPositions and GetNumBattlefieldFlagPositions() or 0
    carrierWait = carrierWait - (elapsed or 1)
    local carriers = carrierWait <= 0   -- (who carries them: once a second, they are looked for in the group)
    if carriers then carrierWait = 1 end
    for i = 1, math.max(count, #flagPins) do
        local x, y, texture
        if i <= count then x, y, texture = C_PvP.GetBattlefieldFlagPosition(i, map) end
        local pin = flagPins[i]
        if x and texture and not IsSecret(x) and not IsSecret(y) then
            pin = pin or NewPin(26, 4)
            flagPins[i] = pin
            pin.icon:SetTexture(texture)
            pin.x, pin.y = x, y
            if carriers then
                local name, class = Carrier(texture)
                pin.name = name
                local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                pin.label:SetText(name or "")
                pin.label:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
                pin.label:SetShown(name ~= nil)
            end
            Place(pin)
            pin:Show()
        elseif pin then
            pin:Hide()
        end
    end
end

-- your group: the game's own frame (Blizzard's map draws it with it), over the picture
local function Units()
    if units == nil then
        local ok, f = pcall(CreateFrame, "UnitPositionFrame", nil, art, "UnitPositionFrameTemplate")
        units = ok and f or false
        if units then
            units:SetAllPoints(art)
            units:SetFrameLevel(art:GetFrameLevel() + 6)
            units:SetPinSize("player", 26)
            units:SetPinSize("party", 12)
            units:SetPinSize("raid", 9)
            units:SetPinTexture("player", "UI-WorldMapArrow")
            units:SetMouseOverUnitExcluded("player", true)
        end
    end
    return units or nil
end

local flagWait = 0
local function LiveUpdate(_, elapsed)
    if units and units:IsShown() then
        units:UpdatePlayerPins()
        units:UpdateTooltips(GameTooltip)
    end
    flagWait = flagWait - elapsed
    if flagWait <= 0 then
        UpdateFlags(0.1 - flagWait)
        UpdateTimers()
        flagWait = 0.1
    end
end

local function StartLive()
    local map = LiveMap()
    local f = map and Units()
    if f then
        local hidden = C_Map.GetMapDisplayInfo and C_Map.GetMapDisplayInfo(map)
        f:SetUiMapID(map)
        f:SetNeedsFullUpdate()
        f:SetShown(not hidden)
    elseif units then
        units:Hide()
    end
    TrackObjectives()
    UpdatePOIs()
    flagWait, carrierWait = 0, 0
    UpdateFlags()
    view:SetScript("OnUpdate", map and ns.Guard(LiveUpdate) or nil)
end

ns.On("AREA_POIS_UPDATED", function()
    TrackObjectives()
    if LiveMap() then UpdatePOIs() end
end)
ns.On("PLAYER_ENTERING_WORLD", TrackObjectives)

-- for /zmap check: what the live layer shows (nil: no battleground's map shown)
function D.Live()
    if not LiveMap() then return end
    local pois, flags, timers, carriers = 0, 0, {}, {}
    for _, pin in ipairs(poiPins) do
        if pin:IsShown() then
            pois = pois + 1
            if pin.label:IsShown() then timers[#timers + 1] = pin.name .. " " .. pin.label:GetText() end
        end
    end
    for _, pin in ipairs(flagPins) do
        if pin:IsShown() then
            flags = flags + 1
            if pin.label:IsShown() then carriers[#carriers + 1] = pin.label:GetText() end
        end
    end
    return { units = units and units:IsShown() or false, pois = pois, flags = flags, timers = timers, carriers = carriers }
end

--------------------------------------------------------------------------------------------------------------

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
    back = ns.Button(view, L.BACK_TO_WORLD, 130, function() D.Close() end)
    back:SetPoint("TOPRIGHT", -6, -6)
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
                b = ns.Button(view, "", 80)
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
    StartLive()
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
