-- Rares seen: when one shows up (its nameplate, your mouse over it, your target), a warning on screen and a
-- sound, a mark on the map where you were for 15 minutes, and word to your guild's Zmap users (with the
-- sharing option on), whose map and screen get it too. Once per rare every 5 minutes; not in instances.
-- And their deaths (one dead under your mouse or as your target, or word from the guild): kept between sessions,
-- so their tooltips say how long ago, and, once one has been seen alive again after it, about when it is back
-- (no data says how long a rare takes: it is learned).
local _, ns = ...
local L, Geo, Comm = ns.L, ns.Geo, ns.Comm
local IsSecret = issecretvalue or function() return false end

local AGAIN = 300      -- seconds before the same rare warns again
local KEEP = 900       -- seconds its mark stays on the map
local SOONEST = 300    -- seconds: back sooner than this after a death is another of its spawns, not the one killed
local seen = {}        -- [npcID or name] = { name, m, x, y, t, by }

--------------------------------------------------------------------------------------------------------------
-- Deaths and respawns: ns.db.rareLog[npcID or name] = { died (time()), by, respawn (the shortest seen from a
-- death to it alive again: about how long it takes) }
--------------------------------------------------------------------------------------------------------------

local function Log(key, create)
    ns.db.rareLog = ns.db.rareLog or {}
    local e = ns.db.rareLog[key]
    if not e and create then
        e = {}
        ns.db.rareLog[key] = e
    end
    return e
end

-- a death: false if it was already known a moment ago
local function Died(key, by)
    local e = Log(key, true)
    if e.died and time() - e.died < AGAIN then return false end
    e.died, e.by = time(), by
    return true
end

-- alive again: how long it took, learned
local function Alive(key)
    local e = Log(key)
    if not (e and e.died) then return end
    local gap = time() - e.died
    if gap > SOONEST then e.respawn = math.min(e.respawn or gap, gap) end
    e.died, e.by = nil, nil
end

local function Span(seconds)
    if SecondsToTime then return SecondsToTime(seconds, true) end
    return ns.Duration(seconds)
end

-- dead and not back yet, as far as Zmap knows (its icon greyed)
function ns.RareDead(key)
    local e = key and ns.db.rareLog and ns.db.rareLog[key]
    return e ~= nil and e.died ~= nil and (not e.respawn or time() - e.died < e.respawn)
end

-- its death and coming back, in a tooltip
function ns.RareTooltip(tip, key)
    local e = key and ns.db.rareLog and ns.db.rareLog[key]
    if not e then return end
    if e.died then
        local ago = time() - e.died
        tip:AddLine(L.RARE_DIED:format(Span(ago)) .. (e.by and (" (" .. e.by .. ")") or ""), 1, 0.45, 0.45)
        if e.respawn and e.respawn > ago then
            tip:AddLine(L.RARE_BACK_IN:format(Span(e.respawn - ago)), 1, 0.82, 0)
        elseif e.respawn then
            tip:AddLine(L.RARE_MAYBE_BACK, 0.4, 1, 0.4)
        else
            tip:AddLine(L.RARE_RESPAWN_UNKNOWN, 0.7, 0.7, 0.7)
        end
    elseif e.respawn then
        tip:AddLine(L.RARE_RESPAWN:format(Span(e.respawn)), 0.7, 0.7, 0.7)
    end
end

local P = ns.Pins.New("rareseen", { level = 97, size = 24, option = "rareAlert", minZoom = 1 })

function P:OnCreate(pin)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    pin.ring:SetPoint("CENTER")
    pin.ring:SetSize(40, 40)
    pin.ring:SetVertexColor(1, 0.35, 0.2)
end

function P:Refresh()
    self:ReleaseAll()
    local now = GetTime()
    for key, r in pairs(seen) do
        if now - r.t > KEEP then
            seen[key] = nil
        else
            local u, v = Geo.ToWorld(r.m, r.x, r.y)
            if u then
                local pin = self:Acquire()
                pin.icon:SetAtlas(r.elite and "VignetteKillElite" or "VignetteKill")
                pin.rare = r
                self:Place(pin, u, v)
            end
        end
    end
