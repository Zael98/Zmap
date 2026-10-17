-- NPCs: found by name (English, then as the game names them), by service, nearest first; the marks where they
-- stand; going there; townsfolk and rares from the data; names learned from nameplates and in the background.
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
OPEN()
local W, H = ZNS.Geo.W, ZNS.Geo.H
local function First(text)
    local r = ZNS.Search.Find(text)[1]
    return r and (r.text .. " | " .. tostring(r.sub) .. " | " .. tostring(r.zone)) or "nothing"
end
OUT("farley: " .. First("farley"))
STATE.units.nameplate1 = { id = 295, name = "Tabernera Farley" }
EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
OUT("learned: " .. ZNS.Npcs.Name(295))
OUT("spanish name: " .. First("tabernera far"))
OUT("english still: " .. First("innkeeper farley"))
OUT("tabernero nearest: " .. First("tabernero"))
OUT("grosk searchable: " .. First("grosk"))

ZNS.Search.Go(ZNS.Search.Find("farley")[1])
FRAMES(20)
local marks = PINS("found")
local u, v = ZNS.Geo.ToWorld(1429, 0.436, 0.66)
local l, t, r, b = ZNS.Map.ViewRect()
OUT(("go farley: marks %d, view near %s"):format(#marks, tostring(math.abs((l + r) / 2 - u * W) < 1 and math.abs((t + b) / 2 - v * H) < 1)))
marks[1].scripts.OnClick(marks[1], "LeftButton")
OUT("navigating to: " .. tostring(ZNS.Arrow.Target() and ZNS.Arrow.Target().name))

ZNS.Map.SetView(u * W, v * H, 12)
FRAMES(3)
local fromData, farley, horde = 0, "", false
for _, pin in ipairs(PINS("townsfolk")) do
    if pin.npc then
        fromData = fromData + 1
        if pin.npc == 295 then farley = HOVER(pin) end
        if ZNS.NPCS[pin.npc][4] == "H" then horde = true end
    end
end
OUT(("townsfolk from data: %d, farley tooltip: %s"):format(fromData, farley))
OUT("horde only shown: " .. tostring(horde))
local rares = 0
for id in pairs(ZNS.NPCS) do if ZNS.Npcs.Rare(id) then rares = rares + 1 end end
OUT("rares in data: " .. rares)

local ids = {}
for id in pairs(ZNS.NPCS) do ids[#ids + 1] = id end
table.sort(ids)
STATE.cached = { [ids[3]] = "Nombre de prueba" }
ADVANCE(40)
OUT(("asked in background: %s, learned: %s"):format(tostring((STATE.asked or 0) > 0), ZNS.Npcs.Name(ids[3])))
local ahead = ids[ZNS.db.npcAskAt + 20]   -- (a little ahead of where the background asking is)
STATE.server = { [ahead] = "Respuesta del servidor" }
ADVANCE(15)
OUT("not cached, asked again: " .. ZNS.Npcs.Name(ahead))
-- an NPC the data lacks: targeted close by, remembered, sent to the guild, found by the search
STATE.units.target = { id = 999001, name = "Vigía Torvo", sub = "Explorador", near = true }
EVENT("PLAYER_TARGET_CHANGED")
local sent = STATE.sent[#STATE.sent] and STATE.sent[#STATE.sent].msg or ""
OUT(("seen: remembered %s, sent %s"):format(tostring(ZNS.db.seen and ZNS.db.seen[999001] ~= nil), sent:sub(1, 8)))
OUT("seen searchable: " .. First("vigia torvo"))
STATE.units.target = { id = 999002, name = "Lejano", near = false }
EVENT("PLAYER_TARGET_CHANGED")
OUT("far away not remembered: " .. tostring(not (ZNS.db.seen and ZNS.db.seen[999002])))
EVENT("CHAT_MSG_ADDON", "Zmap", "S	999003	1436	0.5000	0.4000	Guardia Kerr	", "GUILD", "Lyra-Realm")
OUT("from guild: " .. First("guardia kerr"))
OUT("errors " .. #STATE.errors)
