# Zmap

Mapa del mundo continuo para WoW Forever (1.60.1). Sustituye al mapa del juego (tecla M): todas las zonas cosidas en un solo mapa, con zoom desde el mundo entero hasta el terreno real del minimapa.

## Qué hace

- **Mapa continuo**: mapa del mundo → continente → zonas cosidas → terreno del minimapa al acercarte → mapa propio de cada capital. Todo con las texturas del propio juego; las máscaras que cosen las zonas salen de los datos del cliente.
- **Zonas sin explorar**: mostrarlas, oscurecidas (por defecto) u ocultas.
- **Nombres y niveles de zona**, coloreados según tu nivel.
- **Pines** (Ctrl+clic o clic derecho): nombre, nota, color; compartir con el grupo, la hermandad o como enlace en el chat (al pulsar un enlace de mapa del chat se abre Zmap en ese punto). `/zway x y nombre` (y `/way` si no tienes TomTom).
- **Flecha en pantalla** hacia el destino, con distancia y tiempo estimado; también activa el marcador del propio juego. Al morir, apunta a tu cadáver.
- **Vuelos**: los puntos de vuelo de tu facción (los no descubiertos en gris). Al pasar el ratón, la ruta y el tiempo desde el más cercano; con un clic eliges otro origen. Mientras vuelas, un temporizador que aprende la duración real de cada vuelo.
- **Mazmorras y bandas** con su nivel en Forever, **barcos y zepelines** con su ruta, **misiones** (clic: abre la misión en el registro).
- **Grupo** en el mapa; **hermandad**: quien use Zmap ve dónde estás (desactivable).
- **PNJ**: unos 8.400 PNJ de Forever con su posición (la base de datos de Forever de Questie, completada con Warcraft DB). Se buscan por nombre, título o servicio («tabernero»), el más cercano primero; al elegir uno, el mapa va hasta él y marca todos los sitios donde aparece (clic en la marca: la flecha te lleva). Los nombres llegan en inglés y Zmap aprende los del juego en tu idioma (al verlos y, poco a poco, preguntándoselos al juego). Los PNJ que faltan se aprenden al seleccionarlos de cerca y se comparten con la hermandad.
- **Vendedores, instructores, taberneros, banqueros, subastadores, establos y ángeles** de tu facción en el mapa, cada vendedor e instructor con el icono de lo que vende o enseña (encantamiento, cocina, armas, comida, su clase...) (de los datos y de los que conoces en el juego), y **raros**.
- **Misiones al estilo Questie**: signos de exclamación donde están las misiones que puedes coger (según tu nivel, raza, clase y las que ya hiciste; las de nivel bajo, opcionales), y para las misiones de tu registro sus objetivos (los bichos y objetos, un color por misión) y, cuando están completas, a quién entregarlas.
- **Hierbas y minerales** de los datos (unos 25.000 puntos) en gris los que aún no puedes recoger; además de los que recoges tú, que se recuerdan y se comparten con la hermandad. Solo con la profesión: sin Herboristería no salen hierbas ni su opción, y lo mismo con Minería.
- **Buzones, yunques, forjas y piedras de encuentro** en el mapa.
- **Minimapa**: el destino (en el borde si está lejos), tus pines, misiones, objetivos y hierbas o minerales cercanos.
- **Zephras Isle**: la zona de inicio de los Windshaper Skyborne (un mapa aparte en el juego) está en el mar del norte, entre los continentes, como cualquier otra zona; con las aeronaves que llevan a ella desde Dalaran y Mulgore.
- **Cuevas y minas**: las cuevas, minas y entradas de mazmorra del cliente en su sitio real; al acercarte emerge su mapa entero (sin el marco) y la superficie se oscurece. Las de varias plantas tienen un botón por planta abajo.
- **Mapas de campo de batalla**: Valle de Alterac, Garganta Grito de Guerra, Cuenca de Arathi y las Islas Lanza Negra de Forever. Dentro de uno, el mapa lo abre con tu grupo (dibujado por el propio marco del juego), los objetivos (bases, torres, cementerios, con el color de quien los tiene) y las banderas.
- **Mapas de mazmorra**: dentro de una instancia el mapa abre el de la mazmorra, por plantas y con sus jefes; también con un clic en la entrada. Botón para volver al mundo.
- **Hermandad sin Zmap**: quien no tiene Zmap aparece en su zona (un círculo hueco junto al nombre de la zona); el juego solo dice en qué zona está, no el punto exacto.
- **Igualar colores** (opcional): suaviza el cambio de color entre zonas vecinas.
- `/zmap diag`: un informe para copiar si algo falla.
- **Buscador**: zonas, subzonas, puntos de vuelo, mazmorras, PNJ, pines y hierbas; sin importar tildes.

