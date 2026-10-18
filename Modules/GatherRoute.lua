-- A gathering route: round a zone's herbs and ore that you can gather (the data's and those found), the nodes
-- near each other as one stop, in a loop as short as it gets (nearest first, then the crossings undone). Drawn
-- on the map, and the arrow leads from stop to stop, round and round, until another way takes the arrow or it
-- is stopped (the map's right-click menu, either way).
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
local route   -- { mapID, instance, stops = { { u, v }, ... }, at (the stop led to) }

local function Dist(a, b) return math.sqrt(((a[1] - b[1]) * W) ^ 2 + ((a[2] - b[2]) * H) ^ 2) end

-- the stops: the nodes merged by cell (their middle), thinned evenly if too many
local function Stops(mapID)
    local cells, list = {}, {}
    for _, n in ipairs(ns.GatherSpots(mapID)) do
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

local function Guide()
    local s = route.stops[route.at]
    ns.Arrow.SetTarget({ instance = route.instance, u = s[1], v = s[2], name = L.GATHER_NEXT:format(route.at, #route.stops),
        gather = true })
end

function GR.Stop()
    if not route then return end
    route = nil
    if ns.Map.Frame() then lines:Clear() end
    local t = ns.Arrow.Target()
    if t and t.gather then ns.Arrow.Clear() end
end

-- a route round the zone (its uiMap); false if there is nothing there you can gather
function GR.Start(mapID)
    local stops = Stops(mapID)
    if #stops < 2 then
        ns.Print(L.GATHER_NONE)
        return false
    end
    ns.Route.Clear()
    local u, v = Geo.UnitPosition("player")
    route = { mapID = mapID, instance = Geo.Instance(mapID), stops = Tour(stops, u, v), at = 1 }
    local ride = (UnitLevel("player") or 1) >= 40 and 11 or 7
    ns.Print(L.GATHER_ROUTE:format(#stops, Geo.Name(mapID), ns.Duration(Length(route.stops) / ride + #stops * GATHER)))
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
ns.On("ZMAP_SHOW", function() if route then Draw() end end)
ns.On("ZMAP_MENU", function(root, u, v, mapID)
    if route then
        root:CreateButton(L.MENU_GATHER_STOP, function() GR.Stop() end)
    elseif mapID and (ns.GatherSkill("herb") or ns.GatherSkill("ore")) then
        root:CreateButton(L.MENU_GATHER_ROUTE:format(Geo.Name(mapID)), function() GR.Start(mapID) end)
    end
end)
