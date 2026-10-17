-- The Zmap window: a viewport onto the stitched map (Art.lua draws it, Pins.lua puts things on it). The
-- wheel zooms at the cursor, dragging pans, a double click zooms in; around it, the bar of buttons and
-- the coordinates.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local Map = {}
ns.Map = Map

local W, H = Geo.W, Geo.H
local MIN_ZOOM, MAX_ZOOM = 0.8, 64
local WHEEL = 1.35           -- zoom per wheel notch
local EASE = 14              -- how fast the zoom eases towards its goal (per second)
local GLIDE = 0.5            -- seconds a "go there" takes
local HEADER, FOOTER = 34, 22
local CLICK_PX = 4           -- a press that moves less than this is a click, not a drag
local SEA = { 0.31, 0.31, 0.27 }   -- under the art: a muted parchment sea where nothing is drawn

local frame, viewport, canvas, grip
local view = { x = W / 2, y = H / 2, z = 1 }
local zoomGoal               -- { z, ax, ay (world point held still), px, py (where it stays in the viewport) }
local glide                  -- { x0, y0, z0, x1, y1, z1, t }
local drag                   -- { px, py, x, y, moved }
local lastClick = 0
local following = false
local viewDirty, sinceView, sinceTick = false, 0, 0
local lastK

--------------------------------------------------------------------------------------------------------------
-- The view
--------------------------------------------------------------------------------------------------------------

-- the viewport's size; before the game has laid it out (the first show), the window's less its bars
local function ViewSize()
    local vw, vh = viewport:GetSize()
    if not (vw and vw >= 1 and vh and vh >= 1) then
        local fw, fh = frame:GetSize()
        if not (fw and fw >= 1) then fw, fh = UIParent:GetSize() end
        vw, vh = fw - 12, fh - HEADER - FOOTER
    end
    return vw, vh
end

local function Fit()
    local vw, vh = ViewSize()
    return math.min(vw / W, vh / H)
end

-- viewport units per world unit
function Map.K() return Fit() * view.z end
function Map.Zoom() return view.z end
function Map.Canvas() return canvas end
function Map.IsShown() return frame ~= nil and frame:IsShown() end
function Map.Frame() return frame end

-- the part of the map in view, in world units: left, top, right, bottom
function Map.ViewRect()
    local vw, vh = ViewSize()
    local k = Map.K()
    local hw, hh = vw / (2 * k), vh / (2 * k)
    return view.x - hw, view.y - hh, view.x + hw, view.y + hh
end

-- the cursor: in the viewport (its units from the top left), then on the map (world units)
local function Cursor()
    local cx, cy = GetCursorPosition()
    local s = viewport:GetEffectiveScale()
    local px, py = cx / s - viewport:GetLeft(), viewport:GetTop() - cy / s
    local vw, vh = ViewSize()
    local k = Map.K()
    return px, py, view.x + (px - vw / 2) / k, view.y + (py - vh / 2) / k
end

function Map.CursorUV()
    local _, _, x, y = Cursor()
    return x / W, y / H
end

local function ApplyView()
    view.z = math.max(MIN_ZOOM, math.min(MAX_ZOOM, view.z))
    view.x = math.max(-0.2 * W, math.min(1.2 * W, view.x))
    view.y = math.max(-0.2 * H, math.min(1.2 * H, view.y))
    local vw, vh = ViewSize()
    local k = Map.K()
    if not (k > 0) then return end   -- (not laid out yet)
    canvas:SetScale(k)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", vw / (2 * k) - view.x, -(vh / (2 * k) - view.y))
    if k ~= lastK then
        lastK = k
        ns.Pins.Layout()   -- right away: icons keep their size on screen as the canvas scales
    end
    viewDirty = true
end

function Map.SetView(x, y, z)
    view.x, view.y, view.z = x, y, z or view.z
    zoomGoal, glide = nil, nil
    ApplyView()
end

-- the zoom at which a map's rectangle fills the view
function Map.ZoomFor(mapID, share)
    local l, r, t, b = Geo.Rect(mapID)
    if not l then return view.z end
    local vw, vh = ViewSize()
    return math.min(vw / ((r - l) * W), vh / ((b - t) * H)) * (share or 0.9) / Fit()
end

