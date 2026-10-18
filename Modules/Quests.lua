-- Your quests on the map: where their objectives are (numbered as in your quest log) and, once done,
-- where to hand them in. A click opens the quest in Zmap's quest log (Modules/QuestPanel.lua).
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("quests", { level = 50, size = 22, option = "quests", minZoom = 1.5, cull = true })

function P:OnCreate(pin)
    pin.num = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.num:SetPoint("CENTER", 0, 0)
    pin.num:SetTextColor(1, 1, 1)
end

ns.BlizzardQuestPins = {}   -- quests the game itself places (QuestMap.lua does not repeat their hand-in)

function P:Refresh()
    self:ReleaseAll()
    wipe(ns.BlizzardQuestPins)
    if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
    local seen = {}
    local u0, v0, u1, v1 = ns.Pins.ViewBox()
    for _, mapID in ipairs(Geo.Zones()) do
        local l, r, t, b = Geo.Rect(mapID)
        local ok, list = false, nil
        if l < u1 and r > u0 and t < v1 and b > v0 then   -- (the zones in view: the game makes a list for each asked)
            ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        end
        for _, q in ipairs(ok and list or {}) do
            local key = q.questID .. ":" .. math.floor(q.x * 200) .. ":" .. math.floor(q.y * 200)
            if not seen[key] and q.x and q.y then
                seen[key] = true
                local u, v = Geo.ToWorld(mapID, q.x, q.y)
                local pin = self:Acquire()
                local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(q.questID)
                if done then
                    pin.icon:SetAtlas("QuestTurnin")
                    pin.num:SetText("")
                else
                    pin.icon:SetAtlas("UI-QuestPoi-QuestNumber")
                    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q.questID)
                    pin.num:SetText(index or "")
                end
                pin.questID, pin.mapID, pin.x, pin.y = q.questID, mapID, q.x, q.y
                ns.BlizzardQuestPins[q.questID] = true
                self:Place(pin, u, v)
            end
        end
    end
end

function P:Tooltip(pin, tip)
    local id = pin.questID
    tip:SetText(C_QuestLog.GetTitleForQuestID(id) or ("#" .. id), 1, 0.82, 0, 1, true)
    if C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then
        tip:AddLine(L.QUEST_DONE, 0.4, 1, 0.4)
    else
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
            if o.text and o.text ~= "" then
                if o.finished then tip:AddLine(o.text, 0.5, 0.5, 0.5, true) else tip:AddLine(o.text, 1, 1, 1, true) end
            end
        end
    end
    tip:AddLine(L.QUEST_HINT, 0.6, 0.6, 0.6, true)
end

function P:OnClick(pin, button)
    if button == "LeftButton" and IsControlKeyDown() then
        ns.Waypoints.Add(pin.mapID, pin.x, pin.y, C_QuestLog.GetTitleForQuestID(pin.questID), { navigate = true, temp = true })
    elseif button == "LeftButton" then
        ns.QuestPanel.Show(pin.questID)
    end
end

local refresh = ns.Debounce(0.5, function() P:Update() end)
ns.On("QUEST_LOG_UPDATE", refresh)
ns.On("QUEST_POI_UPDATE", refresh)
ns.On("QUEST_WATCH_UPDATE", refresh)
