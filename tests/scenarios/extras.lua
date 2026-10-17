-- The data's quests, herbs and ore, mailboxes and anvils; guildmates without Zmap; the minimap; a dungeon's own
-- map; the zones' colours; /zmap diag.
START()
STATE.player.wx, STATE.player.wy = -9460, 62   -- Goldshire
STATE.log = { 33 }                              -- Wolves Across the Border
STATE.completed = {}
EVENT("QUEST_LOG_UPDATE")
OPEN()
local W, H = ZNS.Geo.W, ZNS.Geo.H
local gu, gv = ZNS.Geo.ToWorld(1429, 0.42, 0.65)

-- quests to pick up, near Goldshire
ZNS.Map.SetView(gu * W, gv * H, 6)
FRAMES(3)
local function GiverOf(npc)
    for _, pin in ipairs(PINS("givers")) do
        if pin.mark and pin.mark.npc == npc then return pin end
    end
end
local dughan = GiverOf(240)   -- Marshal Dughan
OUT(("givers: %d, dughan %s"):format(#PINS("givers"), dughan and HOVER(dughan) or "none"))
-- done, it is no longer offered
STATE.completed = { 7, 783, 11, 176, 239, 59, 60, 61, 62, 76, 106, 109, 111, 112, 114, 15, 21, 35, 40, 47, 54, 85, 86, 87, 88, 107, 118, 184 }
EVENT("QUEST_TURNED_IN")
ADVANCE(2)
FRAMES(3)
local still = 0
for _, pin in ipairs(PINS("givers")) do
    for _, q in ipairs(pin.mark.quests) do if q == 7 or q == 783 then still = still + 1 end end
end
OUT("completed gone: " .. tostring(still == 0))
-- too low to take, nothing for level 1
STATE.player.level = 1
EVENT("PLAYER_LEVEL_UP")
ADVANCE(2)
FRAMES(3)
local high = 0
for _, pin in ipairs(PINS("givers")) do
    for _, q in ipairs(pin.mark.quests) do if ZNS.QUESTS[q][3] > 1 then high = high + 1 end end
end
OUT("above level offered: " .. high)
STATE.player.level = 12
EVENT("PLAYER_LEVEL_UP")
ADVANCE(2)

-- the objectives of the quest in the log: its wolves, and where to turn it in
FRAMES(3)
local wolves, turnIn, tip = 0, false, ""
for _, pin in ipairs(PINS("objectives")) do
    if pin.mark.turnIn then turnIn = true elseif pin.mark.quest == 33 then wolves = wolves + 1; tip = tip ~= "" and tip or HOVER(pin) end
end
STATE.finished = { [33] = true }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
FRAMES(3)
for _, pin in ipairs(PINS("objectives")) do
    if pin.mark.turnIn and pin.mark.quest == 33 then turnIn = true end
end
OUT(("objectives: wolves %d, turn-in %s, tooltip %s"):format(wolves, tostring(turnIn), tip))

-- herbs from the data: none without the profession, then those of your skill
local function DataHerbs()
    local n, grey, ore = 0, 0, 0
    for _, pin in ipairs(PINS("gather")) do
        if pin.data and pin.data.kind == "ore" then
            ore = ore + 1
        elseif pin.data then
            n = n + 1
            if pin.data.skill > 50 then grey = grey + 1 end
        end
    end
    return n, grey, ore
end
-- and the layers menu offers herbs only with Herbalism, ore only with Mining
local function Offered()
    local text = ZNS.LayerTexts()
    return ("herbs %s, ore %s"):format(tostring(text:find(ZNS.L.OPT_HERBS, 1, true) ~= nil), tostring(text:find(ZNS.L.OPT_ORE, 1, true) ~= nil))
end
ZNS.Map.SetView(gu * W, gv * H, 9)
STATE.skills = {}
EVENT("SKILL_LINES_CHANGED")
FRAMES(3)
local n0, _, ore0 = DataHerbs()
OUT(("no profession: herbs %d, ore %d, offered %s"):format(n0, ore0, Offered()))
STATE.skills = { herb = 50 }
EVENT("SKILL_LINES_CHANGED")
FRAMES(3)
local n, grey, ore = DataHerbs()
OUT(("herbalism 50: herbs %d, above skill greyed %s, ore %d, offered %s"):format(n, tostring(grey > 0), ore, Offered()))
STATE.skills = { herb = 50, ore = 1 }
EVENT("SKILL_LINES_CHANGED")
FRAMES(3)
local _, _, oreNow = DataHerbs()
OUT(("with mining: ore %s"):format(tostring(oreNow > 0)))

-- mailboxes and anvils of Goldshire
ZNS.Map.SetView(gu * W, gv * H, 12)
FRAMES(3)
local kinds = {}
for _, pin in ipairs(PINS("townsfolk")) do
    if pin.object then kinds[pin.object] = (kinds[pin.object] or 0) + 1; kinds.tip = kinds.tip or HOVER(pin) end
end
OUT(("utilities: mailbox %s, anvil %s, tooltip %s"):format(tostring(kinds.mailbox ~= nil), tostring(kinds.anvil ~= nil), tostring(kinds.tip)))

-- guildmates without Zmap: in their zone, by name
STATE.roster = {
    { name = "Domi", level = 12, zone = "Bosque de Elwynn", online = true, class = "WARRIOR" },
    { name = "Korra", level = 30, zone = "Bosque de Elwynn", online = true, class = "MAGE" },
    { name = "Brann", level = 41, zone = "Bosque de Elwynn", online = true, class = "PALADIN" },
    { name = "Durm", level = 20, zone = "Los Baldíos", online = false, class = "ROGUE" },
}
EVENT("GUILD_ROSTER_UPDATE")
ZNS.Map.SetView(gu * W, gv * H, 3)
FRAMES(3)
local mates = PINS("guildzone")
OUT(("guild without zmap: %d, tooltip %s"):format(#mates, mates[1] and HOVER(mates[1]) or "none"))
OUT("apart: " .. tostring(#mates == 2 and (mates[1].u ~= mates[2].u or mates[1].v ~= mates[2].v)))

-- the minimap: the destination at its edge while far
ZNS.Waypoints.Add(1429, 0.90, 0.80, "Lejos", { navigate = true })
FRAMES(3)
local minimapPins = 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.parent == ZmapMinimapPins and w.shown then minimapPins = minimapPins + 1 end
end
OUT("minimap pins: " .. minimapPins)

-- a dungeon: its own map inside, and from its entrance
ZNS.Map.Close()
STATE.instance, STATE.instanceID, STATE.instanceName = true, 36, "Las Minas de la Muerte"
OPEN()
OUT(("inside deadmines: shown %s"):format(tostring(ZNS.Dungeon.IsShown())))
local dview
for _, w in ipairs(ALL_WIDGETS) do if w.parent == ZmapFrame.viewport and w.scripts.OnMouseUp and w ~= ZmapFrame.layersPanel and w:IsShown() and w._level and w.kind == "Frame" and w.scripts.OnMouseWheel and w ~= ZmapFrame.viewport then dview = w end end
dview.scripts.OnMouseUp(dview, "RightButton")
OUT("back to the world: " .. tostring(not ZNS.Dungeon.IsShown()))
ZNS.Map.Close()
STATE.instance = false
OPEN()
OUT("outside: dungeon map shown " .. tostring(ZNS.Dungeon.IsShown()))

-- the zones' colours, even
ZNS.SetOpt("harmonize", true)
FRAMES(3)
OUT("tinted: " .. tostring(ZNS.Art.Tint(1429)[1] ~= 1 or ZNS.Art.Tint(1429)[2] ~= 1 or ZNS.Art.Tint(1429)[3] ~= 1))

-- /zmap diag
SlashCmdList.ZMAP("diag")
local text = ZmapDiag and ZmapDiag.edit and ZmapDiag.edit:GetText() or ""
OUT(("diag: shown %s, lines %d, quests line %s"):format(tostring(ZmapDiag and ZmapDiag.shown), select(2, text:gsub("\n", "")) + 1,
    tostring(text:find("quests: 1 in log", 1, true) ~= nil)))
for line in text:gmatch("[^\n]+") do
    if line:find("ERROR") then OUT("diag " .. line) end
end
OUT("errors " .. #STATE.errors)
if #STATE.errors > 0 then OUT("ADDON ERRORS: " .. table.concat(STATE.errors, " || ")) end

-- the layers panel folds to a tab and opens again, remembered
ZNS.Map.Close()
OPEN()
local side, tab = ZmapFrame.layersPanel, ZmapFrame.layersButton
local foldButton
for _, w in ipairs(ALL_WIDGETS) do if w.parent == side and w.kind == "Button" then foldButton = w end end
foldButton.scripts.OnClick(foldButton)
local folded = not side:IsShown() and tab:IsShown() and ZNS.db.window.layers == false
tab.scripts.OnClick(tab)
OUT(("layers fold: folded %s, open again %s"):format(tostring(folded), tostring(side:IsShown() and not tab:IsShown())))

-- vendors and trainers by what they sell or teach
local function IconOf(id)
    local look = ZNS.FolkLook(id)
    return look and tostring(look[1]):match("([%w_%-]+)$") or "none"
end
OUT(("specialties: enchanting %s, cooking %s, warrior %s, weaponsmith %s, food %s, tailoring %s, cook trainer %s, enchanter %s"):format(
    IconOf(1318), IconOf(3085), IconOf(911), IconOf(54), IconOf(2303), IconOf(1347), IconOf(1355), IconOf(3606)))

-- the townsfolk unfold into their types, each on or off by itself
ZNS.Map.SetView(gu * W, gv * H, 12)
FRAMES(3)
local side2 = ZmapFrame.layersPanel
local folkRow
for _, b in ipairs(side2.rows) do if b.layer[1] == "townsfolk" then folkRow = b end end
folkRow.scripts.OnClick(folkRow)
local subsShown = 0
for _, b in ipairs(side2.subs) do if b:IsShown() then subsShown = subsShown + 1 end end
local function CountCat(cat)
    local n = 0
    for _, pin in ipairs(PINS("townsfolk")) do
        if pin.npc and ZNS.FolkLook(pin.npc).cat == cat then n = n + 1 end
    end
    return n
end
local foodBefore, innBefore = CountCat("food"), CountCat("innkeeper")
local foodRow
for _, b in ipairs(side2.subs) do if b.cat == "food" then foodRow = b end end
foodRow.scripts.OnClick(foodRow)
FRAMES(3)
OUT(("folk types: rows %d, food %s -> %d, innkeepers kept %s, row alpha %.2f"):format(subsShown, tostring(foodBefore > 0),
    CountCat("food"), tostring(CountCat("innkeeper") >= innBefore and innBefore > 0), foodRow.icon:GetAlpha()))
foodRow.scripts.OnClick(foodRow)
FRAMES(3)
OUT("food back: " .. tostring(CountCat("food") == foodBefore))

-- "all" off, then one type: only that type
local allRow, profRow
for _, b in ipairs(side2.subs) do
    if b.isAll then allRow = b elseif b.cat == "proftrainer" then profRow = b end
end
allRow.scripts.OnClick(allRow)
FRAMES(3)
local noneLeft = #PINS("townsfolk")
profRow.scripts.OnClick(profRow)
FRAMES(3)
local onlyProf = #PINS("townsfolk") > 0
for _, pin in ipairs(PINS("townsfolk")) do
    if not (pin.npc and ZNS.FolkLook(pin.npc).cat == "proftrainer") then onlyProf = false end
end
OUT(("all off then one: none %s, only profession trainers %s, all row alpha %.2f"):format(tostring(noneLeft == 0),
    tostring(onlyProf), allRow.icon:GetAlpha()))
-- the layer off from elsewhere, then a type: that one alone
ZNS.SetOpt("townsfolk", false)
FRAMES(2)
profRow.scripts.OnClick(profRow)
FRAMES(3)
local alone = ZNS.Opt("townsfolk") and ZNS.FolkTypeShown("proftrainer") and not ZNS.FolkTypeShown("food")
allRow.scripts.OnClick(allRow)
FRAMES(3)
OUT(("layer off then one: alone %s; all again: %s"):format(tostring(alone), tostring(ZNS.AllFolkTypesShown())))
