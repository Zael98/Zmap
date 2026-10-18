-- A gathering route: round a zone's herbs and ore that you can gather (all of them, or one kind: chosen in the
-- map's right-click menu), the nodes near each other as one stop, in a loop as short as it gets (nearest first,
-- then the crossings undone). Drawn on the map, a bar at its top says what it is and where you are in it, and the
-- arrow leads from stop to stop, round and round, until another way takes the arrow or it is stopped (the bar's
-- close button, or the menu).
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local GR = {}
ns.GatherRoute = GR

local W, H = Geo.W, Geo.H
local MERGE = 2.5        -- canvas units (about 110 yards, what the minimap shows round you): nodes in one cell
                         -- this big are one stop
local MAX_STOPS = 80
local REACHED = 30       -- yards from a stop that count as there
local GATHER = 3         -- seconds at each stop (about)
local YARDS = 44.6       -- yards in a canvas unit (the canvas is the same yards across and down)
local COLOR = { 0.3, 1, 0.45 }

local lines = ns.Pins.Lines()
local route   -- { mapID, instance, stops = { { u, v }, ... }, at (the stop led to), label, lap (seconds) }
local bar

local function Dist(a, b) return math.sqrt(((a[1] - b[1]) * W) ^ 2 + ((a[2] - b[2]) * H) ^ 2) end

