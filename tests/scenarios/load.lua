-- Logging in and using the map as a player would: open it on your zone, zoom at the cursor, drag, double
-- click, close and open again.
OUT("files ok")
START()
STATE.player.wx, STATE.player.wy = -9460, 62     -- Goldshire, Elwynn Forest
STATE.layoutPending = true                        -- the first time, the window is not laid out yet when shown
OPEN()
local cl, ct, cr, cb = ZNS.Map.ViewRect()
local pu, pv = ZNS.Geo.UnitPosition("player")
OUT(("first open: zoom %.1f, on the player %s"):format(ZNS.Map.Zoom(),
    tostring(math.abs((cl + cr) / 2 - pu * ZNS.Geo.W) < 0.5 and math.abs((ct + cb) / 2 - pv * ZNS.Geo.H) < 0.5)))
OUT("opened", tostring(ZmapFrame:IsVisible()))
local _, _, m = ZNS.Geo.UnitPosition("player")
OUT("zone at start: " .. tostring(m))
OUT("labels " .. #PINS("labels"))
local dim = 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Texture" and w.desat == 0.35 and w:IsVisible() then dim = dim + 1 end
end
OUT("unexplored dimmed " .. dim)

local u, v = ZNS.Geo.ToWorld(1429, 0.42, 0.66)
local z0 = ZNS.Map.Zoom()
local sx, sy = SCREEN_OF(u, v)
WHEEL(u, v, 2)
local sx2, sy2 = SCREEN_OF(u, v)
OUT(("after wheel: zoom up %s, point held %s"):format(tostring(ZNS.Map.Zoom() > z0),
    tostring(math.abs(sx2 - sx) < 1 and math.abs(sy2 - sy) < 1)))

local l0 = ZNS.Map.ViewRect()
DRAG(u, v, u + 0.01, v)
local l1 = ZNS.Map.ViewRect()
OUT(("after drag: moved %s, following %s"):format(tostring(math.abs(l1 - l0) > 1), tostring(ZNS.Map.Following())))

local z1 = ZNS.Map.Zoom()
CLICK_MAP(u, v)
STATE.time = STATE.time + 0.1
CLICK_MAP(u, v)
FRAMES(20)
OUT("double click: zoom up " .. tostring(ZNS.Map.Zoom() > z1 * 1.5))

-- the map always fills the window: zoom right out and drag it far away, in a wide and in a tall window
local function Inside()
    local l, t, r, b = ZNS.Map.ViewRect()
    return l >= -1e-6 and t >= -1e-6 and r <= ZNS.Geo.W + 1e-6 and b <= ZNS.Geo.H + 1e-6
end
local fills = true
for _, size in ipairs({ { 1700, 700 }, { 800, 900 } }) do
    ZmapFrame:SetSize(size[1], size[2])
    VIEWPORT().scripts.OnSizeChanged(VIEWPORT())
    WHEEL(u, v, -12, 40)
    fills = fills and Inside()
    local cl, ct, cr, cb = ZNS.Map.ViewRect()
    DRAG((cl + cr) / 2 / ZNS.Geo.W, (ct + cb) / 2 / ZNS.Geo.H, 0.95, 0.95)
    DRAG(0.9, 0.9, 0.05, 0.05)
    fills = fills and Inside() and ZNS.Map.Zoom() >= 1
end
OUT(("zoomed out and dragged away: map fills the window %s, zoom %.2f"):format(tostring(fills), ZNS.Map.Zoom()))
ZmapFrame:SetSize(1382, 842)
VIEWPORT().scripts.OnSizeChanged(VIEWPORT())

ZNS.Map.Close()
OUT("closed: saved view " .. tostring(ZNS.db.view ~= nil and ZNS.db.view.z >= 1))
OPEN()
local _, _, m2 = ZNS.Geo.UnitPosition("player")
OUT("reopen on player: zone " .. tostring(m2))
OUT("errors " .. #STATE.errors)
local list = {}
for k in pairs(STATE.unknown) do list[#list + 1] = k end
table.sort(list)
OUT("unknown methods: " .. table.concat(list, ", "))
