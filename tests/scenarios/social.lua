-- Your guild and group on the map: what we send and when, what we show from others, how it expires.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
ADVANCE(9)   -- (the first broadcast goes 8 seconds after logging in)
local first
for _, s in ipairs(STATE.sent) do if s.msg:sub(1, 1) == "P" then first = first or s.msg end end
OUT("broadcast on login: " .. tostring(first))

STATE.instance = true
local before = #STATE.sent
ADVANCE(60)
local sentInInstance = false
for i = before + 1, #STATE.sent do if STATE.sent[i].msg:sub(1, 1) == "P" then sentInInstance = true end end
OUT("no broadcast in instance: " .. tostring(not sentInInstance))
STATE.instance = false

OPEN()
EVENT("CHAT_MSG_ADDON", "Zmap", "P\t1436\t0.5000\t0.5000\t33\tMAGE", "GUILD", "Lyra-Forever")
FRAMES(2)
local g = PINS("guild")
OUT("guildmate shown: " .. tostring(g[1] and g[1].label.text))
OUT("guildmate tooltip: " .. (g[1] and HOVER(g[1]) or ""))

-- your own position comes back to you from the guild channel: you are not a guildmate. On WoW Forever the
-- surname stands where the realm does ("Domi-Service"); someone with your first name and another surname is
-- someone else
STATE.surname = "Service"
EVENT("CHAT_MSG_ADDON", "Zmap", "P\t1436\t0.5100\t0.5100\t33\tWARRIOR", "GUILD", "Domi-Service")
EVENT("CHAT_MSG_ADDON", "Zmap", "P\t1436\t0.5200\t0.5200\t21\tMAGE", "GUILD", "Domi-Otro")
FRAMES(2)
local labels = {}
for _, p in ipairs(PINS("guild")) do labels[#labels + 1] = p.label.text end
table.sort(labels)
OUT("you are not a guildmate: " .. table.concat(labels, ", "))
-- nor in the guild roster (the guildmates without Zmap, by their zone)
STATE.roster = {
    { name = "Domi", full = "Domi-Service", level = 12, zone = "Bosque de Elwynn", online = true, class = "WARRIOR" },
    { name = "Korra", full = "Korra-Nube", level = 30, zone = "Bosque de Elwynn", online = true, class = "MAGE" },
}
EVENT("GUILD_ROSTER_UPDATE")
FRAMES(2)
local roster = {}
for _, p in ipairs(PINS("guildzone")) do roster[#roster + 1] = p.label.text end
OUT("roster without you: " .. table.concat(roster, ", "))
STATE.surname, STATE.roster = nil, nil
ADVANCE(100)
FRAMES(60, 0.1)
OUT("expired: " .. #PINS("guild"))

STATE.group = { { name = "Thrall", class = "SHAMAN", map = 1429, x = 0.5, y = 0.6 } }
EVENT("GROUP_ROSTER_UPDATE")
FRAMES(12, 0.1)
local grp = PINS("group")
OUT("group shown: " .. tostring(grp[1] and grp[1].label.text))

local n = #STATE.sent
EVENT("CHAT_MSG_ADDON", "Zmap", "Q", "GUILD", "Lyra-Realm")
ADVANCE(6)
local answered = false
for i = n + 1, #STATE.sent do if STATE.sent[i].msg:sub(1, 1) == "P" then answered = true end end
OUT("query answered: " .. tostring(answered))
OUT("errors " .. #STATE.errors)
