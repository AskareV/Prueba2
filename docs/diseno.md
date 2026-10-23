# Documento de diseño

Juego 2D para celular, en horizontal, hecho con Godot 4.7. Este documento reúne
las decisiones tomadas hasta ahora. Lo marcado como **provisional** se puede
cambiar; lo marcado como **pendiente** aún no está decidido.

## 1. Idea general

- **Género:** RPG clásico en 2D con **combate por turnos**.
- **Fuera del combate:** exploración de mazmorras ("mazmorreo").
- **Referencia:** *My Pet Protector* (Undefined, 2009; Kongregate y Armor Games):
  entrenar a un personaje entre expediciones, mazmorras de distinta dificultad,
  estrés o cansancio que obliga a volver, y finales según cómo se jugó.
- **Protagonista:** el **rey de una ciudad devastada**. Reconstruye la ciudad
  (sección 7.11), mejora sus características (sección 8) y explora mazmorras y
  zonas. Expandir el reino a otros territorios todavía es una idea.
- **Tono:** realista, pero **sin gore**. Las heridas se muestran con colores,
  íconos y textos sobrios.

## 2. Pantalla de combate

- Pantalla horizontal.
- El **personaje del jugador** va siempre a la **izquierda** y el **enemigo**
  siempre a la **derecha**.

## 3. Lateralidad: diestros y zurdos

- Cada personaje es **diestro** o **zurdo**, y su sprite lo muestra: lleva el arma
  en su mano dominante.
- El **jugador elige** si su personaje es diestro o zurdo.
- "Derecho" e "izquierdo" son siempre **del personaje**, no de la pantalla.
- Herir la mano o el brazo dominante del rival lo debilita más y puede desarmarlo.
- **Pendiente:** si existen personajes ambidiestros.

## 4. Punto A: partes del cuerpo

El cuerpo tiene **21 partes** agrupadas en **6 zonas**.

| Zona | Partes |
|---|---|
| 1. Cabeza | cráneo, ojo izquierdo, ojo derecho, cuello |
| 2. Torso | tórax izquierdo, tórax derecho, abdomen |
| 3. Brazo derecho | hombro y trapecio, brazo, antebrazo, mano |
| 4. Brazo izquierdo | hombro y trapecio, brazo, antebrazo, mano |
| 5. Pierna derecha | muslo, espinilla, pie |
| 6. Pierna izquierda | muslo, espinilla, pie |

Nombres acordados: **cráneo** (la parte) para no confundirlo con la zona Cabeza, y
**espinilla** (la parte del cuerpo); "espinillera" queda reservado para la armadura.

**Cómo se ataca:**
1. El jugador toca **Atacar**.
2. Elige una de las **6 zonas**.
3. Se muestran las partes de esa zona y elige **una parte**.

## 5. Punto B: heridas

### B.1 Sangrado

- Puede ser **externo** o **interno**, según la herida.
- Cada personaje tiene un **contador de sangre**. Un adulto tiene unos 5 litros.
- Cada herida tiene su propio nivel de sangrado; en cada turno se descuenta la
  suma de todas.

| | Externo | Interno |
|---|---|---|
| Causa | Cortes y perforaciones en la piel | Golpes en cabeza, tórax o abdomen; fractura de muslo |
| ¿Se ve? | Sí | No; solo por síntomas (palidez, debilidad) |
| Cómo se detiene | Leve: solo con el tiempo. Moderado: vendaje. Grave: torniquete (solo brazos y piernas) | Medicina, curandero o la enfermería de la ciudad |

Estados según la sangre perdida (**provisional**, inspirado en la clasificación
médica de hemorragias):

| Sangre perdida | Estado | Efecto |
|---|---|---|
| 0–15% | Normal | Ninguno |
| 15–30% | Agitado | Un poco menos de precisión |
| 30–40% | Débil y confuso | Menos fuerza; puede perder turnos |
| Más de 40% | Shock | Puede desmayarse; si sigue sangrando, muere |

- Los enemigos usan el mismo sistema. Su sangrado externo se ve; el interno, no.
- No todas las criaturas sangran (por ejemplo, esqueletos o gólems).
- **Pendiente:** cómo se integra con la **vida** (el héroe tiene 100). No debe ser
  un simple "−1 de vida por turno".
- **Pendiente:** si la sangre perdida se recupera sola al terminar el combate.

### B.2 Órganos y funciones de supervivencia

Funciones: **Conciencia**, **Visión**, **Respiración**, **Movimiento de piernas** y
**Movimiento de brazos** (este último se mide por separado en cada brazo; el
dominante es el que ataca). La circulación ya la cubre el sangrado (B.1).

