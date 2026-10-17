-- Zmap on the minimap: the destination (at the edge while it is farther than the minimap shows), your pins,
-- and near you the herbs and ore of your professions, the quest givers and your quests' objectives.
local _, ns = ...
local Geo = ns.Geo
local MM = {}
ns.MinimapPins = MM

-- yards across the minimap at each zoom level (the game's own sizes), outdoors and indoors
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }
local MAX = 60

local frame, pool, used = nil, {}, {}

local function Pin()
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Frame", nil, frame)
        pin:SetSize(12, 12)
        pin.icon = pin:CreateTexture(nil, "OVERLAY")
        pin.icon:SetAllPoints()
    end
    pin:Show()
    used[#used + 1] = pin
    return pin
end

local function Clear()
    for i = #used, 1, -1 do
        used[i]:Hide()
        pool[#pool + 1] = used[i]
        used[i] = nil
    end
end

-- where a world point (yards) falls on the minimap: x, y from its centre (pixels), and whether it is inside
local function Place(px, py, wx, wy, scale, facing, radius, square)
    local east, north = -(wy - py) * scale, (wx - px) * scale
    if facing then   -- the minimap turns with you: what is ahead is up
        local c, s = math.cos(-facing), math.sin(-facing)
        east, north = east * c - north * s, east * s + north * c
    end
    local inside
    if square then
        inside = math.max(math.abs(east), math.abs(north)) <= radius
    else
        inside = east * east + north * north <= radius * radius
    end
    return east, north, inside
end

local function Update()
    Clear()
    if not ns.db or not ns.Opt("minimapPins") or not Minimap:IsVisible() then return end
    local px, py, instance = Geo.PlayerYards()
    local pu, pv, pm = Geo.UnitPosition("player")
    if not px or not pm or Geo.Instance(pm) ~= instance then return end
    local zoom = Minimap:GetZoom() or 0
    local yards = (IsIndoors and IsIndoors() and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]
    local width = Minimap:GetWidth()
    local scale, radius = width / yards, width / 2 - 6
    local facing = GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or nil
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local reach = (yards / 2) ^ 2 * 1.5   -- (squared yards: what could be on the minimap)

    local count = 0
    local function Show(u, v, atlas, texture, r, g, b, size, edge)
        if count >= MAX then return end
        local wx, wy = Geo.ToYards(instance, u, v)
        if not wx then return end
        if not edge and (wx - px) ^ 2 + (wy - py) ^ 2 > reach then return end
        local x, y, inside = Place(px, py, wx, wy, scale, facing, radius, square)
        if not inside then
            if not edge then return end
            local d = math.sqrt(x * x + y * y)   -- the destination waits at the edge, towards it
            x, y = x / d * radius, y / d * radius
        end
        count = count + 1
        local pin = Pin()
        if atlas then pin.icon:SetAtlas(atlas) else pin.icon:SetTexture(texture) end
        pin.icon:SetVertexColor(r or 1, g or 1, b or 1)
        pin:SetSize(size or 12, size or 12)
        pin:SetPoint("CENTER", frame, "CENTER", x, y)
    end

    local target = ns.Arrow.Target()
    if target and target.instance == instance then
        Show(target.u, target.v, "Waypoint-MapPin-Tracked", nil, 1, 1, 1, 16, true)
    end
    for _, p in pairs(ns.db.pins) do
        local u, v = Geo.ToWorld(p.m, p.x, p.y)
        if u and Geo.Instance(p.m) == instance then Show(u, v, "Waypoint-MapPin-Untracked", nil, 1, 0.82, 0, 14) end
    end
    if ns.Opt("available") then
        for _, mark in ipairs(ns.QuestMap.Givers()) do
            if not mark.trivial or ns.Opt("trivial") then Show(mark.u, mark.v, "QuestNormal", nil, 1, 1, 1, 14) end
        end
    end
    if ns.Opt("objectives") then
        for _, mark in ipairs(ns.QuestMap.Objectives()) do
            if mark.turnIn then
                Show(mark.u, mark.v, "QuestTurnin", nil, 1, 1, 1, 14)
            else
                Show(mark.u, mark.v, "WhiteCircle-RaidBlips", nil, mark.color[1], mark.color[2], mark.color[3], 8)
            end
        end
    end
    for _, n in ipairs(ns.GatherNear and ns.GatherNear(pm) or {}) do
        Show(n.u, n.v, nil, n.icon, 1, 1, 1, 12)
    end
end

ns.On("PLAYER_LOGIN", function()
    if not Minimap then return end
    frame = CreateFrame("Frame", "ZmapMinimapPins", Minimap)
    frame:SetAllPoints(Minimap)
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    local wait = 0
    frame:SetScript("OnUpdate", ns.Guard(function(_, elapsed)
        wait = wait - elapsed
        if wait <= 0 then
            wait = 0.1
            Update()
        end
    end))
end)

MM.Update = Update
