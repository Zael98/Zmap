-- You on the map: the arrow (turning as you turn), a ping when the map opens, your coordinates below.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("player", { level = 90, size = 28 })
local pin

function P:OnCreate(p)
    p.icon:SetAtlas("minimaparrow")
    p.ring = p:CreateTexture(nil, "BACKGROUND")
    p.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    p.ring:SetBlendMode("ADD")
    p.ring:SetPoint("CENTER")
    p.ring:SetSize(28, 28)
    p.ring:Hide()
end

function P:Tooltip(p, tip)
    tip:SetText(UnitName("player"), 1, 1, 1)
    if p.mapID then tip:AddLine(("%s  %s"):format(Geo.Name(p.mapID), ns.Coords(p.x, p.y)), 1, 0.82, 0) end
end

function P:OnClick(_, button)
    if button == "RightButton" then ns.Waypoints.LinkAt(pin.u, pin.v) end
end

local pingUntil = 0

local function Update()
    if not pin then
        pin = P:Acquire()
    end
    local u, v, mapID, x, y = Geo.UnitPosition("player")
    if not u then
        pin:Hide()
        ns.Map.SetPlayerText(L.NO_POSITION_SHORT)
        return
    end
    pin:Show()
    pin.mapID, pin.x, pin.y = mapID, x, y
    P:Place(pin, u, v)
    local facing = GetPlayerFacing()
    if facing and not (issecretvalue and issecretvalue(facing)) then pin.icon:SetRotation(facing) end
    ns.Map.SetPlayerText(L.PLAYER_AT:format(Geo.Name(mapID), ns.Coords(x, y)))
    ns.Map.Follow(u, v)
end

function P:Refresh() Update() end

ns.On("ZMAP_TICK", function() if P.frame and P.frame:IsShown() then Update() end end)

-- between the ticks, every frame: the arrow where you are and how you face (the world's yards: plain numbers, no
-- garbage), so it glides instead of jumping ten times a second
local IsSecret = issecretvalue or function() return false end
local glider = CreateFrame("Frame")
glider:SetScript("OnUpdate", function()
    if not (pin and pin:IsShown() and ns.Map.IsShown()) then return end
    local wx, wy, _, instance = UnitPosition("player")
    if not wx or IsSecret(wx) or IsSecret(wy) then return end
    local u, v = Geo.FromYards(instance, wx, wy)
    if not u then return end
    P:Place(pin, u, v)
    ns.Map.Follow(u, v)   -- (the view with it, when it follows you)
    local facing = GetPlayerFacing()
    if facing and not IsSecret(facing) then pin.icon:SetRotation(facing) end
end)
-- the ping: a ring that grows and fades for two seconds after the map opens
local animator = CreateFrame("Frame")
local function Animate()
    local left = pingUntil - GetTime()
    if not pin or left <= 0 or not ns.Map.IsShown() then
        if pin then pin.ring:Hide() end
        animator:SetScript("OnUpdate", nil)
        return
    end
    local p = 1 - left / 2
    pin.ring:Show()
    pin.ring:SetSize(28 + 90 * p, 28 + 90 * p)
    pin.ring:SetAlpha(1 - p)
end

ns.On("ZMAP_SHOW", function()
    pingUntil = GetTime() + 2
    animator:SetScript("OnUpdate", ns.Guard(Animate))
end)