-- glide to a point (u, v) at a zoom
function Map.GoTo(u, v, z)
    z = math.max(MIN_ZOOM, math.min(MAX_ZOOM, z or view.z))
    glide = { x0 = view.x, y0 = view.y, z0 = view.z, x1 = u * W, y1 = v * H, z1 = z, t = 0 }
    zoomGoal = nil
    following = false
end

function Map.GoToMap(mapID)
    local l, r, t, b = Geo.Rect(mapID)
    if l then Map.GoTo((l + r) / 2, (t + b) / 2, Map.ZoomFor(mapID)) end
end

local function ZoomAt(x, y, z, px, py)
    local vw, vh = ViewSize()
    zoomGoal = { z = math.max(MIN_ZOOM, math.min(MAX_ZOOM, z)), ax = x, ay = y, px = px or vw / 2, py = py or vh / 2 }
    glide = nil
end

-- center on the player (fitting their zone, when opening) and keep following them until the map is dragged
function Map.CenterOnPlayer(fitZone)
    local u, v, mapID = Geo.UnitPosition("player")
    if not u then
        ns.Print(L.NO_POSITION)
        return false
    end
    local z = fitZone and Map.ZoomFor(mapID, 0.85) or math.max(view.z, 2.5)
    Map.SetView(u * W, v * H, z)
    following = true
    return true
end

function Map.Following() return following end

-- the player module calls this as they move
function Map.Follow(u, v)
    if following and not drag and not glide then
        if zoomGoal then
            zoomGoal.ax, zoomGoal.ay = u * W, v * H
            local vw, vh = ViewSize()
            zoomGoal.px, zoomGoal.py = vw / 2, vh / 2
        else
            view.x, view.y = u * W, v * H
            ApplyView()
        end
    end
end

--------------------------------------------------------------------------------------------------------------
-- The frame loop
--------------------------------------------------------------------------------------------------------------

local cursorText, playerText, statusText

local function UpdateCursorText()
    if not viewport:IsMouseOver() then
        cursorText:SetText("")
        return
    end
    local u, v = Map.CursorUV()
    local mapID, x, y = Geo.ZoneAt(u, v)
    if mapID then
        cursorText:SetText(L.CURSOR:format(Geo.Name(mapID), ns.Coords(x, y)))
    else
        cursorText:SetText("")
    end
end

function Map.SetPlayerText(text) if playerText then playerText:SetText(text or "") end end
function Map.SetStatus(text) if statusText then statusText:SetText(text or "") end end

local function UpdateFade()
    local a = 1
    if ns.Opt("fadeMoving") and not ns.db.window.full and IsPlayerMoving and IsPlayerMoving() and not frame:IsMouseOver() then
        a = ns.Opt("fadeAlpha")
    end
    if math.abs(frame:GetAlpha() - a) > 0.01 then frame:SetAlpha(a) end
end

local function OnUpdate(_, elapsed)
    local changed = false
    if drag then
        local px, py = Cursor()
        if not drag.moved and (math.abs(px - drag.px) > CLICK_PX or math.abs(py - drag.py) > CLICK_PX) then
            drag.moved = true
            following = false
        end
        if drag.moved then
            local k = Map.K()
            view.x = drag.x - (px - drag.px) / k
            view.y = drag.y - (py - drag.py) / k
            changed = true
        end
    end
    if zoomGoal then
        local z = view.z * (zoomGoal.z / view.z) ^ math.min(1, elapsed * EASE)
        if math.abs(z / zoomGoal.z - 1) < 0.002 then z = zoomGoal.z end
        view.z = z
        local vw, vh = ViewSize()
        local k = Fit() * z
        view.x = zoomGoal.ax - (zoomGoal.px - vw / 2) / k
        view.y = zoomGoal.ay - (zoomGoal.py - vh / 2) / k
        if z == zoomGoal.z then zoomGoal = nil end
        changed = true
    end
    if glide then
        glide.t = glide.t + elapsed
        local p = math.min(1, glide.t / GLIDE)
        local e = p * p * (3 - 2 * p)
        view.x = glide.x0 + (glide.x1 - glide.x0) * e
        view.y = glide.y0 + (glide.y1 - glide.y0) * e
        view.z = glide.z0 * (glide.z1 / glide.z0) ^ e
        if p >= 1 then glide = nil end
        changed = true
    end
    if changed then ApplyView() end
    sinceView = sinceView + elapsed
    if viewDirty and sinceView > 0.05 then   -- the layers cull and rebuild at most 20 times a second
        viewDirty, sinceView = false, 0
        ns.Fire("ZMAP_VIEW")
    end
    sinceTick = sinceTick + elapsed
    if sinceTick > 0.1 then
        ns.Fire("ZMAP_TICK", sinceTick)
        sinceTick = 0
        UpdateCursorText()
        UpdateFade()
    end
