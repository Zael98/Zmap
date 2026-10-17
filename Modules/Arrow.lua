-- The arrow on screen: points to the destination (a pin, your corpse), turning as you turn, with the
-- distance and how long it will take at your speed. Drag it to move it; right-click for its menu.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local Arrow = {}
ns.Arrow = Arrow

local ARRIVE = 8           -- yards: there
local target               -- { instance, u, v, name, onArrive }
local frame
local speed = 0            -- yards a second towards the target (smoothed)
local lastDist, lastTime

local function Create()
    frame = CreateFrame("Button", "ZmapArrow", UIParent)
    frame:SetSize(64, 64)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("RightButtonUp")
    local pos = ns.db.arrow
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
    frame:SetScript("OnDragStart", function(self) if not ns.db.arrowLocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        ns.db.arrow = { p, rp, x, y }
    end)
    frame.arrow = frame:CreateTexture(nil, "ARTWORK")
    frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    frame.arrow:SetSize(56, 56)
    frame.arrow:SetPoint("CENTER")
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame.name:SetShadowOffset(1, -1)
    frame.dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.dist:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.dist:SetShadowOffset(1, -1)
    frame:SetScript("OnClick", function(self)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(target and target.name or "Zmap")
            root:CreateButton(L.ARROW_CLEAR, function()
                if ns.Waypoints.Active() then ns.Waypoints.Stop() else Arrow.Clear() end
            end)
            root:CreateCheckbox(L.ARROW_LOCK, function() return ns.db.arrowLocked end, function()
                ns.db.arrowLocked = not ns.db.arrowLocked
            end)
        end)
    end)
    frame:Hide()
end

-- green when you face it, through yellow, to red when it is behind you
local function Tint(angle)
    local off = math.abs(angle) / math.pi   -- 0 ahead, 1 behind
    if off < 0.5 then return off * 2, 1, 0.1 end
    return 1, 1 - (off - 0.5) * 2, 0.1
end

local function Update(_, elapsed)
    if not target then return end
    local px, py, instance = Geo.PlayerYards()
    if not px then
        frame.arrow:Hide()
        frame.dist:SetText(L.ARROW_NO_POSITION)
        return
    end
    if instance ~= target.instance then
        frame.arrow:Hide()
        frame.dist:SetText(L.ARROW_OTHER_CONTINENT)
        return
    end
    local tx, ty = Geo.ToYards(target.instance, target.u, target.v)
    local dn, dw = tx - px, ty - py           -- north, west
    local dist = math.sqrt(dn * dn + dw * dw)
    if dist < ARRIVE then
        local done = target.onArrive
        Arrow.Clear()
        if done then done() end
        return
    end
    local facing = GetPlayerFacing()
    frame.arrow:Show()
    if facing and not (issecretvalue and issecretvalue(facing)) then
        local angle = math.atan2(dw, dn) - facing  -- counter-clockwise from where you look
        angle = (angle + math.pi) % (2 * math.pi) - math.pi
        frame.arrow:SetRotation(angle)
        frame.arrow:SetVertexColor(Tint(angle))
    end
    -- speed towards it, smoothed over a few seconds
    local now = GetTime()
    if lastDist and now > lastTime then
        local v = (lastDist - dist) / (now - lastTime)
        speed = speed + (v - speed) * math.min(1, (now - lastTime) / 2)
    end
    lastDist, lastTime = dist, now
    local text = L.YARDS:format(dist)
    if speed > 1 then text = text .. "  ~" .. ns.Duration(dist / speed) end
    frame.dist:SetText(text)
end

-- t: { instance, u, v, name, onArrive }
function Arrow.SetTarget(t)
    target = t
    speed, lastDist, lastTime = 0, nil, nil
    if not ns.Opt("arrow") then return end
    if not frame then Create() end
    frame.name:SetText(t.name or "")
    frame:Show()
    frame:SetScript("OnUpdate", ns.Guard(Update))
end

function Arrow.Clear()
    target = nil
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

function Arrow.Target() return target end

ns.On("ZMAP_OPTION", function(key, value)
    if key ~= "arrow" then return end
    if value and target then
        Arrow.SetTarget(target)
    elseif frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end)
