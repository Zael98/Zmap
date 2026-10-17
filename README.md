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
- **Hierbas y minerales** que recoges y **PNJ** con los que hablas (vendedores, instructores, taberneros, banqueros, subastadores, establos, ángeles, buzones): se recuerdan y se comparten con la hermandad.
- **Buscador**: zonas, subzonas, puntos de vuelo, mazmorras, pines, PNJ y hierbas; sin importar tildes.

## Controles

Rueda: zoom en el cursor · Arrastrar: moverse · Doble clic: acercar · Clic derecho: menú · Ctrl+clic: pin · Mayús+clic: enlazar el punto en el chat · Esc: cerrar.

Comandos: `/zmap` (abrir/cerrar), `/zmap opciones`, `/zmap pines`, `/zmap buscar <texto>`, `/zmap borrarnodos`, `/zmap reset` (posición de la ventana).

## Desarrollo

- `python tools/build_data.py` regenera `Data/*.lua` y `Media/Masks/*.tga` a partir de las tablas del cliente (exportadas por wago.tools). Hay que volver a ejecutarlo cuando Forever cambie sus mapas.
- `python tests/run.py` carga el addon en Lua 5.1 (lupa) con una imitación de la API del juego y ejecuta los escenarios de `tests/scenarios`.
- `python tools/preview.py` dibuja en PNG lo que pinta el escenario `art` (tests/out), con las texturas y máscaras reales, para revisar el cosido sin entrar al juego.