## Controles

Rueda: zoom en el cursor · Arrastrar: moverse · Doble clic: acercar · Clic derecho: menú · Ctrl+clic: pin · Mayús+clic: enlazar el punto en el chat · Esc: cerrar.

Capas: el panel de la izquierda del mapa, agrupado (Mapa, Viajes, Misiones, Gente, Recolección, Minimapa); un clic enciende o apaga cada capa. «PNJ de ciudad» se despliega en sus tipos (taberneros, banqueros, instructores de clase y de profesión, armas, armaduras, comida, suministros, buzones, yunques...), cada uno se enciende o apaga por separado. Se pliega con la flecha y vuelve con la pestaña «Capas».

Comandos: `/zmap` (abrir/cerrar), `/zmap opciones`, `/zmap pines`, `/zmap buscar <texto>`, `/zmap borrarnodos`, `/zmap reset` (posición de la ventana), `/zmap diag`.

## Desarrollo

- `python tools/build_data.py` regenera `Data/*.lua` (salvo `Npcs.lua`) y `Media/Masks/*.tga` a partir de las tablas del cliente (exportadas por wago.tools). Hay que volver a ejecutarlo cuando Forever cambie sus mapas.
- `python tools/build_data.py` también genera `Data/DungeonMaps.lua` (las tablas de Forever no tienen mapas de mazmorra; los saca de las de Mists Classic y comprueba que las imágenes estén en Forever) y los tonos de `ns.TINTS`.
- `python tools/build_npcs.py` regenera `Data/Npcs.lua`, `Data/Objects.lua` y `Data/Quests.lua` uniendo la base de datos de Forever de Questie (de la última versión publicada en GitHub) y Warcraft DB (forever.warcraftdb.com; ~7.000 páginas). Todo queda en caché en `tools/cache`. Conviene repetirlo cuando salga una versión nueva de Questie.
- Licencia: GPL-3.0 (`LICENSE`), obligatoria porque los datos de PNJ, misiones y objetos vienen de Questie (GPL-3.0).
- `python tools/install.py` copia el addon a la carpeta AddOns de Forever.
- Publicar: GitHub Actions pasa las pruebas en cada push; al subir una etiqueta `v<versión>` (solo cuando se ordena publicar), las pasa y publica con BigWigs packager en CurseForge (secreto `CF_API_KEY`) y como versión de GitHub. Antes: subir `## Version` en el TOC y añadir su sección a `CHANGELOG.md`.
- `python tools/package.py` prepara la versión para CurseForge: `Zmap-<versión>.zip` y su changelog (de `CHANGELOG.md`) en `Escritorio/Zmap_zips`. No sube nada.
- `python tools/logo.py` dibuja `logo.png`, la imagen del proyecto.
- `python tests/run.py` carga el addon en Lua 5.1 (lupa) con una imitación de la API del juego y ejecuta los escenarios de `tests/scenarios`.
- `python tools/preview.py` dibuja en PNG lo que pinta el escenario `art` (tests/out), con las texturas y máscaras reales, para revisar el cosido sin entrar al juego.
