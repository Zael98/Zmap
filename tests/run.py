"""Zmap tests: loads the addon in Lua 5.1 (lupa) with stubs of the WoW API (tests/stubs.lua) and runs each
scenario in tests/scenarios, checking what it reports with OUT(...). Scenarios marked "all" run in
English and Spanish. python tests/run.py [scenario ...]   (pip install lupa)
Exit code 1 when anything fails.

A scenario may also write OUT("ART <name>", DUMP_ART()): the art drawn for that view goes to
tests/out/<name>.txt, and tools/preview.py renders it to a PNG to look at."""
import re
import sys
from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
TESTS = Path(__file__).resolve().parent
OUT_DIR = TESTS / "out"

# scenario -> (runs in both languages?, [patterns each must match some line of its output])
CHECKS = {
    "load": (True, [r"^files ok$", r"^errors 0$", r"^opened true", r"^zone at start: 1429$",
                    r"^first open: zoom (9|1\d)\.\d, on the player true$",
                    r"^labels \d\d+$", r"^unexplored dimmed [1-9]\d*$", r"^after wheel: zoom up true, point held true$",
                    r"^after drag: moved true, following false$", r"^double click: zoom up true$",
                    r"^zoomed out and dragged away: map fills the window true, zoom 1\.00$",
                    r"^closed: saved view true$", r"^reopen on player: zone 1429$"]),
    "art": (False, [r"^world: world shown true, zones shown 0, isle shown 2$", r"^continent: zones built [1-9]\d*, all of them in view true$",
                    r"^zone: halo masks \d+ core masks \d+, every tile masked true$", r"^tiles inside rects: true$",
                    r"^close: terrain tiles [1-9]\d*, alpha 1\.00$", r"^city: stormwind alpha [0-9.]+ shown true$",
                    r"^unexplored hide: hidden [1-9]\d*$", r"^cave: inside 38, zoom \d+, tiles 12$", r"^cave zoomed out: shown false$", r"^cave floors: Mina Abisal, Minas Inferiores; lower shown 12, first hidden true$", r"^unexplored show: dimmed 0$", r"^errors 0$"]),
    "pins": (True, [r"^ctrl click: pins 1, prompt true$", r"^named: Mi herbolario$",
                    r"^navigate: target true, blizzard waypoint 1429, supertracked true$",
                    r"^arrow north: rotation -?0\.00, distance 100 (yd|m)$", r"^arrow behind: rotation 3\.14$",
                    r"^arrived: active nil, arrow hidden true, temp pin gone true$",
                    r"^share guild: W\t1429\t", r"^received: pins 2, by Lyra$",
                    r"^menu: .*(Ir hasta allí|Go there).*", r"^link in chat: \|cffffff00\|Hworldmap:1429",
                    r"^way command: pin true, navigating true$", r"^delete all: pins 0$",
                    r"^chat link: zmap true, blizzard false, pins 1, on the point true$",
                    r"^chat link, M not replaced: blizzard true, pins 1$",
                    r"^tomtom: pins \+1, arrow Questie: Lobos, valid true, exists true$", r"^tomtom removed: pins \+0, valid false, unknown map nil$",
                    r"^errors 0$"]),
    "flights": (False, [r"^nodes shown \d+ \(alliance and neutral only: true\)$",
                        r"^undiscovered icon: TaxiNode_Undiscovered$",
                        r"^route Stormwind->Ironforge: \d+:\d\d, hops 1$",
                        r"^tooltip: .*Desde .*~\d+:\d\d", r"^hover lines: [1-9]\d*$",
                        r"^origin chosen: true, tooltip from it: true$",
                        r"^timer: bar shown true, text .*Volando a .*$", r"^landed: recorded 9\d\.?\d* s, bar hidden true$",
                        r"^speed learned: true$", r"^advice: fly to 6, text Para Forjaz, vuela a .*, button true$", r"^advice goldshire: A Villadorada se llega antes por tierra desde aquí$", r"^errors 0$"]),
    "social": (False, [r"^broadcast on login: P\t1429\t", r"^no broadcast in instance: true$",
                       r"^guildmate shown: Lyra$", r"^guildmate tooltip: .*Nivel 33.*$", r"^expired: 0$",
                       r"^group shown: Thrall$", r"^query answered: true$", r"^errors 0$"]),
    "finds": (False, [r"^herb recorded: 1, sent N\therb\t", r"^same herb again: nodes 1, times 2$",
                      r"^received ore: nodes 2, by Lyra$", r"^herb pins at zoom 6: [1-9]\d*$",
                      r"^vendor met: Gregor \(Herrero\) repair, sent T\trepair\t",
                      r"^innkeeper by gossip: true$", r"^mailbox: true$", r"^received folk: Aldric$",
                      r"^folk pins: [1-9]\d*$", r"^errors 0$"]),
    "search": (False, [r"^ventorm: Ciudad de Ventormenta", r"^villadorada: Villadorada \(Bosque de Elwynn\)$",
                       r"^minas: Minas de la Muerte", r"^herb search: Flor de paz$", r"^go: glided to Goldshire true$",
                       r"^accents: true$", r"^battleground: Garganta Grito de Guerra \(Campo de batalla\), map shown true$",
                       r"^dungeon: (Las )?Minas de la Muerte, map shown true, bosses [1-9]\d*$", r"^errors 0$"]),
    "misc": (False, [r"^binding: M -> ZmapToggleButton$", r"^binding off: none$", r"^binding in combat: deferred, then M$",
                     r"^options panel: checks \d+, replace checked true$", r"^layers panel: open true, .*Maestros de vuelo.*$",
                     r"^row off: alpha 0\.45$",
                     r"^layer off: flights hidden true$", r"^corpse: arrow to corpse true$", r"^alive: arrow cleared true$",
                     r"^quests: 2 pins, turn-in true$", r"^quest click: zmap 101, blizzard nil$",
                     r"^dungeons: \d+ entrances, forever one true, level text .*16.*$",
                     r"^transports: lines [1-9]\d*, docks [1-9]\d*$", r"^levels: Riverglades 25-32$",
                     r"^welcome once: true$", r"^errors 0$"]),
    "stress": (False, [r"^widgets after one tour \d+, after five \d+, grew false$", r"^errors 0$"]),
    "npcs": (False, [r"^farley: Innkeeper Farley \| Tabernero \| Bosque de Elwynn$", r"^learned: Tabernera Farley$",
                     r"^spanish name: Tabernera Farley", r"^english still: Tabernera Farley",
                     r"^tabernero nearest: Tabernera Farley", r"^grosk searchable: Innkeeper Grosk",
                     r"^go farley: marks [1-9]\d*, view near true$", r"^navigating to: Tabernera Farley$",
                     r"^townsfolk from data: [1-9]\d*, farley tooltip: .*Tabernero.*$", r"^horde only shown: false$",
                     r"^rares in data: [1-9]\d*$", r"^asked in background: true, learned: Nombre de prueba$",
                     r"^not cached, asked again: Respuesta del servidor$",
                     r"^seen: remembered true, sent S\t999001$", r"^seen searchable: Vigía Torvo \| Explorador",
                     r"^far away not remembered: true$", r"^from guild: Guardia Kerr", r"^errors 0$"]),
    "extras": (False, [r"^givers: [1-9]\d*, dughan .*", r"^completed gone: true$", r"^above level offered: 0$",
                       r"^objectives: wolves [1-9]\d*, turn-in true, tooltip .*Wolves Across the Border.*",
                       r"^objective areas: [1-9]\d* areas, outline true, bands true; off: [1-9]\d* dots, outline 0$",
                       r"^no profession: herbs 0, ore 0, offered herbs false, ore false$",
                       r"^herbalism 50: off 0; on: herbs [1-9]\d*, above skill 0, ore 0, offered herbs true, ore false; chosen above: greyed true$",
                       r"^one kind: others shown 0$",
                       r"^with mining: ore true$",
                       r"^utilities: mailbox true, anvil true, tooltip .+", r"^guild without zmap: 2, tooltip .*Sin Zmap.*",
                       r"^apart: true$", r"^minimap pins: [1-9]\d*$", r"^inside deadmines: shown true$",
                       r"^back to the world: true$", r"^deadmines bosses: 8, 1\. Rhahk'Zor, .*Cocinitas, 8\. Edwin VanCleef$", r"^brd: to floor 2, numbered on it true$", r"^outside: dungeon map shown false$", r"^tinted: true$",
                       r"^diag: shown true, lines \d\d, quests line true$", r"^layers fold: folded true, open again true$", r"^folk types: rows 20, food true -> 0, innkeepers kept true, row alpha 0.45$", r"^only mine: classes 1 \(warrior true\), all [2-9]; profession trainers shown without professions true$", r"^food back: true$",
                       r"^all off then one: none true, only profession trainers true, all row alpha 0.45$",
                       r"^layer off then one: alone true; all again: true$", r"^rares: warned 3, sent 1, marks 3, last .*Golpeador.*Lyra.*$", r"^rare death: dead true, Muerto hace 0:00 / Aún no se sabe cuánto tarda en volver; learned 3600; again: Muerto hace 0:00 / Vuelve en unos 1:00:00$", r"^check: Zmap check: \d+ failed of \d+, ok 1\d, failed: ((zone art|quest titles in your language)(, )?)*$", r"^quests to reach and buy: fargodeep offered true, places [1-9]\d*, sellers [1-9]\d*$",
                       r"^specialties: enchanting Trade_Engraving, cooking INV_Misc_Food_15, warrior UI-Classes-Circles, weaponsmith INV_Sword_04, food INV_Drink_05, tailoring Trade_Tailoring, cook trainer INV_Misc_Food_15, enchanter Trade_Engraving$", r"^errors 0$"]),
    "questpanel": (False, [r"^list: shown true; Bosque de Elwynn \| \[\d+\] Wolves Across the Border \| - Lobo matado: 3/8 \| Guerrero \| \[\d+\] El collar de Fargodeep \| - Lista para entregar$",
                           r"^tracked true, mark true; folded: Bosque de Elwynn \| \[\d+\] Wolves Across the Border \| - Lobo matado: 3/8 \| Guerrero$",
                           r"^details of 33: \[\d+\] Wolves Across the Border \| Objetivo de la misión \| - Lobo matado: 3/8 \| Description \| Texto de la misión 33 \| Rewards \| You will receive: \| Espada vieja \| 150 cobre; map moved true$",
                           r"^go there: arrow true$", r"^share: index 2; abandon: 33 ABANDON_QUEST, asked Wolves Across the Border$",
                           r"^back: details nil$", r"^map click: details 33, blizzard nil$", r"^reopened: shown true; folded: shown false, tab true, after reopening false; tab click: shown true$", r"^not offered: still marked false; after a level up true$",
                           r"^errors 0$"]),
    "gatherroute": (False, [r"^route: true, stops [1-9]\d*, each once true, arrow Siguiente nodo \(1/\d+\)$",
                            r"^said: .*Ruta de recolección: \d+ paradas en Bosque de Elwynn, unos [\d:]+ por vuelta$",
                            r"^after the first: Siguiente nodo \(2/\d+\)$", r"^another way: route false$",
                            r"^no profession: false, .*Aquí no hay hierbas ni minerales",
                            r"^route menu: [3-9] entries, first Todo lo que puedo recoger$",
                            r"^one kind: .+, \d+ stops; bar Ruta de recolección: .+ · parada 1/\d+ · ~[\d:]+ por vuelta$",
                            r"^closed: route false, bar false$", r"^errors 0$"]),
    "minimapstyle": (False, [r"^blizzard: mask ui-hud-minimap-frame-generic-mask, back false, border true, shape ROUND \| round: mask TempPortraitAlphaMask, back true, border false, shape ROUND \| round_clean: mask TempPortraitAlphaMask, back false, border false, shape ROUND \| square: mask WHITE8X8, back true, border false, shape SQUARE \| square_dark: mask WHITE8X8, back true, border false, shape SQUARE \| square_clean: mask WHITE8X8, back false, border false, shape SQUARE$",
                             r"^square_dark: scale 1\.3, zone false, tracking false$", r"^after Blizzard's update: mask WHITE8X8$",
                             r"^next: square_clean$", r"^errors 0$"]),
    "memory": (False, [r"^logged in: (1\d)\.\d MB$", r"^search index: [0-2]\.\d MB$", r"^map closed, walking: \d{1,3} KB in 10 s$",
                       r"^map open, walking: \d{1,3} KB in 10 s$", r"^map open, panning: \d{1,3} KB in 10 s$",
                       r"^map open, zooming: (\d{1,3}|[1-3]\d{3}) KB a minute$", r"^errors 0$"]),
    "battleground": (False, [r"^alterac: shown true, overlays 8, objectives 2, group frame true on 1459, updated true$",
                             r"^alterac bosses listed: 0$", r"^alterac objectives after update: 3$",
                             r"^warsong: overlays 0, objectives 0, flags 1, group frame on 1460$",
                             r"^warsong flags after a pick up: 2$",
                             r"^warsong carriers: Grommash, Lyra$", r"^arathi timers: Establos (1:00|0:59)$",
                             r"^arathi timers later: Establos 0:[23]\d$",
                             r"^deadmines: live nil, group frame shown false, flags shown 0$", r"^errors 0$"]),
    "isle": (False, [r"^position: zone 2521, on the isle true$", r"^zone at the player: 2521$", r"^opened on the isle: true$",
                     r"^quest givers on the isle: [1-9]\d*$", r"^airships: 2, docks on the isle 2$",
                     r"^route to orgrimmar: walk,airship,.*walk$", r"^corpse on the isle: true$", r"^errors 0$"]),
    "route": (False, [r"^goldshire: walk$", r"^ironforge: walk,tram,walk, arrow Ve a Tranvía Subterráneo$",
                      r"^darnassus: .*boat.*, \d+:\d\d$", r"^step after reaching the first: 2, panel rows \d+$",
                      r"^cleared: true$", r"^no flights known: (walk,)?tram,walk$",
                      r"^home: (1437|1455)$", r"^hearthstone: hearth(,walk)?; Usa la piedra de hogar: Forjaz$",
                      r"^hearthstone on cooldown: walk,tram,walk$", r"^teleport: teleport(,walk)?; Lanza Teletransporte: Forjaz$",
                      r"^after the teleport: step 2$", r"^errors 0$"]),
    "locales": (False, [r"^languages: DE EN ES FR IT KO PT RU TW ZH$", r"^DE: missing none; format mismatch none$", r"^EN: missing none; format mismatch none$", r"^ES: missing none; format mismatch none$", r"^FR: missing none; format mismatch none$", r"^IT: missing none; format mismatch none$", r"^KO: missing none; format mismatch none$", r"^PT: missing none; format mismatch none$", r"^RU: missing none; format mismatch none$", r"^TW: missing none; format mismatch none$", r"^ZH: missing none; format mismatch none$"]),
}


