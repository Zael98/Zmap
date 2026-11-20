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
ZNS.SetOpt("herbs", true)   -- (herbs and ore are off until you turn them on)
ZNS.SetOpt("ore", true)
local u, v = ZNS.Geo.ToWorld(1429, 0.4, 0.6)
ZNS.Map.SetView(u * ZNS.Geo.W, v * ZNS.Geo.H, 6)
FRAMES(3)
OUT("herb pins at zoom 6: " .. #PINS("gather"))

-- fishing from a pool (Floating Wreckage) facing north: learned 16 yards ahead and shared; from open water (the
-- bobber), nothing
STATE.skills.fish = 100
EVENT("SKILL_LINES_CHANGED")
local fishing, source = true, "GameObject-0-1-0-1-180685-0000AAAA"
IsFishingLoot = function() return fishing end
GetLootSourceInfo = function() return source end
STATE.player.facing = 0
local before, beforeX = Nodes(), STATE.player.wx
EVENT("LOOT_OPENED")
local pool
for _, list in pairs(ZNS.db.nodes) do for _, n in ipairs(list) do if n.kind == "fish" then pool = n end end end
local pu, pv = ZNS.Geo.FromYards(0, beforeX + 16, STATE.player.wy)
local _, ex, ey = ZNS.Geo.ZoneAt(pu, pv)
OUT(("pool learned: %s, %s, ahead %s, sent %s"):format(tostring(Nodes() == before + 1), tostring(pool and pool.name),
    tostring(pool ~= nil and math.abs(pool.x - ex) < 0.001 and math.abs(pool.y - ey) < 0.001), LastSent():match("^N\tfish") and "yes" or "no"))
STATE.time = STATE.time + 5
source = "GameObject-0-1-0-1-35591-0000BBBB"   -- (the bobber: open water)
EVENT("LOOT_OPENED")
fishing = false
OUT("open water: nodes " .. tostring(Nodes() == before + 1))
local fu, fv = ZNS.Geo.ToWorld(pool and 1429 or 1429, pool and pool.x or 0.4, pool and pool.y or 0.6)
ZNS.Map.SetView(fu * ZNS.Geo.W, fv * ZNS.Geo.H, 8)
FRAMES(3)
local poolPin
for _, p in ipairs(PINS("gather")) do if p.node and p.node.kind == "fish" then poolPin = p end end
OUT("pool on the map: " .. tostring(poolPin and HOVER(poolPin)))
IsFishingLoot, GetLootSourceInfo = nil, nil

local entered, clicks = nil, {}
local nodes = { [42006000] = { icon = "Interface\\Icons\\INV_Misc_Bag_10", tCoordLeft = 0.1, tCoordRight = 0.9,
    tCoordTop = 0.1, tCoordBottom = 0.9 }, [42506100] = 134400 }
local plugin = {
    GetNodes2 = function(self, mapID, minimap)
        if mapID ~= 1429 then return function() end end
        return function(_, prev) local c, icon = next(nodes, prev) return c, nil, icon, 1, 1 end, nil, nil
    end,
    OnEnter = function(pin, mapID, coord) entered = mapID .. ":" .. coord end,
    OnClick = function(pin, button, down, mapID, coord) clicks[#clicks + 1] = button .. tostring(down) end,
}
HandyNotes = { plugins = { Treasures = plugin }, db = { profile = { enabledPlugins = {}, icon_scale = 1, icon_alpha = 1 } },
    IsEnabled = function() return true end, UpdateWorldMapPlugin = function() end, UpdateWorldMap = function() end }
EVENT("PLAYER_LOGIN")
local hu, hv = ZNS.Geo.ToWorld(1429, 0.42, 0.6)
ZNS.Map.SetView(hu * ZNS.Geo.W, hv * ZNS.Geo.H, 6)
FRAMES(3)
local hn = PINS("handynotes")
if hn[1] then hn[1].scripts.OnEnter(hn[1]); hn[1].scripts.OnClick(hn[1], "RightButton") end
HandyNotes.db.profile.enabledPlugins.Treasures = false
HandyNotes:UpdateWorldMapPlugin("Treasures")
FRAMES(2)
OUT(("handynotes: nodes %d, tooltip %s, clicks %s, plugin off %d"):format(#hn, tostring(entered),
    table.concat(clicks, ","), #PINS("handynotes")))
HandyNotes = nil

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
