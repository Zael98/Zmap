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
    Line("memory", function()
        UpdateAddOnMemoryUsage()
        return ("%.1f MB"):format(GetAddOnMemoryUsage("Zmap") / 1024)
    end)
    Line("errors caught", function() return #ns.errors end)
    for i, err in ipairs(ns.errors) do out[#out + 1] = ("  %d. %s"):format(i, err) end
    return table.concat(out, "\n")
end

ns.Diag = Report

--------------------------------------------------------------------------------------------------------------
-- /zmap check: each feature tried with the game's own API, OK or FAIL and what it found
--------------------------------------------------------------------------------------------------------------

local function Check()
    local out, failed = {}, 0
    local function Try(label, fn)
        local ok, good, detail = pcall(fn)
        if not ok then good, detail = false, tostring(good) end
        if not good then failed = failed + 1 end
        out[#out + 1] = ("%s %s: %s"):format(good and "OK  " or "FAIL", label, tostring(detail or ""))
    end
    local _, _, m = Geo.UnitPosition("player")
    Try("your position", function() return m ~= nil, m and Geo.Name(m) or "none (instance?)" end)
    Try("zone art", function()
        local tiles = m and ns.MAPS[m] and ns.MAPS[m][5]
        local client = m and C_Map.GetMapArtLayerTextures(m, 1)
        return tiles and client and tiles[1] == client[1], ("data %s, client %s"):format(tostring(tiles and tiles[1]), tostring(client and client[1]))
    end)
    Try("quest givers near you", function()
        local n = 0
        for _, mark in ipairs(ns.QuestMap.Givers()) do if mark.m == m then n = n + 1 end end
        return n > 0, n .. " in this zone"
    end)
    Try("quest log read", function()
        local log = ns.QuestMap.InLog()
        return true, #log .. " quests, " .. #ns.QuestMap.Objectives() .. " objective marks"
    end)
    Try("quest titles in your language", function()
        local id = ns.QuestMap.InLog()[1]
        if not id then return true, "(no quest in the log)" end
        return C_QuestLog.GetTitleForQuestID(id) ~= nil, ns.QuestMap.Title(id)
    end)
    Try("townsfolk here", function()
        local kinds = {}
        for _, f in ipairs(ns.Npcs.Townsfolk()) do
            if f.m == m then
                local look = ns.FolkLook(f.id)
                if look then kinds[look.cat] = (kinds[look.cat] or 0) + 1 end
            end
        end
        local parts = {}
        for cat, n in pairs(kinds) do parts[#parts + 1] = cat .. " " .. n end
        return true, #parts > 0 and table.concat(parts, ", ") or "none in this zone"
    end)
    Try("professions read", function()
        return true, ("herbalism %s, mining %s"):format(tostring(ns.GatherSkill("herb")), tostring(ns.GatherSkill("ore")))
    end)
    Try("item names (herbs, ore)", function()
        local name = C_Item.GetItemNameByID(2447)   -- Peacebloom
        if not name then C_Item.RequestLoadItemDataByID(2447) end
        return true, name or "asked for, try again in a moment"
    end)
    Try("guild roster -> zones", function()
        if not IsInGuild() then return true, "(not in a guild)" end
        local online, placed = 0, 0
        for i = 1, GetNumGuildMembers() do
            local _, _, _, _, _, zone, _, _, isOnline = GetGuildRosterInfo(i)
            if isOnline then
                online = online + 1
                for _, id in ipairs(Geo.Zones()) do
                    if Geo.Name(id) == zone then placed = placed + 1 break end
                end
            end
        end
        return online == 0 or placed > 0, ("%d online, %d in a known zone"):format(online, placed)
    end)
    Try("group positions", function()
        if not IsInGroup() then return true, "(not in a group)" end
        local seen = 0
        for i = 1, GetNumSubgroupMembers() do
            if Geo.UnitPosition("party" .. i) then seen = seen + 1 end
        end
        return seen > 0, ("%d of %d placed"):format(seen, GetNumSubgroupMembers())
    end)
    Try("flight masters known", function()
        local nodes = ns.Flights.Network()
        local n = 0
        for _ in pairs(nodes) do n = n + 1 end
        return true, n > 0 and n or "none yet (they are learned when you open a flight master's map)"
    end)
    Try("route to your capital", function()
        local capital = UnitFactionGroup("player") == "Horde" and 1454 or 1453
        local u, v = Geo.ToWorld(capital, 0.5, 0.5)
        local saved = ns.Route.Current()
        local ok = ns.Route.To(u, v, Geo.Name(capital))
        local r = ns.Route.Current()
        local legs = {}
        for _, leg in ipairs(r and r.legs or {}) do legs[#legs + 1] = leg.mode end
        if not saved then ns.Route.Clear() end
        return ok, r and (table.concat(legs, ", ") .. ", " .. ns.Duration(r.seconds)) or "none"
    end)
    Try("dungeon maps", function()
        local n = 0
        for _ in pairs(ns.DUNGEON_MAPS) do n = n + 1 end
        local _, kind, _, _, _, _, _, inst = GetInstanceInfo()
        local here = IsInInstance() and (ns.Dungeon.Has(inst) and "this one has a map" or "no map for this one") or "outside"
        return n > 0, n .. " instances; " .. here
    end)
    Try("battleground map", function()
        local _, kind = IsInInstance()
        if kind ~= "pvp" then return true, "(not in a battleground)" end
        local live = ns.Dungeon.Live()
        if not live then return false, "not shown (open the map here)" end
        return live.units, ("group frame %s, objectives %d, flags %d"):format(tostring(live.units), live.pois, live.flags)
    end)
    Try("minimap pins", function()
        return ZmapMinimapPins ~= nil and Minimap:GetWidth() > 0, ("minimap %d px, %s, rotating %s"):format(Minimap:GetWidth(),
            GetMinimapShape and GetMinimapShape() or "ROUND", tostring(GetCVar("rotateMinimap") == "1"))
    end)
    Try("rare detection", function()
        return UnitClassification ~= nil, "nameplates, mouse over and target are watched"
    end)
    Try("NPC names in your language", function()
        local learned, total = 0, 0
        for _ in pairs(ns.NPCS) do total = total + 1 end
        for _ in pairs(ns.db.npcNames and ns.db.npcNames[GetLocale()] or {}) do learned = learned + 1 end
        return learned > 0 or GetLocale() == "enUS", ("%d of %d"):format(learned, total)
    end)
    Try("taxi API", function() return C_TaxiMap.GetAllTaxiNodes ~= nil, "flight advice at flight masters" end)
    -- what Zmap holds, and what of it is garbage the game has not collected yet (a full collection, once)
    Try("memory", function()
        UpdateAddOnMemoryUsage()
        local mb = GetAddOnMemoryUsage("Zmap") / 1024
        pcall(collectgarbage, "collect")
        UpdateAddOnMemoryUsage()
        local used = GetAddOnMemoryUsage("Zmap") / 1024
        return used < 40, ("%.1f MB, %.1f MB in use after a collection"):format(mb, used)
    end)
    table.insert(out, 1, ("Zmap check: %d failed of %d"):format(failed, #out))
    return table.concat(out, "\n"), failed
end

ns.Check = Check

local function Show(text)
    local f = Window()
    f.edit:SetText(text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

ns.commands.diag = function() Show(Report()) end
ns.commands.check = function() Show((Check()) .. "\n\n" .. Report()) end
ns.commands.comprobar = ns.commands.check
