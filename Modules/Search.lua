-- The search box: zones, subzones (Goldshire, Crossroads...), flight masters, dungeons, every NPC (by name,
-- in English or in your language once Zmap knows it, by title or by service: "tabernero"), your pins and
-- the townsfolk and herbs found. Accents and case do not matter; the nearest come first. Enter or a click
-- goes there; an NPC gets a mark on every place it stands.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local Search = {}
ns.Search = Search

local MAX = 12
local NPC_ICON = "Interface\\GossipFrame\\GossipGossipIcon"
local box, list, buttons = nil, nil, {}
local results = {}

local function Entry(kind, text, sub, u, v, zoom, icon, atlas, mapID)
    return { kind = kind, text = text, sub = sub, u = u, v = v, zoom = zoom, icon = icon, atlas = atlas, mapID = mapID,
        key = ns.Fold(text), subKey = sub and ns.Fold(sub) }
end

-- an NPC's entry: its name as Zmap knows it in your language, its English name too, its title or services
local npcEntries = {}
local function NpcText(e)
    local N, id = ns.Npcs, e.npc
    local name, title = N.Name(id), N.Title(id)
    local sub = title ~= "" and title or N.ServiceText(id)
    e.text, e.sub = name, sub ~= "" and sub or L.NPC
    e.key, e.subKey = ns.Fold(name), ns.Fold(e.sub)
    local english = ns.NPCS[id][1]
    e.alt = name ~= english and ns.Fold(english) or nil
    local services = N.ServiceText(id)
    if services ~= "" and services ~= sub then e.subKey = e.subKey .. " " .. ns.Fold(services) end
end

