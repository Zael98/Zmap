-- Guildmates who use Zmap, on your map: each sends where they are to the guild (addon messages, never in
-- instances or combat) every so often, if they share it (on by default; the options turn it off).
local _, ns = ...
local L, Geo, Comm = ns.L, ns.Geo, ns.Comm

local EVERY = 15         -- seconds between our updates while we move
local QUIET = 60         -- ... and while we stand still
local TTL = 75           -- a guildmate not heard from for this long leaves the map
local members = {}       -- [sender] = { m, x, y, level, class, t }
local last = {}          -- what we sent last: m, x, y, t

local P = ns.Pins.New("guild", { level = 70, size = 13, option = "guild" })

function P:OnCreate(pin)
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
    pin.label:SetShadowOffset(1, -1)
end

function P:Refresh()
    self:ReleaseAll()
    local now = GetTime()
    for sender, m in pairs(members) do
        local name = Ambiguate(sender, "none")
        if now - m.t > TTL then
            members[sender] = nil
        elseif not (UnitInParty(name) or UnitInRaid(name)) then   -- the group module already shows them
            local u, v = Geo.ToWorld(m.m, m.x, m.y)
            if u then
                local pin = self:Acquire()
                local r, g, b = ns.ClassColor(m.class)
                pin.icon:SetAtlas("WhiteCircle-RaidBlips")
                pin.icon:SetVertexColor(r, g, b)
                pin.label:SetText(name)
                pin.label:SetTextColor(r * 0.85 + 0.15, g * 0.85 + 0.15, b * 0.85 + 0.15)
                pin.member, pin.name = m, name
                self:Place(pin, u, v)
            end
        end
    end
end

function P:Tooltip(pin, tip)
    local m = pin.member
    local r, g, b = ns.ClassColor(m.class)
    tip:SetText(pin.name, r, g, b)
    tip:AddLine(L.GUILDMATE_LEVEL:format(m.level or "?"), 1, 1, 1)
    tip:AddLine(("%s  %s"):format(Geo.Name(m.m), ns.Coords(m.x, m.y)), 1, 0.82, 0)
    tip:AddLine(L.SEEN_AGO:format(math.floor(GetTime() - m.t)), 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "LeftButton" and IsControlKeyDown() then
        ns.Waypoints.Add(pin.member.m, pin.member.x, pin.member.y, pin.name, { navigate = true, temp = true })
    end
end

Comm.On("P", function(sender, channel, m, x, y, level, class)
    if channel ~= "GUILD" then return end
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if not (m and x and y and Geo.Kind(m)) then return end
    members[sender] = { m = m, x = x, y = y, level = tonumber(level), class = class, t = GetTime() }
    P:Update()
end)

-- someone came online and asks where everyone is
local function Broadcast(force)
    if not ns.db or not ns.Opt("shareGuild") or not IsInGuild() then return end
    if InCombatLockdown() or IsInInstance() then return end
    local _, _, m, x, y = Geo.UnitPosition("player")
    if not m then return end
    local now = GetTime()
    local moved = last.m ~= m or math.abs((last.x or 0) - x) > 0.002 or math.abs((last.y or 0) - y) > 0.002
    if not force and not moved and now - (last.t or 0) < QUIET then return end
    if Comm.Send("P", "GUILD", nil, m, ("%.4f"):format(x), ("%.4f"):format(y), UnitLevel("player"), select(2, UnitClass("player"))) then
        last.m, last.x, last.y, last.t = m, x, y, now
    end
end

Comm.On("Q", function(_, channel)
    if channel == "GUILD" then C_Timer.After(1 + math.random() * 4, function() Broadcast(true) end) end
end)

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(8, function()
        if ns.Opt("guild") then Comm.Send("Q", "GUILD") end
        Broadcast(true)
        C_Timer.NewTicker(EVERY, function() Broadcast(false) end)
    end)
end)

-- the list fades as people go quiet, even with nothing new arriving
local wait = 0
ns.On("ZMAP_TICK", function(elapsed)
    wait = wait - elapsed
    if wait <= 0 then
        wait = 5
        P:Update()
    end
end)