def read(path):
    return Path(path).read_text(encoding="utf-8")


def addon_files():
    toc = read(ROOT / "Zmap.toc").splitlines()
    return [line.strip().replace("\\", "/") for line in toc if line.strip().endswith(".lua")]


def runtime(locale, out):
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    L.globals().LOCALE = locale
    L.globals().OUT = lambda *a: out.append(" ".join("nil" if v is None else str(v) for v in a))
    L.execute(read(TESTS / "stubs.lua"))
    ns = L.eval("{}")
    load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end f('Zmap', ns) end")
    for name in addon_files():
        load(read(ROOT / name), name, ns)
    L.globals().ZNS = ns
    L.globals().FILES = L.table_from(addon_files())
    L.globals().SOURCES = L.table_from({name: read(ROOT / name) for name in addon_files()})
    L.execute(read(TESTS / "helpers.lua"))
    return L


def run(name, locale):
    out = []
    L = runtime(locale, out)
    try:
        L.execute(read(TESTS / "scenarios" / f"{name}.lua"))
    except Exception as e:  # a Lua error: report it as the scenario's output
        out.append(f"LUA ERROR: {e}")
    errors = list(L.globals().STATE.errors.values())
    if errors:
        out.append("ADDON ERRORS: " + " || ".join(str(e) for e in errors))
    return out


def main():
    names = sys.argv[1:] or list(CHECKS)
    failed = 0
    OUT_DIR.mkdir(exist_ok=True)
    for name in names:
        both, patterns = CHECKS[name]
        for locale in (["esES", "enUS"] if both else ["esES"]):
            out = run(name, locale)
            arts = [line for line in out if line.startswith("ART ")]
            for art in arts:
                _, art_name, dump = art.split(" ", 2)   # "ART <name> <view line, then a line per texture>"
                (OUT_DIR / f"{art_name}.txt").write_text(dump, encoding="utf-8")
            lines = [line for line in out if not line.startswith("ART ")]
            missing = [p for p in patterns if not any(re.search(p, line) for line in lines)]
            bad = [line for line in lines if line.startswith(("LUA ERROR", "ADDON ERRORS"))]
            ok = not missing and not bad
            failed += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {name} ({locale})")
            if not ok:
                for line in lines:
                    print("     |", line)
                for p in missing:
                    print("     missing:", p)
    print("all passed" if not failed else f"{failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
