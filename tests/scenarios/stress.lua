-- A long session: across both continents, in and out, open and closed, again and again. Nothing piles up.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
local W, H = ZNS.Geo.W, ZNS.Geo.H
local spots = { { 1429, 30 }, { 1415, 3 }, { 1414, 3 }, { 1446, 12 }, { 1453, 40 }, { 947, 1 }, { 2548, 8 }, { 1452, 20 } }
local function Tour()
    OPEN()
    for _, s in ipairs(spots) do
        local l, r, t, b = ZNS.Geo.Rect(s[1])
        ZNS.Map.GoTo((l + r) / 2, (t + b) / 2, s[2])
        FRAMES(12)
        WHEEL((l + r) / 2, (t + b) / 2, -1, 6)
        DRAG((l + r) / 2, (t + b) / 2, (l + r) / 2 + 0.01, (t + b) / 2)
    end
    ZNS.Map.Close()
    FRAME()
end
Tour()
local after1 = #ALL_WIDGETS
for _ = 1, 4 do Tour() end
local after5 = #ALL_WIDGETS
OUT(("widgets after one tour %d, after five %d, grew %s"):format(after1, after5, tostring(after5 > after1 + 50)))
OUT("errors " .. #STATE.errors)