end

--------------------------------------------------------------------------------------------------------------
-- Mouse
--------------------------------------------------------------------------------------------------------------

local function ContextMenu(u, v)
    if not MenuUtil then return end
    local mapID, x, y = Geo.ZoneAt(u, v)
    MenuUtil.CreateContextMenu(viewport, function(_, root)
        if mapID then root:CreateTitle(("%s  %s"):format(Geo.Name(mapID), ns.Coords(x, y))) end
        if mapID then
            root:CreateButton(L.MENU_PIN_HERE, function() ns.Waypoints.AddAt(u, v, { ask = true }) end)
            root:CreateButton(L.MENU_GO_HERE, function() ns.Waypoints.AddAt(u, v, { navigate = true, temp = true }) end)
            root:CreateButton(L.MENU_LINK_HERE, function() ns.Waypoints.LinkAt(u, v) end)
        end
        ns.Fire("ZMAP_MENU", root, u, v, mapID)
        root:CreateDivider()
        root:CreateButton(L.MENU_ZOOM_OUT, function() ZoomAt(u * W, v * H, view.z / 2.5) end)
        root:CreateButton(L.MENU_CENTER_ME, function() Map.CenterOnPlayer(false) end)
    end)
end

local function OnMouseUp(_, button)
    local wasDrag = drag and drag.moved
    drag = nil
    if wasDrag then return end
    local px, py, x, y = Cursor()
    local u, v = x / W, y / H
    if button == "RightButton" then
        ContextMenu(u, v)
    elseif button == "LeftButton" then
        if IsControlKeyDown() then
            ns.Waypoints.AddAt(u, v, { ask = true })
        elseif IsShiftKeyDown() then
            ns.Waypoints.LinkAt(u, v)
        else
            local now = GetTime()
            if now - lastClick < 0.35 then
                lastClick = 0
                following = false
                ZoomAt(x, y, view.z * 2.5, px, py)
            else
                lastClick = now
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------------------------------------

local function SaveWindow()
    if ns.db.window.full then return end
    local point, _, rel, x, y = frame:GetPoint(1)
    local win = ns.db.window
    win.point, win.rel, win.x, win.y = point, rel, x, y
    win.w, win.h = frame:GetSize()
end

local function PlaceWindow()
    local win = ns.db.window
    frame:ClearAllPoints()
    if win.full then
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("FULLSCREEN")
        grip:Hide()
    else
        local uw, uh = UIParent:GetSize()
        frame:SetSize(win.w or math.floor(uw * 0.72), win.h or math.floor(uh * 0.78))
        frame:SetPoint(win.point or "CENTER", UIParent, win.rel or "CENTER", win.x or 0, win.y or 0)
        frame:SetFrameStrata("HIGH")
        grip:Show()
    end
end

function Map.SetFullscreen(on)
    if not on then frame:SetAlpha(1) end
    ns.db.window.full = on and true or nil
    PlaceWindow()
    if frame.fullButton then frame.fullButton:SetText(on and L.WINDOWED or L.FULLSCREEN) end
end

