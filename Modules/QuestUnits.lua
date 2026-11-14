-- Your quests on the NPCs themselves, the way Questie shows them: hovering one says which quest of your log it is
-- for (with what is left of it), which quests it gives and which it takes; a mark over the nameplate of the ones
-- a quest of yours needs (to kill, or for what they drop) and of those who take a quest you finished. From the
-- data (Data/Quests.lua via QuestMap.lua). The game hides who a unit is in combat in some places (a secret GUID):
-- then nothing is added.
local _, ns = ...
local L = ns.L
local QM = ns.QuestMap
local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

-- an NPC's ID from its GUID (nil: not an NPC, or the game keeps it secret)
local function GuidNpc(guid)
    if not guid or IsSecret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- (a unit token can itself be secret, e.g. a tooltip's unit in some places: the unit functions refuse it then)
local function NpcID(unit)
    if not unit or IsSecret(unit) or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    return GuidNpc(UnitGUID(unit))
end

-- what is left of a quest, the objectives naming this unit first (a kill), else all that are left
local function Left(id, name)
    local mine, all = {}, {}
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        if o.text and o.text ~= "" and not o.finished then
            all[#all + 1] = o.text
            if name and not IsSecret(name) and o.text:find(name, 1, true) then mine[#mine + 1] = o.text end
        end
    end
    return #mine > 0 and mine or all
end

-- the lines it adds to a unit's tooltip: { text, r, g, b } (guid: the tooltip's own, when the unit is not known)
function ns.QuestUnitLines(unit, guid)
    local id = GuidNpc(guid) or NpcID(unit)
    local info = id and QM.ForNpc(id)
    if not info then return {} end
    local out, name = {}, nil
    if unit and not IsSecret(unit) and UnitExists(unit) then name = UnitName(unit) end
    for _, q in ipairs(info.need) do
        out[#out + 1] = { QM.Title(q), 1, 0.82, 0 }
        for _, text in ipairs(Left(q, name)) do out[#out + 1] = { "  - " .. text, 0.85, 0.85, 0.85 } end
    end
    for _, q in ipairs(info.takes) do out[#out + 1] = { L.QUEST_UNIT_TAKES:format(QM.Title(q)), 0.4, 1, 0.4 } end
    for _, q in ipairs(info.gives) do out[#out + 1] = { L.QUEST_UNIT_GIVES:format(QM.Title(q)), 1, 1, 0.5 } end
    return out
end

local function OnUnitTooltip(tip, data)
    if not ns.Opt("questTooltips") or tip ~= GameTooltip then return end
    local ok, _, unit = pcall(tip.GetUnit, tip)
    if not ok then unit = nil end
    local lines = ns.QuestUnitLines(unit, type(data) == "table" and data.guid or nil)
    for _, l in ipairs(lines) do tip:AddLine(l[1], l[2], l[3], l[4]) end
    if #lines > 0 then tip:Show() end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", OnUnitTooltip)
end

--------------------------------------------------------------------------------------------------------------
-- Over the nameplates
--------------------------------------------------------------------------------------------------------------

local plates = {}   -- [unit token] = its plate
local NEED, TAKE = "Interface\\GossipFrame\\ActiveQuestIcon", "Interface\\GossipFrame\\ActiveQuestIcon"

-- the mark a unit gets: "need" (a quest of yours wants it), "take" (it takes a quest you finished) or nil
function ns.QuestUnitMark(unit)
    local id = NpcID(unit)
    local info = id and QM.ForNpc(id)
    if not info then return end
    if #info.need > 0 then return "need" end
    if #info.takes > 0 then return "take" end
end

local function Mark(unit)
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    plates[unit] = plate
    local kind = ns.Opt("questPlates") and ns.QuestUnitMark(unit)
    if not kind then
        if plate.ZmapQuest then plate.ZmapQuest:Hide() end
        return
    end
    if not plate.ZmapQuest then
        plate.ZmapQuest = plate:CreateTexture(nil, "OVERLAY")
        plate.ZmapQuest:SetSize(18, 18)
        plate.ZmapQuest:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    end
    plate.ZmapQuest:SetTexture(kind == "need" and NEED or TAKE)
    if kind == "need" then plate.ZmapQuest:SetVertexColor(1, 0.82, 0) else plate.ZmapQuest:SetVertexColor(0.4, 1, 0.4) end
    plate.ZmapQuest:Show()
end

ns.On("NAME_PLATE_UNIT_ADDED", Mark)
ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    local plate = plates[unit]
    if plate and plate.ZmapQuest then plate.ZmapQuest:Hide() end
    plates[unit] = nil
end)
-- the log changed, or the option: every plate on screen again
local function All() for unit in pairs(plates) do Mark(unit) end end
ns.On("ZMAP_QUESTS", All)
ns.On("ZMAP_OPTION", function(key) if key == "questPlates" then All() end end)

-- for the tests
function ns.QuestPlateShown(unit)
    local plate = plates[unit]
    return plate ~= nil and plate.ZmapQuest ~= nil and plate.ZmapQuest:IsShown()
end
