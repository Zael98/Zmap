-- HandyNotes on Zmap's map: the nodes of every HandyNotes plugin you have (treasures, rares, notes...) on the zones in
-- view, with the plugin's own icon, size, tooltip and clicks, as HandyNotes draws them on Blizzard's map (which Zmap
-- takes the place of). Through HandyNotes' plugin API: plugin:GetNodes2(uiMapID, minimap) gives
-- (coord, uiMapID, icon, scale, alpha) for each node, coord = x * 10000 rounded, times 10000, plus y * 10000 rounded.
local _, ns = ...
local Geo = ns.Geo

local MAX = 400       -- nodes drawn at once
local PER_MAP = 3000  -- (a plugin's iterator stops here, whatever it says)

local P = ns.Pins.New("handynotes", { land = true, level = 52, size = 12, option = "handynotes", minZoom = 1.3, cull = true })

-- HandyNotes, when it is there and on
local function HandyNotes()
    local h = _G.HandyNotes
    if type(h) ~= "table" or type(h.plugins) ~= "table" then return end
    if h.IsEnabled then
        local ok, on = pcall(h.IsEnabled, h)
        if ok and not on then return end
    end
    return h
end

local function Profile(h)
    return type(h.db) == "table" and type(h.db.profile) == "table" and h.db.profile or {}
end

-- a plugin turned on in HandyNotes' options (all are, by default)
local function PluginOn(h, name)
    local enabled = Profile(h).enabledPlugins
    return not enabled or enabled[name] ~= false
end

local function Draw(pin, icon, scale, alpha, profile)
    local tex = pin.icon
    if type(icon) == "table" then
        tex:SetTexture(icon.icon)
        if icon.tCoordLeft then
            tex:SetTexCoord(icon.tCoordLeft, icon.tCoordRight, icon.tCoordTop, icon.tCoordBottom)
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
        if icon.r then tex:SetVertexColor(icon.r, icon.g, icon.b, icon.a or 1) else tex:SetVertexColor(1, 1, 1, 1) end
    else
        tex:SetTexture(icon)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(1, 1, 1, 1)
    end
    pin:SetAlpha(math.min(math.max((profile.icon_alpha or 1) * (alpha or 1), 0), 1))
    return (profile.icon_scale or 1) * (scale or 1)
end

function P:Refresh()
    self:ReleaseAll()
    local h = HandyNotes()
    if not h then return end
    local profile = Profile(h)
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
    local count, seen = 0, {}
    for _, mapID in ipairs(Geo.Zones()) do
        local l, r, t, b = Geo.Rect(mapID)
        if l and l < u1 and r > u0 and t < v1 and b > v0 then
            for name, handler in pairs(h.plugins) do
                if count >= MAX then return end
                if type(handler) == "table" and handler.GetNodes2 and PluginOn(h, name) then
                    local ok, iter, state, value = pcall(handler.GetNodes2, handler, mapID, false)
                    if ok and type(iter) == "function" then
                        for _ = 1, PER_MAP do
                            local fine, coord, m, icon, scale, alpha = pcall(iter, state, value)
                            if not fine or not coord or count >= MAX then break end
                            value = coord
                            m = m or mapID
                            local key = name .. ":" .. m .. ":" .. coord
                            if not seen[key] then
                                seen[key] = true
                                local u, v = Geo.ToWorld(m, math.floor(coord / 10000) / 10000, (coord % 10000) / 10000)
                                if u and u > u0 and u < u1 and v > v0 and v < v1 then
                                    count = count + 1
                                    local pin = self:Acquire()
                                    pin.plugin, pin.map, pin.coord = name, m, coord
                                    self:Place(pin, u, v, Draw(pin, icon, scale, alpha, profile))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- the plugin's own tooltip and clicks, as HandyNotes calls them (the pin as `self`)
local function Call(pin, method, ...)
    local h = HandyNotes()
    local handler = h and h.plugins[pin.plugin]
    local fn = handler and handler[method]
    if type(fn) == "function" then pcall(fn, pin, ...) end
end

function P:OnEnter(pin) Call(pin, "OnEnter", pin.map, pin.coord) end
function P:OnLeave(pin) Call(pin, "OnLeave", pin.map, pin.coord) end
function P:OnClick(pin, button)
    Call(pin, "OnClick", button, true, pin.map, pin.coord)    -- (HandyNotes calls it on the press and the release)
    Call(pin, "OnClick", button, false, pin.map, pin.coord)
end

-- a plugin's nodes changed (HandyNotes_NotifyUpdate), or HandyNotes' options: again
ns.On("PLAYER_LOGIN", function()
    local h = _G.HandyNotes
    if type(h) ~= "table" then return end
    for _, method in ipairs({ "UpdateWorldMap", "UpdateWorldMapPlugin" }) do
        if type(h[method]) == "function" then hooksecurefunc(h, method, function() P:Update() end) end
    end
end)

ns.HandyNotesLayer = P
