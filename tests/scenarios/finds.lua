-- What you find: herbs and ore you gather, townsfolk you talk to; what is sent to the guild and received.
START()
STATE.player.wx, STATE.player.wy = -9460, 62
STATE.skills = { herb = 75, ore = 75 }   -- (herbs and ore only show with the profession)
local function Nodes() local n = 0 for _, list in pairs(ZNS.db.nodes) do n = n + #list end return n end
local function LastSent() return STATE.sent[#STATE.sent] and STATE.sent[#STATE.sent].msg or "" end

EVENT("UNIT_SPELLCAST_SENT", "player", "Flor de paz", "Cast-1", 2366)
EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2366)
OUT(("herb recorded: %d, sent %s"):format(Nodes(), LastSent()))
STATE.player.wx = STATE.player.wx + 2
EVENT("UNIT_SPELLCAST_SENT", "player", "Flor de paz", "Cast-2", 2366)
EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 2366)
OUT(("same herb again: nodes %d, times %d"):format(Nodes(), ZNS.db.nodes[1429][1].n))
-- another spell's cast is not a find
EVENT("UNIT_SPELLCAST_SENT", "player", "Lobo", "Cast-3", 133)
EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 133)
EVENT("CHAT_MSG_ADDON", "Zmap", "N\tore\t1429\t0.3000\t0.7000\tFilón de cobre", "GUILD", "Lyra-Realm")
local by
for _, n in ipairs(ZNS.db.nodes[1429]) do if n.by then by = n.by end end
OUT(("received ore: nodes %d, by %s"):format(Nodes(), tostring(by)))

OPEN()
local u, v = ZNS.Geo.ToWorld(1429, 0.4, 0.6)
ZNS.Map.SetView(u * ZNS.Geo.W, v * ZNS.Geo.H, 6)
FRAMES(3)
OUT("herb pins at zoom 6: " .. #PINS("gather"))

STATE.npc = { name = "Gregor", id = 1234, sub = "Herrero", repair = true }
EVENT("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
local f = ZNS.db.folk["repair:1234"]
OUT(("vendor met: %s (%s) %s, sent %s"):format(f and f.name, f and f.sub, f and f.kind, LastSent()))
STATE.npc = { name = "Tabernera Farley", id = 295, sub = "Tabernera" }
STATE.gossip = { { icon = 132052, name = "Haz de esta posada tu hogar." } }
EVENT("GOSSIP_SHOW")
OUT("innkeeper by gossip: " .. tostring(ZNS.db.folk["innkeeper:295"] ~= nil))
STATE.npc = nil
EVENT("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.MailInfo)
local mail = false
for k in pairs(ZNS.db.folk) do if k:find("^mailbox") then mail = true end end
OUT("mailbox: " .. tostring(mail))
EVENT("CHAT_MSG_ADDON", "Zmap", "T\ttrainer\t1429\t0.4100\t0.6500\tAldric\tInstructor de guerreros\t911", "GUILD", "Lyra-Realm")
OUT("received folk: " .. tostring(ZNS.db.folk["trainer:911"] and ZNS.db.folk["trainer:911"].name))
ZNS.Map.SetView(u * ZNS.Geo.W, v * ZNS.Geo.H, 12)
FRAMES(3)
OUT("folk pins: " .. #PINS("townsfolk"))
OUT("errors " .. #STATE.errors)
