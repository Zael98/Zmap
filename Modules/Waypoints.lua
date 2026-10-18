-- Your pins: points you mark (Ctrl+click on the map, its right-click menu, /zway), each with a name, a note
-- and a colour, shared with your group or guild if you like. One at a time is the destination: the arrow
-- on screen (Arrow.lua) and the game's own waypoint marker lead you there.
local _, ns = ...
local L, Geo = ns.L, ns.Geo
local WP = {}
ns.Waypoints = WP

local COLORS = {
    { 1, 0.82, 0 }, { 0.3, 0.75, 1 }, { 0.35, 1, 0.45 }, { 1, 0.35, 0.35 }, { 0.85, 0.5, 1 }, { 1, 1, 1 },
}
local active   -- the pin we are navigating to

local P = ns.Pins.New("pins", { level = 60, size = 22, option = "pins" })

local function Pin(id) return ns.db.pins[id] end

function WP.Active() return active end

--------------------------------------------------------------------------------------------------------------
-- A small dialog for a pin's name or note (Blizzard's popups sit under a full-screen map)
--------------------------------------------------------------------------------------------------------------

local prompt
function ns.Prompt(title, text, onAccept)
    if not prompt then
        prompt = CreateFrame("Frame", "ZmapPrompt", UIParent, "BackdropTemplate")
        prompt:SetSize(340, 112)
        prompt:SetPoint("CENTER", 0, 120)
        prompt:SetFrameStrata("FULLSCREEN_DIALOG")
        prompt:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        prompt:SetBackdropColor(0.07, 0.07, 0.08, 0.97)
        prompt:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
        prompt:EnableMouse(true)
        prompt.title = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        prompt.title:SetPoint("TOP", 0, -14)
        prompt.edit = CreateFrame("EditBox", nil, prompt, "InputBoxTemplate")
        prompt.edit:SetSize(290, 22)
        prompt.edit:SetPoint("TOP", 0, -38)
        prompt.edit:SetAutoFocus(true)
        prompt.edit:SetMaxLetters(120)
        local function Accept()
            local fn = prompt.onAccept
            prompt:Hide()
            if fn then fn(prompt.edit:GetText()) end
        end
        prompt.edit:SetScript("OnEnterPressed", Accept)
        prompt.edit:SetScript("OnEscapePressed", function() prompt:Hide() end)
        local ok = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
        ok:SetSize(110, 22)
        ok:SetPoint("BOTTOMRIGHT", prompt, "BOTTOM", -6, 12)
        ok:SetText(OKAY)
        ok:SetScript("OnClick", Accept)
        local cancel = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
        cancel:SetSize(110, 22)
        cancel:SetPoint("BOTTOMLEFT", prompt, "BOTTOM", 6, 12)
        cancel:SetText(CANCEL)
        cancel:SetScript("OnClick", function() prompt:Hide() end)
    end
    prompt.title:SetText(title)
    prompt.onAccept = onAccept
    prompt:Show()
    prompt.edit:SetText(text or "")
    prompt.edit:SetFocus()
    prompt.edit:HighlightText()
end

-- a yes/no question, same reason
function ns.Confirm(text, onYes)
    ns.Prompt(text .. "  " .. L.TYPE_YES, "", function(answer)
        local a = ns.Fold(answer or "")
        if a == ns.Fold(L.YES) or a == "si" or a == "yes" or a == "y" or a == "s" then onYes() end
    end)
end

--------------------------------------------------------------------------------------------------------------
-- Pins
--------------------------------------------------------------------------------------------------------------

local function DefaultName(mapID, x, y)
    return ("%s %s"):format(Geo.Name(mapID), ns.Coords(x, y))
end

-- opts: note, color, by (who shared it), temp (gone once reached), navigate, ask (for its name)
function WP.Add(mapID, x, y, name, opts)
    opts = opts or {}
    ns.db.pinSeq = (ns.db.pinSeq or 0) + 1
    local id = ns.db.pinSeq
    ns.db.pins[id] = { m = mapID, x = x, y = y, name = name or DefaultName(mapID, x, y), note = opts.note,
        color = opts.color or 1, t = time(), by = opts.by, temp = opts.temp }
    if opts.navigate then WP.Navigate(id) end
    if opts.ask then WP.Rename(id) end
    P:Update()
    return id