| Parte | Qué hay dentro | Qué afecta |
|---|---|---|
| Cráneo | cerebro | Conciencia |
| Ojos | ojo | Visión: con uno, menos precisión; sin los dos, **ciego** (acierta un tercio) |
| Cuello | tráquea, arterias carótidas, columna | Respiración; movimiento de brazos y piernas (columna); sangrado grave |
| Tórax izquierdo | corazón, pulmón izquierdo, costillas | Respiración; sangrado |
| Tórax derecho | pulmón derecho, costillas | Respiración |
| Abdomen | hígado, bazo, estómago, intestinos | Sangrado interno; infección (riesgo alto) |
| Hombro y trapecio | clavícula, articulación | Movimiento de ese brazo |
| Brazo | húmero, arteria braquial | Movimiento de ese brazo; sangrado |
| Antebrazo | radio, cúbito, tendones | Movimiento de ese brazo (agarre) |
| Mano | huesos y tendones | Movimiento de ese brazo (sostener el arma) |
| Muslo | fémur, arteria femoral | Movimiento de piernas; sangrado grave |
| Espinilla | tibia, peroné | Movimiento de piernas |
| Pie | huesos del pie | Movimiento de piernas (equilibrio) |

Descartados: sistema digestivo, habla y audición.

### B.3 Dolor

- Contador global, como la sangre.
- Cada herida suma dolor; una fractura duele mucho aunque casi no sangre.
- Mucho dolor empeora todas las acciones y puede causar un desmayo.
- Se calma con medicina; cada personaje aguanta más o menos dolor.

### B.4 Infecciones

- **Causas:** heridas abiertas (cortes y perforaciones; los golpes contundentes no
  abren la piel), mordeduras de ciertas criaturas, heridas en el abdomen y lugares
  sucios como mazmorras o cloacas.
- **Avanzan en días**, no en turnos: se notan fuera del combate.

| Etapa | Qué pasa | Efecto (provisional) |
|---|---|---|
| Riesgo | Herida abierta sin tratar | Nada aún; vendarla limpia baja el riesgo |
| Infección leve | La herida empeora | Más dolor y curación más lenta |
| Infección grave | Fiebre | Menos conciencia y aguante |
| Infección generalizada | Muy grave | Puede ser mortal sin tratamiento |

- **Tratamiento:** limpiar y vendar pronto; hierbas o medicinas para la leve; la
  enfermería de la ciudad para la grave.

## 6. Sistema de batalla (provisional)

Reglas **provisionales** para probar el sistema de cuerpo; se usan igual en la
demo de combate y en las mazmorras y zonas del reino. Se ajustarán cuando
definamos armas y daño.

- **Vida:** el rey tiene **100** (más con Vitalidad). Rivales de la demo:
  Bandido 80, Orco 105 y Lancero 95.
- **Tipos de arma:**

| Tipo | Arma | Fuerza del golpe | Más daño en | Menos daño en | Otros efectos |
|---|---|---|---|---|---|
| Cortante | Espada | 14–17 | brazo, antebrazo, mano, muslo y espinilla (×1,15), cuello (×1,15), pie (×1,1) | cráneo (×0,9) | |
| Contundente | Maza | 15–19 | cráneo (×1,15), tórax y hombro (×1,1) | cuello (×0,9), ojo (×0,8) | aturde y desarma con más facilidad; puede fracturar |
| Punzante | Lanza | 12–16 | ojo (×1,25), cuello, tórax y abdomen (×1,2) | cráneo, mano y pie (×0,85) | más precisa con partes pequeñas |
| Arcano | Bastón (solo en el reino) | 11–14 | | | daño mágico; gasta maná (ver 8.4) |

  Sin arma se pelea con los **puños** (4–5, contundente) y, sin brazos útiles, a
  **patadas** (9–11, contundente).
- **Acciones:** Atacar (zona → parte), Defender (se defiende mejor y recibe la
  mitad de daño), Magia (ver 8.4), **Objeto** (en el reino: tomar una poción,
  gasta el turno), cambiar o recoger el arma, y Huir.
- **Orden de turnos por velocidad** (como la barra de *Champions of Chaos*):
  cada luchador avanza según su rapidez y actúa el que llega primero. Con la
  misma rapidez se alternan; el bastante más rápido actúa **dos veces seguidas**
  (nunca más de 2). Arriba, al centro, se ven los próximos 6 turnos. Las piernas
  heridas frenan (hasta un 40% menos con las dos inutilizadas). Los rivales de
  la demo tienen la rapidez del rey: sanos se alternan, pero las piernas heridas,
  Ralentizar y los empujones cambian el orden.
- **Al apuntar:** cada botón muestra la probabilidad de acierto y, en las partes,
  el daño posible. En brazos y piernas también muestra cuántos golpes faltan para
  inutilizarlos. Al elegir una zona, una **lupa** la muestra ampliada para tocar
  partes pequeñas como ojos, manos o pies.

### 6.1 Acierto y defensa: combate táctico

La idea: los brazos protegen el cuerpo. Primero se debilita la defensa del rival
y después se va a la cabeza o el torso.

| Zona | Cómo se defiende | Acierto con espada, rival sano |
|---|---|---|
| Brazos | Van delante para bloquear: no esquivan | 64% (mano) a 85% |
| Piernas | Esquivan (igual que antes) | 42% (pie) a 60% (muslo) |
| Torso | Esquiva y lo **cubren** los brazos y las piernas | 46–48% |
| Cabeza | Igual que el torso; además es pequeña | 16% (ojos) a 33% (cráneo) |

