# Zmap

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