end

function WP.AddAt(u, v, opts)
    local mapID, x, y = Geo.ZoneAt(u, v)
    if not mapID then
        ns.Print(L.NO_ZONE_HERE)
        return
    end
    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
    return WP.Add(mapID, x, y, nil, opts)
end

function WP.Remove(id)
    if id == active then WP.Stop() end
    ns.db.pins[id] = nil
    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_REMOVE)
    P:Update()
end

function WP.Rename(id)
    local p = Pin(id)
    if not p then return end
    ns.Prompt(L.PIN_NAME, p.name, function(text)
        if text and text:match("%S") then p.name = text end
        P:Update()
    end)
end

function WP.EditNote(id)
    local p = Pin(id)
    if not p then return end
    ns.Prompt(L.PIN_NOTE, p.note, function(text)
        p.note = text and text:match("%S") and text or nil
    end)
end

--------------------------------------------------------------------------------------------------------------
-- Navigation: our arrow and the game's waypoint
--------------------------------------------------------------------------------------------------------------

function WP.Navigate(id)
    local p = Pin(id)
    if not p then return end
    active = id
    local u, v = Geo.ToWorld(p.m, p.x, p.y)
    ns.Arrow.SetTarget({ instance = Geo.Instance(p.m), u = u, v = v, name = p.name,
        onArrive = function() WP.Arrived(id) end })
    if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(p.m) and UiMapPoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(p.m, p.x, p.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
    P:Update()
end

function WP.Stop()
    if not active then return end
    active = nil
    ns.Arrow.Clear()
    if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    P:Update()
end

function WP.Arrived(id)
    local p = Pin(id)
    ns.Print(L.ARRIVED:format(p and p.name or ""))
    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_OFF)
    WP.Stop()
    if p and p.temp then
        ns.db.pins[id] = nil
        P:Update()
    end
end

--------------------------------------------------------------------------------------------------------------
-- Sharing
--------------------------------------------------------------------------------------------------------------

local function InsertInChat(text)
    local insert = ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not (insert and insert(text)) and open then open(text) end
end

-- the game's map link for a point, in the chat box (everyone can click it, with or without Zmap)
function WP.LinkMapPoint(mapID, x, y)
    if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) and UiMapPoint then
        local previous = C_Map.GetUserWaypoint()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        local link = C_Map.GetUserWaypointHyperlink()
        if previous then C_Map.SetUserWaypoint(previous) else C_Map.ClearUserWaypoint() end
        if link then
            InsertInChat(link)
            PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CHAT_SHARE)
            return
        end
    end
    InsertInChat(("%s (%s)"):format(Geo.Name(mapID), ns.Coords(x, y)))
end

function WP.LinkAt(u, v)
    local mapID, x, y = Geo.ZoneAt(u, v)
    if mapID then WP.LinkMapPoint(mapID, x, y) end
end

