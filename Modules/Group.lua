-- Your party or raid on the map, in their class colours (the game gives their positions outside instances).
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("group", { level = 80, size = 14, option = "group" })

function P:OnCreate(pin)
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
    pin.label:SetShadowOffset(1, -1)
end

local function Units()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do list[#list + 1] = "party" .. i end
    end
    return list
end

function P:Refresh()
    self:ReleaseAll()
    for _, unit in ipairs(Units()) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local u, v, mapID, x, y = Geo.UnitPosition(unit)
            if u then
                local pin = self:Acquire()
                local _, class = UnitClass(unit)
                local r, g, b = ns.ClassColor(class)
                if UnitIsDeadOrGhost(unit) then
                    pin.icon:SetAtlas("playerdeadblip")
                    pin.icon:SetVertexColor(1, 1, 1)
                else
                    pin.icon:SetAtlas("WhiteCircle-RaidBlips")
                    pin.icon:SetVertexColor(r, g, b)
                end
                pin.label:SetText(UnitName(unit))
                pin.label:SetTextColor(r, g, b)
                pin.unit, pin.mapID, pin.x, pin.y = unit, mapID, x, y
                self:Place(pin, u, v)
            end
        end
    end
end

function P:Tooltip(pin, tip)
    local _, class = UnitClass(pin.unit)
    local r, g, b = ns.ClassColor(class)
    tip:SetText(UnitName(pin.unit) or "?", r, g, b)
    tip:AddLine(LEVEL .. " " .. (UnitLevel(pin.unit) or "?"), 1, 1, 1)
    tip:AddLine(("%s  %s"):format(Geo.Name(pin.mapID), ns.Coords(pin.x, pin.y)), 1, 0.82, 0)
    if UnitIsDeadOrGhost(pin.unit) then tip:AddLine(DEAD, 1, 0.3, 0.3) end
end

function P:OnClick(pin, button)
    if button == "LeftButton" and IsControlKeyDown() then
        ns.Waypoints.Add(pin.mapID, pin.x, pin.y, UnitName(pin.unit), { navigate = true, temp = true })
    end
end

local wait = 0
ns.On("ZMAP_TICK", function(elapsed)
    wait = wait - elapsed
    if wait <= 0 then
        wait = 0.5
        P:Update()
    end
end)
ns.On("GROUP_ROSTER_UPDATE", function() P:Update() end)
