-- Your corpse: on the map while you are a ghost, and the arrow points to it (if the option is on). The game knows
-- where it is only a moment after you release (Blizzard's map asks each time it is drawn), so while you are dead
-- or a ghost Zmap asks every second.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("corpse", { level = 85, size = 22 })
local corpse   -- u, v, instance
local IsSecret = issecretvalue or function() return false end

-- where the game has the corpse on a map: u, v, instance
local function On(mapID)
    local pos = C_DeathInfo.GetCorpseMapPosition(mapID)
    local x, y = pos and pos.x, pos and pos.y
    if not x or IsSecret(x) or IsSecret(y) or (x == 0 and y == 0) then return end
    local u, v = Geo.ToWorld(mapID, x, y)
    return u and { u = u, v = v, instance = Geo.Instance(mapID) }
end

-- on the map you are on (as a ghost, most often the corpse's own zone), else on the continents and the isle (it
-- may be in another zone than the graveyard)
local function Find()
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) or not UnitIsGhost("player") then return end
    local _, _, here = Geo.UnitPosition("player")
    local found = here and On(here)
    if found then return found end
    for _, land in ipairs(Geo.Lands()) do
        found = On(land)
        if found then return found end
    end
end

local function Same(a, b)
    if not (a and b) then return a == b end
    return a.instance == b.instance and math.abs(a.u - b.u) < 1e-4 and math.abs(a.v - b.v) < 1e-4
end

-- the game's tombstone, as Blizzard's map draws a corpse
function P:OnCreate(pin)
    pin.icon:SetTexture("Interface\\Minimap\\POIIcons")
    pin.icon:SetTexCoord(0.56640625, 0.6328125, 0.001953125, 0.03515625)
end

function P:Refresh()
    self:ReleaseAll()
    if corpse then self:Place(self:Acquire(), corpse.u, corpse.v) end
end

function P:Tooltip(_, tip) tip:SetText(L.YOUR_CORPSE, 1, 1, 1) end

-- the map and the arrow follow the corpse only when it appears, moves or goes (a cleared arrow stays cleared)
local function Update()
    local now = Find()
    if Same(now, corpse) then return end
    local had = corpse
    corpse = now
    P:Update()
    if corpse and ns.Opt("corpseArrow") and not ns.Waypoints.Active() then
        ns.Arrow.SetTarget({ instance = corpse.instance, u = corpse.u, v = corpse.v, name = L.YOUR_CORPSE, corpse = true })
    elseif had and not corpse then
        local t = ns.Arrow.Target()
        if t and t.corpse then ns.Arrow.Clear() end
    end
end

local ticker   -- (asks every second while you are dead or a ghost)
local function Watch()
    Update()
    local dead = UnitIsDeadOrGhost("player")
    if dead and not ticker then
        ticker = C_Timer.NewTicker(1, function() ns.Safe(Watch) end)
    elseif not dead and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- (PLAYER_ALIVE also comes when you release: you are a ghost then)
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, Watch)
end