-- a map link clicked in chat (the game's own, "worldmap:mapID:x:y", x and y in ten-thousandths): while Zmap
-- takes M's place, Zmap opens on that point with a pin there for the session, instead of Blizzard's map (it
-- has opened it already: closed again)
function WP.OpenMapLink(link)
    local mapID, x, y = tostring(link):match("^worldmap:(%d+):(%d+):(%d+)")
    mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
    if not (mapID and Geo.Kind(mapID) and ns.Opt("replaceMap")) then return end
    x, y = x / 10000, y / 10000
    if WorldMapFrame and WorldMapFrame:IsShown() and not InCombatLockdown() then HideUIPanel(WorldMapFrame) end
    local id
    for pid, p in pairs(ns.db.pins) do
        if p.m == mapID and math.abs(p.x - x) < 0.0005 and math.abs(p.y - y) < 0.0005 then id = pid end
    end
    id = id or WP.Add(mapID, x, y, nil, { temp = true, color = 2 })
    ns.Map.Open()
    local u, v = Geo.ToWorld(mapID, x, y)
    ns.Map.GoTo(u, v, ns.Map.ZoomFor(mapID) * (Geo.Kind(mapID) == "zone" and 2 or 1))
    return id
end
if SetItemRef then hooksecurefunc("SetItemRef", function(link) WP.OpenMapLink(link) end) end

function WP.Share(id, channel)
    local p = Pin(id)
    if not p then return end
    if ns.Comm.Send("W", channel, nil, p.m, ("%.4f"):format(p.x), ("%.4f"):format(p.y), p.name or "", p.note or "") then
        ns.Print(L.PIN_SHARED:format(p.name))
    else
        ns.Print(L.CANNOT_SHARE)
    end
end

ns.Comm.On("W", function(sender, channel, m, x, y, name, note)
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if not (m and x and y and Geo.Kind(m)) then return end
    local who = Ambiguate(sender, "short")
    WP.Add(m, x, y, name ~= "" and name or nil, { note = note ~= "" and note or nil, by = who, color = 2 })
    ns.Print(L.PIN_RECEIVED:format(who, name or "", Geo.Name(m), ns.Coords(x, y)))
end)

--------------------------------------------------------------------------------------------------------------
-- On the map
--------------------------------------------------------------------------------------------------------------

function P:Refresh()
    self:ReleaseAll()
    for id, p in pairs(ns.db.pins) do
        local u, v = Geo.ToWorld(p.m, p.x, p.y)
        if u then
            local pin = self:Acquire()
            pin.id = id
            pin.icon:SetAtlas(id == active and "Waypoint-MapPin-Tracked" or "Waypoint-MapPin-Untracked")
            local c = COLORS[p.color or 1] or COLORS[1]
            pin.icon:SetVertexColor(c[1], c[2], c[3])
            self:Place(pin, u, v, id == active and 1.2 or 1)
        end
    end
end

function P:Tooltip(pin, tip)
    local p = Pin(pin.id)
    if not p then return end
    local c = COLORS[p.color or 1] or COLORS[1]
    tip:SetText(p.name, c[1], c[2], c[3], 1, true)
    if p.note then tip:AddLine(p.note, 1, 1, 1, true) end
    tip:AddLine(("%s  %s"):format(Geo.Name(p.m), ns.Coords(p.x, p.y)), 1, 0.82, 0)
    if p.by then tip:AddLine(L.SHARED_BY:format(p.by), 0.6, 0.8, 1) end
    tip:AddLine(pin.id == active and L.PIN_HINT_ACTIVE or L.PIN_HINT, 0.6, 0.6, 0.6, true)
end

local function ColorName(i)
    local c = COLORS[i]
    return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, L["COLOR_" .. i])
end

local function PinMenu(owner, id)
    local p = Pin(id)
    if not (p and MenuUtil) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(p.name)
        root:CreateButton(id == active and L.STOP_NAV or L.NAVIGATE, function()
            if id == active then WP.Stop() else WP.Navigate(id) end
        end)
        root:CreateButton(L.RENAME, function() WP.Rename(id) end)
        root:CreateButton(L.EDIT_NOTE, function() WP.EditNote(id) end)
        local colors = root:CreateButton(L.COLOR)
        for i in ipairs(COLORS) do
            colors:CreateRadio(ColorName(i), function() return (p.color or 1) == i end, function()
                p.color = i
                P:Update()
            end)
        end
        local share = root:CreateButton(L.SHARE)
        share:CreateButton(L.SHARE_GROUP, function() WP.Share(id, IsInRaid() and "RAID" or "PARTY") end)
        share:CreateButton(L.SHARE_GUILD, function() WP.Share(id, "GUILD") end)
        share:CreateButton(L.SHARE_CHAT, function() WP.LinkMapPoint(p.m, p.x, p.y) end)
        root:CreateDivider()
        root:CreateButton(L.DELETE, function() WP.Remove(id) end)
    end)
