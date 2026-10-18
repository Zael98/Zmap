-- M opens Zmap; the options panel and the layers menu; your corpse; quests; dungeons; boats; zone levels.
START()
OUT("binding: M -> " .. tostring(STATE.bindings.M))
ZNS.SetOpt("replaceMap", false)
OUT("binding off: " .. (STATE.bindings.M or "none"))
STATE.combat = true
ZNS.SetOpt("replaceMap", true)
local during = STATE.bindings.M
STATE.combat = false
EVENT("PLAYER_REGEN_ENABLED")
OUT("binding in combat: " .. (during and "applied" or "deferred") .. ", then " .. tostring(STATE.bindings.M and "M"))

local checks, replace = 0, nil
for _, w in ipairs(ALL_WIDGETS) do
    if w.Text and w.scripts.OnClick and w.kind == "CheckButton" then
        checks = checks + 1
        if w.Text.text == ZNS.L.OPT_REPLACE then replace = w end
    end
end
ZNS.OpenOptions()
local panel = replace and replace.parent
if panel and panel.scripts.OnShow then panel.scripts.OnShow(panel) end
OUT(("options panel: checks %d, replace checked %s"):format(checks, tostring(replace and replace.checked)))

STATE.player.wx, STATE.player.wy = -9460, 62
OPEN()
local side = ZmapFrame.layersPanel
OUT(("layers panel: open %s, %s"):format(tostring(side:IsShown()), ZNS.LayerTexts()))
ZmapFrame.layersButton.scripts.OnClick(ZmapFrame.layersButton)   -- (the tab is hidden while open: nothing)
local function Row(text)
    for _, b in ipairs(side.rows) do if b.text:GetText() == text then return b end end
end
local flightsRow = Row(ZNS.L.OPT_FLIGHTS)
flightsRow.scripts.OnClick(flightsRow)
FRAMES(2)
OUT(("row off: alpha %.2f"):format(flightsRow.icon:GetAlpha()))
OUT("layer off: flights hidden " .. tostring(not PROVIDER("flights").frame:IsVisible()))
ZNS.SetOpt("flights", true)

STATE.ghost = true
STATE.corpse = { map = 1415, x = 0.4, y = 0.6 }
EVENT("PLAYER_ALIVE")
local t = ZNS.Arrow.Target()
OUT("corpse: arrow to corpse " .. tostring(t ~= nil and t.corpse == true))
STATE.ghost, STATE.corpse = false, nil
EVENT("PLAYER_UNGHOST")
OUT("alive: arrow cleared " .. tostring(ZNS.Arrow.Target() == nil))

local l, r, tt, b = ZNS.Geo.Rect(1429)
ZNS.Map.SetView((l + r) / 2 * ZNS.Geo.W, (tt + b) / 2 * ZNS.Geo.H, 4)
FRAMES(3)
local q = PINS("quests")
local turnin = false
for _, p in ipairs(q) do if p.icon.atlas == "QuestTurnin" then turnin = true end end
OUT(("quests: %d pins, turn-in %s"):format(#q, tostring(turnin)))
for _, p in ipairs(q) do if p.questID == 101 then p.scripts.OnClick(p, "LeftButton") end end
OUT(("quest click: zmap %s, blizzard %s"):format(tostring(select(3, ZNS.QuestPanel.Lines())), tostring(STATE.openedQuest)))

OPEN()
ZNS.Map.SetView(501, 334, 2)
FRAMES(3)
local d = PINS("dungeons")
local forever, dm = false, nil
for _, p in ipairs(d) do
    if p.entry.name == "Excavation Site: Wetlands" then forever = p.entry.level == 26 end
    if p.entry.name == "Minas de la Muerte" or p.entry.name == "Deadmines" then dm = HOVER(p) end
end
OUT(("dungeons: %d entrances, forever one %s, level text %s"):format(#d, tostring(forever), tostring(dm)))
local lines, docks = 0, #PINS("transports")
for _, w in ipairs(ALL_WIDGETS) do if w.kind == "Line" and w.shown then lines = lines + 1 end end
OUT(("transports: lines %d, docks %d"):format(lines, docks))
local lo, hi = ZNS.ZoneLevels(2548)
OUT(("levels: Riverglades %s-%s"):format(tostring(lo), tostring(hi)))
local welcomes = 0
for _, p in ipairs(STATE.printed) do if p:find(ZNS.L.WELCOME, 1, true) then welcomes = welcomes + 1 end end
EVENT("PLAYER_LOGIN")
local again = 0
for _, p in ipairs(STATE.printed) do if p:find(ZNS.L.WELCOME, 1, true) then again = again + 1 end end
OUT("welcome once: " .. tostring(welcomes == 1 and again == 1))
OUT("errors " .. #STATE.errors)