-- what does not change while you play: built once (each NPC's entry is kept up to date as Zmap learns its name)
local static
local function Static()
    if static then return static end
    static = {}
    local function Add(e) if e.text and e.u then static[#static + 1] = e end end
    for _, id in ipairs(Geo.Zones()) do
        local l, r, t, b = Geo.Rect(id)
        Add(Entry("zone", Geo.Name(id), Geo.Kind(id) == "city" and L.CITY or L.ZONE, (l + r) / 2, (t + b) / 2, nil, nil, nil, id))
        -- its subzones: the middle of each overlay that names one
        for _, o in ipairs(Geo.Info(id)[7] or {}) do
            local area = o[5][1] and ns.AREAS[o[5][1]]
            if area then
                local u, v = Geo.ToWorld(id, (o[3] + o[1] / 2) / 1002, (o[4] + o[2] / 2) / 668)
                Add(Entry("subzone", ns.Name(area), Geo.Name(id), u, v, 8))
            end
        end
    end
    for id, n in pairs(ns.TAXI_NODES) do
        local u, v = Geo.FromYards(n[1], n[2], n[3])
        Add(Entry("flight", ns.Flights.Name(id), L.FLIGHT_MASTER, u, v, 8, nil, "TaxiNode_Neutral"))
    end
    for _, e in ipairs(ns.DungeonList()) do
        Add(Entry("dungeon", e.name, e.raid and L.RAID or L.DUNGEON, e.u, e.v, 7, nil, e.raid and "Raid" or "Dungeon"))
    end
    local N = ns.Npcs
    for id in pairs(ns.NPCS or {}) do
        local spawn = N.Spawns(id)[1]
        if spawn then
            local kind = N.Kind(id)
            local e = { kind = "npc", npc = id, zoom = 10, icon = kind and ns.FOLK_ICONS[kind] or NPC_ICON,
                atlas = N.Rare(id) and "VignetteKill" or nil, zone = Geo.Name(spawn[1]) }
            e.u, e.v = Geo.ToWorld(spawn[1], spawn[2], spawn[3])
            NpcText(e)
            npcEntries[id] = e
            Add(e)
        end
    end
    return static
end

ns.Npcs.OnLearn = function(id)
    local e = npcEntries[id]
    if e then NpcText(e) end
end

-- what changes as you play: your pins, the NPCs and townsfolk met that the NPC data lacks, herbs and ore found
local function Dynamic()
    local out = {}
    local function Add(e) if e.text and e.u then out[#out + 1] = e end end
    for _, p in pairs(ns.db.pins) do
        local u, v = Geo.ToWorld(p.m, p.x, p.y)
        Add(Entry("pin", p.name, L.MY_PIN, u, v, 10, nil, "Waypoint-MapPin-Untracked"))
    end
    local met = {}
    for id, s in pairs(ns.Npcs.SeenList()) do
        if Geo.Kind(s.m) then
            local u, v = Geo.ToWorld(s.m, s.x, s.y)
            local e = Entry("npc", s.n, s.t or L.NPC, u, v, 12, NPC_ICON)
            e.npc, e.zone = id, Geo.Name(s.m)
            met[id] = true
            Add(e)
        end
    end
    for key, f in pairs(ns.FolkList()) do
        local npc = tonumber(key:match(":(%d+)$"))
        if not (npc and ((ns.NPCS and ns.NPCS[npc]) or met[npc])) then
            local u, v = Geo.ToWorld(f.m, f.x, f.y)
            Add(Entry("folk", f.name, (f.sub or L["FOLK_" .. f.kind]) .. " · " .. Geo.Name(f.m), u, v, 14, ns.FOLK_ICONS[f.kind]))
        end
    end
    local seen = {}
    for _, g in ipairs(ns.GatherList()) do
        local key = g.mapID .. g.node.name
        if not seen[key] then   -- one entry per kind of herb or ore per zone
            seen[key] = true
            local u, v = Geo.ToWorld(g.mapID, g.node.x, g.node.y)
            Add(Entry("herb", g.node.name, Geo.Name(g.mapID), u, v, 6, g.node.kind == "herb" and "Interface\\Icons\\INV_Misc_Herb_01" or "Interface\\Icons\\INV_Ore_Copper_01"))
        end
    end
    return out
end

-- how good a match is: the name starts with it (0), a word of it does (1), it is inside (2); nil: no match
local function Score(name, want)
    if not name then return end
    local at = name:find(want, 1, true)
    if at == 1 then return 0 end
    if at and name:sub(at - 1, at - 1):match("[%s%p]") then return 1 end
    if at and #want >= 3 then return 2 end
end

-- zones and cities first, then subzones and your pins, dungeons, NPCs and flight masters, townsfolk and herbs
local KIND = { zone = 0, subzone = 1, pin = 1, dungeon = 2, npc = 3, flight = 3, folk = 4, herb = 4 }

local function Match(c, want, found)
    local score = Score(c.key, want)
    local alt = Score(c.alt, want)
    if alt and (not score or alt < score) then score = alt end
    if not score then
        local s = Score(c.subKey, want)
        score = s and 3
    end
    if score then
        c.rank = (KIND[c.kind] or 4) * 4 + score
        found[#found + 1] = c
    end
end

function Search.Find(text)
    local want = ns.Fold(text or "")
    wipe(results)
    if #want < 2 then return results end
    local found = {}
    for _, c in ipairs(Static()) do Match(c, want, found) end
    for _, c in ipairs(Dynamic()) do Match(c, want, found) end
    -- the nearest first among equals: an NPC at the spawn nearest to you
    local pu, pv = Geo.UnitPosition("player")
    for _, c in ipairs(found) do
        if c.npc and #found <= 300 then
            local m, x, y = ns.Npcs.Nearest(c.npc)
            if m then
                c.u, c.v = Geo.ToWorld(m, x, y)
                c.zone = Geo.Name(m)
            end
        end
        c.dist = pu and ((c.u - pu) ^ 2 + (c.v - pv) ^ 2) or 0
    end
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.text < b.text
    end)
    for i = 1, math.min(MAX, #found) do results[i] = found[i] end
    return results
end

function Search.Go(c)
    if not c then return end
    if c.npc then
        local m, x, y = ns.Npcs.Nearest(c.npc)
        local u, v = Geo.ToWorld(m, x, y)
        ns.Map.GoTo(u, v, math.max(ns.Map.Zoom(), c.zoom or 10))
        ns.Npcs.Show(c.npc)
    else
        ns.Npcs.Show(nil)
        if c.mapID then
            ns.Map.GoToMap(c.mapID)
        else
            ns.Map.GoTo(c.u, c.v, c.zoom or 8)
        end
        ns.Search.Mark(c.u, c.v, c.mapID == nil)
    end
    if box then
        box:ClearFocus()
        list:Hide()
    end
end

-- a ring where the search went, for a few seconds
local mark = ns.Pins.New("searchmark", { level = 95, size = 40, mouse = false })
local markUntil = 0
function Search.Mark(u, v, show)
    mark:ReleaseAll()
    if not show then return end
    local pin = mark:Acquire()
    pin.icon:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    pin.icon:SetBlendMode("ADD")
    mark:Place(pin, u, v)
    markUntil = GetTime() + 4
end
ns.On("ZMAP_TICK", function()
    if markUntil > 0 and GetTime() > markUntil then
        markUntil = 0
        mark:ReleaseAll()
    end
end)

--------------------------------------------------------------------------------------------------------------
-- The box, in the window's top bar
--------------------------------------------------------------------------------------------------------------

local function ShowResults()
    local found = Search.Find(box:GetText())
    for i = 1, MAX do
        local b = buttons[i]
        local c = found[i]
        if c then
            b.text:SetText(c.text)
            b.sub:SetText(c.zone and ((c.sub or "") .. " · " .. c.zone) or c.sub or "")
            if c.atlas then b.icon:SetAtlas(c.atlas) elseif c.icon then b.icon:SetTexture(c.icon) else b.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01") end
            b.result = c
            b:Show()
        else
            b:Hide()
        end
    end
    list:SetHeight(math.max(1, #found) * 22 + 8)
    list:SetShown(#found > 0 and box:HasFocus())
end

ns.On("ZMAP_CREATED", function(frame)
    box = CreateFrame("EditBox", nil, frame.header, "SearchBoxTemplate")
    box:SetSize(220, 20)
    box:SetPoint("LEFT", frame.header, "LEFT", 70, 0)
    box:SetAutoFocus(false)
    if box.Instructions then box.Instructions:SetText(L.SEARCH) end
    list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -2)
    list:SetWidth(320)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    list:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    list:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
    list:Hide()
    for i = 1, MAX do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(310, 22)
        b:SetPoint("TOPLEFT", 5, -4 - (i - 1) * 22)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 2, 0)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetJustifyH("LEFT")
        b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.sub:SetPoint("RIGHT", -4, 0)
        b.sub:SetJustifyH("RIGHT")
        b:SetScript("OnClick", function(self) Search.Go(self.result) end)
        buttons[i] = b
    end
    box:HookScript("OnTextChanged", ShowResults)
    box:HookScript("OnEditFocusGained", ShowResults)
    box:HookScript("OnEditFocusLost", function() C_Timer.After(0.2, function() list:Hide() end) end)
    box:SetScript("OnEnterPressed", function() Search.Go(results[1]) end)
    box:HookScript("OnEscapePressed", function() box:ClearFocus() list:Hide() end)
end)

ns.commands.buscar = function(text)
    ns.Map.Open()
    local found = Search.Find(text)
    if found[1] then Search.Go(found[1]) else ns.Print(L.NOTHING_FOUND:format(text)) end
end
ns.commands.search = ns.commands.buscar
