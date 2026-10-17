-- Flight masters of your faction on the map, the ones you know bright. Point at one to see the route from
-- the flight master nearest to you (or the one you clicked, to plan from elsewhere) and about how long it
-- takes. While you fly, a timer; the flights you take are timed and remembered, so the guesses get right.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local F = {}
ns.Flights = F

local NODES, PATHS = ns.TAXI_NODES, ns.TAXI_PATHS
local known            -- [nodeID] = true / false (discovered) from the client; nil if it does not say
local clientNames = {} -- [nodeID] = its name in the client's language
local origin           -- the node you chose to plan from
local graph            -- [from] = { paths }

local P = ns.Pins.New("flights", { level = 40, size = 20, option = "flights", minZoom = 1.3 })
local route = ns.Pins.Lines()

local function MyFaction()
    local f = UnitFactionGroup("player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or "N"
end

local function Usable(id)
    local n = NODES[id]
    return n ~= nil and (n[4] == "N" or n[4] == MyFaction())
end

local function Known(id)
    return not known or known[id] ~= false
end

function F.Name(id)
    return clientNames[id] or (NODES[id] and ns.Name(NODES[id][5])) or "?"
end

local function Where(id)
    local n = NODES[id]
    return Geo.FromYards(n[1], n[2], n[3])
end

-- the client says which flight masters you know (for any map, not only at a flight master)
local function ScanKnown()
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
    local found = {}
    local any = false
    for _, mapID in ipairs({ 1415, 1414 }) do
        local ok, list = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                any = true
                found[info.nodeID] = not info.isUndiscovered
                if info.name and info.name ~= "" then clientNames[info.nodeID] = info.name end
            end
        end
    end
    if any then known = found end
end

--------------------------------------------------------------------------------------------------------------
-- Routes and times
--------------------------------------------------------------------------------------------------------------

local function Speed()
    return ns.db.flightSpeed or ns.FLIGHT_SPEED
end

local function HopTime(path)
    return ns.db.flights[path[1] .. "-" .. path[2]] or path[3] / Speed()
end

-- the quickest way from one node to another through nodes you know: seconds, { paths }
function F.Route(from, to)
    if not graph then
        graph = {}
        for _, p in ipairs(PATHS) do
            graph[p[1]] = graph[p[1]] or {}
            table.insert(graph[p[1]], p)
        end
    end
    local dist, prev, done = { [from] = 0 }, {}, {}
    while true do
        local best, bd
        for id, d in pairs(dist) do
            if not done[id] and (not bd or d < bd) then best, bd = id, d end
        end
        if not best then return end
        if best == to then break end
        done[best] = true
        for _, p in ipairs(graph[best] or {}) do
            local n = p[2]
            if Usable(n) and (n == to or Known(n)) then
                local d = bd + HopTime(p)
                if not dist[n] or d < dist[n] then
                    dist[n], prev[n] = d, p
                end
            end
        end
    end
    local hops, at = {}, to
    while at ~= from do
        local p = prev[at]
        table.insert(hops, 1, p)
        at = p[1]
    end
    -- a whole trip timed before beats the sum of its hops
    return ns.db.flights[from .. "-" .. to] or dist[to], hops
end

-- for the route planner: the flight masters you can use { [id] = { instance, x, y } }, and their hops
-- { { from, to, seconds } }
function F.Network()
    local nodes, hops = {}, {}
    for id, n in pairs(NODES) do
        if Usable(id) and Known(id) then nodes[id] = { n[1], n[2], n[3] } end
    end
    for _, p in ipairs(PATHS) do
        if nodes[p[1]] and nodes[p[2]] then hops[#hops + 1] = { p[1], p[2], HopTime(p) } end
    end
    return nodes, hops
end

-- the known flight master nearest to you on this continent
function F.Nearest()
    local px, py, instance = Geo.PlayerYards()
    if not px then return end
    local best, bd
    for id, n in pairs(NODES) do
        if n[1] == instance and Usable(id) and Known(id) then
            local d = (n[2] - px) ^ 2 + (n[3] - py) ^ 2
            if not bd or d < bd then best, bd = id, d end
        end
    end
    return best
end

local function From() return origin or F.Nearest() end

--------------------------------------------------------------------------------------------------------------
-- On the map
--------------------------------------------------------------------------------------------------------------

function P:OnCreate(pin)
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetAtlas("Waypoint-MapPin-Highlight")
    pin.glow:SetPoint("CENTER")
    pin.glow:SetSize(34, 34)
    pin.glow:Hide()
end

function P:Refresh()
    self:ReleaseAll()
    ScanKnown()
    for id, n in pairs(NODES) do
        if Usable(id) then
            local u, v = Where(id)
            local pin = self:Acquire()
            pin.id = id
            if Known(id) then
                pin.icon:SetAtlas(n[4] == "A" and "TaxiNode_Alliance" or n[4] == "H" and "TaxiNode_Horde" or "TaxiNode_Neutral")
            else
                pin.icon:SetAtlas("TaxiNode_Undiscovered")
            end
            pin.glow:SetShown(id == origin)
            self:Place(pin, u, v, id == origin and 1.2 or 1)
        end
    end
end

function P:Tooltip(pin, tip)
    local id = pin.id
    tip:SetText(F.Name(id), 1, 1, 1)
    if not Known(id) then tip:AddLine(L.FLIGHT_UNKNOWN, 1, 0.4, 0.4) end
    local from = From()
    if from and from ~= id then
        local secs, hops = F.Route(from, id)
        if secs then
            local stops = #hops > 1 and L.FLIGHT_STOPS:format(#hops - 1) or L.FLIGHT_DIRECT
            tip:AddLine(L.FLIGHT_FROM:format(F.Name(from), ns.Duration(secs), stops), 1, 0.82, 0, true)
            if ns.db.flights[from .. "-" .. id] then tip:AddLine(L.FLIGHT_MEASURED, 0.5, 0.9, 0.5) end
        elseif Known(id) then
            tip:AddLine(L.FLIGHT_NO_ROUTE:format(F.Name(from)), 1, 0.5, 0.3, true)
        end
    end
    tip:AddLine(origin == id and L.FLIGHT_HINT_ORIGIN or L.FLIGHT_HINT, 0.6, 0.6, 0.6, true)
end

function P:OnEnter(pin)
    route:Clear()
    local from = From()
    if not from or from == pin.id then return end
    local _, hops = F.Route(from, pin.id)
    if not hops then return end
    for _, p in ipairs(hops) do
        local n = NODES[p[1]]
        local pts, poly = {}, p[5]
        for i = 1, #poly - 1, 2 do
            local u, v = Geo.FromYards(n[1], poly[i], poly[i + 1])
            pts[#pts + 1], pts[#pts + 2] = u, v
        end
        route:AddPath(pts, 1, 0.82, 0.1, 0.9, 3)
    end
end

function P:OnLeave() route:Clear() end

function P:OnClick(pin, button)
    if button == "LeftButton" and IsControlKeyDown() then
        local u, v = Where(pin.id)
        local mapID, x, y = Geo.ZoneAt(u, v)
        if mapID then ns.Waypoints.Add(mapID, x, y, F.Name(pin.id), { navigate = true, temp = true }) end
    elseif button == "LeftButton" then
        origin = origin ~= pin.id and pin.id or nil
        P:Update()
    elseif button == "RightButton" then
        origin = nil
        P:Update()
    end
end

ns.On("TAXI_NODE_STATUS_CHANGED", function() P:Update() end)
ns.On("ZMAP_HIDE", function() route:Clear() end)

--------------------------------------------------------------------------------------------------------------
-- The flight timer, and learning how long flights take
--------------------------------------------------------------------------------------------------------------

local flight     -- { from, to, name, taken, start, eta, length }
local bar

local function Bar()
    if bar then return bar end
    bar = CreateFrame("StatusBar", "ZmapFlightBar", UIParent, "BackdropTemplate")
    bar:SetSize(240, 18)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -96)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.25, 0.6, 1)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bar:SetBackdropColor(0, 0, 0, 0.6)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    return bar
end

local function Record(f, seconds)
    if not (f.from and f.to) or seconds < 5 then return end
    local key = f.from .. "-" .. f.to
    local old = ns.db.flights[key]
    ns.db.flights[key] = old and (old + seconds) / 2 or seconds
    -- how fast flights really are: from the trips flown in one hop
    local _, hops = F.Route(f.from, f.to)
    if hops and #hops == 1 then
        local samples = ns.db.flightSamples or {}
        samples[#samples + 1] = hops[1][3] / seconds
        while #samples > 20 do table.remove(samples, 1) end
        ns.db.flightSamples = samples
        local sorted = { unpack(samples) }
        table.sort(sorted)
        ns.db.flightSpeed = sorted[math.ceil(#sorted / 2)]
    end
end

local watcher = CreateFrame("Frame")
local function Watch()
    local now = GetTime()
    if not flight then
        watcher:SetScript("OnUpdate", nil)
        return
    end
    if not flight.start then
        if UnitOnTaxi("player") then
            flight.start = now
            if flight.from and flight.to then flight.eta = F.Route(flight.from, flight.to) end
        elseif now - flight.taken > 10 then   -- never took off
            flight = nil
        end
        return
    end
    if not UnitOnTaxi("player") then
        Record(flight, now - flight.start)
        flight = nil
        if bar then bar:Hide() end
        return
    end
    if not ns.Opt("flightTimer") then
        if bar then bar:Hide() end
        return
    end
    local b = Bar()
    local spent = now - flight.start
    if flight.eta then
        b:SetMinMaxValues(0, flight.eta)
        b:SetValue(math.min(spent, flight.eta))
        b.text:SetText(L.FLIGHT_TIMER:format(flight.name or "?", ns.Duration(math.max(0, flight.eta - spent))))
    else
        b:SetMinMaxValues(0, 1)
        b:SetValue(1)
        b.text:SetText(L.FLIGHT_TIMER_UP:format(flight.name or "?", ns.Duration(spent)))
    end
    b:Show()
end

local function TaxiMapID()
    if FlightMapFrame and FlightMapFrame:IsShown() and FlightMapFrame.GetMapID then return FlightMapFrame:GetMapID() end
    local mapID = C_Map.GetBestMapForUnit("player")
    for _ = 1, 6 do
        local info = mapID and C_Map.GetMapInfo(mapID)
        if not info or info.mapType == Enum.UIMapType.Continent then break end
        mapID = info.parentMapID
    end
    return mapID
end

local function OnTake(slot)
    local mapID = TaxiMapID()
    local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    local from, to, name
    if ok and list then
        for _, n in ipairs(list) do
            if n.state == Enum.FlightPathState.Current then from = n.nodeID end
            if n.slotIndex == slot then to, name = n.nodeID, n.name end
        end
    end
    flight = { from = from, to = to, name = name or (to and F.Name(to)), taken = GetTime() }
    watcher:SetScript("OnUpdate", ns.Guard(Watch))
end

if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", OnTake) end

--------------------------------------------------------------------------------------------------------------
-- At a flight master: where to fly for your destination (the arrow's, else the nearest quest to turn in), the
-- flight and the ride after it weighed together, with a button to take it
--------------------------------------------------------------------------------------------------------------

local RIDE = 7   -- yards a second on foot or a slow mount, for the last stretch

-- where you are heading: { name, instance, x, y } (yards)
local function Heading()
    local t = ns.Arrow.Target()
    if t then
        local x, y = Geo.ToYards(t.instance, t.u, t.v)
        if x then return { name = t.name, instance = t.instance, x = x, y = y } end
    end
    local px, py, instance = Geo.PlayerYards()
    if not px then return end
    local best, bd
    for _, mark in ipairs(ns.QuestMap.Objectives()) do
        if mark.turnIn then
            local x, y = Geo.ToYards(instance, mark.u, mark.v)
            if x then
                local d = (x - px) ^ 2 + (y - py) ^ 2
                if not bd or d < bd then best, bd = { name = ns.QuestMap.Title(mark.quest), instance = instance, x = x, y = y }, d end
            end
        end
    end
    return best
end

-- From this flight master to where you are heading: the best flight { slot, node, seconds (flight + ride) }
-- (nil: quicker by land), and what was weighed { heading, seconds by land }.
function F.Advice(heading)
    heading = heading or Heading()
    if not heading then return end
    local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, TaxiMapID())
    if not ok or type(list) ~= "table" then return end
    local here
    for _, n in ipairs(list) do
        if n.state == Enum.FlightPathState.Current then here = n.nodeID end
    end
    if not here or not NODES[here] or NODES[here][1] ~= heading.instance then return end
    local land = math.sqrt((heading.x - NODES[here][2]) ^ 2 + (heading.y - NODES[here][3]) ^ 2) / RIDE
    local best
    for _, n in ipairs(list) do
        local node = NODES[n.nodeID]
        if n.state == Enum.FlightPathState.Reachable and node and node[1] == heading.instance then
            local flight = F.Route(here, n.nodeID)
            if flight then
                local seconds = flight + math.sqrt((heading.x - node[2]) ^ 2 + (heading.y - node[3]) ^ 2) / RIDE
                if seconds < (best and best.seconds or land) then best = { slot = n.slotIndex, node = n.nodeID, seconds = seconds } end
            end
        end
    end
    return best, { heading = heading, land = land }
end

local advisor
local function ShowAdvice()
    local parent = (FlightMapFrame and FlightMapFrame:IsShown() and FlightMapFrame) or (TaxiFrame and TaxiFrame:IsShown() and TaxiFrame)
    local advice, weighed = F.Advice()
    if not parent or not weighed then
        if advisor then advisor:Hide() end
        return
    end
    if not advisor then
        advisor = CreateFrame("Frame", "ZmapFlightAdvice", UIParent, "BackdropTemplate")
        advisor:SetSize(340, 50)
        advisor:SetFrameStrata("DIALOG")
        advisor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        advisor:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
        advisor:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
        advisor.text = advisor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        advisor.text:SetPoint("LEFT", 10, 0)
        advisor.text:SetPoint("RIGHT", -96, 0)
        advisor.text:SetJustifyH("LEFT")
        advisor.fly = CreateFrame("Button", nil, advisor, "UIPanelButtonTemplate")
        advisor.fly:SetSize(80, 22)
        advisor.fly:SetPoint("RIGHT", -8, 0)
        advisor.fly:SetText(L.FLY)
    end
    advisor:ClearAllPoints()
    advisor:SetPoint("BOTTOM", parent, "TOP", 0, 4)
    local dest = weighed.heading.name or "?"
    if advice then
        advisor.text:SetText(L.FLIGHT_ADVICE:format(dest, F.Name(advice.node), ns.Duration(advice.seconds)))
        advisor.fly:SetScript("OnClick", function() TakeTaxiNode(advice.slot) end)
        advisor.fly:Show()
    else
        advisor.text:SetText(L.FLIGHT_ADVICE_LAND:format(dest))
        advisor.fly:Hide()
    end
    advisor:Show()
end

ns.On("TAXIMAP_OPENED", function()
    known = nil
    ScanKnown()
    C_Timer.After(0, function() ns.Safe(ShowAdvice) end)   -- (once the game has shown its flight map)
end)
ns.On("TAXIMAP_CLOSED", function() if advisor then advisor:Hide() end end)
