-- Quests from the data (Data/Quests.lua, QuestieDB's Forever database), the way Questie shows them: who gives
-- the quests you can take now ("!", by your level, race, class and the quests you have done; grey ones too
-- low for you, if you want them), where the objectives of the quests you carry are (the mobs to kill, the
-- objects to use, the mobs and objects that drop what is asked for), and who takes the ones you finished ("?").
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local QM = {}
ns.QuestMap = QM

local QUESTS = ns.QUESTS or {}
local MAX_PER_QUEST = 80    -- objective marks per quest
local COLORS = { { 1, 0.82, 0.1 }, { 0.3, 0.8, 1 }, { 1, 0.4, 0.4 }, { 0.5, 1, 0.4 }, { 0.9, 0.5, 1 }, { 1, 0.6, 0.2 },
    { 0.4, 1, 0.9 }, { 1, 1, 1 } }

local completed, inLog, finished, logList = {}, {}, {}, {}
local giverMarks, objectiveMarks   -- built from the quest log; nil: to build again
local dirty = true

--------------------------------------------------------------------------------------------------------------
-- What you have done, carry and can take
--------------------------------------------------------------------------------------------------------------

local function Scan()
    wipe(completed)
    wipe(inLog)
    wipe(finished)
    wipe(logList)
    if C_QuestLog.GetAllCompletedQuestIDs then
        for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do completed[id] = true end
    end
    for i = 1, (C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0) do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            logList[#logList + 1] = info.questID
            inLog[info.questID] = true
            if C_QuestLog.IsComplete(info.questID) then finished[info.questID] = true end
        end
    end
end

local function Has(mask, bit) return mask == 0 or math.floor(mask / bit) % 2 == 1 end

-- your race and class as the data's masks (Forever's own races sit on bits 32 and 33)
local function RaceBit()
    local _, _, id = UnitRace("player")
    if id == 95 then return 2 ^ 32 elseif id == 96 then return 2 ^ 33 end
    return 2 ^ ((id or 1) - 1)
end
local function ClassBit()
    local _, _, id = UnitClass("player")
    return 2 ^ ((id or 1) - 1)
end

-- { name, level, required level, races, classes, givers, giver objects, takers, taker objects, mobs, objects,
--   any-of prerequisites, all-of prerequisites, exclusive with, highest level, flags }
function QM.Available(id, q, level, race, class)
    if completed[id] or inLog[id] then return false end
    if q[16] >= 2 then return false end           -- needs a profession or spell, or an event's
    if level < q[3] or (q[15] > 0 and level > q[15]) then return false end
    if not Has(q[4], race) or not Has(q[5], class) then return false end
    if #q[12] > 0 then
        local any = false
        for _, p in ipairs(q[12]) do
            if completed[p] then any = true break end
        end
        if not any then return false end
    end
    for _, p in ipairs(q[13]) do
        if not completed[p] then return false end
    end
    for _, x in ipairs(q[14]) do
        if completed[x] or inLog[x] then return false end
    end
    return true
end

-- too low to be worth it (grey in your quest log)
local function Trivial(q, level)
    local range = GetQuestGreenRange and GetQuestGreenRange() or 8
    return q[2] > 0 and q[2] < level - range
end

-- the quest's name in your language when the game has it (it is asked for, for next time), else English
function QM.Title(id)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if title and title ~= "" then return title end
    if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(id) end
    return QUESTS[id] and QUESTS[id][1] or ("#" .. id)
end

local function Marks(spawns, mark, cap, out)
    for i, s in ipairs(spawns) do
        if i > cap then break end
        local u, v = Geo.ToWorld(s[1], s[2], s[3])
        if u then
            local m = setmetatable({ u = u, v = v, m = s[1], x = s[2], y = s[3] }, { __index = mark })
            out[#out + 1] = m
        end
    end
end

local function Build()
    Scan()
    dirty = false
    local level, race, class = UnitLevel("player") or 1, RaceBit(), ClassBit()
    local N = ns.Npcs
    -- quest givers: one mark per place, with every quest given there
    local byNpc, byObject = {}, {}
    for id, q in pairs(QUESTS) do
        if QM.Available(id, q, level, race, class) then
            for _, npc in ipairs(q[6]) do
                byNpc[npc] = byNpc[npc] or {}
                table.insert(byNpc[npc], id)
            end
            for _, obj in ipairs(q[7]) do
                byObject[obj] = byObject[obj] or {}
                table.insert(byObject[obj], id)
            end
        end
    end
    giverMarks = {}
    local function Giver(quests, mark, spawns)
        local trivial = true
        for _, id in ipairs(quests) do
            if not Trivial(QUESTS[id], level) then trivial = false end
        end
        table.sort(quests, function(a, b) return QUESTS[a][2] < QUESTS[b][2] end)
        mark.quests, mark.trivial = quests, trivial
        Marks(spawns, mark, 6, giverMarks)
    end
    for npc, quests in pairs(byNpc) do Giver(quests, { npc = npc }, N.Spawns(npc)) end
    for obj, quests in pairs(byObject) do Giver(quests, { object = obj }, N.ObjectSpawns(obj)) end
    -- the quests you carry: their objectives, or who takes them once done
    objectiveMarks = {}
    for i, id in ipairs(logList) do
        local q = QUESTS[id]
        if q then
            local color = COLORS[(i - 1) % #COLORS + 1]
            if finished[id] then
                if not (ns.BlizzardQuestPins and ns.BlizzardQuestPins[id]) then
                    for _, npc in ipairs(q[8]) do Marks(N.Spawns(npc), { quest = id, npc = npc, turnIn = true }, 6, objectiveMarks) end
                    for _, obj in ipairs(q[9]) do Marks(N.ObjectSpawns(obj), { quest = id, object = obj, turnIn = true }, 6, objectiveMarks) end
                end
            else
                local before = #objectiveMarks
                for _, npc in ipairs(q[10]) do
                    Marks(N.Spawns(npc), { quest = id, npc = npc, color = color }, MAX_PER_QUEST, objectiveMarks)
                end
                for _, obj in ipairs(q[11]) do
                    Marks(N.ObjectSpawns(obj), { quest = id, object = obj, color = color }, MAX_PER_QUEST, objectiveMarks)
                end
                for k = #objectiveMarks, before + MAX_PER_QUEST + 1, -1 do objectiveMarks[k] = nil end
            end
        end
    end
end

function QM.Givers()
    if dirty or not giverMarks then Build() end
    return giverMarks
end

function QM.Objectives()
    if dirty or not objectiveMarks then Build() end
    return objectiveMarks
end

function QM.InLog() if dirty then Build() end return logList end

--------------------------------------------------------------------------------------------------------------
-- On the map
--------------------------------------------------------------------------------------------------------------

local function InBox(m, u0, v0, u1, v1) return m.u > u0 and m.u < u1 and m.v > v0 and m.v < v1 end

local function WhoName(mark)
    if mark.npc then return ns.Npcs.Name(mark.npc) end
    local o = ns.OBJECTS and ns.OBJECTS[mark.object]
    return o and o[1] or "?"
end

local function QuestLine(id)
    local q = QUESTS[id]
    local r, g, b = ns.LevelColor(q[2] > 0 and q[2] or (UnitLevel("player") or 1))
    return ("[%d] %s"):format(q[2], QM.Title(id)), r, g, b
end

local function Navigate(mark)
    ns.Waypoints.Add(mark.m, mark.x, mark.y, WhoName(mark), { navigate = true, temp = true })
end

local givers = ns.Pins.New("givers", { level = 48, size = 20, option = "available", minZoom = 3, cull = true })

function givers:Refresh()
    self:ReleaseAll()
    local showTrivial = ns.Opt("trivial")
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    for _, mark in ipairs(QM.Givers()) do
        if (showTrivial or not mark.trivial) and InBox(mark, u0, v0, u1, v1) then
            local pin = self:Acquire()
            pin.icon:SetAtlas(mark.trivial and "TrivialQuests" or "QuestNormal")
            pin.mark = mark
            self:Place(pin, mark.u, mark.v)
        end
    end
end

function givers:Tooltip(pin, tip)
    local mark = pin.mark
    tip:SetText(WhoName(mark), 1, 1, 1)
    tip:AddLine(L.QUESTS_HERE, 0.7, 0.7, 0.7)
    for _, id in ipairs(mark.quests) do tip:AddLine(QuestLine(id)) end
    tip:AddLine(("%s  %s"):format(Geo.Name(mark.m), ns.Coords(mark.x, mark.y)), 0.6, 0.6, 0.6)
    tip:AddLine(L.CLICK_NAVIGATE, 0.6, 0.6, 0.6)
end

function givers:OnClick(pin, button)
    if button == "LeftButton" then Navigate(pin.mark) end
end

local objectives = ns.Pins.New("objectives", { level = 47, size = 14, option = "objectives", minZoom = 3, cull = true })

function objectives:Refresh()
    self:ReleaseAll()
    local u0, v0, u1, v1 = ns.Pins.ViewBox(0.1)
    for _, mark in ipairs(QM.Objectives()) do
        if InBox(mark, u0, v0, u1, v1) then
            local pin = self:Acquire()
            if mark.turnIn then
                pin.icon:SetAtlas("QuestTurnin")
                pin.icon:SetVertexColor(1, 1, 1)
                self:Place(pin, mark.u, mark.v, 1.5)
            else
                pin.icon:SetAtlas("WhiteCircle-RaidBlips")
                pin.icon:SetVertexColor(mark.color[1], mark.color[2], mark.color[3])
                self:Place(pin, mark.u, mark.v)
            end
            pin.mark = mark
        end
    end
end

function objectives:Tooltip(pin, tip)
    local mark = pin.mark
    tip:SetText(WhoName(mark), 1, 1, 1)
    if mark.turnIn then
        tip:AddLine(L.TURN_IN:format(QM.Title(mark.quest)), 0.4, 1, 0.4, true)
    else
        tip:AddLine(QuestLine(mark.quest))
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(mark.quest) or {}) do
            if o.text and o.text ~= "" then
                if o.finished then tip:AddLine(o.text, 0.5, 0.5, 0.5, true) else tip:AddLine(o.text, 1, 1, 1, true) end
            end
        end
    end
    tip:AddLine(L.CLICK_NAVIGATE, 0.6, 0.6, 0.6)
end

function objectives:OnClick(pin, button)
    if button == "LeftButton" then Navigate(pin.mark) end
end

local function Changed()
    dirty = true
    givers:Update()
    objectives:Update()
end
local later = ns.Debounce(0.5, Changed)
ns.On("QUEST_LOG_UPDATE", later)
ns.On("QUEST_TURNED_IN", later)
ns.On("QUEST_ACCEPTED", later)
ns.On("QUEST_REMOVED", later)
ns.On("PLAYER_LEVEL_UP", later)
ns.On("ZMAP_OPTION", function(key) if key == "trivial" then givers:Update() end end)
ns.On("ZMAP_SHOW", function() dirty = true end)
