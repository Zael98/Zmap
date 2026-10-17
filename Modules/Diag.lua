-- /zmap diag: what works in this client and what Zmap has, in a box to copy (Ctrl+A, Ctrl+C) and send when
-- something looks wrong. Each check runs in its own pcall, so a failing one shows its error and the rest go on.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local box

local function Window()
    if box then return box end
    local f = CreateFrame("Frame", "ZmapDiag", UIParent, "BackdropTemplate")
    f:SetSize(640, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
    f:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L.DIAG_TITLE)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(590)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    f.edit = edit
    tinsert(UISpecialFrames, "ZmapDiag")
    box = f
    return f
end

local function Report()
    local out = {}
    local function Line(label, fn)
        local ok, value = pcall(fn)
        out[#out + 1] = label .. ": " .. (ok and tostring(value) or ("ERROR " .. tostring(value)))
    end
    Line("Zmap", function() return (C_AddOns.GetAddOnMetadata("Zmap", "Version") or "?") .. ", data " .. (ns.DATA_BUILD or "?") end)
    Line("client", function() local v, b = GetBuildInfo() return v .. " (" .. b .. "), " .. GetLocale() end)
    Line("player", function()
        local _, _, race = UnitRace("player")
        local _, class, classID = UnitClass("player")
        return ("level %d, %s, race %s, class %s/%s"):format(UnitLevel("player"), UnitFactionGroup("player") or "?", tostring(race), class, tostring(classID))
    end)
    Line("position", function()
        local u, v, m, x, y = Geo.UnitPosition("player")
        local wx, wy, inst = Geo.PlayerYards()
        return u and ("%s %s; yards %s, %s, instance %s"):format(Geo.Name(m), ns.Coords(x, y), tostring(wx), tostring(wy), tostring(inst)) or "none (instance?)"
    end)
    Line("rect 1429 (client / data)", function()
        local l, r, t, b = C_Map.GetMapRectOnMap(1429, 947)
        local dl, dr, dt, db = Geo.Rect(1429)
        return ("%.4f %.4f %.4f %.4f / %.4f %.4f %.4f %.4f"):format(l, r, t, b, dl, dr, dt, db)
    end)
    Line("art 1429 first tile (client / data)", function()
        return tostring(C_Map.GetMapArtLayerTextures(1429, 1)[1]) .. " / " .. tostring(ns.MAPS[1429][5][1])
    end)
    Line("explored here", function()
        local _, _, m = Geo.UnitPosition("player")
        local info = m and C_MapExplorationInfo.GetExploredMapTextures(m)
        return info and (#info .. " of " .. #(ns.MAPS[m][7] or {})) or "nil"
    end)
    Line("flight masters (client)", function()
        local list, unknown = C_TaxiMap.GetTaxiNodesForMap(1415) or {}, 0
        for _, n in ipairs(list) do if n.isUndiscovered then unknown = unknown + 1 end end
        local k = C_TaxiMap.GetTaxiNodesForMap(1414) or {}
        return ("%d EK + %d Kalimdor, %d undiscovered (EK)"):format(#list, #k, unknown)
    end)
    Line("dungeon entrances (client)", function()
        local n = 0
        for _, id in ipairs(Geo.Zones()) do n = n + #(C_EncounterJournal.GetDungeonEntrancesForMap(id) or {}) end
        return n
    end)
    Line("quests", function()
        return ("%d in log, %d givers marked, %d objective marks, %d quests in data"):format(#ns.QuestMap.InLog(),
            #ns.QuestMap.Givers(), #ns.QuestMap.Objectives(), (function() local c = 0 for _ in pairs(ns.QUESTS or {}) do c = c + 1 end return c end)())
    end)
    Line("blizzard quest pins", function()
        local c = 0
        for _ in pairs(ns.BlizzardQuestPins or {}) do c = c + 1 end
        return c
    end)
    Line("npc names learned", function()
        local learned, total = 0, 0
        for _ in pairs(ns.NPCS or {}) do total = total + 1 end
        for _ in pairs(ns.db.npcNames and ns.db.npcNames[GetLocale()] or {}) do learned = learned + 1 end
        local asked, answered, waiting, pass = ns.Npcs.AskStats()
        return ("%d of %d (pass %s, at %s; this session asked %d, answered %d, waiting %d)"):format(learned, total,
            tostring(pass), tostring(ns.db.npcAskAt), asked, answered, waiting)
    end)
    Line("npc link (Spirit Healer)", function()
        local data = C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-6491-0000000000")
        local line = data and data.lines and data.lines[1]
        return line and line.leftText or "nothing"
    end)
    Line("professions", function()
        return ("herbalism %s, mining %s"):format(tostring(ns.GatherSkill("herb")), tostring(ns.GatherSkill("ore")))
    end)
    Line("guild", function()
        local online = 0
        for i = 1, GetNumGuildMembers() do
            if select(9, GetGuildRosterInfo(i)) then online = online + 1 end
        end
        return ("%s, %d online"):format(IsInGuild() and "yes" or "no", online)
    end)
    Line("map", function()
        local z, c, t = ns.Art.Stats()
        return ("shown %s, zoom %.2f, zones built %d, cities %d, terrain tiles %d"):format(tostring(ns.Map.IsShown()),
            ns.Map.Zoom(), z, c, t)
    end)
    Line("pins", function()
        local parts = {}
        for _, p in ipairs(ns.Pins.providers) do
            if #p.active > 0 then parts[#parts + 1] = p.name .. " " .. #p.active end
        end
        return table.concat(parts, ", ")
    end)
    Line("M key", function()
        local key = GetBindingKey("TOGGLEWORLDMAP")
        return tostring(key) .. " -> " .. tostring(key and GetBindingAction(key, true))
    end)
    Line("fps", function() return ("%.0f"):format(GetFramerate()) end)
    Line("errors caught", function() return #ns.errors end)
    for i, err in ipairs(ns.errors) do out[#out + 1] = ("  %d. %s"):format(i, err) end
    return table.concat(out, "\n")
end

ns.Diag = Report

ns.commands.diag = function()
    local f = Window()
    f.edit:SetText(Report())
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end