- **Cobertura:** cada brazo útil cubre la cabeza y el torso (10%) y cada pierna
  útil también (3%). Un brazo o una pierna **inutilizado** deja de cubrir, así
  que el acierto en cabeza y torso **sube**. Ejemplo: inutilizar el antebrazo del
  arma del orco sube el acierto en su tórax de 48% a 57%.
- Las piernas además esquivan: si están heridas, el torso, la cabeza y las
  piernas son más fáciles de acertar (los brazos no esquivan) y cuesta huir.
- En guardia (Defender), toda zona es más difícil de alcanzar.

### 6.2 Daño: combates más largos

- Cada arma tiene una **fuerza de golpe** con un rango estrecho (espada 14–17,
  maza 15–19, lanza 12–16), para que el daño dependa poco de la suerte.
- Cada parte convierte esa fuerza, por separado, en:
  - **vida perdida:** poca en brazos y piernas, más en torso y cabeza;
  - **desgaste de la parte:** brazos y piernas se inutilizan en 3 a 7 golpes,
    según el arma (la lanza tarda más). El botón muestra cuántos faltan, por
    ejemplo "Inutilizar: 4–5 golpes", contando la guardia, las lesiones de
    cuello y las fracturas (también la que puede causar una maza por el
    camino).
- Así atacar los brazos tiene sentido aunque quiten poca vida: abren la defensa y
  debilitan al rival.
- Los combates duran unos **23 a 29 turnos** de media, según cómo se ataque
  (antes de estos cambios, unos 11).

### 6.3 Efectos provisionales de las funciones (B.2)

- Visión baja: menos precisión.
- Movimiento de piernas bajo: esquiva menos y le cuesta huir.
- Movimiento del brazo del arma bajo: pega más débil (con el brazo inutilizado, un
  25% menos).
- Golpe en la mano del arma (o, con menos probabilidad, en ese antebrazo):
  puede soltarla. Si el brazo del arma ya no puede sostenerla (también por una
  lesión en el cuello), la suelta siempre. Si la mano dominante queda
  inutilizada, recoge el arma con la otra mano ("mano torpe": menos precisión y
  daño).
- Sin arma se pelea con los puños, que aturden y desarman mucho menos. Sin
  brazos útiles, a **patadas** (dependen de las piernas).
- Golpe en el cráneo: puede aturdir (pierde un turno). Si la conciencia baja
  demasiado, se desmaya y pierde el combate.
- **Ceguera:** con los dos ojos inutilizados se acierta un tercio de lo normal.
- **Fractura:** un golpe contundente en una parte con hueso puede romperla. La
  parte rota rinde un **30% menos**: un brazo pega más flojo y se inutiliza
  antes; una pierna esquiva, huye y avanza menos; el cráneo roto acerca el
  desmayo; el cuello o el tórax rotos bajan la respiración.
- **Respiración baja** (cuello o tórax heridos): más lento en la barra de turnos,
  hasta un 30% menos.
- Las heridas se registran por tipo (corte, contusión, perforación, fractura) para
  conectarlas después con el sangrado, el dolor y las infecciones.

### 6.4 Rivales

Cada rival sigue un plan según su personalidad y a veces improvisa (25%):

- **Bandido (astuto):** va por la mano de tu arma para desarmarte.
- **Orco (bruto):** quiere tu cráneo. Si su acierto ahí es menor de 40%,
  primero ataca tu brazo del arma para abrir tu guardia.
- **Lancero (preciso):** igual, pero quiere tu cuello.

Con la mitad de su vida o menos, cualquier rival se pone en guardia 1 de cada 4
turnos (así sirve romper la guardia). Los brutos **empujan**: con cada golpe
pueden hacerte retroceder un tercio de turno (orco y matón 10%, orco guerrero
15%, verdugo 20%; Firmeza y Resistencia lo bajan). Los que saben magia (ver
8.4) la usan.

### 6.5 Equilibrio (simulado)

Victorias del rey (sin características) en 600 combates simulados por casilla
y arma, promedio de las tres armas, según cómo elige a qué atacar. Medido de
nuevo con las reglas actuales (los rivales se defienden con la mitad de vida y
el orco empuja):

| Cómo ataca el rey | Bandido | Lancero | Orco |
|---|---|---|---|
| Inutiliza el brazo del arma y luego va al cuerpo | 96% | 89% | 72% |
| Inutiliza los dos brazos y luego va al cuerpo | 92% | 76% | 66% |
| La parte del torso que más daña | 83% | 62% | 45% |
| Como la IA de los rivales | 78% | 54% | 35% |
| Primero las piernas | 66% | 43% | 27% |
| Siempre al abdomen | 60% | 29% | 13% |
| Siempre al cuello | 59% | 41% | 28% |
| Siempre al cráneo | 38% | 24% | 21% |
| Partes al azar | 20% | 6% | 2% |

- Inutilizar primero el brazo del arma rinde mucho más que ir directo al
  abdomen, y contra cada rival atacar siempre la misma parte rinde menos que
  abrir la guardia.
- Con la barra de turnos, empezar por las piernas rinde mucho más que antes
  (era 33%, 12% y 7%): las piernas heridas frenan al rival y el rey actúa dos
  veces seguidas más a menudo.
- Dificultad de los rivales: bandido fácil, lancero medio, orco difícil.

