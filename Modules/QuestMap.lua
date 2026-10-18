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
    if ns.char.notOffered and ns.char.notOffered[id] then return false end   -- (its giver did not offer it)
    if math.floor(q[16] / 2) % 2 == 1 then return false end   -- needs a profession or spell
    if q[16] >= 8 then return false end                        -- a holiday's
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

local objectiveAreas   -- built from the objective marks; nil: to build again

local function Build()
    Scan()
    dirty = false
    objectiveAreas = nil
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
                -- what it asks for that is bought, and where to get to
                for _, npc in ipairs(q[17] or {}) do
                    Marks(N.Spawns(npc), { quest = id, npc = npc, color = color, buy = true }, 4, objectiveMarks)
                end
                local places = {}
                for k = 1, #(q[18] or {}) - 1, 2 do
                    local coords = q[18][k + 1]
                    for j = 1, #coords - 1, 2 do places[#places + 1] = { q[18][k], coords[j] / 1000, coords[j + 1] / 1000 } end
                end
                Marks(places, { quest = id, color = color, reach = true }, 6, objectiveMarks)
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
    if mark.reach then return QM.Title(mark.quest) end
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

-- a quest of your log: its colour on the map, and whether it is ready to turn in
function QM.Color(id)
    for i, q in ipairs(QM.InLog()) do
        if q == id then return COLORS[(i - 1) % #COLORS + 1] end
    end
end
function QM.IsFinished(id)
    if dirty then Build() end
    return finished[id] == true
end

-- where to go for a quest of your log: its nearest objective, or who takes it once it is done (a mark; nil:
-- the data knows no place)
function QM.Next(id)
    local u, v = Geo.UnitPosition("player")
    local done, best, bd = QM.IsFinished(id), nil, nil
    for _, m in ipairs(QM.Objectives()) do
        if m.quest == id and (m.turnIn == true) == done then
            local d = u and (m.u - u) ^ 2 + (m.v - v) ^ 2 or 0
            if not bd or d < bd then best, bd = m, d end
        end
    end
    if best then return best end
    -- no mark of Zmap's: the game's own mark of it on some zone, else (done) who takes it in the data
    local function Nearest(m, x, y, mark)
        local mu, mv = Geo.ToWorld(m, x, y)
        local d = mu and (u and (mu - u) ^ 2 + (mv - v) ^ 2 or 0)
        if d and (not bd or d < bd) then
            mark.u, mark.v, mark.m, mark.x, mark.y, mark.quest = mu, mv, m, x, y, id
            best, bd = mark, d
        end
    end
    if C_QuestLog.GetQuestsOnMap then
        for _, mapID in ipairs(Geo.Zones()) do
            local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
            for _, q in ipairs(ok and list or {}) do
                if q.questID == id and q.x then Nearest(mapID, q.x, q.y, { reach = true }) end
            end
        end
    end
    local q = QUESTS[id]
    if not best and q then
        for _, npc in ipairs(done and q[8] or q[10]) do
            for _, s in ipairs(ns.Npcs.Spawns(npc)) do Nearest(s[1], s[2], s[3], { npc = npc, turnIn = done or nil }) end
        end
    end
    return best
end

-- the map there, and the arrow
function QM.GoTo(id)
    local mark = QM.Next(id)
    if not mark then return false end
    ns.Map.GoTo(mark.u, mark.v, math.max(ns.Map.Zoom(), 6))
    Navigate(mark)
    return true
end

local givers = ns.Pins.New("givers", { level = 48, size = 20, option = "available", minZoom = 3, cull = true })

function givers:Refresh()
    self:ReleaseAll()
    local showTrivial = ns.Opt("trivial")
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
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

--------------------------------------------------------------------------------------------------------------
-- Objective areas: a quest's mobs and objects as the area round each group of them (the way Questie shows
-- them), filled in the quest's colour and outlined, with one mark in its middle for what it is. Worked out on
-- the canvas (its units are the same yards across and down), drawn as bands across, the outline over them.
--------------------------------------------------------------------------------------------------------------

