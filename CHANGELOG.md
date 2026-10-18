# Zmap

## Unreleased

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