## 7. Reino (versión preliminar)

Todo lo de esta sección es **provisional** y usa dibujos y números de relleno.

Al abrir el juego aparece el **menú principal**: *Continuar (semana N)* si hay
una partida, *Nueva partida* (pregunta si el rey es diestro o zurdo) y *Demo de
combate* (la demo anterior). La pantalla del reino tiene pestañas arriba:

| Pestaña | Contenido |
|---|---|
| **Rey** | Nivel, experiencia y las 7 características del rey (ver sección 8); los puntos se reparten con +, Confirmar y Deshacer. |
| **Inventario** | Equipo puesto, mochila con el botín y las pociones, equipar, tomar una poción y vender. |
| **Ciudad** | Seis edificios fijos que se reconstruyen y mejoran, y el peligro de la ciudad (ver 7.11). En el castillo se descansa. |
| **Aventura** | Mapa con 4 mazmorras y 3 zonas. |
| **Trabajo** | Trabajos dignos de un rey. |
| **Salir** | Vuelve al menú principal (la partida sigue en *Continuar*). |

### 7.1 Semanas y estrés

- Cada semana se hace **una** actividad: una mazmorra, una salida de siete días
  a una zona o una semana de trabajo. Al terminarla, pasa la semana.
- Al pasar la semana **las mazmorras se reinician**: cambia el plano, vuelven
  los enemigos y los cofres. El plano depende de la mazmorra, de la semana y de
  la partida: dentro de la misma semana siempre es el mismo, y cada partida
  tiene sus propias mazmorras.
- **El juego no tiene fin por ahora:** las semanas siguen sin límite.
- Estrés de 0 a 100. Con **70** o más el rey vuelve a casa y no puede salir de
  aventura; con **60** o más no puede trabajar.
- **Provisional:** en el **castillo** de la Ciudad se puede *Descansar una
  semana*: −40 de estrés y cura las heridas (ver 7.12).
- Al pasar la semana el rey recupera todo su maná, y la **ciudad vive su semana
  sola** (ver 7.11).

### 7.2 Mapa de aventura

Banderín **oscuro** = mazmorra; banderín **rojo** = zona de siete días.

| Lugar | Tipo | Dificultad | Enemigos | Estrés por paso |
|---|---|---|---|---|
| Madriguera goblin | Mazmorra | Fácil | Goblins, goblins lanceros, chamanes goblin | 1 |
| Guarida de bandidos | Mazmorra | Fácil / medio | Ladrones, matones, bandidos | 1,2 |
| Fortaleza orca | Mazmorra | Medio | Orcos, orcos guerreros, cazadores y chamanes | 1,4 |
| Ciudadela maldita | Mazmorra | Difícil | Caballeros negros, cultistas, verdugos | 1,6 |
| Bosque sombrío | Zona | Fácil | Goblins, goblins lanceros, chamanes goblin, ladrones | 5 por día |
| Ruinas del castillo | Zona | Fácil / medio | Ladrones, matones, bandidos, chamanes goblin | 5 por día |
| Paso de la montaña | Zona | Medio | Orcos cazadores, guerreros y chamanes; matones | 5 por día |

### 7.3 Mazmorras

Como en *My Pet Protector*, adaptado al celular:

- Cuadrícula de 15 × 9. Se mueve con la **cruceta** o **tocando una casilla
  vecina** (en computadora, también con las flechas del teclado).
- Cada paso suma estrés, **descubre las cuatro casillas vecinas** y cura un
  poco al rey (ver 7.12). La que sigue negra después de descubrirla es un
  **muro**. Arriba se ven el estrés y la vida; abajo a la derecha, *Tomar
  poción*.
- **Espadas cruzadas** = enemigo: empieza un combate. **Cofre** = oro y un
  objeto. **H** = salida: al volver a pisarla se sale de la mazmorra.
- Ganar un combate: +3 de estrés. Perder: +50 y el rey vuelve al castillo.
  Huir: vuelve a la casilla anterior y el enemigo sigue ahí.
- Con 70 de estrés el rey vuelve a casa en ese mismo paso, aunque vaya hacia
  un enemigo (no empieza la pelea).
- La primera vez se muestra una ayuda con la leyenda (botón **?**).
- Cada mazmorra tiene 5 o 6 enemigos y 3 o 4 cofres, nunca a menos de 3 pasos
  de la H. Los cofres prefieren los callejones sin salida.

### 7.4 Zonas de siete días

Casillas *Día 1* a *Día 7*. Cada toque revela el día siguiente: +5 de estrés
(Cardio lo baja), la cura de 4 pasos de mazmorra (ver 7.12) y un suceso al azar.
Si caminar ese día lleva el estrés a 70, ese día no hay suceso (ni combate) y el
rey vuelve a casa.

| Suceso | Probabilidad | Efecto |
|---|---|---|
| Combate | 30% | Un enemigo de la zona |
| Nada | 25% | Día tranquilo |
| Oro | 20% | 5 a 15 de oro × nivel de la zona |
| Objeto | 10% | Un objeto de botín (a veces una poción) |
| Descanso | 10% | −10 de estrés |
| Trampa | 5% | +10 de estrés |

