-- Your group's quests: each Zmap user of your party or raid tells the others which quests they carry and how far
-- they are ("QL": questID:done/total or questID:c when ready to turn in, as many as fit one message), when their
-- log changes and when someone joins (who joins asks with "QA"). The quest log shows who shares each quest.
local _, ns = ...
local QG = {}
ns.QuestGroup = QG

local mates = {}   -- [name] = { [questID] = { done, total } or { ready = true } }

local function Channel()
    if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end

local function Short(name) return (Ambiguate and Ambiguate(name, "short")) or name:match("^[^-]+") or name end

-- what you carry, as "id:done/total" or "id:c" fields
local function Mine()
    local out = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        local id = info and not info.isHeader and info.questID
        if not id or id <= 0 then
            -- (a header)
        elseif C_QuestLog.IsComplete(id) then
            out[#out + 1] = id .. ":c"
        else
            local done, total = 0, 0
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                total = total + 1
                if o.finished then done = done + 1 end
            end
            out[#out + 1] = ("%d:%d/%d"):format(id, done, total)
        end
    end
    return out
end

function QG.Send()
    local channel = Channel()
    if not channel then return end
    local fields, length = {}, 3
    for _, f in ipairs(Mine()) do
        if length + #f + 1 > 240 then break end   -- (one message; the rest wait for the next change)
        fields[#fields + 1] = f
        length = length + #f + 1
    end
    ns.Comm.Send("QL", channel, nil, unpack(fields))
end
local later = ns.Debounce(2, QG.Send)

ns.Comm.On("QL", function(sender, channel, ...)
    if channel ~= "PARTY" and channel ~= "RAID" then return end
    local list = {}
    for i = 1, select("#", ...) do
        local id, rest = (select(i, ...)):match("^(%d+):(.+)$")
        if id then
            local done, total = rest:match("^(%d+)/(%d+)$")
            list[tonumber(id)] = rest == "c" and { ready = true } or { tonumber(done) or 0, tonumber(total) or 0 }
        end
    end
    mates[Short(sender)] = list
    ns.Fire("ZMAP_QUESTS")
end)
ns.Comm.On("QA", function(_, channel)
    if channel == "PARTY" or channel == "RAID" then later() end
end)

-- who of your group also has it: { { name, ready, done, total }, ... } by name
function QG.For(id)
    local out = {}
    for name, list in pairs(mates) do
        local q = list[id]
        if q then out[#out + 1] = { name = name, ready = q.ready, done = q[1], total = q[2] } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- the ones who left the group are forgotten; who joined is asked
local function Roster()
    local here = {}
    local n = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, n do
        local name = UnitName((IsInRaid() and "raid" or "party") .. i)
        if name then here[Short(name)] = true end
    end
    local changed = false
    for name in pairs(mates) do
        if not here[name] then
            mates[name] = nil
            changed = true
        end
    end
    if changed then ns.Fire("ZMAP_QUESTS") end
    local channel = Channel()
    if channel then
        ns.Comm.Send("QA", channel)
        later()
    end
end

ns.On("GROUP_ROSTER_UPDATE", ns.Debounce(1, Roster))
ns.On("QUEST_LOG_UPDATE", later)
ns.On("PLAYER_LOGIN", function() if IsInGroup() then Roster() end end)
