-- The search box: zones, subzones, dungeons, herbs found; accents do not matter; Enter goes there.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
EVENT("UNIT_SPELLCAST_SENT", "player", "Flor de paz", "Cast-1", 2366)
EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2366)
OPEN()
local box
for _, w in ipairs(ALL_WIDGETS) do if w.Instructions then box = w end end
local function First(text)
    local r = ZNS.Search.Find(text)
    return r[1] and (r[1].text .. " (" .. tostring(r[1].sub) .. ")") or "nothing"
end
OUT("ventorm: " .. First("ventorm"))
OUT("villadorada: " .. First("villadorada"))
OUT("minas: " .. First("minas de la"))
OUT("herb search: " .. (ZNS.Search.Find("flor de")[1] or {}).text)
OUT("accents: " .. tostring(First("paramos") == First("Páramos")))
box:SetFocus()
TYPE(box, "villadorada")
box.scripts.OnEnterPressed(box)
FRAMES(20)
local u, v = ZNS.Search.Find("villadorada")[1].u, ZNS.Search.Find("villadorada")[1].v
local l, t, r, b = ZNS.Map.ViewRect()
local cx, cy = (l + r) / 2 / ZNS.Geo.W, (t + b) / 2 / ZNS.Geo.H
OUT("go: glided to Goldshire " .. tostring(math.abs(cx - u) < 0.001 and math.abs(cy - v) < 0.001))
-- any map from the search: a battleground's, a dungeon's (over its entrance)
local bg = ZNS.Search.Find("garganta grito")[1]
ZNS.Search.Go(bg)
local _, _, floor = ZNS.Dungeon.Shown()
OUT(("battleground: %s (%s), map shown %s"):format(bg.text, bg.sub, tostring(ZNS.Dungeon.IsShown() and floor == 1)))
ZNS.Dungeon.Close()
local dm = ZNS.Search.Find("minas de la muerte")[1]
ZNS.Search.Go(dm)
local listed = ZNS.Dungeon.Shown()
OUT(("dungeon: %s, map shown %s, bosses %d"):format(dm.text, tostring(ZNS.Dungeon.IsShown()), #listed))
ZNS.Dungeon.Close()
OUT("errors " .. #STATE.errors)