*Volver a casa* termina la salida (y la semana) en cualquier momento; el botón
"atrás" del celular no la termina mientras sigue en curso, para no perder la
semana sin querer. Perder un combate o llegar a 70 de estrés también la termina.

### 7.5 Botín y calidades

- Enemigo vencido: oro y **40%** de soltar un objeto (Buen ojo lo sube). Cofre:
  siempre un objeto y 5 a 15 de oro × nivel. El objeto es siempre del nivel del
  lugar donde se encontró (de ahí salen su calidad y su material), y el oro de un
  enemigo se ajusta a ese nivel (un matón, de nivel 2, da la mitad más en un
  lugar de nivel 3).
- Un 25% del botín es una **poción de curación** (ver 7.12). El resto: 35%
  **arma** (espada, maza, lanza o bastón) y 65% **armadura** (casco, peto,
  brazales o grebas).
- El material depende del nivel del lugar: bronce, hierro, acero, obsidiana.
  Cada nivel hace el arma un 25% más fuerte y la armadura más resistente.

Probabilidad de cada calidad según la dificultad del lugar:

| Calidad | Fácil | Fácil / medio | Medio | Difícil | Daño del arma | Armadura | Precisión |
|---|---|---|---|---|---|---|---|
| Normal | 75% | 65% | 55% | 40% | ×1 | ×1 | — |
| Raro | 20% | 26% | 30% | 35% | ×1,15 | ×1,3 | +2% |
| Épico | 4,5% | 8% | 12% | 19% | ×1,35 | ×1,7 | +4% |
| Legendario | 0,5% | 1% | 3% | 6% | ×1,6 | ×2,2 | +6% |

### 7.6 Armadura y resistencia mágica (como en League of Legends)

- Daño recibido = daño × **100 / (100 + armadura)**. 50 de armadura quita 33%,
  100 quita 50%, 200 quita 67%. Cada punto rinde lo mismo y nunca se llega a
  100% de reducción.
- La **armadura** frena el daño físico (espada, maza, lanza, puños, patadas).
  La **resistencia mágica** frena el daño mágico (bastón).
- Se aplica **por zona del cuerpo**: casco → cabeza; peto → torso; brazales →
  los dos brazos; grebas → las dos piernas.
- Las piezas **de metal** (75%) dan mucha armadura y poca resistencia mágica;
  las piezas **con runas** (25%), al revés.
- Los enemigos también llevan armadura: los goblins casi nada, el caballero
  negro mucha, el cultista mucha resistencia mágica.
- En las mazmorras y zonas el rey pelea con el arma que tiene equipada (se
  cambia en el Inventario, no durante el combate).

### 7.7 Vender

En el Inventario se toca un objeto de la mochila y luego *Vender por N de oro*;
hay que tocar otra vez para confirmar. Lo equipado no se vende (primero se
quita o se cambia).

| Calidad | Fácil | Fácil / medio | Medio | Difícil |
|---|---|---|---|---|
| Normal | 8 | 12 | 16 | 20 |
| Raro | 30 | 45 | 60 | 75 |
| Épico | 120 | 180 | 240 | 300 |
| Legendario | 500 | 750 | 1000 | 1250 |

### 7.8 Trabajos del rey

Ocupan la semana entera. Cada día sale bien o mal: probabilidad 55% + dominio
÷ 250 (máximo 95%). Solo se cobran los días buenos; cada día trabajado suma 2
de dominio (hasta 100). Si los siete salen bien, se cobra el triple del pago
diario de más.

| Trabajo | Oro por día | Estrés de la semana |
|---|---|---|
| Audiencias reales | 10 | 14 |
| Patrullar las murallas | 12 | 21 |
| Entrenar a la guardia | 9 | 28 |
| Cobrar impuestos | 16 | 24,5 |
| Presidir el tribunal | 20 | 35 |
| Negociar con mercaderes | 26 | 42 |

### 7.9 Equilibrio de los enemigos (simulado)

Se simuló de nuevo con la barra de turnos por velocidad y las características
del rey: ver la tabla de la sección 8.5 (la fila "Sin puntos" es el rey sin
características).

### 7.10 Partida guardada

- La partida **se guarda sola**: cada vez que cambia algo (lo mira cada segundo)
  y al cerrar la aplicación o pasarla a segundo plano. Al abrir el juego se carga.
- *Continuar* sigue donde quedó: en el reino, en la mazmorra o en la zona. Si se
  cerró en medio de un combate, ese combate **empieza de nuevo**.
- En el menú, el botón "atrás" pregunta *¿Salir del juego?* antes de cerrarlo.
- *Nueva partida* reemplaza la guardada (lo avisa).

### 7.11 Ciudad

La ciudad es **autosuficiente**: produce su comida, cobra impuestos y sus
soldados la defienden sin el rey. El rey solo invierte oro. Si está mal
protegida, el **peligro** sube y pueden atacarla; las batallas de la ciudad se
resuelven solas y se pueden perder. Todos los números son **provisionales**.

**Edificios fijos (seis).** Se tocan para abrir su ventana. La partida empieza
con el castillo en pie y los demás **en ruinas** (nivel 0): hay que
reconstruirlos con oro y después se mejoran hasta nivel 3. Ningún edificio puede
tener más nivel que el castillo.

