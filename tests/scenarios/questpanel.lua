-- The quests panel: the quests you carry and their objectives, in their colour; a click goes to the nearest
-- objective (or to who takes the quest once done) and sets the arrow; it is remembered open.
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
STATE.player.level = 12
STATE.log = { 33 }                              -- Wolves Across the Border
STATE.completed = {}
EVENT("QUEST_LOG_UPDATE")
OPEN()
ZmapFrame.questsButton:Click()
local lines, shown = ZNS.QuestPanel.Lines()
OUT(("panel: shown %s; %s"):format(tostring(shown), table.concat(lines, " | ")))

local function Row()
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Button" and w.quest and w:IsVisible() then return w end
    end
end
Row():Click()
local target = ZNS.Arrow.Target()
local l, t, r, b = ZNS.Map.ViewRect()
FRAMES(30)
local l2, t2 = ZNS.Map.ViewRect()
OUT(("click: arrow %s, map moved %s"):format(tostring(target ~= nil), tostring(l2 ~= l or t2 ~= t)))

-- done: who takes it
STATE.finished = { [33] = true }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(1)
lines = ZNS.QuestPanel.Lines()
OUT("finished: " .. table.concat(lines, " | "))
Row():Click()
OUT("turn in: arrow to " .. tostring(ZNS.Arrow.Target() and ZNS.Arrow.Target().name))

-- closed and opened again: still there
ZNS.Map.Close()
OPEN()
local _, again = ZNS.QuestPanel.Lines()
OUT("reopened: shown " .. tostring(again))
ZmapFrame.questsButton:Click()
local _, gone = ZNS.QuestPanel.Lines()
OUT("toggled: shown " .. tostring(gone))
OUT("errors " .. #STATE.errors)
