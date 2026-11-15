-- Pins: Ctrl+click, naming, going there (our arrow and the game's waypoint), arriving, sharing, receiving,
-- the menus, /zway, deleting them all.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
OPEN()
local function Count() local n = 0 for _ in pairs(ZNS.db.pins) do n = n + 1 end return n end

local u, v = ZNS.Geo.ToWorld(1429, 0.42, 0.66)
STATE.ctrl = true
CLICK_MAP(u, v)
STATE.ctrl = false
OUT(("ctrl click: pins %d, prompt %s"):format(Count(), tostring(ZmapPrompt and ZmapPrompt.shown)))
ANSWER("Mi herbolario")
local id = next(ZNS.db.pins)
OUT("named: " .. ZNS.db.pins[id].name)

-- go there: a point 100 yards north of the player
local pu, pv = ZNS.Geo.FromYards(0, STATE.player.wx + 100, STATE.player.wy)
local m, x, y = ZNS.Geo.ZoneAt(pu, pv)
local target = ZNS.Waypoints.Add(m, x, y, "Norte", { temp = true })
ZNS.Waypoints.Navigate(target)
FRAME()
OUT(("navigate: target %s, blizzard waypoint %s, supertracked %s"):format(tostring(ZNS.Arrow.Target() ~= nil),
    tostring(STATE.waypoint and STATE.waypoint.uiMapID), tostring(STATE.superTracked)))
STATE.player.facing = 0
FRAME()
OUT(("arrow north: rotation %.2f, distance %s"):format(ZmapArrow.arrow.rotation, ZmapArrow.dist.text))
STATE.player.facing = math.pi
FRAME()
OUT(("arrow behind: rotation %.2f"):format(math.abs(ZmapArrow.arrow.rotation)))
STATE.player.wx = STATE.player.wx + 97
FRAME()
OUT(("arrived: active %s, arrow hidden %s, temp pin gone %s"):format(tostring(ZNS.Waypoints.Active()),
    tostring(not ZmapArrow.shown), tostring(ZNS.db.pins[target] == nil)))

-- share with the guild, receive from someone
ZNS.Waypoints.Share(id, "GUILD")
OUT("share guild: " .. STATE.sent[#STATE.sent].msg)
-- the guild chat gets the game's map link (everyone sees it, with or without Zmap), with the pin's name
local said = STATE.said and STATE.said[#STATE.said]
OUT(("said in guild: %s, channel %s"):format(tostring(said and said[1]), tostring(said and said[2])))
-- whisper it to one player: the menu offers your target and the people you whispered lately; the game's link
-- goes as a whisper and the pin as a whispered add-on message
EVENT("CHAT_MSG_WHISPER", "hola", "Korra-Nube")
EVENT("CHAT_MSG_WHISPER_INFORM", "hey", "Lyra-Brisa")
EVENT("CHAT_MSG_WHISPER", "eco", "Domi")
STATE.units.target = { name = "Thrall" }
local isPlayer = UnitIsPlayer
UnitIsPlayer = function(u) return u == "target" or isPlayer(u) end
local function Who()
    local out = {}
    for _, t in ipairs(ZNS.Waypoints.WhisperNames()) do out[#out + 1] = t.who end
    return table.concat(out, ", ")
end
OUT("whisper names: " .. Who())
ZNS.Waypoints.Whisper(id, "Lyra-Brisa")
said = STATE.said[#STATE.said]
local whisper = STATE.sent[#STATE.sent]
OUT(("whispered: %s, channel %s, to %s; add-on %s to %s"):format(tostring(said[1]), tostring(said[2]),
    tostring(said[3]), whisper.channel, tostring(whisper.target)))
-- Battle.net: a friend who whispered you is offered while online, by account name, and gets a Battle.net whisper
STATE.bnFriends = { { bnetAccountID = 7, accountName = "Ana", battleTag = "Ana#2101", gameAccountInfo = { isOnline = true } },
    { bnetAccountID = 9, accountName = "Off", battleTag = "Off#1", gameAccountInfo = { isOnline = false } } }
EVENT("CHAT_MSG_BN_WHISPER", "hola", "Ana", "", "", "", "", 0, 0, "", 0, 1, nil, 7)
EVENT("CHAT_MSG_BN_WHISPER_INFORM", "hey", "Off", "", "", "", "", 0, 0, "", 0, 2, nil, 9)
local labels = {}
for _, t in ipairs(ZNS.Waypoints.WhisperNames()) do labels[#labels + 1] = t.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
OUT("whisper names with bnet: " .. table.concat(labels, ", "))
local sentBefore = #STATE.sent
ZNS.Waypoints.Whisper(id, "bn:Ana#2101")
said = STATE.said[#STATE.said]
OUT(("bnet whispered: %s, channel %s, to %s; add-on messages %d"):format(tostring(said[1]), tostring(said[2]),
    tostring(said[3]), #STATE.sent - sentBefore))
STATE.bnFriends = nil
UnitIsPlayer = isPlayer
STATE.units.target = nil
EVENT("CHAT_MSG_ADDON", "Zmap", "W\t1436\t0.5600\t0.4700\tGrifo\tCerca del faro", "GUILD", "Lyra-Realm")
local by
for _, p in pairs(ZNS.db.pins) do if p.by then by = p.by end end
OUT(("received: pins %d, by %s"):format(Count(), tostring(by)))

-- a pin's menu (right-click), the list menu
local pins = PINS("pins")
pins[1].scripts.OnClick(pins[1], "RightButton")
OUT("menu: " .. MENU_TEXTS())
PICK(ZNS.L.SHARE, ZNS.L.SHARE_CHAT)
OUT("link in chat: " .. tostring(STATE.chat[#STATE.chat]))
ZmapFrame.pinsButton:Click()
OUT("pins list: " .. MENU_TEXTS())

-- /zway
ZNS.Waypoints.Command("45,2 60,1 Hierbas")
local found = false
for _, p in pairs(ZNS.db.pins) do if p.name == "Hierbas" then found = true end end
OUT(("way command: pin %s, navigating %s"):format(tostring(found), tostring(ZNS.Waypoints.Active() ~= nil)))
ZNS.Waypoints.Command(ZNS.Geo.Name(1429) .. " 30 40")
ZNS.Waypoints.Command("Narnia 30 40")
OUT("way unknown zone: " .. LAST_PRINT())

ZmapFrame.pinsButton:Click()
PICK(ZNS.L.DELETE_ALL)
ANSWER(ZNS.L.YES)
OUT("delete all: pins " .. Count())

-- a map link clicked in chat: Zmap opens on the point (Blizzard's map closed again), a pin there; twice, one pin
ZNS.Map.Close()
SetItemRef("worldmap:1429:4200:6500", "[Map Pin Location]", "LeftButton")
SetItemRef("worldmap:1429:4200:6500", "[Map Pin Location]", "LeftButton")
FRAMES(40)
local lu, lv = ZNS.Geo.ToWorld(1429, 0.42, 0.65)
local vl, vt, vr, vb = ZNS.Map.ViewRect()
OUT(("chat link: zmap %s, blizzard %s, pins %d, on the point %s"):format(tostring(ZmapFrame:IsShown()), tostring(WorldMapFrame:IsShown()),
    Count(), tostring(math.abs((vl + vr) / 2 / ZNS.Geo.W - lu) < 0.002 and math.abs((vt + vb) / 2 / ZNS.Geo.H - lv) < 0.002)))
ZNS.SetOpt("replaceMap", false)
SetItemRef("worldmap:1429:3000:3000", "[Map Pin Location]", "LeftButton")
OUT(("chat link, M not replaced: blizzard %s, pins %d"):format(tostring(WorldMapFrame:IsShown()), Count()))
ZNS.SetOpt("replaceMap", true)
-- an addon that sends its waypoints to TomTom (not installed): Zmap's pin and arrow
local before = Count()
local uid = TomTom:AddWaypoint(1429, 0.5, 0.5, { title = "Questie: Lobos", from = "Questie", crazy = true })
local arrow = ZNS.Arrow.Target()
OUT(("tomtom: pins +%d, arrow %s, valid %s, exists %s"):format(Count() - before, tostring(arrow and arrow.name),
    tostring(TomTom:IsValidWaypoint(uid)), tostring(TomTom:WaypointExists(1429, 0.5, 0.5))))
TomTom:RemoveWaypoint(uid)
OUT(("tomtom removed: pins +%d, valid %s, unknown map %s"):format(Count() - before, tostring(TomTom:IsValidWaypoint(uid)),
    tostring((TomTom:AddWaypoint(99999, 0.5, 0.5)))))
OUT("errors " .. #STATE.errors)
