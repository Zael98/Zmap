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
-- (the text in your language: Questie's translation for the esES run)
OUT("quest text in your language: " .. tostring(ZNS.QUEST_TEXT ~= nil and (ZNS.QUEST_TEXT[1078] or ""):find("Ventormenta", 1, true) ~= nil))
-- Shift over a quest mark: each quest's details (levels and id, what it asks, who takes it), as Questie shows them;
-- pressing Shift with the cursor already on it shows them at once
dughan.scripts.OnEnter(dughan)
local plain = table.concat(STATE.tooltip, " / ")
STATE.shift = true
EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
local detailed = table.concat(STATE.tooltip, " / ")
STATE.shift = false
EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
local back = table.concat(STATE.tooltip, " / ")
dughan.scripts.OnLeave(dughan)
local firstQuest = dughan.mark.quests[1]
OUT(("shift details: hint %s, levels %s, text %s, turn in %s, back without %s"):format(
    tostring(plain:find(ZNS.L.QUEST_SHIFT_DETAILS, 1, true) ~= nil),
    tostring(detailed:find(ZNS.L.QUEST_DETAIL_LEVELS:format(ZNS.QUESTS[firstQuest][2], ZNS.QUESTS[firstQuest][3], firstQuest), 1, true) ~= nil),
    tostring(detailed:find((ZNS.QUEST_TEXT and ZNS.QUEST_TEXT[firstQuest]) or ZNS.QUESTS[firstQuest][22] or "?", 1, true) ~= nil),
    tostring(detailed:find(ZNS.L.TURN_IN:sub(1, 6), 1, true) ~= nil),
    tostring(back == plain)))
-- the option to hide the data's icons where you have not been: in a zone never visited the givers go, your own pin
-- stays; explored, they are back; a city (no overlays) counts as discovered
local function ShownPins(name) local n = 0 for _, p in ipairs(PINS(name)) do if p.shown then n = n + 1 end end return n end
local mine = ZNS.Waypoints.Add(1429, 0.42, 0.65, "Mio")
ZNS.SetOpt("hideUnexploredIcons", true)
STATE.explored = "never"
EVENT("MAP_EXPLORATION_UPDATED")
FRAMES(2)
local hiddenGivers, myPin = ShownPins("givers"), ShownPins("pins")
STATE.explored = "all"
EVENT("MAP_EXPLORATION_UPDATED")
FRAMES(2)
local su, sv = ZNS.Geo.ToWorld(1453, 0.5, 0.5)
local city = ZNS.Art.Undiscovered(su, sv)
OUT(("unexplored icons: givers %d (of %d), my pin %d, explored: givers %d, city undiscovered %s"):format(
    hiddenGivers, #PINS("givers"), myPin, ShownPins("givers"), tostring(city)))
ZNS.SetOpt("hideUnexploredIcons", false)
ZNS.Waypoints.Remove(mine)
STATE.explored = nil
EVENT("MAP_EXPLORATION_UPDATED")
FRAMES(2)
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
STATE.shift = true
local wolfPin
for _, pin in ipairs(PINS("objectives")) do if pin.mark and pin.mark.quest == 33 and not pin.mark.turnIn then wolfPin = pin end end
local wolfTip = wolfPin and HOVER(wolfPin) or ""
STATE.shift = false
OUT("shift on your quest: game text " .. tostring(wolfTip:find("Objetivo de la misión", 1, true) ~= nil))
-- as areas (the option, on by default): the wolves' groups outlined and filled; off, a dot for each spawn
local edges, bands = ZNS.QuestMap.AreasShown()
local areas = wolves
ZNS.SetOpt("objectiveAreas", false)
FRAMES(2)
local dots = 0
for _, pin in ipairs(PINS("objectives")) do if pin.mark.quest == 33 and not pin.mark.turnIn then dots = dots + 1 end end
local offEdges = ZNS.QuestMap.AreasShown()
OUT(("objective areas: %d areas, outline %s, bands %s; off: %d dots, outline %d"):format(areas, tostring(edges > 0),
    tostring(bands > 0), dots, offEdges))
ZNS.SetOpt("objectiveAreas", true)
FRAMES(2)
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
local off = DataHerbs()   -- (the layer is off until you turn it on)
ZNS.SetOpt("herbs", true)
FRAMES(3)
local n, grey, ore = DataHerbs()
-- a kind above your skill, chosen in the layers panel: shown, greyed
local above
for _, kind in ipairs(ZNS.GatherTypes("herb")) do if kind.skill > 50 and not above then above = kind end end
ZNS.SetGatherTypeShown(above, true)
FRAMES(3)
local _, greyNow = DataHerbs()
OUT(("herbalism 50: off %d; on: herbs %d, above skill %d, ore %d, offered %s; chosen above: greyed %s"):format(off, n, grey, ore,
    Offered(), tostring(greyNow > 0)))
-- only one kind
local first = ZNS.GatherTypes("herb")[1]
ZNS.SetGatherTypeShown({ kind = "herb" }, false)
ZNS.SetGatherTypeShown(first, true)
FRAMES(3)
local only = 0
for _, pin in ipairs(PINS("gather")) do if pin.data and pin.data.item ~= first.item then only = only + 1 end end
OUT(("one kind: others shown %d"):format(only))
ZNS.SetGatherTypeShown({ kind = "herb" }, nil)
STATE.skills = { herb = 50, ore = 1 }
EVENT("SKILL_LINES_CHANGED")
ZNS.SetOpt("ore", true)
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
local minimapPins, minimapNodes = 0, 0
for _, w in ipairs(ALL_WIDGETS) do
    if w.parent == ZmapMinimapPins and w.shown then
        minimapPins = minimapPins + 1
        if w.icon and type(w.icon.file) == "number" then minimapNodes = minimapNodes + 1 end   -- (an item's icon)
    end
end
OUT("minimap pins: " .. minimapPins)
-- herbs and ore are not Zmap's on the minimap, with their layers on (as here): the data only knows where they can
-- grow; the game's own tracking (Find Herbs, Find Minerals) shows the ones there now
OUT("minimap herbs and ore: " .. minimapNodes)

-- a dungeon: its own map inside, and from its entrance
ZNS.Map.Close()
STATE.instance, STATE.instanceID, STATE.instanceName = true, 36, "Las Minas de la Muerte"
OPEN()
OUT(("inside deadmines: shown %s"):format(tostring(ZNS.Dungeon.IsShown())))
local listed = ZNS.Dungeon.Shown()
OUT(("deadmines bosses: %d, %s"):format(#listed, table.concat(listed, ", ")))
local dview
for _, w in ipairs(ALL_WIDGETS) do if w.parent == ZmapFrame.viewport and w.scripts.OnMouseUp and w ~= ZmapFrame.layersPanel and w:IsShown() and w._level and w.kind == "Frame" and w.scripts.OnMouseWheel and w ~= ZmapFrame.viewport then dview = w end end
dview.scripts.OnMouseUp(dview, "RightButton")
OUT("back to the world: " .. tostring(not ZNS.Dungeon.IsShown()))
-- DungeonJournal installed (a stand-in with its public functions): the dungeon's map has a "Journal" button that opens
-- it on that dungeon's bosses; matched by the data's English name, by your language's name, or a wing's first page
local opened, toggled = nil, 0
ForeverDungeonJournal_NS = {
    DB = { ["Blackrock Depths"] = {}, ["Scarlet Monastery: Graveyard"] = {}, ["Hall of Thanes"] = {},
        ["Scarlet Monastery: Library"] = {} },
    ORDER = { "Hall of Thanes", "Scarlet Monastery: Graveyard", "Scarlet Monastery: Library", "Blackrock Depths" },
    DungeonFromInstanceName = function(name)
        local bare = name:lower():gsub("^the%s+", ""):gsub("[%s%p]", "")
        for key in pairs(ForeverDungeonJournal_NS.DB) do
            if key:lower():gsub("^the%s+", ""):gsub("[%s%p]", "") == bare then return key end
        end
    end,
    LocalizeDungeonName = function(page) return page == "Hall of Thanes" and "Salón de los Feudales" or page end,
    ToggleJournal = function() toggled = toggled + 1 end,
    OpenSearchResult = function(r) opened = r.dungeonName .. "/" .. r.kind end,
}
ZNS.Dungeon.Open(230, "Profundidades de Roca Negra")
local jb
for _, w in ipairs(ALL_WIDGETS) do if w.kind == "Button" and w.text == ZNS.L.JOURNAL and w:IsShown() then jb = w end end
if jb then jb:Click() end
OUT(("journal: button %s, opened %s, shown %d; wing %s; your language %s; none %s"):format(tostring(jb ~= nil), tostring(opened),
    toggled, tostring((ZNS.Journal.Page("Scarlet Monastery", "Monasterio Escarlata"))),
    tostring((ZNS.Journal.Page(nil, "Salón de los Feudales"))), tostring((ZNS.Journal.Page("Molten Core", "Núcleo de Magma")))))
-- Scarlet Monastery: its four wings in its map's tooltip; on the Library, the journal opens the Library
local wings = table.concat(ZNS.Dungeon.Floors(189) or {}, ", ")
ZNS.Dungeon.Open(189, "Monasterio Escarlata")
for _, w in ipairs(ALL_WIDGETS) do
    if w.kind == "Button" and w.text == "Biblioteca" and w:IsShown() then w:Click() end
end
if jb then jb:Click() end
OUT(("wings: %s; journal on the library %s"):format(wings, tostring(opened)))
ForeverDungeonJournal_NS = nil
ZNS.Dungeon.Open(230, "Profundidades de Roca Negra")
OUT("journal without DungeonJournal: button " .. tostring(jb ~= nil and jb:IsShown()))
-- Scarlet Monastery: a mark for each wing's door (measured in game), each opening the dungeon's map on its wing;
-- Stratholme: its two gates
local sm, strat = {}, 0
for _, e in ipairs(ZNS.DungeonList()) do
    if e.inst == 189 then sm[#sm + 1] = e end
    if e.inst == 329 then strat = strat + 1 end
end
local lib
for _, e in ipairs(sm) do if e.floor == 2 then lib = e end end
local lx, ly = ZNS.Geo.ToZone(1420, lib.u, lib.v)   -- (Tirisfal Glades, where they were measured)
ZNS.Dungeon.Open(189, lib.dungeon, lib.floor)
local _, _, shownFloor = ZNS.Dungeon.Shown()
OUT(("wing doors: monastery %d, library %s at %.1f %.1f, opens floor %s; stratholme gates %d"):format(#sm, lib.name,
    lx * 100, ly * 100, tostring(shownFloor), strat))
ZNS.Dungeon.Close()
-- Blackrock Depths: a boss on another floor, chosen in the list
ZNS.Dungeon.Open(230, "Profundidades de Roca Negra")
local bossesBRD = ZNS.DUNGEON_MAPS[230].bosses
local target
for i, b in ipairs(bossesBRD) do if b[2] == 2 and not target then target = i end end
ZNS.Dungeon.GoToBoss(target)
local _, placed, floor = ZNS.Dungeon.Shown()
local numbered = false
for _, text in ipairs(placed) do if text:find("^" .. target .. "%. ") then numbered = true end end
OUT(("brd: to floor %s, numbered on it %s"):format(tostring(floor), tostring(numbered)))
ZNS.Dungeon.Close()
ZNS.Map.Close()
-- the Hall of Thanes, one of Forever's new dungeons: no game has a map of it, so its picture is the game's minimap
-- of it (the part of its tiles the data crops), with its bosses beside it
STATE.instanceID, STATE.instanceName = 3065, "El Salón de los Feudales"
OPEN()
local thanes, thanesPlaced = ZNS.Dungeon.Shown()
-- a floor's tiles shown (and the frame they are on)
local function Picture(floor)
    local files, shown, on = {}, 0, nil
    for _, id in ipairs(floor[1]) do if id ~= 0 then files[id] = true end end
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and files[w.file] and w:IsVisible() then shown, on = shown + 1, w.parent end
    end
    return shown, on
end
local function Shape(frame, w, h)
    return frame ~= nil and frame:GetHeight() > 0 and math.abs(frame:GetWidth() / frame:GetHeight() - w / h) < 0.01
end
local thanesFloor = ZNS.DUNGEON_MAPS[3065].floors[1]
local crop = thanesFloor.crop
local thanesTiles, thanesArt = Picture(thanesFloor)
OUT(("hall of thanes: shown %s, bosses %d (%s), placed %d, minimap tiles %d of %d, its shape %s"):format(
    tostring(ZNS.Dungeon.IsShown()), #thanes, tostring(thanes[1]), #thanesPlaced, thanesTiles, #thanesFloor[1],
    tostring(Shape(thanesArt, crop[4] - crop[2], crop[3] - crop[1]))))
ZNS.Dungeon.Open(230, "Profundidades de Roca Negra")
local brdTiles, brdArt = Picture(ZNS.DUNGEON_MAPS[230].floors[1])
OUT(("a dungeon with its own map after it: tiles %d, its shape %s, minimap tiles left %d"):format(brdTiles,
    tostring(Shape(brdArt, 1002, 668)), (Picture(thanesFloor))))
ZNS.Dungeon.Close()
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

-- only my class and professions: a warrior sees warrior trainers only, and every profession's while they
-- have fewer than two
ZNS.SetAllFolkTypes(true)
STATE.skills = {}
EVENT("SKILL_LINES_CHANGED")
local function Classes()
    local seen, n = {}, 0
    for _, pin in ipairs(PINS("townsfolk")) do
        local look = pin.npc and ZNS.FolkLook(pin.npc)
        if look and look.class and not seen[look.class] then seen[look.class] = true; n = n + 1 end
    end
    return seen, n
end
ZNS.Map.SetView(gu * W, gv * H, 9)
FRAMES(3)
local seenMine, nMine = Classes()
local profs = CountCat("proftrainer")
ZNS.SetOpt("folkMine", false)
FRAMES(3)
local _, nAll = Classes()
ZNS.SetOpt("folkMine", true)
FRAMES(3)
OUT(("only mine: classes %d (warrior %s), all %d; profession trainers shown without professions %s"):format(nMine,
    tostring(seenMine.WARRIOR == true), nAll, tostring(profs > 0)))

-- a rare on a nameplate (one rare in every data version): warned once, marked, told to the guild; a guildmate's too
local sentBefore = #STATE.sent
local printedBefore = #STATE.printed
STATE.units.nameplate7 = { id = 99, name = "Morgaine la Taimada" }
EVENT("NAME_PLATE_UNIT_ADDED", "nameplate7")
EVENT("NAME_PLATE_UNIT_ADDED", "nameplate7")
local rareSent = 0
for i = sentBefore + 1, #STATE.sent do if STATE.sent[i].msg:sub(1, 2) == "R\t" then rareSent = rareSent + 1 end end
STATE.units.nameplate8 = { id = 999123, name = "Bicho Raro", class = "rareelite" }
EVENT("NAME_PLATE_UNIT_ADDED", "nameplate8")
EVENT("CHAT_MSG_ADDON", "Zmap", "R\t0\t1429\t0.3000\t0.4000\tGolpeador\t0", "GUILD", "Lyra-Realm")
FRAMES(3)
local marks = #PINS("rareseen")
OUT(("rares: warned %d, sent %d, marks %d, last %s"):format(#STATE.printed - printedBefore, rareSent, marks, LAST_PRINT()))

-- a rare dies (your target): known dead, kept; seen alive an hour later, how long it takes is learned; dead again,
-- its tooltip says when it is back
local function Tip(id)
    local lines = {}
    ZNS.RareTooltip({ AddLine = function(_, text) lines[#lines + 1] = text end }, id)
    return table.concat(lines, " / ")
end
STATE.units.target = { id = 99, name = "Morgaine la Taimada", dead = true }
EVENT("UNIT_HEALTH", "target")
local deadNow, first = ZNS.RareDead(99), Tip(99)
ADVANCE(3600)
STATE.units.target = { id = 99, name = "Morgaine la Taimada" }
EVENT("PLAYER_TARGET_CHANGED")
local learned = ZNS.db.rareLog[99].respawn
ADVANCE(400)
STATE.units.target = { id = 99, name = "Morgaine la Taimada", dead = true }
EVENT("UNIT_HEALTH", "target")
OUT(("rare death: dead %s, %s; learned %s; again: %s"):format(tostring(deadNow), first, tostring(learned), Tip(99)))
STATE.units.target = nil

-- quests: one done by reaching a place is offered and marks the place; one asking for something bought marks
-- its sellers
STATE.player.level = 7
STATE.completed = {}
STATE.log = {}
EVENT("PLAYER_LEVEL_UP")
ADVANCE(2)
local fargodeepOffered = false
for _, mark in ipairs(ZNS.QuestMap.Givers()) do
    for _, q in ipairs(mark.quests) do if q == 62 then fargodeepOffered = true end end
end
STATE.log, STATE.finished = { 62, 116 }, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local reach, buy = 0, 0
for _, mark in ipairs(ZNS.QuestMap.Objectives()) do
    if mark.quest == 62 and mark.reach then reach = reach + 1 end
    if mark.quest == 116 and mark.buy then buy = buy + 1 end
end
OUT(("quests to reach and buy: fargodeep offered %s, places %d, sellers %d"):format(tostring(fargodeepOffered), reach, buy))

-- what else holds a quest back, as Questie checks it: a breadcrumb (Raven Hill, 163) is not offered once you carry
-- the quest it leads to (5); a quest that needs a standing waits for it
local function Offered(id)
    for _, mark in ipairs(ZNS.QuestMap.Givers()) do
        for _, q in ipairs(mark.quests) do if q == id then return true end end
    end
    return false
end
STATE.player.level, STATE.completed, STATE.log, STATE.finished = 20, {}, {}, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local crumb = Offered(163)
STATE.log = { 5 }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local crumbCarried = Offered(163)
local repQuest, need
for id, q in pairs(ZNS.QUESTS) do
    local r = q[20]
    if r and r.minRep and not r.maxRep and #q[12] == 0 and #q[13] == 0 and q[5] == 0 and q[16] == 0 and q[3] <= 60
        and q[15] == 0 and #q[6] > 0 and ZNS.Npcs.Places(q[6][1])[1] and (q[4] == 0 or q[4] % 2 == 1) then
        repQuest, need = id, r.minRep
        break
    end
end
local standing = 0
local oldRep = C_Reputation
C_Reputation = { GetFactionDataByID = function(f) if f == need[1] then return { name = "Facción", currentStanding = standing } end end }
STATE.player.level, STATE.log = 60, {}
standing = need[2] - 1
EVENT("UPDATE_FACTION")
ADVANCE(2)
local below = Offered(repQuest)
standing = need[2]
EVENT("UPDATE_FACTION")
ADVANCE(2)
local reached = Offered(repQuest)
C_Reputation = oldRep
OUT(("quest rules: breadcrumb %s, with its quest carried %s; standing below %s, reached %s"):format(tostring(crumb),
    tostring(crumbCarried), tostring(below), tostring(reached)))
-- a herbalism quest: offered only with Herbalism, so far in it; one Questie hides on the map is never offered; none
-- is offered at every level for lack of a required level (its own level stands for it)
local herbQuest, herbNeed
for id, q in pairs(ZNS.QUESTS) do
    local r = q[20]
    if r and r.skill and r.skill[1] == 182 and not r.minRep and not r.spell and #q[12] == 0 and #q[13] == 0
        and q[5] == 0 and q[16] == 0 and q[15] == 0 and #q[6] > 0 and ZNS.Npcs.Places(q[6][1])[1] and (q[4] == 0 or q[4] % 2 == 1) then
        herbQuest, herbNeed = id, r.skill[2]
        break
    end
end
STATE.skills = nil
EVENT("SKILL_LINES_CHANGED")
ADVANCE(2)
local noHerb = Offered(herbQuest)
STATE.skills = { herb = math.max(herbNeed, 1) }
EVENT("SKILL_LINES_CHANGED")
ADVANCE(2)
local withHerb = Offered(herbQuest)
STATE.skills = nil
EVENT("SKILL_LINES_CHANGED")
local hiddenShown, hiddenCount, noLevel = false, 0, 0
for id, q in pairs(ZNS.QUESTS) do
    if q[16] >= 16 then
        hiddenCount = hiddenCount + 1
        if ZNS.QuestMap.Available(id, q, 60, 1, 2 ^ 30) then hiddenShown = true end
    end
    if q[3] == 0 and q[2] > 1 then noLevel = noLevel + 1 end
end
OUT(("quest rules: herbalism quest without it %s, with it %s; hidden on the map %d, offered %s; without a level %d")
    :format(tostring(noHerb), tostring(withHerb), hiddenCount, tostring(hiddenShown), noLevel))

-- the Alliance's Call of Water meets Classic's water spirits (NPCs 5894/5895, Silverpine in the data, where the
-- Horde still goes) at Stendel's Pond in Westfall: its objective, its turn-in and the next step's giver are there
STATE.player.level, STATE.player.class, STATE.player.classID, STATE.player.raceID = 23, "SHAMAN", 7, 3
STATE.completed = { 94494, 94495, 94497, 94499, 94500, 94501 }
STATE.log, STATE.finished = { 94502 }, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local QMap = ZNS.QuestMap
local objective = QMap.Next(94502)
STATE.completed[#STATE.completed + 1] = 94502
STATE.log, STATE.finished = { 94503 }, { [94503] = true }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local turnIn = QMap.TurnIn(94503)
STATE.completed[#STATE.completed + 1] = 94503
STATE.log, STATE.finished = {}, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local giverMap
for _, mark in ipairs(QMap.Givers()) do
    for _, q in ipairs(mark.quests) do if q == 94505 then giverMap = mark.m end end
end
local horde = ZNS.Npcs.Spawns(5894)[1]
OUT(("call of water: objective %s, turn-in %s, next giver %s; horde's still %s"):format(tostring(objective and objective.m),
    tostring(turnIn and turnIn.m), tostring(giverMap), tostring(horde and horde[1])))
STATE.player.class, STATE.player.classID, STATE.player.raceID = "WARRIOR", nil, nil
STATE.completed, STATE.log, STATE.finished = {}, {}, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)

-- a quest with two places to kill (The People's Militia: Defias Trappers, then Defias Smugglers): once the trappers
-- are done their places leave the map, and "Go" leads to the smugglers; while the game's objectives cannot be
-- matched to the data's (another count), nothing is left out
local function MilitiaMobs()
    local seen = {}
    for _, m in ipairs(ZNS.QuestMap.Objectives()) do if m.quest == 12 and m.npc then seen[m.npc] = true end end
    return tostring(seen[504] == true) .. "/" .. tostring(seen[95] == true)
end
STATE.player.level, STATE.completed, STATE.log, STATE.finished = 12, {}, { 12 }, {}
STATE.objectives = { [12] = { { type = "monster", finished = false }, { type = "monster", finished = false } } }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local before = MilitiaMobs()
STATE.objectives[12][1].finished = true
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
local after = MilitiaMobs()
local nextMark = ZNS.QuestMap.Next(12)
local need = ZNS.QuestMap.ForNpc(504)
STATE.objectives[12] = { { type = "monster", finished = true } }
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)
OUT(("objectives one by one: trappers/smugglers %s, trappers done %s, go to %s, trappers still needed %s, unmatched %s")
    :format(before, after, tostring(nextMark and nextMark.npc), tostring(need ~= nil and #need.need > 0), MilitiaMobs()))
STATE.objectives, STATE.log = nil, {}
EVENT("QUEST_LOG_UPDATE")
ADVANCE(2)

-- a quest of both factions, taken by an Alliance NPC and a Horde one: an Alliance player standing by the Horde one
-- is still sent to the Alliance's (and a Horde player to the Horde's)
local both, allyNpc, hordeNpc
for id, q in pairs(ZNS.QUESTS) do
    local a, h
    for _, npc in ipairs(q[8]) do
        local d = ZNS.NPCS[npc]
        if d and d[4] == "A" and ZNS.Npcs.Places(npc)[1] then a = npc end
        if d and d[4] == "H" and ZNS.Npcs.Places(npc)[1] then h = npc end
    end
    if a and h and (not both or id < both) then both, allyNpc, hordeNpc = id, a, h end
end
local function StandBy(npc)
    local p = ZNS.Npcs.Places(npc)[1]
    local u, v = ZNS.Geo.ToWorld(p[1], p[2], p[3])
    local inst = ZNS.Geo.Instance(p[1])
    STATE.player.inst = inst
    STATE.player.wx, STATE.player.wy = ZNS.Geo.ToYards(inst, u, v)
end
local saved = { STATE.player.inst, STATE.player.wx, STATE.player.wy, STATE.player.faction }
StandBy(hordeNpc)
local allianceGoes = ZNS.QuestMap.TurnIn(both).npc
STATE.player.faction = "Horde"
StandBy(allyNpc)
local hordeGoes = ZNS.QuestMap.TurnIn(both).npc
STATE.player.inst, STATE.player.wx, STATE.player.wy, STATE.player.faction = saved[1], saved[2], saved[3], saved[4]
OUT(("both factions: quest found %s, alliance by the horde's goes to the alliance's %s, horde by the alliance's to the horde's %s")
    :format(tostring(both ~= nil), tostring(allianceGoes == allyNpc), tostring(hordeGoes == hordeNpc)))

-- /zmap check: every feature tried, OK or FAIL each
SlashCmdList.ZMAP("check")
local checkText = ZmapDiag.edit:GetText()
local okLines, failLines = 0, {}
for line in checkText:gmatch("[^\n]+") do
    if line:find("^OK  ") then okLines = okLines + 1 elseif line:find("^FAIL") then failLines[#failLines + 1] = line:match("^FAIL ([^:]+)") end
end
OUT(("check: %s, ok %d, failed: %s"):format(checkText:match("^Zmap check: [^\n]+") or "none", okLines, table.concat(failLines, ", ")))
