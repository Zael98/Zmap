-- How to get there: the quickest way from where you are to a point, on foot (or riding), by the flights you
-- know and by your faction's boats and zeppelins. Drawn on the map a leg at a time, listed with its times,
-- and the arrow leads you leg by leg (each leg's end reached, the next).
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local R = {}
ns.Route = R

local CROSSING = 240      -- seconds a boat or zeppelin takes, waiting for it included (about)
local TAKE_OFF = 10       -- seconds lost at each flight master
local REACHED = 40        -- yards from a leg's end that count as there
local ISLANDS = { [1438] = "teldrassil", [1457] = "teldrassil" }   -- zones you cannot walk out of
local COLORS = { walk = { 1, 1, 1 }, fly = { 1, 0.82, 0.1 }, boat = { 0.35, 0.68, 1 }, zeppelin = { 1, 0.5, 0.2 } }

local lines = ns.Pins.Lines()
local route     -- { legs = { { mode, from = point, to = point, seconds, name } }, seconds, step, dest }
local panel

local function Ride()
    return (UnitLevel("player") or 1) >= 40 and 11 or 7   -- yards a second: on foot, or with a mount
end

local function Island(p)
    local u, v = Geo.FromYards(p.instance, p.x, p.y)
    local mapID = u and Geo.ZoneAt(u, v)
    return mapID and ISLANDS[mapID] or "main"
end

local function Mine(faction)
    local f = UnitFactionGroup("player")
    return faction == "N" or (faction == "A" and f == "Alliance") or (faction == "H" and f == "Horde")
end

-- every place the way can go through: { instance, x, y, name, island }
local function Places(start, dest)
    local places = { start, dest }
    local fly = {}   -- [flight node] = place
    local nodes, hops = ns.Flights.Network()
    for id, n in pairs(nodes) do
        local p = { instance = n[1], x = n[2], y = n[3], name = ns.Flights.Name(id) }
        places[#places + 1], fly[id] = p, p
    end
    local sails = {}
    for _, t in ipairs(ns.TRANSPORTS) do
        if Mine(t[2]) then
            local a, b = t[5][1], t[5][2]
            local pa = { instance = a[1], x = a[2], y = a[3], name = L.DOCK:format(ns.Name(t[6])) }
            local pb = { instance = b[1], x = b[2], y = b[3], name = pa.name }
            places[#places + 1], places[#places + 2] = pa, pb
            sails[#sails + 1] = { pa, pb, t[1], ns.Name(t[6]) }
        end
    end
    for _, p in ipairs(places) do p.island = Island(p) end
    return places, fly, hops, sails
end

-- the quickest way (Dijkstra over every place): { legs }, seconds
local function Plan(start, dest)
    local places, fly, hops, sails = Places(start, dest)
    local ride = Ride()
    local edges = {}   -- [place] = { { to, seconds, mode, name } }
    local function Edge(a, b, seconds, mode, name)
        edges[a] = edges[a] or {}
        table.insert(edges[a], { b, seconds, mode, name })
    end
    for _, a in ipairs(places) do
        for _, b in ipairs(places) do
            if a ~= b and a.instance == b.instance and a.island == b.island then
                Edge(a, b, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) / ride, "walk")
            end
        end
    end
    for _, h in ipairs(hops) do Edge(fly[h[1]], fly[h[2]], h[3] + TAKE_OFF, "fly") end
    for _, s in ipairs(sails) do
        local name = s[4]
        Edge(s[1], s[2], CROSSING, s[3], name)
        Edge(s[2], s[1], CROSSING, s[3], name)
    end
    local dist, prev, done = { [start] = 0 }, {}, {}
    while true do
        local best, bd
        for p, d in pairs(dist) do
            if not done[p] and (not bd or d < bd) then best, bd = p, d end
        end
        if not best or best == dest then break end
        done[best] = true
        for _, e in ipairs(edges[best] or {}) do
            local d = bd + e[2]
            if not dist[e[1]] or d < dist[e[1]] then
                dist[e[1]], prev[e[1]] = d, { best, e }
            end
        end
    end
    if not dist[dest] then return end
    -- back from the destination; hops of one flight make one leg
    local legs, at = {}, dest
    while at ~= start do
        local from, e = prev[at][1], prev[at][2]
        local leg = legs[1]
        if leg and leg.mode == "fly" and e[3] == "fly" then
            leg.from, leg.seconds = from, leg.seconds + e[2]
        else
            table.insert(legs, 1, { mode = e[3], from = from, to = at, seconds = e[2], name = e[4] })
        end
        at = from
    end
    -- a few steps on foot (to the flight master you stand by) are no leg
    for i = #legs, 1, -1 do
        local leg = legs[i]
        if leg.mode == "walk" and #legs > 1 and (leg.from.x - leg.to.x) ^ 2 + (leg.from.y - leg.to.y) ^ 2 < REACHED * REACHED then
            table.remove(legs, i)
        end
    end
    return legs, dist[dest]
end

--------------------------------------------------------------------------------------------------------------
-- On the map and on screen
--------------------------------------------------------------------------------------------------------------

local function StepText(leg)
    if leg.mode == "walk" then return L.WAY_WALK:format(leg.to.name) end
    if leg.mode == "fly" then return L.WAY_FLY:format(leg.from.name, leg.to.name) end
    return L.WAY_SAIL:format(leg.name or "")
end

local function Draw()
    if not ns.Map.Frame() then return end   -- (the map not made yet: drawn when it opens)
    lines:Clear()
    if not route then return end
    for i, leg in ipairs(route.legs) do
        local c = COLORS[leg.mode] or COLORS.walk
        local u1, v1 = Geo.FromYards(leg.from.instance, leg.from.x, leg.from.y)
        local u2, v2 = Geo.FromYards(leg.to.instance, leg.to.x, leg.to.y)
        if u1 and u2 then
            local done = i < route.step
            lines:Add(u1, v1, u2, v2, c[1], c[2], c[3], done and 0.3 or 0.95, leg.mode == "walk" and 2 or 3)
        end
    end
end

local function Panel()
    local frame = ns.Map.Frame()
    if not frame then return end
    if not panel then
        panel = CreateFrame("Frame", nil, frame.viewport, "BackdropTemplate")
        panel:SetPoint("TOPRIGHT", -6, -6)
        panel:SetWidth(260)
        panel:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
        panel:EnableMouse(true)
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        panel:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
        panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 0.9)
        panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.title:SetPoint("TOPLEFT", 10, -9)
        panel.title:SetPoint("RIGHT", -30, 0)
        panel.title:SetJustifyH("LEFT")
        local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() R.Clear() end)
        panel.rows = {}
    end
    if not route then
        panel:Hide()
        return
    end
    panel.title:SetText(L.WAY_TITLE:format(route.dest.name or "?", ns.Duration(route.seconds)))
    for _, row in ipairs(panel.rows) do row:Hide() end
    local y = -30
    for i, leg in ipairs(route.legs) do
        local row = panel.rows[i]
        if not row then
            row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetJustifyH("LEFT")
            panel.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        row:SetPoint("RIGHT", -8, 0)
        row:SetText(("%d. %s  |cff999999%s|r"):format(i, StepText(leg), ns.Duration(leg.seconds)))
        if i < route.step then row:SetTextColor(0.5, 0.5, 0.5)
        elseif i == route.step then row:SetTextColor(1, 0.82, 0)
        else row:SetTextColor(1, 1, 1) end
        row:Show()
        y = y - 16
    end
    panel:SetHeight(-y + 8)
    panel:Show()
end

-- the arrow to the current leg's end
local function Guide()
    local leg = route and route.legs[route.step]
    if not leg then return end
    local u, v = Geo.FromYards(leg.to.instance, leg.to.x, leg.to.y)
    ns.Arrow.SetTarget({ instance = leg.to.instance, u = u, v = v, name = StepText(leg) })
end

function R.Clear()
    route = nil
    if ns.Map.Frame() then lines:Clear() end
    if panel then panel:Hide() end
    ns.Arrow.Clear()
end

-- plan the way to a map point (u, v) and lead there; false if there is none from here
function R.To(u, v, name)
    local px, py, instance = Geo.PlayerYards()
    if not px then
        ns.Print(L.WAY_NO_POSITION)
        return false
    end
    local mapID, x, y = Geo.ZoneAt(u, v)
    local dx, dy = Geo.ToYards(mapID and Geo.Instance(mapID), u, v)
    if not dx then return false end
    local start = { instance = instance, x = px, y = py, name = L.WAY_HERE }
    local dest = { instance = Geo.Instance(mapID), x = dx, y = dy, name = name or (mapID and Geo.Name(mapID)) }
    local legs, seconds = Plan(start, dest)
    if not legs then
        ns.Print(L.WAY_NONE)
        return false
    end
    route = { legs = legs, seconds = seconds, step = 1, dest = dest }
    Draw()
    Panel()
    Guide()
    return true
end

function R.Current() return route end

-- each leg's end reached: the next (checked every second)
local function Check()
    if not route then return end
    local leg = route.legs[route.step]
    local px, py, instance = Geo.PlayerYards()
    if not (leg and px) or instance ~= leg.to.instance then return end
    if (px - leg.to.x) ^ 2 + (py - leg.to.y) ^ 2 < REACHED * REACHED then
        route.step = route.step + 1
        if route.step > #route.legs then
            ns.Print(L.ARRIVED:format(route.dest.name or ""))
            PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_OFF)
            R.Clear()
            return
        end
        ns.Print(StepText(route.legs[route.step]))
        Draw()
        Panel()
        Guide()
    end
end
R.Check = Check

ns.On("PLAYER_LOGIN", function() C_Timer.NewTicker(1, function() ns.Safe(Check) end) end)
ns.On("ZMAP_SHOW", function() if route then Draw(); Panel() end end)
ns.On("ZMAP_MENU", function(root, u, v, mapID)
    if mapID then root:CreateButton(L.MENU_ROUTE_HERE, function() R.To(u, v) end) end
end)