local W, H = Geo.W, Geo.H
local AREA_GAP = 3       -- canvas units (about 135 yards): spawns nearer than this to one of a group are in it
local AREA_PAD = 1.2     -- canvas units round each spawn
local AREA_FILL, AREA_EDGE = 0.2, 0.8

-- the convex hull of points { x1, y1, x2, y2, ... } (Andrew's monotone chain), as such a list
local function Hull(pts)
    local p = {}
    for i = 1, #pts - 1, 2 do p[#p + 1] = { pts[i], pts[i + 1] } end
    table.sort(p, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    local function Cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
    local h = {}
    for _, q in ipairs(p) do
        while #h >= 2 and Cross(h[#h - 1], h[#h], q) <= 0 do h[#h] = nil end
        h[#h + 1] = q
    end
    local lower = #h + 1
    for i = #p - 1, 1, -1 do
        while #h >= lower and Cross(h[#h - 1], h[#h], p[i]) <= 0 do h[#h] = nil end
        h[#h + 1] = p[i]
    end
    h[#h] = nil
    local out = {}
    for _, q in ipairs(h) do out[#out + 1], out[#out + 2] = q[1], q[2] end
    return out
end

-- { hull, mark (the spawn nearest its middle: its tooltip, where a click leads), color, u, v, u0, v0, u1, v1 }
function QM.Areas()
    if objectiveAreas and not dirty then return objectiveAreas end
    local byQuest = {}
    for _, m in ipairs(QM.Objectives()) do
        if not (m.turnIn or m.buy or m.reach) then
            byQuest[m.quest] = byQuest[m.quest] or {}
            table.insert(byQuest[m.quest], m)
        end
    end
    objectiveAreas = {}
    for _, marks in pairs(byQuest) do
        -- the groups (union-find over the spawns near each other)
        local parent = {}
        local function Root(i)
            while parent[i] ~= i do
                parent[i] = parent[parent[i]]
                i = parent[i]
            end
            return i
        end
        for i = 1, #marks do parent[i] = i end
        for i = 1, #marks do
            for j = i + 1, #marks do
                local dx, dy = (marks[i].u - marks[j].u) * W, (marks[i].v - marks[j].v) * H
                if dx * dx + dy * dy < AREA_GAP * AREA_GAP then parent[Root(i)] = Root(j) end
            end
        end
        local groups = {}
        for i, m in ipairs(marks) do
            local r = Root(i)
            groups[r] = groups[r] or {}
            table.insert(groups[r], m)
        end
        for _, group in pairs(groups) do
            local pts, cx, cy = {}, 0, 0
            for _, m in ipairs(group) do
                local x, y = m.u * W, m.v * H
                cx, cy = cx + x / #group, cy + y / #group
                for k = 0, 7 do
                    pts[#pts + 1] = x + math.cos(k * math.pi / 4) * AREA_PAD
                    pts[#pts + 1] = y + math.sin(k * math.pi / 4) * AREA_PAD
                end
            end
            local best, bd
            for _, m in ipairs(group) do
                local d = (m.u * W - cx) ^ 2 + (m.v * H - cy) ^ 2
                if not bd or d < bd then best, bd = m, d end
            end
            local hull = Hull(pts)
            local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
            for i = 1, #hull - 1, 2 do
                x0, x1 = math.min(x0, hull[i]), math.max(x1, hull[i])
                y0, y1 = math.min(y0, hull[i + 1]), math.max(y1, hull[i + 1])
            end
            objectiveAreas[#objectiveAreas + 1] = { hull = hull, mark = best, color = best.color, u = cx / W, v = cy / H,
                u0 = x0 / W, v0 = y0 / H, u1 = x1 / W, v1 = y1 / H }
        end
    end
    return objectiveAreas
end

local areaFrame, areaBands, areaUsed = nil, {}, 0
local areaLines = ns.Pins.Lines()

local function ClearAreas()
    for i = 1, areaUsed do areaBands[i]:Hide() end
    areaUsed = 0
    areaLines:Clear()
end

local function DrawArea(a)
    if not areaFrame then
        areaFrame = CreateFrame("Frame", nil, ns.Map.Canvas())
        areaFrame:SetAllPoints()
        areaFrame:SetFrameLevel(ns.Art.levelTop - 2)   -- (under the outlines and the pins)
    end
    local c, hull = a.color, a.hull
    local ymin, ymax = a.v0 * H, a.v1 * H
    local band = math.max(3 / ns.Map.K(), (ymax - ymin) / 48)   -- (about 3 pixels on screen; 48 at most)
    local y = ymin
    while y < ymax do
        local yc, xmin, xmax = y + band / 2, math.huge, -math.huge
        for i = 1, #hull - 1, 2 do
            local j = i + 2 > #hull and 1 or i + 2
            local x1, y1, x2, y2 = hull[i], hull[i + 1], hull[j], hull[j + 1]
            if (y1 <= yc and y2 > yc) or (y2 <= yc and y1 > yc) then
                local x = x1 + (yc - y1) * (x2 - x1) / (y2 - y1)
                xmin, xmax = math.min(xmin, x), math.max(xmax, x)
            end
        end
        if xmax > xmin then
            areaUsed = areaUsed + 1
            local tex = areaBands[areaUsed]
            if not tex then
                tex = areaFrame:CreateTexture(nil, "ARTWORK")
                areaBands[areaUsed] = tex
            end
            tex:SetColorTexture(c[1], c[2], c[3], AREA_FILL)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", areaFrame, "TOPLEFT", xmin, -y)
            tex:SetSize(xmax - xmin, math.min(band, ymax - y))
            tex:Show()
        end
        y = y + band
    end
    for i = 1, #hull - 1, 2 do
        local j = i + 2 > #hull and 1 or i + 2
        areaLines:Add(hull[i] / W, hull[i + 1] / H, hull[j] / W, hull[j + 1] / H, c[1], c[2], c[3], AREA_EDGE, 2)
    end
end

-- for the tests: the outline's pieces and the bands drawn
function QM.AreasShown()
    return #areaLines.active, areaUsed
end

local BUY_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local objectives = ns.Pins.New("objectives", { level = 47, size = 14, option = "objectives", minZoom = 3, cull = true })

function objectives:Refresh()
    self:ReleaseAll()
    ClearAreas()
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
    local areas = ns.Opt("objectiveAreas")
    if areas then
        for _, a in ipairs(QM.Areas()) do
            if a.u1 > u0 and a.u0 < u1 and a.v1 > v0 and a.v0 < v1 then
                DrawArea(a)
                local pin = self:Acquire()
                pin.icon:SetAtlas("WhiteCircle-RaidBlips")
                pin.icon:SetVertexColor(a.color[1], a.color[2], a.color[3])
                pin.mark = a.mark
                self:Place(pin, a.u, a.v, 1.4)
            end
        end
    end
    for _, mark in ipairs(QM.Objectives()) do
        if InBox(mark, u0, v0, u1, v1) and not (areas and not (mark.turnIn or mark.buy or mark.reach)) then
            local pin = self:Acquire()
            if mark.turnIn then
                pin.icon:SetAtlas("QuestTurnin")
                pin.icon:SetVertexColor(1, 1, 1)
                self:Place(pin, mark.u, mark.v, 1.5)
            elseif mark.buy then
                pin.icon:SetTexture(BUY_ICON)
                pin.icon:SetVertexColor(1, 1, 1)
                self:Place(pin, mark.u, mark.v, 1.3)
            elseif mark.reach then
                pin.icon:SetAtlas("Waypoint-MapPin-Untracked")
                pin.icon:SetVertexColor(mark.color[1], mark.color[2], mark.color[3])
                self:Place(pin, mark.u, mark.v, 1.8)
            else
                pin.icon:SetAtlas("WhiteCircle-RaidBlips")
                pin.icon:SetVertexColor(mark.color[1], mark.color[2], mark.color[3])
                self:Place(pin, mark.u, mark.v)
            end
            pin.mark = mark
        end
    end
end

function objectives:OnHidden() ClearAreas() end

function objectives:Tooltip(pin, tip)
    local mark = pin.mark
    tip:SetText(WhoName(mark), 1, 1, 1)
    if mark.turnIn then
        tip:AddLine(L.TURN_IN:format(QM.Title(mark.quest)), 0.4, 1, 0.4, true)
    else
        if mark.buy then tip:AddLine(L.QUEST_BUY, 1, 0.82, 0) end
        if mark.reach then tip:AddLine(L.QUEST_REACH, 1, 0.82, 0) else tip:AddLine(QuestLine(mark.quest)) end
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(mark.quest) or {}) do
            if o.text and o.text ~= "" then
                if o.finished then tip:AddLine(o.text, 0.5, 0.5, 0.5, true) else tip:AddLine(o.text, 1, 1, 1, true) end
            end
        end
    end
    tip:AddLine(L.QUEST_HINT, 0.6, 0.6, 0.6)
end

-- a quest of your log: its details in Zmap's quest log; with Ctrl, the arrow there
function objectives:OnClick(pin, button)
    if button ~= "LeftButton" then return end
    if IsControlKeyDown() then Navigate(pin.mark) else ns.QuestPanel.Show(pin.mark.quest) end
end

local function Changed()
    dirty = true
    givers:Update()
    objectives:Update()
    ns.Fire("ZMAP_QUESTS")   -- (the quests panel)
end
-- What a giver really offers, told by the game as you talk to it: the quests of the data it gives that it does not
-- offer are left off the map (the data cannot know all that holds a quest back), until your level or the quests
-- you have done change
local function Offered(questIDs)
    local guid = UnitGUID("npc")
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    npc = tonumber(npc)
    if kind ~= "Creature" or not npc then return end
    local offered = {}
    for _, id in ipairs(questIDs) do offered[id] = true end
    local level, race, class = UnitLevel("player") or 1, RaceBit(), ClassBit()
    local changed = false
    for id, q in pairs(QUESTS) do
        for _, giver in ipairs(q[6]) do
            if giver == npc and not offered[id] and QM.Available(id, q, level, race, class) then
                ns.char.notOffered = ns.char.notOffered or {}
                ns.char.notOffered[id] = true
                changed = true
            end
        end
    end
    if changed then
        dirty = true
        givers:Update()
    end
end
ns.On("GOSSIP_SHOW", function()
    if not (C_GossipInfo and C_GossipInfo.GetAvailableQuests) then return end
    local ids = {}
    for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do ids[#ids + 1] = info.questID end
    Offered(ids)
end)
ns.On("QUEST_GREETING", function()
    local ids = {}
    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        ids[#ids + 1] = select(5, GetAvailableQuestInfo(i))
    end
    Offered(ids)
end)
local function Unlearn() if ns.char.notOffered then wipe(ns.char.notOffered) end end
ns.On("PLAYER_LEVEL_UP", Unlearn)
ns.On("QUEST_TURNED_IN", Unlearn)

local later = ns.Debounce(0.5, Changed)
ns.On("QUEST_LOG_UPDATE", later)
ns.On("QUEST_TURNED_IN", later)
ns.On("QUEST_ACCEPTED", later)
ns.On("QUEST_REMOVED", later)
ns.On("PLAYER_LEVEL_UP", later)
ns.On("ZMAP_OPTION", function(key)
    if key == "trivial" then givers:Update() end
    if key == "objectiveAreas" then objectives:Update() end
end)
ns.On("ZMAP_SHOW", function() dirty = true end)
