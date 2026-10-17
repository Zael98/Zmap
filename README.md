# Zmap

Mapa del mundo continuo para WoW Forever (1.60.1). Sustituye al mapa del juego (tecla M): todas las zonas cosidas en un solo mapa, con zoom desde el mundo entero hasta el terreno real del minimapa.

## Qué hace

- **Mapa continuo**: mapa del mundo → continente → zonas cosidas → terreno del minimapa al acercarte → mapa propio de cada capital. Todo con las texturas del propio juego; las máscaras que cosen las zonas salen de los datos del cliente.
- **Zonas sin explorar**: mostrarlas, oscurecidas (por defecto) u ocultas.
- **Nombres y niveles de zona**, coloreados según tu nivel.
- **Pines** (Ctrl+clic o clic derecho): nombre, nota, color; compartir con el grupo, la hermandad o como enlace en el chat. `/zway x y nombre` (y `/way` si no tienes TomTom).
- **Flecha en pantalla** hacia el destino, con distancia y tiempo estimado; también activa el marcador del propio juego. Al morir, apunta a tu cadáver.
- **Vuelos**: los puntos de vuelo de tu facción (los no descubiertos en gris). Al pasar el ratón, la ruta y el tiempo desde el más cercano; con un clic eliges otro origen. Mientras vuelas, un temporizador que aprende la duración real de cada vuelo.
- **Mazmorras y bandas** con su nivel en Forever, **barcos y zepelines** con su ruta, **misiones** (clic: abre la misión en el registro).
- **Grupo** en el mapa; **hermandad**: quien use Zmap ve dónde estás (desactivable).
- **PNJ**: unos 8.400 PNJ de Forever con su posición (la base de datos de Forever de Questie, completada con Warcraft DB). Se buscan por nombre, título o servicio («tabernero»), el más cercano primero; al elegir uno, el mapa va hasta él y marca todos los sitios donde aparece (clic en la marca: la flecha te lleva). Los nombres llegan en inglés y Zmap aprende los del juego en tu idioma (al verlos y, poco a poco, preguntándoselos al juego). Los PNJ que faltan se aprenden al seleccionarlos de cerca y se comparten con la hermandad.
- **Vendedores, instructores, taberneros, banqueros, subastadores, establos y ángeles** de tu facción en el mapa (de los datos y de los que conoces en el juego), y **raros**.
- **Hierbas y minerales** que recoges: se recuerdan y se comparten con la hermandad.
- **Buscador**: zonas, subzonas, puntos de vuelo, mazmorras, PNJ, pines y hierbas; sin importar tildes.

## Controles

Rueda: zoom en el cursor · Arrastrar: moverse · Doble clic: acercar · Clic derecho: menú · Ctrl+clic: pin · Mayús+clic: enlazar el punto en el chat · Esc: cerrar.

Comandos: `/zmap` (abrir/cerrar), `/zmap opciones`, `/zmap pines`, `/zmap buscar <texto>`, `/zmap borrarnodos`, `/zmap reset` (posición de la ventana).

## Desarrollo

- `python tools/build_data.py` regenera `Data/*.lua` (salvo `Npcs.lua`) y `Media/Masks/*.tga` a partir de las tablas del cliente (exportadas por wago.tools). Hay que volver a ejecutarlo cuando Forever cambie sus mapas.
- `python tools/build_npcs.py` regenera `Data/Npcs.lua` uniendo la base de datos de Forever de Questie (de la última versión publicada en GitHub) y Warcraft DB (forever.warcraftdb.com; ~7.000 páginas). Todo queda en caché en `tools/cache`. Conviene repetirlo cuando salga una versión nueva de Questie.
- Licencia: los datos de PNJ de Questie son GPL-3.0. Para uso propio y de la hermandad no cambia nada; si algún día se publica Zmap, tendría que publicarse también bajo GPL-3.0 (o quitar esos datos).
- `python tools/install.py` copia el addon a la carpeta AddOns de Forever.
- `python tests/run.py` carga el addon en Lua 5.1 (lupa) con una imitación de la API del juego y ejecuta los escenarios de `tests/scenarios`.
- `python tools/preview.py` dibuja en PNG lo que pinta el escenario `art` (tests/out), con las texturas y máscaras reales, para revisar el cosido sin entrar al juego.
