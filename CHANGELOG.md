# Zmap

## 1.6.1 — Call of Water for the Alliance

- **Call of Water (Alliance shamans)**: the steps at the Forgotten Shrine now point to Stendel's Pond in Westfall. Before, the map and "Go" sent you to the Horde's spot in Silverpine Forest, because Forever reuses Classic's water spirits there. The Horde's version still points to Silverpine.

## 1.6.0 — Your quests on the NPCs

- **Your quests on the NPCs themselves**: hovering an NPC says which quest of your log it is for, with what is left of it, and which quests it gives or takes. A mark over the nameplates of the NPCs your quests need (to kill, or for what they drop), and of those who take a quest you finished. Both can be turned off in the options (Quest log). In some places the game hides who a unit is during combat; there they show nothing.
- **NPC names in your language from the start**: names now come from Blizzard's API in every language (631 NPCs so far: the API is still filling in), so the search finds them in your language before you have seen them. The others are still learned in game as before.

- Data from Forever build 1.60.1.70938 and Questie bundle v12.8.0+v1.0.16.

## 1.5.0 — A fuller quest log

- **How hard each quest is**: titles take the level's colour, as on the map (grey too low, green, yellow, orange, red), with their tags in the game's words (elite, group, dungeon…).
- **How full your log is**: "Quests 18/25" on top, orange when it is nearly full and red when it is full.
- **Search**: a box on top keeps only the quests whose name or objectives match (folded zones open for it).
- **Order**: by zone, by level, or nearest first (with how far each one is).
- **Fold or unfold every zone** at once, and a right-click on a zone tracks or untracks all its quests.
- **Hovering a quest** makes its marks and areas stand out on the map; the others fade.
- **Shift-click** a quest to link it in the chat (also in its right-click menu).
- **Who takes it**: the details say who you turn the quest in to and where; a click puts the arrow there ("Go to turn it in" in the right-click menu too).
- **Reward tooltips**: hovering a reward shows the item's tooltip, compared with what you wear.
- **Your group's quests**: with Zmap, your party or raid share their quests. The list shows how many of them have each one ([+2]), and the details show how far each one is or whether it is ready to turn in.
- **Tracking by itself** (options, off by default): track the quests you take, and stop tracking the ones ready to turn in.
- **Side and background** (options): the log on the map's right or left side (beside the layers panel), and how see-through its background is.

## 1.4.7 — Quest log size

- **Quest log size** (Options, under the icon size): makes Zmap's quest log bigger or smaller, from 80% to 200%. Its text, icons and buttons grow together, which makes it easier to read on big screens such as 4K.
- Data from Forever build 1.60.1.70888 and Questie bundle v12.6.5+v1.0.13.

## 1.4.6 — Only the tracked quests, and L opens Zmap's quest log

- **Only tracked quests** (a new layer, under Quests): turned on, the map and the minimap mark only the quests you track — their objectives, objective areas and where to hand them in — so a zone full of quests is no longer full of marks. The quest givers ("!") keep their own layer.
- **L opens Zmap's quest log**: the quest log's key opens Zmap with its quest log shown (even when you had folded it away); pressed again, it closes. An option gives L back to Blizzard's map, and the key bindings (AddOns) have a key of its own for it.

## 1.4.5 — Forever's new dungeons on the map

- **Forever's new dungeons have their map**: the Hall of Thanes, the Ruins of Lordaeron, the City of Dalaran and the Excavation Site in the Wetlands have no map in any game, so inside them the map stayed on the world. Now it opens on the dungeon, drawn from the game's own minimap of it and cut to the dungeon itself (its own areas, not the land around it), with its bosses beside it. Zul'Gurub too.
- Inside a dungeon there is still no arrow for you on these: the game tells addons nowhere where you are in an instance.

## 1.4.4 — On the Deeprun Tram

- **The Deeprun Tram has you on the map**: the tram is a world of its own with no map, so the game gives no place on any map there, and Zmap said so in the chat each time the map opened. Now it puts you on the line between its Stormwind and Ironforge doors, as far along it as you are, your arrow turned the way you face and the tram's name below. The map opens on the whole ride, and Center works there too.
- **Nothing in the chat when the map opens where the game gives no position** (in an instance...): the map's bottom bar says it. Only Center, when you ask for it, says why in the chat.

## 1.4.3 — You are no longer your own guildmate

- **Your own dot is gone from the map**: what Zmap sends your guild comes back to you, and on WoW Forever a name carries its surname where the realm used to go ("Name-Surname"), so Zmap did not know it was you and drew you as one more guildmate. It compares the whole name now: someone with your first name and another surname still shows. The guild roster leaves you out the same way.

## 1.4.2 — One icon for each thing, your corpse found, fixes from the game

