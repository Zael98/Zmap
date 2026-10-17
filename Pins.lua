-- Icons and labels on the map. Each kind of thing (flight masters, group members, your pins...) is a
-- provider with its own layer; its pins sit on the canvas at a map point (u, v) and keep their size on
-- screen as it zooms (each pin is scaled by the inverse of the canvas's scale, like Blizzard's map pins).
local _, ns = ...
local Pins = {}
ns.Pins = Pins

local W, H = ns.Geo.W, ns.Geo.H
local root, lines
local providers = {}
Pins.providers = providers

local Provider = {}
Provider.__index = Provider

-- spec: level (stacking, higher on top), size, option (the setting that shows it), minZoom, maxZoom,
--       mouse (false: labels the cursor goes through), and the methods Refresh, Tooltip, OnClick, OnEnter
function Pins.New(name, spec)
    local p = setmetatable(spec or {}, Provider)
    p.name = name
    p.active, p.pool = {}, {}
    providers[#providers + 1] = p
    if root then p:CreateFrame() end
    return p
end

function Provider:CreateFrame()
    self.frame = CreateFrame("Frame", nil, root)
    self.frame:SetAllPoints(root)
    self.frame:SetFrameLevel(root:GetFrameLevel() + (self.level or 10))
end

local function Enter(pin)
    local p = pin.provider
    if p.OnEnter then p:OnEnter(pin) end
    if p.Tooltip then
        GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
        p:Tooltip(pin, GameTooltip)
        GameTooltip:Show()
    end
end

local function Leave(pin)
    local p = pin.provider
    if p.OnLeave then p:OnLeave(pin) end
    GameTooltip:Hide()
end

local function Click(pin, button)
    local p = pin.provider
    if p.OnClick then p:OnClick(pin, button) end
end

function Provider:Acquire()
    local pin = table.remove(self.pool)
    if not pin then
        pin = CreateFrame("Button", nil, self.frame)
        local size = self.size or 16
        pin:SetSize(size, size)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints()
        pin.provider = self
        if self.mouse == false then
            pin:EnableMouse(false)
        else
            pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            pin:SetScript("OnEnter", Enter)
            pin:SetScript("OnLeave", Leave)
            pin:SetScript("OnClick", Click)
        end
        if self.OnCreate then self:OnCreate(pin) end
    end
    pin.mul = 1
    pin:Show()
    self.active[#self.active + 1] = pin
    return pin
end

function Provider:ReleaseAll()
    for i = #self.active, 1, -1 do
        local pin = self.active[i]
        pin:Hide()
        pin.data = nil
        self.pool[#self.pool + 1] = pin
        self.active[i] = nil
    end
end

local function Place(pin)
    local k = ns.Map.K()
    local s = ns.Opt("iconScale") * (pin.provider.scale or 1) * (pin.mul or 1)
    pin:SetScale(s / k)
    pin:SetPoint("CENTER", root, "TOPLEFT", pin.u * W * k / s, -pin.v * H * k / s)
end

-- put a pin at a point of the map (u, v); mul: its size relative to the provider's
function Provider:Place(pin, u, v, mul)
    pin.u, pin.v, pin.mul = u, v, mul or pin.mul or 1
    Place(pin)
end

function Provider:Shown()
    if self.option and not ns.Opt(self.option) then return false end
    local z = ns.Map.Zoom()
    if self.minZoom and z < self.minZoom then return false end
    if self.maxZoom and z > self.maxZoom then return false end
    return true
end

function Provider:Refresh() end

-- one provider again (its data changed)
function Provider:Update()
    if not self.frame or not ns.Map.IsShown() then return end
    local shown = self:Shown()
    self.frame:SetShown(shown)
    if shown then
        ns.Safe(self.Refresh, self)
    elseif self.cleared ~= true then
        self:ReleaseAll()
        if self.OnHidden then self:OnHidden() end
    end
    self.cleared = not shown
end

-- every pin to its place and size (the canvas zoomed)
function Pins.Layout()
    if not root then return end
    for _, p in ipairs(providers) do
        if p.frame:IsShown() then
            for _, pin in ipairs(p.active) do
                if pin.u then Place(pin) end
            end
        end
    end
    Pins.LayoutLines()
end

-- the view moved: providers that come and go with the zoom, or keep only what is in view, refresh
local lastZoom
local function OnView()
    local z = ns.Map.Zoom()
    for _, p in ipairs(providers) do
        local shown = p:Shown()
        if shown ~= p.frame:IsShown() or (shown and p.cull) or (shown and p.zoomRefresh and z ~= lastZoom) then
            p:Update()
        end
    end
    lastZoom = z
end

function Pins.Init(canvas)
    root = CreateFrame("Frame", nil, canvas)
    root:SetAllPoints(canvas)
    root:SetFrameLevel(ns.Art.levelTop)
    lines = CreateFrame("Frame", nil, canvas)
    lines:SetAllPoints(canvas)
    lines:SetFrameLevel(ns.Art.levelTop - 1)
    lines.active, lines.pool = {}, {}
    for _, p in ipairs(providers) do p:CreateFrame() end
end

function Pins.UpdateAll()
    for _, p in ipairs(providers) do p:Update() end
end

-- the part of the map in view (with a margin), for providers that only place what can be seen: u, v box
function Pins.ViewBox(margin)
    local left, top, right, bottom = ns.Map.ViewRect()
    local mx, my = (right - left) * (margin or 0.1), (bottom - top) * (margin or 0.1)
    return (left - mx) / W, (top - my) / H, (right + mx) / W, (bottom + my) / H
end

--------------------------------------------------------------------------------------------------------------
-- Lines (flight routes, boats): drawn in map units, their thickness kept in screen pixels
--------------------------------------------------------------------------------------------------------------

local LineSet = {}
LineSet.__index = LineSet

function Pins.Lines()
    return setmetatable({ active = {} }, LineSet)
end

-- a line from (u1, v1) to (u2, v2), px thick on screen
function LineSet:Add(u1, v1, u2, v2, r, g, b, a, px)
    local line = table.remove(lines.pool)
    if not line then
        line = lines:CreateLine(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    line:SetStartPoint("TOPLEFT", lines, u1 * W, -v1 * H)
    line:SetEndPoint("TOPLEFT", lines, u2 * W, -v2 * H)
    line:SetVertexColor(r, g, b, a or 1)
    line.px = px or 2
    line:SetThickness(line.px / ns.Map.K())
    line:Show()
    self.active[#self.active + 1] = line
    lines.active[line] = true
    return line
end

-- a polyline: { u1, v1, u2, v2, ... }
function LineSet:AddPath(points, r, g, b, a, px)
    for i = 1, #points - 3, 2 do
        self:Add(points[i], points[i + 1], points[i + 2], points[i + 3], r, g, b, a, px)
    end
end

function LineSet:Clear()
    for i = #self.active, 1, -1 do
        local line = self.active[i]
        line:Hide()
        lines.active[line] = nil
        lines.pool[#lines.pool + 1] = line
        self.active[i] = nil
    end
end

function Pins.LayoutLines()
    local k = ns.Map.K()
    for line in pairs(lines.active) do line:SetThickness(line.px / k) end
end

ns.On("ZMAP_VIEW", OnView)
ns.On("ZMAP_SHOW", function() lastZoom = nil; Pins.UpdateAll() end)
ns.On("ZMAP_OPTION", function(key)
    for _, p in ipairs(providers) do
        if p.option == key or key == "iconScale" then p:Update() end
    end
    if key == "iconScale" then Pins.Layout() end
end)
