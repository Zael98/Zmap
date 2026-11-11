-- The quest log on the map: the quests under their headers with what is left of them, a box to track each, the
-- headers folding; a quest's details (its text, objectives, rewards) with Go there, Share, Abandon and Back; a
-- click on a quest's mark on the map opens its details too, in Zmap (not Blizzard's map).
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
STATE.player.level = 12
STATE.log = { { header = "Bosque de Elwynn" }, 33, { header = "Guerrero" }, 102 }
STATE.completed = {}
STATE.rewards, STATE.rewardMoney = { { "Espada vieja", 135274, 1 } }, 150
EVENT("QUEST_LOG_UPDATE")
OPEN()   -- (the log is there from the map's opening)
local lines, shown = ZNS.QuestPanel.Lines()
OUT(("list: shown %s; %s"):format(tostring(shown), table.concat(lines, " | ")))

local function Row(id)
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Button" and w.quest == id and w:IsVisible() then return w end
    end
end
local function ButtonCalled(text)
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Button" and w.text == text and w:IsVisible() then return w end
    end
end

-- track it, fold a header
Row(33).check:Click()
local _, _, header
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Button" and w.fold and w.title == "Guerrero" and w:IsVisible() then header = w end
end
header:Click()
local folded = ZNS.QuestPanel.Lines()
OUT(("tracked %s, mark %s; folded: %s"):format(tostring(STATE.watched and STATE.watched[33]), tostring(Row(33).check.mark:IsShown()),
    table.concat(folded, " | ")))
header:Click()

-- its details: the map goes there
local l, t = ZNS.Map.ViewRect()
Row(33):Click("LeftButton")
FRAMES(30)
local l2, t2 = ZNS.Map.ViewRect()
local _, _, quest = ZNS.QuestPanel.Lines()
lines = ZNS.QuestPanel.Lines()
OUT(("details of %s: %s; map moved %s"):format(tostring(quest), table.concat(lines, " | "), tostring(l2 ~= l or t2 ~= t)))
ButtonCalled(ZNS.L.QUEST_GO):Click()
OUT("go there: arrow " .. tostring(ZNS.Arrow.Target() ~= nil))
ButtonCalled(SHARE_QUEST_ABBREV or "Share"):Click()
ButtonCalled(ABANDON_QUEST_ABBREV or "Abandon"):Click()
OUT(("share: index %s; abandon: %s %s, asked %s"):format(tostring(STATE.shared), tostring(STATE.abandoning),
    tostring(STATE.popup and STATE.popup[1]), tostring(STATE.popup and STATE.popup[2])))
ButtonCalled(BACK or "Back"):Click()
local _, _, back = ZNS.QuestPanel.Lines()
OUT("back: details " .. tostring(back))

-- a click on its mark on the map: its details, in Zmap
ZNS.Map.SetView(ZNS.Geo.W * 0.735, ZNS.Geo.H * 0.64, 12)
FRAMES(5)
for _, p in ipairs(PINS("objectives")) do
    if p.mark.quest == 33 and not p.mark.turnIn then p.scripts.OnClick(p, "LeftButton") break end
end
local _, _, fromMap = ZNS.QuestPanel.Lines()
OUT(("map click: details %s, blizzard %s"):format(tostring(fromMap), tostring(STATE.openedQuest)))

-- closed and opened again: still there; the button hides it
ZNS.Map.Close()
OPEN()
local _, again = ZNS.QuestPanel.Lines()
ZmapFrame.questsPanel.foldButton:Click()
local _, gone = ZNS.QuestPanel.Lines()
local tab = ZmapFrame.questsTab:IsShown()
ZNS.Map.Close()
OPEN()
local _, stillFolded = ZNS.QuestPanel.Lines()
ZmapFrame.questsTab:Click()
local _, back = ZNS.QuestPanel.Lines()
OUT(("reopened: shown %s; folded: shown %s, tab %s, after reopening %s; tab click: shown %s"):format(tostring(again),
    tostring(gone), tostring(tab), tostring(stillFolded), tostring(back)))
-- a giver that does not offer a quest the data says it gives: that quest is no longer marked
local mark = ZNS.QuestMap.Givers()[1]
local npc, quest = mark.npc, mark.quests[1]
STATE.npc, STATE.offered = { id = npc, name = "Dador" }, {}
EVENT("GOSSIP_SHOW")
local still = false
for _, m in ipairs(ZNS.QuestMap.Givers()) do
    for _, q in ipairs(m.quests) do if q == quest then still = true end end
end
EVENT("PLAYER_LEVEL_UP")
ADVANCE(1)
local again = false
for _, m in ipairs(ZNS.QuestMap.Givers()) do
    for _, q in ipairs(m.quests) do if q == quest then again = true end end
end
OUT(("not offered: still marked %s; after a level up %s"):format(tostring(still), tostring(again)))
STATE.npc, STATE.offered = nil, nil

-- only the tracked quests: 33 is tracked, 102 is not; its marks go from the map and the minimap
OPEN()
ZNS.Map.SetView(ZNS.Geo.W * 0.735, ZNS.Geo.H * 0.64, 3)
FRAMES(5)
local function Marks(id)
    local n = 0
    for _, p in ipairs(PINS("objectives")) do if p.mark.quest == id then n = n + 1 end end
    for _, p in ipairs(PINS("quests")) do if p.questID == id then n = n + 1 end end
    return n
end
local before102, before33 = Marks(102), Marks(33)
ZNS.SetOpt("trackedOnly", true)
ADVANCE(1)
FRAMES(3)
OUT(("tracked only: 102 %d -> %d, 33 %d -> %d, shown 102 %s"):format(before102, Marks(102), before33, Marks(33),
    tostring(ZNS.QuestMap.Shown(102))))
STATE.watched[102] = true
EVENT("QUEST_WATCH_UPDATE")
ADVANCE(1)
FRAMES(3)
OUT(("tracked it: 102 %d"):format(Marks(102)))
STATE.watched[102] = nil
ZNS.SetOpt("trackedOnly", false)
ADVANCE(1)

-- L: the map with its quest log, even when the log was folded; again, closed
ZNS.Map.Close()
ZNS.db.questPanel = false
OUT("binding: L -> " .. tostring(STATE.bindings.L))
ZmapQuestsButton:Click()
local opened, logShown = ZNS.Map.IsShown(), ZNS.QuestPanel.Shown()
ZmapQuestsButton:Click()
OUT(("L: map %s, log %s; again: map %s"):format(tostring(opened), tostring(logShown), tostring(ZNS.Map.IsShown())))
ZNS.SetOpt("replaceQuestLog", false)
OUT("L given back: " .. tostring(STATE.bindings.L) .. ", M " .. tostring(STATE.bindings.M))
ZNS.SetOpt("replaceQuestLog", true)

-- its size (an option, for big screens): the whole log, its tab too; the route panel keeps to its left
OPEN()
ZNS.SetOpt("questScale", 1.5)
OUT(("size: panel %s, tab %s, width %s"):format(tostring(ZmapFrame.questsPanel:GetScale()),
    tostring(ZmapFrame.questsTab:GetScale()), tostring(ZNS.QuestPanel.Width())))
ZNS.SetOpt("questScale", 1)
OUT("errors " .. #STATE.errors)