end

function P:Tooltip(pin, tip)
    local r = pin.rare
    tip:SetText(r.name, 1, 0.5, 0.3)
    tip:AddLine(L.RARE_SEEN_AGO:format(math.max(1, math.floor((GetTime() - r.t) / 60))), 1, 1, 1)
    if r.by then tip:AddLine(L.FOUND_BY:format(r.by), 0.6, 0.8, 1) end
    tip:AddLine(("%s  %s"):format(Geo.Name(r.m), ns.Coords(r.x, r.y)), 0.6, 0.6, 0.6)
    ns.RareTooltip(tip, r.key)
    tip:AddLine(L.CLICK_NAVIGATE, 0.6, 0.6, 0.6)
end

function P:OnClick(pin, button)
    if button == "LeftButton" then
        local r = pin.rare
        ns.Waypoints.Add(r.m, r.x, r.y, r.name, { navigate = true, temp = true })
    end
end

local function Warn(r)
    if not ns.Opt("rareAlert") then return end
    local text = r.by and L.RARE_SEEN_BY:format(r.name, r.by) or L.RARE_SEEN:format(r.name)
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.5, b = 0.3 })
    end
    PlaySound(SOUNDKIT.RAID_WARNING)
    ns.Print(("%s — %s %s"):format(text, Geo.Name(r.m), ns.Coords(r.x, r.y)))
end

-- a rare seen at a place: false if it already warned a moment ago
local function Note(key, name, elite, m, x, y, by)
    local old = seen[key]
    if old and GetTime() - old.t < AGAIN then return false end
    local r = { key = key, name = name, elite = elite, m = m, x = x, y = y, t = GetTime(), by = by }
    seen[key] = r
    Warn(r)
    P:Update()
    return true
end

local RARE = { rare = true, rareelite = true }

local function Check(unit)
    if IsInInstance() or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or IsSecret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return end
    id = tonumber(id)
    local class = UnitClassification(unit)
    if IsSecret(class) then class = nil end
    if not (RARE[class] or (id and ns.Npcs.Rare(id))) then return end
    local name = UnitName(unit)
    if not name or IsSecret(name) then return end
    local dead = UnitIsDead(unit)
    if IsSecret(dead) then return end
    if dead then
        if Died(id or name) and ns.Opt("shareFinds") and IsInGuild() then Comm.Send("D", "GUILD", nil, id or 0, name) end
        ns.Fire("ZMAP_RARES")
        return
    end
    Alive(id or name)
    local _, _, m, x, y = Geo.UnitPosition("player")
    if not m then return end
    local elite = class == "rareelite" or (id and ns.Npcs.Elite(id)) or false
    if Note(id or name, name, elite, m, x, y) and ns.Opt("shareFinds") and IsInGuild() then
        Comm.Send("R", "GUILD", nil, id or 0, m, ("%.4f"):format(x), ("%.4f"):format(y), name, elite and 1 or 0)
    end
end

Comm.On("R", function(sender, channel, id, m, x, y, name, elite)
    id, m, x, y = tonumber(id), tonumber(m), tonumber(x), tonumber(y)
    if channel ~= "GUILD" or not (m and x and y and Geo.Kind(m)) or not name or name == "" then return end
    Note(id ~= 0 and id or name, name, elite == "1", m, x, y, Ambiguate(sender, "short"))
end)

Comm.On("D", function(sender, channel, id, name)
    id = tonumber(id)
    if channel ~= "GUILD" or not name or name == "" then return end
    if Died(id ~= 0 and id or name, Ambiguate(sender, "short")) then ns.Fire("ZMAP_RARES") end
end)

ns.On("NAME_PLATE_UNIT_ADDED", Check)
ns.On("UPDATE_MOUSEOVER_UNIT", function() Check("mouseover") end)
ns.On("PLAYER_TARGET_CHANGED", function() Check("target") end)
ns.On("UNIT_HEALTH", function(unit)   -- (your target dying)
    if unit ~= "target" then return end
    local dead = UnitIsDead("target")
    if dead and not IsSecret(dead) then Check("target") end
end)

-- for the tests
function ns.RaresSeen() return seen end
