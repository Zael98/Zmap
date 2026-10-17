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
OUT("errors " .. #STATE.errors)
