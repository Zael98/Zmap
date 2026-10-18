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
OPEN()
ZmapFrame.questsButton:Click()
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
    if w.kind == "Button" and w.fold and w.text and w.text:GetText() == "Guerrero" and w:IsVisible() then header = w end
end
header:Click()
OUT(("tracked %s, mark %s; folded: %s"):format(tostring(STATE.watched and STATE.watched[33]), tostring(Row(33).check.mark:IsShown()),
    header.fold:GetText()))

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
ZmapFrame.questsButton:Click()
local _, gone = ZNS.QuestPanel.Lines()
OUT(("reopened: shown %s; toggled: shown %s"):format(tostring(again), tostring(gone)))
OUT("errors " .. #STATE.errors)
