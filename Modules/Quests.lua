-- Your quests on the map: where their objectives are (numbered as in your quest log) and, once done,
-- where to hand them in. A click opens the quest in Blizzard's quest log.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("quests", { level = 50, size = 22, option = "quests", minZoom = 1.5 })

function P:OnCreate(pin)
    pin.num = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.num:SetPoint("CENTER", 0, 0)
    pin.num:SetTextColor(1, 1, 1)
end

function P:Refresh()
    self:ReleaseAll()
    if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
    local seen = {}
    for _, mapID in ipairs(Geo.Zones()) do
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
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
        ns.Map.Close()
        if QuestMapFrame_OpenToQuestDetails then
            QuestMapFrame_OpenToQuestDetails(pin.questID)
        elseif OpenQuestLog then
            OpenQuestLog()
        end
    end
end

local refresh = ns.Debounce(0.5, function() P:Update() end)
ns.On("QUEST_LOG_UPDATE", refresh)
ns.On("QUEST_POI_UPDATE", refresh)
ns.On("QUEST_WATCH_UPDATE", refresh)