- **One icon for one thing in one place**: the data lists some vendors, trainers, quest givers and rares at many points side by side (a patrol, the same spot seen again), a smithy's anvils one by one, and some mailboxes and herbs under both their old and their Forever IDs, so they were drawn again and again on top of each other. Each is drawn once for a place now (40 yards; a herb or vein of the same kind, 8). A rare's icons that would still overlap at the zoom you look at become one, and part again as you zoom in.
- **Your corpse is marked**: Zmap asked for it only the moment you released, before the game knows where it is, so it was often never marked. It now asks every second while you are dead or a ghost, and marks it with the game's own tombstone.
- **The minimap leaves herbs and ore to the game**: Zmap drew every place one can grow, most of them empty at any time. The game's own tracking (Find Herbs, Find Minerals) shows the ones there to gather now. The map still shows every place.
- **The search** shows a result's name and, under it, what it is and where, each on its own line (long ones ran into each other).
- **The options scroll** inside the game's settings window (the last ones were outside it), and what comes after the layers' grid moves down with it.
- Data from the client's build 1.60.1.70755 (Questie bundle v12.4.0).

## 1.4.1 — The quest log on the map, new buttons, a smooth arrow, quests reviewed

- **The quest log is part of the map**: a panel down its right side from the moment it opens, in the layers panel's style, folding away to a tab. Its zones' + / - fold their quests (they did nothing).
- **New buttons**: Zmap's own, dark with a thin gold edge, brighter under the mouse (the top bar, the quest log, dungeon and cave floors).
- **Go there always finds the quest**: when Zmap has no mark of it, the game's own mark of it, or who takes it in the data. A finished quest's hand-in is marked unless the game marks that very hand-in.
- **Your arrow glides**: it follows you and turns every frame (it jumped ten times a second), the view with it.
- **The quests reviewed**: those Questie itself never shows on Forever (2,394 on its list: duplicates, not in the game...) and those Forever's client no longer has are left out (356 that Zmap marked). **Repeatable quests** (lost items such as the saptas, reputation turn-ins) only with their new layer on (off).
- **Quests you cannot take are no longer marked** once you talk to their giver: what it really offers is learned (until you level up or hand in a quest). On the minimap too.
- Less garbage from the game's own lists: an NPC's tooltip is read once, Blizzard's quest marks are asked for only for the zones in view, and the cursor's zone only when it moves.

## 1.4.0 — Battlegrounds, quest log, routes and less memory

- **Battleground maps**: Alterac Valley, Warsong Gulch, Arathi Basin and Forever's new Darkspear Islands. Open the map inside one and it shows it (Forever's own pictures, Alterac Valley's drawn whole), with **your group** (drawn by the game's own frame, as Blizzard's map does: class colours, your arrow), **the objectives** (bases, towers, graveyards, mines, in their owner's colours, with their names on hover) and **the flags** where they are or who carries them. Right-click to go back to the world.
- **Capture countdowns** in Arathi Basin and Alterac Valley: an assaulted base, tower or graveyard counts down under its icon, in the colour of who assaults it (Zmap follows them with the map closed too). And **who carries each flag** in Warsong Gulch, under it.
- **The search opens any map**: a battleground's, and a dungeon's (over its entrance).
- **How to get there** also takes your **hearthstone** (or Astral Recall; waiting for it if it is on cooldown), the **teleports** you can cast (mages, druids) and the **Deeprun Tram**.
- **Quest objectives as areas**: a quest's mobs and objects drawn as the area round each group of them, in the quest's colour, with one mark in the middle (an option, on; off, a dot for each spawn as before).
- **Your quest log, on the map** (the top bar's Quests button), as Blizzard's map has it: the quests under their zone (headers fold), each with its icon, its colour on Zmap's map, a box to track it and what is left of it. A click shows its **details** (what it is about, what it asks, its rewards) with Back, Go there (the arrow), Track, Share and Abandon. **A click on a quest on the map opens it there too, not in Blizzard's map** (Ctrl+click: the arrow).
- **Herbs and ore: you choose what the map shows.** In the layers panel each unfolds into its kinds (the skill each needs); by default those you can gather. Off until you turn them on.
- **Gathering route** (right-click the map): a loop round the zone's herbs and ore, of everything you can gather or of one kind (the most there first), drawn on the map, the arrow from stop to stop, and a bar at the top with where you are in it and a button to stop it.
- **Rares**: their deaths are kept (and shared with your guild); Zmap learns how long each takes to come back and its tooltip says when it is back. Dead ones are greyed on the map.
- **TomTom's API** while TomTom is not installed: Questie's and guides' waypoints become Zmap's pins and arrow.
- **Translations** use the game's own words where they name the same thing (minimap tracking, legend...).
- **Less memory**: the layers that show what is in view no longer rebuild on every move (walking with the map open made 25 times more garbage), the townsfolk layer only builds what is in view, and the search keeps a third of the memory and only once used; zooming makes a fifteenth of the garbage it did (the herbs and townsfolk layers no longer make a table for everything in view). `/zmap check` shows memory after a collection too.
- Data from the client's build 1.60.1.70450 (names fixed in some languages, three capitals' new art).