-- the stops: the nodes (of some kinds, [key] = true; nil: every kind) merged by cell (their middle), thinned
-- evenly if too many
local function Stops(mapID, keys)
    local cells, list = {}, {}
    for _, n in ipairs(ns.GatherSpots(mapID, keys)) do
        local key = math.floor(n[1] * W / MERGE) .. ":" .. math.floor(n[2] * H / MERGE)
        local c = cells[key]
        if not c then
            c = { 0, 0, 0 }
            cells[key] = c
            list[#list + 1] = c
        end
        c[1], c[2], c[3] = c[1] + n[1], c[2] + n[2], c[3] + 1
    end
    for _, c in ipairs(list) do c[1], c[2] = c[1] / c[3], c[2] / c[3] end
    return ns.Pins.Spread(list, MAX_STOPS)
end

-- the loop: nearest first from the stop nearest to you, then 2-opt (reverse a stretch while that shortens it)
local function Tour(stops, u, v)
    local n = #stops
    local first, fd = 1, nil
    for i, s in ipairs(stops) do
        local d = u and Dist(s, { u, v }) or 0
        if not fd or d < fd then first, fd = i, d end
    end
    local tour, used = { stops[first] }, { [first] = true }
    for _ = 2, n do
        local last, best, bd = tour[#tour], nil, nil
        for i, s in ipairs(stops) do
            if not used[i] then
                local d = Dist(last, s)
                if not bd or d < bd then best, bd = i, d end
            end
        end
        used[best] = true
        tour[#tour + 1] = stops[best]
    end
    for _ = 1, 8 do
        local better = false
        for i = 1, n - 2 do
            for j = i + 2, (i == 1) and n - 1 or n do   -- (the edges i, i+1 and j, j+1 share no stop)
                local a, b, c, d = tour[i], tour[i + 1], tour[j], tour[j % n + 1]
                if Dist(a, c) + Dist(b, d) < Dist(a, b) + Dist(c, d) - 1e-6 then
                    local x, y = i + 1, j
                    while x < y do
                        tour[x], tour[y] = tour[y], tour[x]
                        x, y = x + 1, y - 1
                    end
                    better = true
                end
            end
        end
        if not better then break end
    end
    return tour
end

local function Length(stops)
    local total = 0
    for i, s in ipairs(stops) do total = total + Dist(s, stops[i % #stops + 1]) end
    return total * YARDS
end

local function Draw()
    if not ns.Map.Frame() then return end
    lines:Clear()
    if not route then return end
    local stops = route.stops
    for i, s in ipairs(stops) do
        local t = stops[i % #stops + 1]
        lines:Add(s[1], s[2], t[1], t[2], COLOR[1], COLOR[2], COLOR[3], 0.8, 2)
    end
end

-- the bar at the map's top: what the route is, the stop you are led to, a lap's time; its close button stops it
local function Bar()
    local frame = ns.Map.Frame()
    if not frame then return end
    if not bar then
        bar = CreateFrame("Frame", nil, frame.viewport, "BackdropTemplate")
        bar:SetPoint("TOP", 0, -6)
        bar:SetHeight(26)
        bar:SetFrameLevel(frame.viewport:GetFrameLevel() + 200)
        bar:EnableMouse(true)
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        bar:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
        bar:SetBackdropBorderColor(COLOR[1], COLOR[2], COLOR[3], 0.8)
        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.text:SetPoint("LEFT", 10, 0)
        local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
        close:SetSize(22, 22)
        close:SetPoint("RIGHT", -2, 0)
        close:SetScript("OnClick", function() GR.Stop() end)
        bar.close = close
    end
    if not route then
        bar:Hide()
        return
    end
    bar.text:SetText(L.GATHER_BAR:format(route.label, route.at, #route.stops, ns.Duration(route.lap)))
    bar:SetWidth((bar.text:GetStringWidth() or 300) + 44)
    bar:Show()
end

local function Guide()
    local s = route.stops[route.at]
    ns.Arrow.SetTarget({ instance = route.instance, u = s[1], v = s[2], name = L.GATHER_NEXT:format(route.at, #route.stops),
        gather = true })
    Bar()
end

function GR.Stop()
    if not route then return end
    route = nil
    if ns.Map.Frame() then lines:Clear() end
    Bar()
    local t = ns.Arrow.Target()
    if t and t.gather then ns.Arrow.Clear() end
end

-- a route round the zone (its uiMap), of some kinds ([key] = true, called label; nil: every kind you can
-- gather); false if there is nothing there to gather
function GR.Start(mapID, keys, label)
    local stops = Stops(mapID, keys)
    if #stops < 2 then
        ns.Print(L.GATHER_NONE)
        return false
    end
    ns.Route.Clear()
    local u, v = Geo.UnitPosition("player")
    local ride = (UnitLevel("player") or 1) >= 40 and 11 or 7
    route = { mapID = mapID, instance = Geo.Instance(mapID), stops = Tour(stops, u, v), at = 1, label = label or L.GATHER_ALL }
    route.lap = Length(route.stops) / ride + #stops * GATHER
    ns.Print(L.GATHER_ROUTE:format(#stops, Geo.Name(mapID), ns.Duration(route.lap)))
    Draw()
    Guide()
    return true
end

function GR.Current() return route end

-- the stop reached: the next (checked every second); the arrow taken by another way: the route ends
local function Check()
    if not route then return end
    local t = ns.Arrow.Target()
    if not (t and t.gather) then
        GR.Stop()
        return
    end
    local px, py, instance = Geo.PlayerYards()
    if not px or instance ~= route.instance then return end
    local s = route.stops[route.at]
    local sx, sy = Geo.ToYards(route.instance, s[1], s[2])
    if (px - sx) ^ 2 + (py - sy) ^ 2 < REACHED * REACHED then
        route.at = route.at % #route.stops + 1
        Guide()
    end
end
GR.Check = Check

ns.On("PLAYER_LOGIN", function() C_Timer.NewTicker(1, function() ns.Safe(Check) end) end)
ns.On("ZMAP_SHOW", function() if route then Draw(); Bar() end end)
-- the menu: stop the route, or one round this zone, of what you choose (everything you can gather, or one kind:
-- the most there first, with how many)
ns.On("ZMAP_MENU", function(root, u, v, mapID)
    if route then
        root:CreateButton(L.MENU_GATHER_STOP, function() GR.Stop() end)
        return
    end
    if not (mapID and (ns.GatherSkill("herb") or ns.GatherSkill("ore"))) then return end
    local kinds = ns.GatherZoneTypes(mapID)
    if #kinds == 0 then return end
    local menu = root:CreateButton(L.MENU_GATHER_ROUTE:format(Geo.Name(mapID)))
    menu:CreateButton(L.GATHER_ALL, function() GR.Start(mapID) end)
    for _, e in ipairs(kinds) do
        local t, name = e[1], ns.ItemName(e[1].item, e[1].name)
        menu:CreateButton(("%s (%d)"):format(name, e[2]), function() GR.Start(mapID, { [t.key] = true }, name) end)
    end
end)
