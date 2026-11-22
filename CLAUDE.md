# Palitos (Roblox): Guerra de Salón

Versión de Roblox de Palitos. **No es como la de TikTok:** aquí tú eres un palito, eliges bando (Azul o Rojo, una sola vez) y clase, y peleas junto a soldados de la máquina para borrar el castillo rival. Las reglas de Aron y la regla de "juego original" están en `../palitos/CLAUDE.md` y aplican aquí igual (español, sin pagos, sin publicar ni hacer commits sin permiso, nada de copiar Stick War, con Robux solo se vende cómo se ve).

## Decisiones (2026-11-12, aprobadas por Aron)
- Batallas cortas por bandos (máximo 7 min), no mundo abierto.
- Primeras 3 clases: **Rayón** (guerrero), **Tirachinas** (arquero), **Corrector** (curandero). Cada una: ataque (clic), Q y E.
- Nunca está vacío: la máquina completa cada bando hasta 8 peleadores; las personas reemplazan a los soldados.
- Después: Resaltador (mago), Tapa (tanque), guerra de la semana (marcador global Azul vs Rojo), tienda de tintas y adornos.

## Cómo se trabaja
Igual que `../la-balsa-roblox` (Rojo, Lune, luau-lsp; `tipos` es un enlace a los de La Balsa).
- `rojo build -o Palitos.rbxlx` arma el juego. `lune run tests/rules` prueba las reglas y simula batallas enteras.
- Tipos: `rojo sourcemap default.project.json -o sourcemap.json && luau-lsp analyze --definitions=tipos/globalTypes.d.luau --sourcemap=sourcemap.json src tests/studio`
- Prueba automática en Studio: `python3 tests/studio/logserver.py salida.log &`, `rojo build test.project.json -o PruebaDebug.rbxlx`, abrir con Test → Server & Clients. Los clientes juegan solos. **Nunca publicar PruebaDebug.rbxlx.**

## Estructura
- `src/shared/Rules.luau`: reglas puras (clases y habilidades, a quién le pega cada una, soldados, castillos, premios, niveles).
- `src/server/Main.server.luau`: batallas, daño, soldados, torres, premios. `World.luau`: la hoja y los castillos. `Palito.luau`: cómo se ve un palito (trazos sobre el cuerpo R15 invisible; soldados sin Humanoid). `Data.luau`: guardado (DataStore `Palitos_v1`).
- `src/client/Main.client.luau`: menú de bando y clase, marcador, botones, trazos de ataques, piernas de los soldados.

## Estado
- [x] 2026-11-12: primera versión escrita. Compila, sin errores de tipos, 37 pruebas de reglas pasan (batalla pareja solo de máquina llega a los 7 min; un bando que pega 60% más gana en 4 a 6 min).
- [x] 2026-11-12: **probado en Studio con 2 bots** (Test → Server & Clients): batalla completa, premios, reaparecer, sin errores de nuestros scripts. El palito se ve bien (trazos sobre el cuerpo invisible). La prueba usa el puerto 8766 (`logserver.py salida.log 8766`). En la prueba las barras de castillo salen bajas porque solo el servidor acelera `CFG`; en el juego real no pasa.
- [ ] Sin probar con personas: apuntar con el mouse, el impulso de Carga y Voltereta, el menú de bando y clase con clics de verdad, celular, guardado real.
- [ ] Falta: animación de ataque, sonidos, números de daño, mago y tanque, guerra de la semana, tienda, ícono y miniatura (Blender, como en La Balsa).
- Los modelos se arman con piezas por código; los modelos de Blender solo se pueden meter subiéndolos desde Studio con la cuenta de Aron.
- 2026-11-12: subido **privado** a la cuenta de Aron: https://www.roblox.com/games/138810857178227 (se actualiza con File → Publish As → Palitos → Overwrite, desde Palitos.rbxlx).