local function Button(parent, text, width, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tooltip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
end

local function Create()
    frame = CreateFrame("Frame", "ZmapFrame", UIParent, "BackdropTemplate")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(520, 360)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
    frame:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
    frame:Hide()
    tinsert(UISpecialFrames, "ZmapFrame")   -- Escape closes it

    -- the bar on top: drag it to move the window
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 6, -5)
    header:SetPoint("TOPRIGHT", -6, -5)
    header:SetHeight(HEADER - 6)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not ns.db.window.full then frame:StartMoving() end end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SaveWindow() end)
    frame.header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 4, 0)
    title:SetText("|cff4fc3f7Z|rmap")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    -- above everything on the map (its icons stack well over a hundred levels up)
    header:SetFrameLevel(frame:GetFrameLevel() + 300)
    close:SetFrameLevel(frame:GetFrameLevel() + 301)

    -- right to left: the window's buttons
    local x = -30
    local function Right(text, width, onClick, tooltip)
        local b = Button(header, text, width, onClick, tooltip)
        b:SetPoint("RIGHT", header, "RIGHT", x, 0)
        x = x - width - 4
        return b
    end
    frame.fullButton = Right(ns.db.window.full and L.WINDOWED or L.FULLSCREEN, 96, function()
        Map.SetFullscreen(not ns.db.window.full)
    end)
    Right(L.BLIZZARD_MAP, 96, function() Map.OpenBlizzard() end, L.BLIZZARD_MAP_TIP)
    Right(L.CENTER, 70, function() Map.CenterOnPlayer(false) end, L.CENTER_TIP)
    frame.pinsButton = Right(L.PINS, 70, function(self) ns.Waypoints.Menu(self) end, L.PINS_TIP)
    frame.layersButton = Right(L.LAYERS, 70, function(self) ns.LayersMenu(self) end, L.LAYERS_TIP)

    -- the map itself
    viewport = CreateFrame("Frame", nil, frame)
    viewport:SetPoint("TOPLEFT", 6, -HEADER)
    viewport:SetPoint("BOTTOMRIGHT", -6, FOOTER)
    viewport:SetClipsChildren(true)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    local sea = viewport:CreateTexture(nil, "BACKGROUND", nil, -8)
    sea:SetAllPoints()
    sea:SetColorTexture(SEA[1], SEA[2], SEA[3], 1)
    frame.viewport = viewport

    canvas = CreateFrame("Frame", nil, viewport)
    canvas:SetSize(W, H)
    canvas:SetPoint("TOPLEFT")

    viewport:SetScript("OnMouseWheel", function(_, delta)
        local px, py, x, y = Cursor()
        following = false   -- you are looking somewhere: the view stops following you
        ZoomAt(x, y, (zoomGoal and zoomGoal.z or view.z) * WHEEL ^ delta, px, py)
    end)
    viewport:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            local px, py = Cursor()
            drag = { px = px, py = py, x = view.x, y = view.y }
            glide = nil
        end
    end)
    viewport:SetScript("OnMouseUp", OnMouseUp)
    viewport:SetScript("OnSizeChanged", function() lastK = nil; ApplyView() end)

    -- the bar at the bottom: the player's and the cursor's coordinates
    playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    playerText:SetPoint("BOTTOMLEFT", 10, 6)
    cursorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cursorText:SetPoint("BOTTOMRIGHT", -24, 6)
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOM", 0, 6)

    grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SaveWindow() end)

    PlaceWindow()
    ns.Art.Init(canvas)
    ns.Pins.Init(canvas)

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        frame:SetScript("OnUpdate", ns.Guard(OnUpdate))
        lastK = nil
        local opened = false
        if ns.Opt("openOn") == "player" or not ns.db.view then
            opened = Map.CenterOnPlayer(true)
        end
        if not opened then
            local saved = ns.db.view
            if saved then Map.SetView(saved.x, saved.y, saved.z) else Map.SetView(W / 2, H / 2, 1) end
        end
        ns.Fire("ZMAP_SHOW")
        ns.Fire("ZMAP_VIEW")
        C_Timer.After(0, function() lastK = nil; ApplyView() end)   -- (once the game has laid the window out)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
        frame:SetScript("OnUpdate", nil)
        drag, zoomGoal, glide = nil, nil, nil
        ns.db.view = { x = view.x, y = view.y, z = view.z }
        ns.Fire("ZMAP_HIDE")
    end)
    ns.Fire("ZMAP_CREATED", frame)
end

function Map.Open()
    if not frame then Create() end
    frame:Show()
    frame:Raise()
end

function Map.Close()
    if frame then frame:Hide() end
end

function Map.Toggle()
    if frame and frame:IsShown() then Map.Close() else Map.Open() end
end

-- Blizzard's own map (its quest log lives there)
function Map.OpenBlizzard()
    Map.Close()
    if ToggleWorldMap then ToggleWorldMap() end
end

ns.commands.reset = function()
    ns.db.window = {}
    ns.db.view = nil
    if frame then PlaceWindow() end
    ns.Print(L.RESET_DONE)
end