## 1.3.0 — Zephras Isle

- **Zephras Isle**, the Windshaper Skyborne's starting zone (an instance of its own, in no map of Azeroth), is on the map in the northern sea between the continents: your position on it, its quests, NPCs, gathering and exploration, like any zone. It shows from the world's zoom on.
- **The airships to Zephras Isle** (from Dalaran in the Alterac Mountains and from Mulgore) on the map with the boats and zeppelins, and in the way to get there.
- **Map links in chat** open Zmap on that point with a pin there (instead of Blizzard's map), while Zmap takes M's place.

## 1.2.0 — Caves and mines

- **Caves, mines and ways into dungeons** (Fargodeep Mine, Skull Rock, Blackrock Mountain, Wailing Caverns, Maraudon...) on the map at their real place: zoom right in on one and its own map surfaces, the land above dimmed; zoom back out and it sinks. Open the map inside one and it shows it. A layer to turn them off.
- **Floors**: caves with more than one (Fargodeep Mine's lower mines, Blackrock Mountain's Spire and Depths, Maraudon, the Caverns of Time, Tiragarde Keep, Ban'ethil Barrow Den) get a button for each floor at the bottom of the map.
- Zoom goes twice as far in (a small cave can fill the window).

## 1.1.0 — How to get there, rare warnings and ten languages

### 🧭 How to get there
- Right-click the map > **How to get here**: the quickest way from where you are, on foot, by the flights you know and by your faction's boats and zeppelins. Drawn leg by leg, listed with times, and the arrow leads you through each leg.
- Only the flights your character knows are used: Zmap learns them each time you open a flight master's map (the game does not say which ones you have not discovered).
- **At a flight master**: where to fly for your destination (or the nearest quest to turn in), with a button to take that flight — or "quicker by land".

### ⚠️ Rares
- A rare on a nameplate, under the mouse or targeted: an on-screen warning and a sound, a mark on the map for 15 minutes, and word to your guild's Zmap users.

### ❗ Quests
- Quests done by **reaching a place** (explore, escort) mark that place — and are offered again (they were hidden by mistake).
- Items a quest asks for that are **bought**: their sellers are marked.
- Holiday quests are left out outside their holiday.

### 👥 Townsfolk
- **Only my class and professions** (on by default): class trainers of your class only, profession trainers of your professions (all of them while you have fewer than two).

### 🌍 Ten languages
- English, Spanish, German, French, Portuguese, Italian, Russian, Korean and Chinese (simplified and traditional). Zone, dungeon, boss and flight names come from the game in each language.

### ⚙️ And more
- `/zmap check`: every feature tried in game, OK or FAIL each, ready to copy.
- Uses about half the memory (herbs and ore are worked out per zone, only for your professions).

## 1.0.0 — First release

### 🗺️ One seamless world map
- Replaces the game map (M): every zone stitched into a single map, from the whole world down to the minimap's own terrain up close, and each capital's city map.
- Unexplored areas shown, dimmed or hidden; zone names and level ranges coloured against your level.
- Dungeon and raid maps, floor by floor, with every boss in order (numbered on the map where its place is known): inside an instance, or with a click on its entrance. Right-click to go back.

### 📍 Getting around
- Pins with name, note and colour; share them with your group, your guild or as a chat link. `/zway x y name` (and `/way` without TomTom).
- An on-screen arrow to the destination, with distance and time; to your corpse when you die.
- Flight masters of your faction, routes and times from the nearest one, and a flight timer that learns real flight times.
- Boats and zeppelins with their routes.
- Pins on the minimap: the destination (at its edge when far), your pins, quests and nearby herbs and ore.

### ❗ Quests, Questie-style
- Exclamation marks where the quests you can take are (your level, race, class and the quests you have done).
- For the quests in your log: their objectives (a colour per quest) and, once done, where to turn them in.

### 👥 People
- **Townsfolk** of your faction with an icon for what they sell or teach, by type: innkeepers, bankers, auctioneers, class and profession trainers, weapons, armour, food, supplies, mailboxes, anvils and forges... each type on or off in the layers panel.
- **Rares** from the data.
- Your **group** on the map, and your **guild**: exact positions for Zmap users, the zone for the rest.
- **NPC search** by name, title or service ("innkeeper"), nearest first; the map goes there and marks every place it stands. ~8,400 NPCs; names are learned in your game language.

### 🌿 Gathering
- Herbs and ore from the data (~25,000 nodes) for your Herbalism and Mining, greyed when above your skill; only shown if you have the profession.
- The nodes you gather are remembered and shared with your guild's Zmap users.

### ⚙️ And more
- A layers panel down the map's side, grouped, one click per layer; folds away to a tab.
- Search box for zones, subzones, flight masters, dungeons, NPCs, pins and herbs.
- English and Spanish. `/zmap diag` gives a report to copy when something looks wrong.
