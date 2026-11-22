-- The search box: zones, subzones, dungeons, herbs found; accents do not matter; Enter goes there.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
EVENT("UNIT_SPELLCAST_SENT", "player", "Flor de paz", "Cast-1", 2366)
EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2366)
OPEN()
local box
for _, w in ipairs(ALL_WIDGETS) do if w.Instructions and w.scripts.OnEnterPressed then box = w end end   -- (the map's, not the quest log's)
local function First(text)
    local r = ZNS.Search.Find(text)
    return r[1] and (r[1].text .. " (" .. tostring(r[1].sub) .. ")") or "nothing"
end
OUT("ventorm: " .. First("ventorm"))
OUT("villadorada: " .. First("villadorada"))
OUT("minas: " .. First("minas de la"))
OUT("herb search: " .. (ZNS.Search.Find("flor de")[1] or {}).text)
OUT("accents: " .. tostring(First("paramos") == First("Páramos")))
-- a quest you can pick up, by its title in your language: found as one to pick up, and going there sets the arrow
-- to who gives it
local avail
for _, m in ipairs(ZNS.QuestMap.Givers()) do
    for _, id in ipairs(m.quests) do
        if not avail and ZNS.QUEST_NAMES and ZNS.QUEST_NAMES[id] and #ZNS.QUEST_NAMES[id] > 12 then avail = id end
    end
end
local hits = ZNS.Search.Find(ZNS.QUEST_NAMES[avail])
local hit
for _, c in ipairs(hits) do if c.questID == avail then hit = c end end
if hit then ZNS.Search.Go(hit) end
local target = ZNS.Arrow.Target()
OUT(("quest to pick up: found %s, %s, arrow %s"):format(tostring(hit ~= nil), tostring(hit and hit.sub:find(ZNS.L.QUEST_TO_TAKE, 1, true) == 1),
    tostring(target ~= nil)))
ZNS.Waypoints.Stop()
local byEnglish
for _, c in ipairs(ZNS.Search.Find(ZNS.QUESTS[avail][1])) do if c.questID == avail then byEnglish = true end end
OUT("quest by its english title: " .. tostring(byEnglish == true))

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
-- a result's name and, under it, what it is and where: each on its own line, held by both edges (cut short,
-- never running into the other)
box:SetFocus()
TYPE(box, "instructor de")
local rows, apart = 0, true
for _, w in ipairs(ALL_WIDGETS) do
    if w.shown and w.result and w.sub then
        rows = rows + 1
        local t, s = w.text.points, w.sub.points
        apart = apart and t.LEFT ~= nil and t.RIGHT ~= nil and s.TOPLEFT ~= nil and s.TOPLEFT.rel == w.text
            and s.TOPRIGHT ~= nil and s.TOPRIGHT.rel == w.text and (w.sub:GetText() == "" or t.LEFT.y > 0)
    end
end
OUT(("rows: %d, name over what it is %s"):format(rows, tostring(apart)))
OUT("errors " .. #STATE.errors)