| Edificio | Oro para nivel 1 / 2 / 3 | Qué hace (nivel 1 / 2 / 3) |
|---|---|---|
| Castillo | (empieza en 1) / 400 / 1000 | Murallas: +4 / +8 / +12 de defensa. Aquí descansa el rey (y se cura) y se ve el estado de la ciudad. |
| Herrería | 150 / 400 / 900 | Sube una calidad tu arma o armadura puesta, hasta rara / épica / legendaria (cuesta 3 veces el precio de venta base del objeto con la calidad nueva). Los soldados defienden ×1,25 / ×1,5 / ×1,75. |
| Granja | 100 / 300 / 700 | 10 / 18 / 28 de comida por semana. |
| Mercado | 120 / 350 / 800 | 15 / 30 / 50 de oro de impuestos por semana; vende 3 / 4 / 5 objetos de nivel 1 / 2 / 3 que cambian cada semana, y 2 / 3 / 4 pociones (se compran de a una). Precio: 4 veces el de venta base; Negociación lo baja hasta un 40% menos, y nunca por debajo de lo que te pagarían al venderlo. |
| Barracas | 150 / 400 / 900 | Caben 5 / 10 / 15 soldados (40 de oro cada uno). Cada soldado come 2 de comida por semana. |
| Enfermería | 120 / 300 / 700 | Al descansar en el castillo recuperas el 60% / 80% / 100% de tu vida máxima y 60 / 80 / 100 puntos de cada parte herida (sin ella, 40% y 40). |

**La semana de la ciudad** (al pasar la semana):
1. La granja produce y los soldados comen. Sin comida suficiente, se van
   soldados (uno por cada 2 de comida que falte). Empieza con 20 de comida.
2. El mercado cobra impuestos.
3. **Peligro** (0 a 100%): sube 10 por semana y cada punto de **defensa** lo
   baja 0,8. Defensa = soldados × equipo de la herrería × moral (Liderazgo,
   +3% por punto) + murallas del castillo.
4. Con ese peligro como probabilidad, hay un **ataque**. Su fuerza es
   8 + 0,8 × semana (con azar de ×0,8 a ×1,25) contra la defensa (con azar de
   ×0,85 a ×1,15):
   - **Se gana:** el peligro baja 30 y muere hasta el 15% de los soldados
     (redondeado hacia abajo: con menos de 7 soldados no muere ninguno).
   - **Se pierde:** se llevan el 20% del oro y el 50% de la comida, muere la
     mitad de los soldados (redondeado hacia arriba), un edificio (no el
     castillo) baja un nivel y el peligro baja 20. Si dañan las barracas, se
     van los soldados que ya no caben.
5. Si atacaron o se fueron soldados, al volver al reino aparece una ventana
   con las noticias. El castillo muestra el informe de la última semana.

Simulado en 40 semanas (200 partidas por caso, medido de nuevo con las reglas
actuales): sin invertir en la ciudad hay unos 13 ataques y se pierden todos; con
barracas, granja y 5 soldados, unos 6 o 7; con todo mejorado y unos 250 de oro
por semana, menos de 1.

### 7.12 Salud del rey: las heridas duran

Todos los números son **provisionales**.

- La vida, el maná, las partes heridas y las fracturas **siguen de un combate al
  siguiente**. Después de un combate no se recupera nada.
- **Al caminar** el rey se va curando, todas las partes a la vez: cada paso de
  la mazmorra cura el 1% de la vida máxima, 1 punto de cada parte herida y 0,5 de
  maná. Un día de marcha en una zona cura como 4 pasos. Los decimales de vida se
  juntan de un paso al siguiente.
- **Descansar una semana en el castillo** (sin trabajar) recupera el 40% de la
  vida máxima y 40 puntos de cada parte herida; con la enfermería, más (60% /
  80% / 100%). Trabajar no cura. El botón de descanso dice cuánto vas a curar.
- **Recuperación** multiplica toda la curación (+5% por punto).
- Una parte que se cura del todo deja de estar fracturada.
- El maná se llena al pasar la semana.
- Si pierde un combate, lo traen de vuelta con 1 de vida y despierto (aunque se
  haya desmayado).
- Si la mano del arma quedó inútil, el combate siguiente empieza con el arma en
  la otra mano (mano torpe) o, si ninguna sirve, sin arma.
- **Poción de curación:** recupera 40 de vida y 25 puntos de cada parte herida.
  Sale en cofres, enemigos y zonas (25% del botín) y en el mercado (venta: 10 de
  oro). Se apilan en el inventario. Se toman en el combate (botón **Objeto**,
  gasta el turno), entre combates en la mazmorra o la zona (*Tomar poción*) y en
  el Inventario. Las que se toman en un combate se gastan al terminarlo: si la
  aplicación se cierra a la mitad, el combate empieza de nuevo y no se pierden.
- La vida se ve en la pestaña Rey, en la ventana de cada lugar del mapa y arriba
  en la mazmorra y la zona.

## 8. Características del rey

