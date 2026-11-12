-- The quest log's extras: how full the log is, the difficulty colours and tags, the search, the order by level and
-- nearest first, folding every zone, a quest's marks standing out on the map, Shift-click links, a zone's
-- right-click tracking, who takes a quest, your group's progress, the rewards' tooltips, tracking by itself, the
-- log's side and background.
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
STATE.player.level = 12
STATE.log = { { header = "Bosque de Elwynn" }, 33, { header = "Guerrero" }, 102 }
STATE.completed = {}
STATE.watched = {}
STATE.rewards, STATE.rewardMoney = { { "Espada vieja", 135274, 1 } }, 150
C_QuestLog.GetMaxNumQuestsCanAccept = function() return 3 end
C_QuestLog.GetQuestTagInfo = function(id) if id == 102 then return { tagName = "Élite", tagID = 1 } end end
local linked
function GetQuestLink(id) return "|Hquest:" .. id .. "|h[" .. id .. "]|h" end
function ChatEdit_InsertLink(link) linked = link return true end
local tipItem
function GameTooltip:SetQuestLogItem(kind, index, id) tipItem = kind .. " " .. index .. " " .. id end
EVENT("QUEST_LOG_UPDATE")
ADVANCE(1)
OPEN()
FRAMES(3)
local QP = ZNS.QuestPanel
local function Lines() return table.concat((QP.Lines()), " | ") end
local function Row(id)
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Button" and w.quest == id and w:IsVisible() then return w end
    end
end

-- how full: 2 of 3, orange; the level's colour (33 is level 2 for a level 12: green); the tag
OUT("title: " .. tostring(QP.Title()))
local c = Row(33).text.textColor
OUT(("colour of 33: %.2f %.2f %.2f; 102: %s"):format(c[1], c[2], c[3], tostring(Row(102).text:GetText())))

-- search: what matches stays (a folded zone opens for it); nothing found says so
QP.Search("collar")
OUT("search collar: " .. Lines())
QP.Search("zzzz")
OUT("search none: " .. Lines())
QP.Search("")

-- order: by level (no headers), nearest first, back to by zone
QP.CycleSort()
OUT("by level: " .. Lines())
QP.CycleSort()
OUT("nearest: " .. Lines())
QP.CycleSort()

-- every zone folded, then open again
QP.FoldAll()
OUT("all folded: " .. Lines())
QP.FoldAll()
OUT("all open: " .. Lines())

-- hovering a quest: its marks stand out, the others dim
ZNS.Map.SetView(ZNS.Geo.W * 0.735, ZNS.Geo.H * 0.64, 12)
FRAMES(5)
Row(33).scripts.OnEnter(Row(33))
FRAMES(2)
local bright, others = 0, true
for _, p in ipairs(PINS("objectives")) do
    if p.mark.quest == 33 and p.alpha == 1 then bright = bright + 1 end
    if p.mark.quest ~= 33 and p.alpha == 1 then others = false end
end
Row(33).scripts.OnLeave(Row(33))
FRAMES(2)
local after = 0
for _, p in ipairs(PINS("objectives")) do if p.alpha < 1 then after = after + 1 end end
OUT(("highlight: 33 bright %s, others dim %s; after leaving dim %d"):format(tostring(bright > 0), tostring(others), after))

-- Shift-click: the link in the chat, the details not opened
STATE.shift = true
Row(102):Click("LeftButton")
STATE.shift = false
local _, _, opened = QP.Lines()
OUT(("shift-click: %s, details %s"):format(tostring(linked), tostring(opened)))

-- right-click on a zone: track all, untrack all
local header
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Button" and w.fold and w.title == "Bosque de Elwynn" and w:IsVisible() then header = w end
end
header:Click("RightButton")
PICK(ZNS.L.QUEST_TRACK_ZONE)
local tracked = STATE.watched[33] == true
header:Click("RightButton")
PICK(ZNS.L.QUEST_UNTRACK_ZONE)
OUT(("zone menu: tracked %s, untracked %s"):format(tostring(tracked), tostring(STATE.watched[33] == nil)))

-- your group: Lyra has 33 at 1/2 and 102 ready; the list counts her, the details say how far she is
STATE.group = { { name = "Lyra", class = "MAGE" } }
EVENT("CHAT_MSG_ADDON", "Zmap", "QL\t33:1/2\t102:c", "PARTY", "Lyra-Forever")
local sentAsk = false
EVENT("GROUP_ROSTER_UPDATE")
ADVANCE(3)
for _, s in ipairs(STATE.sent) do if s.msg:sub(1, 2) == "QA" then sentAsk = true end end
OUT(("group: row %s; asked %s"):format(tostring(Row(33).text:GetText()), tostring(sentAsk)))

-- details: who takes it (a click: the arrow there), the group, the reward's tooltip
QP.Show(33)
FRAMES(5)
OUT("details: " .. Lines())
local link
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Button" and w.onClick and w.text and w:IsVisible() and tostring(w.text:GetText()):find(ZNS.L.QUEST_TURN_IN_AT:match("^[^:]+"), 1, true) then link = w end
end
ZNS.Arrow.Clear()
link:Click()
local reward
for _, w in ipairs(ALL_WIDGETS) do if w.kind == "Frame" and w.quest == 33 and w.index and w:IsVisible() then reward = w end end
reward.scripts.OnEnter(reward)
OUT(("turn-in click: arrow %s; reward tooltip: %s"):format(tostring(ZNS.Arrow.Target() ~= nil), tostring(tipItem)))
QP.Show(nil)

-- tracking by itself: a quest taken is tracked; once ready, no longer
ZNS.SetOpt("autoTrack", true)
ZNS.SetOpt("autoUntrack", true)
table.insert(STATE.log, 2, 101)
EVENT("QUEST_ACCEPTED", 101)
local auto = STATE.watched[101] == true
EVENT("QUEST_LOG_UPDATE")
ADVANCE(1)
STATE.finished = { [101] = true }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(1)
OUT(("auto: tracked on taking %s, untracked when ready %s"):format(tostring(auto), tostring(STATE.watched[101] == nil)))

-- the left side, beside the layers panel; the background
ZNS.SetOpt("questSide", "left")
local point, _, _, x = ZmapFrame.questsPanel:GetPoint(1)
ZNS.SetOpt("questAlpha", 0.5)
OUT(("left: %s x>6 %s; width for the route %s"):format(tostring(point), tostring(x > 6), tostring(QP.Width())))
ZNS.SetOpt("questSide", "right")
OUT("errors " .. #STATE.errors)