end

function P:OnClick(pin, button)
    if button == "RightButton" then
        PinMenu(pin, pin.id)
    elseif pin.id == active then
        WP.Stop()
    else
        WP.Navigate(pin.id)
    end
end

-- the list of pins (the window's Pins button)
function WP.Menu(owner)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.MY_PINS)
        local ids = {}
        for id in pairs(ns.db.pins) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b) return (ns.db.pins[a].t or 0) > (ns.db.pins[b].t or 0) end)
        if #ids == 0 then root:CreateButton(L.NO_PINS, function() end) end
        for _, id in ipairs(ids) do
            local p = ns.db.pins[id]
            local label = ("%s%s |cff999999(%s)|r"):format(id == active and "> " or "", p.name, Geo.Name(p.m))
            local entry = root:CreateButton(label)
            entry:CreateButton(L.SHOW_ON_MAP, function()
                local u, v = Geo.ToWorld(p.m, p.x, p.y)
                ns.Map.GoTo(u, v, math.max(ns.Map.Zoom(), 6))
            end)
            entry:CreateButton(id == active and L.STOP_NAV or L.NAVIGATE, function()
                if id == active then WP.Stop() else WP.Navigate(id) end
            end)
            entry:CreateButton(L.DELETE, function() WP.Remove(id) end)
        end
        if #ids > 0 then
            root:CreateDivider()
            root:CreateButton(L.DELETE_ALL, function()
                ns.Confirm(L.DELETE_ALL_CONFIRM, function()
                    WP.Stop()
                    wipe(ns.db.pins)
                    P:Update()
                end)
            end)
        end
    end)
end

--------------------------------------------------------------------------------------------------------------
-- /zway x y [name] (also /way, unless TomTom has it): a pin in your zone, or "/zway Zone name x y [name]"
--------------------------------------------------------------------------------------------------------------

local function FindZone(text)
    local want = ns.Fold(text)
    local best
    for _, id in ipairs(Geo.Zones()) do
        local name = ns.Fold(Geo.Name(id))
        if name == want then return id end
        if not best and name:find(want, 1, true) == 1 then best = id end
    end
    return best
end

function WP.Command(msg)
    msg = (msg or ""):gsub("(%d),(%d)", "%1.%2")
    local before, x, y, rest = msg:match("^%s*(.-)%s*(%d+%.?%d*)[%s,]+(%d+%.?%d*)%s*(.-)%s*$")
    x, y = tonumber(x), tonumber(y)
    if not (x and y) then
        ns.Print(L.WAY_USAGE)
        return
    end
    local mapID
    if before ~= "" then
        mapID = FindZone(before)
        if not mapID then
            ns.Print(L.WAY_NO_ZONE:format(before))
            return
        end
    else
        local _, _, m = Geo.UnitPosition("player")
        mapID = m
    end
    if not mapID then
        ns.Print(L.NO_POSITION)
        return
    end
    WP.Add(mapID, x / 100, y / 100, rest ~= "" and rest or nil, { navigate = true })
    ns.Print(L.WAY_SET:format(Geo.Name(mapID), ns.Coords(x / 100, y / 100)))
end

SLASH_ZMAPWAY1 = "/zway"
SlashCmdList.ZMAPWAY = WP.Command
ns.commands.way = WP.Command
ns.commands.pins = function() ns.Map.Open(); WP.Menu(ns.Map.Frame().pinsButton) end
ns.commands.pines = ns.commands.pins

ns.On("PLAYER_LOGIN", function()
    local tomtom = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("TomTom")
    if not tomtom and not SlashCmdList.TOMTOM_WAY then
        SLASH_ZMAPWAYALT1 = "/way"
        SlashCmdList.ZMAPWAYALT = WP.Command
    end
end)

ns.On("ZMAP_DB", function()
    -- temporary pins (a guildmate, "go here") do not outlive the session
    for id, p in pairs(ns.db.pins) do
        if p.temp then ns.db.pins[id] = nil end
    end
end)