Siete características con tres partes cada una. **Todo empieza en 3**, y en 3
no cambia nada: los efectos dependen de los puntos por encima de 3. Todos los
números son **provisionales**.

### 8.1 Cómo se suben

- **Partida nueva:** las 7 principales en 3 y **15 puntos** para repartir entre
  ellas.
- **Al subir de nivel:** **1 punto** más para una principal.
- **Cada punto en una principal** sube **+1 sus tres partes** y da **3 puntos
  para repartir solo entre esas tres** (no sirven para las partes de otra
  principal). Ej.: 3 puntos en Fuerza dan 9 puntos para Fuerza máxima, Fuerza
  explosiva y Fuerza de agarre. Se pueden guardar para después. Los 15 puntos
  del principio también dan 3 cada uno.
- **Tope:** ninguna parte mejora más allá de **+20** sobre la base (23): los
  puntos de más no hacen nada.
- En la pestaña **Rey** se toca **+**, y los puntos quedan en verde hasta tocar
  **Confirmar** (o **Deshacer**). La pestaña muestra "Rey (+)" si hay puntos.
- **Experiencia:** 10 × nivel del lugar por vencer a un enemigo y 4 × nivel por
  abrir un cofre. Subir del nivel N al siguiente pide 50 × N. Sin nivel máximo.
- **Amuleto:** cada punto suyo por encima de 3 suma **0,075 a las otras 20 partes**
  (como mucho 1,5, con el tope).

### 8.2 Qué hace cada parte (por cada punto sobre 3)

| Característica | Parte | Efecto |
|---|---|---|
| Fuerza | Fuerza máxima | +2% de daño con armas físicas |
| | Fuerza explosiva | +5% de aturdir, fractura más fácil, rompe la guardia del rival (+2% del daño que recibe al defenderse) y 2% de empujarlo un tercio de turno hacia atrás (máx. 25%) |
| | Fuerza de agarre | Al defenderte recibes un 2% menos de daño (mínimo 25%); −5% de que te desarmen y +5% de desarmar; la mano torpe castiga un 6% menos |
| Destreza | Precisión | +0,75% de acierto en todas las partes |
| | Reflejos | −1% de acierto del rival en todas tus partes |
| | Velocidad | +0,2 de rapidez en la barra de turnos (la base del rey es 13) y +2% de huir |
| Aguante | Vitalidad | +5 de vida máxima (100 en la base) |
| | Cardio | −4% de estrés por cada paso en la mazmorra y cada día de marcha en una zona |
| | Recuperación | +5% de toda la curación: al caminar y al descansar (ver 7.12) |
| Resiliencia | Compostura | −4% de estrés por combates (ganar o perder), trampas y trabajos |
| | Resistencia | +3% de armadura y resistencia mágica del equipo; −3% de cualquier estado en contra (aturdir, desarmar, empujón) |
| | Firmeza | −6% de quedar aturdido, −8% de ser empujado y aguanta más antes de desmayarse |
| Suerte | Golpe de suerte | +1,5% de golpe crítico (×1,5 de daño, no cambia el acierto) |
| | Buen ojo | +5% de probabilidad de calidades raras o mejores y +5% de oro, en cofres y enemigos; +5% de que un enemigo suelte un objeto |
| | Amuleto | +0,075 a todas las demás partes; +5% de días buenos (oro, objeto, descanso) y −5% de trampas en las zonas |
| Inteligencia | Arcano | +3% de daño mágico (bastón y hechizos) y +1 de vida por cada Curación |
| | Estudio | +5% de experiencia |
| | Mago | +5 de maná máximo (20 en la base) y +0,5 de maná por turno (2 en la base) |
| Carisma | Negociación | +3% al vender (como mucho ×1,6, con el tope) y −2% al comprar en el mercado (como mucho 40% menos, y nunca por debajo de lo que te pagarían al venderlo) |
| | Liderazgo | Provisional: +3% de moral de los soldados de la ciudad, que defienden mejor y bajan más el peligro |
| | Presencia | +3% de pago en los trabajos. Si tu Presencia supera por 3 o más el **coraje** del enemigo, queda **atemorizado** todo el combate: −8% de acierto, −10% de daño y −5% de rapidez |

Ninguna parte mejora más allá de +20 puntos (ver 8.1). Ningún multiplicador
que reduce estrés, estados o trampas baja de un 30% de lo normal, y el acierto
nunca baja de 5% ni pasa de 95%. Coraje de los
enemigos: goblins 2–3, ladrón 3, bandido 4, matón y lancero 5, orcos 5–6,
cultista 8, caballero negro y verdugo 9.

### 8.3 Rapidez de los enemigos

| Rápidos | Normales | Lentos |
|---|---|---|
| Goblin 16, ladrón 16, goblin lancero 15, chamán goblin 14, orco cazador 14 | Cultista 13 (y los rivales de la demo, como el rey) | Caballero negro 12, chamán orco 12, orco guerrero 11, matón 11, verdugo 10 |

El rey empieza con 13; cada punto de Velocidad suma 0,2. Para huir también
cuenta quién es más rápido: cada punto de rapidez de ventaja suma un 2%.

### 8.4 Maná y hechizos (provisionales)

