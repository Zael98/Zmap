-- Your corpse: on the map while you are a ghost, and the arrow points to it (if the option is on).
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("corpse", { level = 85, size = 22 })
local corpse   -- u, v, instance

local function Find()
    corpse = nil
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) or not UnitIsGhost("player") then return end
    -- the corpse may be in another zone than the graveyard: look on the continent
    for _, cont in ipairs({ 1415, 1414 }) do
        local pos = C_DeathInfo.GetCorpseMapPosition(cont)
        if pos and pos.x and not (pos.x == 0 and pos.y == 0) then
            local u, v = Geo.ToWorld(cont, pos.x, pos.y)
            corpse = { u = u, v = v, instance = Geo.Instance(cont) }
            return
        end
    end
end

function P:Refresh()
    self:ReleaseAll()
    if corpse then
        local pin = self:Acquire()
        pin.icon:SetAtlas("ui-hud-minimap-arrow-corpse")
        self:Place(pin, corpse.u, corpse.v)
    end
end

function P:Tooltip(_, tip) tip:SetText(L.YOUR_CORPSE, 1, 1, 1) end

local function Update()
    local had = corpse ~= nil
    Find()
    P:Update()
    if corpse and ns.Opt("corpseArrow") and not ns.Waypoints.Active() then
        ns.Arrow.SetTarget({ instance = corpse.instance, u = corpse.u, v = corpse.v, name = L.YOUR_CORPSE, corpse = true })
    elseif had and not corpse then
        local t = ns.Arrow.Target()
        if t and t.corpse then ns.Arrow.Clear() end
    end
end

ns.On("PLAYER_DEAD", function() C_Timer.After(1, Update) end)
ns.On("PLAYER_ALIVE", Update)       -- (also when you release: you are a ghost then)
ns.On("PLAYER_UNGHOST", Update)
ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, Update) end)