- El rey tiene 20 de maná (Mago lo sube) y recupera +2 al empezar cada turno
  suyo. En el reino, el maná que gasta sigue gastado en el combate siguiente (se
  recupera al caminar y al pasar la semana).
- **El bastón gasta 3 de maná por golpe.** Sin maná pega como un palo:
  contundente y con la mitad de daño.
- **Enemigos que saben magia:** chamán goblin (15 de maná; Llamarada y
  Curación), chamán orco (25) y cultista (30), estos dos también con
  Ralentizar. Su bastón también gasta maná. Con poca vida se curan, frenan al
  rey si es más rápido y a veces lanzan una llamarada; sus hechizos pegan y
  curan según su bastón (el del chamán goblin, menos que el del rey; el del
  cultista, bastante más).
- **Hechizos** (botón **Magia**), que se pagan al lanzarlos y no necesitan arma:

| Hechizo | Maná | Efecto |
|---|---|---|
| Llamarada | 6 | Fuego mágico contra la parte que elijas (10–13, como un ataque arcano) |
| Curación | 8 | Recuperas 15 de vida (+1 por punto de Arcano) |
| Ralentizar | 5 | El rival pierde medio turno en la barra |

Por ahora el rey sabe los tres desde el principio.

### 8.5 Equilibrio con características (simulado)

Medido con las reglas actuales (3 puntos de partes por punto principal y tope
de +20). Los puntos principales (los 15 del principio y uno por nivel) se reparten
en las mismas proporciones, y los de partes por igual entre sus 3 partes.
"Parejo": 3 en Fuerza y 2 en cada una de las demás. "Guerrero": 5 en Fuerza,
Destreza y Aguante. "Todo fuerza": los 15 en Fuerza. El rey pelea como la IA
de los rivales, con espada y armadura de metal.

**Un combate, empezando sano** (150 combates por casilla):

| Rey | Reparto | Ladrón | Orco guerrero | Cultista | Caballero negro | Verdugo |
|---|---|---|---|---|---|---|
| Nivel 1, sin armadura | Sin puntos | 83% | 2% | 15% | 0% | 0% |
| | Parejo | 100% | 74% | 76% | 17% | 32% |
| | Guerrero | 100% | 97% | 99% | 63% | 91% |
| | Todo fuerza | 99% | 54% | 68% | 17% | 35% |
| Nivel 5, equipo nivel 2 raro | Sin puntos | 100% | 39% | 53% | 7% | 20% |
| | Parejo | 100% | 99% | 99% | 95% | 97% |
| Nivel 10, equipo nivel 3 raro | Sin puntos | 99% | 69% | 72% | 25% | 53% |
| | Parejo | 100% | 100% | 100% | 99% | 100% |

**Una mazmorra entera**, con las heridas que duran de un combate al siguiente,
6 pasos de cura entre combates y sin pociones (300 intentos; % de veces que
vence a todos). Si la mano del arma queda inútil, el combate siguiente empieza
con la otra mano:

| Rey | Reparto | Madriguera goblin | Guarida de bandidos | Fortaleza orca | Ciudadela maldita |
|---|---|---|---|---|---|
| Nivel 1, sin armadura | Sin puntos | 13% | 0% | 0% | 0% |
| | Parejo | 99% | 7% | 0% | 0% |
| | Guerrero | 100% | 50% | 0% | 0% |
| Nivel 5, equipo nivel 2 raro | Parejo | 100% | 96% | 1% | 0% |
| | Guerrero | 100% | 100% | 52% | 8% |
| Nivel 10, equipo nivel 3 raro | Parejo | 100% | 100% | 63% | 4% |
| | Guerrero | 100% | 100% | 93% | 80% |

- Antes de estos cambios, con los 15 puntos el rey "parejo" ganaba el 97% al
  verdugo con el equipo inicial; ahora, el 32%.
- Poner los 15 puntos en Fuerza rinde mucho menos que repartirlos entre Fuerza,
  Destreza y Aguante: con el tope, los puntos de más no sirven.
- Las heridas que duran hacen que la dificultad real sea la mazmorra entera,
  no un combate suelto: al empezar, solo la madriguera goblin se puede limpiar.
- Los enemigos todavía no se hacen más fuertes con las semanas.

## 9. Pendientes

- Armas, armaduras y daño definitivos.
- Sangrado (B.1) y cómo se une con la vida; infecciones (B.4).
- Dolor (B.3): falta decidir si se quita.
- Estrés o cansancio dentro del combate.
- Escudos (el agarre ya mejora el bloqueo con el arma).
- Cómo funciona Liderazgo (hoy, provisional: +3% de moral de los soldados).
- Cómo se aprenden los hechizos (hoy el rey sabe los tres desde el principio).
- Ambidiestros.
- ¿Quién baja a la mazmorra: solo el rey, el rey con compañeros o héroes enviados?
- ¿Habrá límite de tiempo o finales? Por ahora el juego no tiene fin.
- ¿Qué devastó la ciudad?
- La escuela y otros edificios (ideas: torres de vigía, taberna, templo, torre
  del mago, casas, granero, tesoro).
- Estilo visual (propuesta: pixel art retro).
- Nombre del juego.
