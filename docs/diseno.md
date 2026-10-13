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
- **Idea en evaluación:** el protagonista es el **rey de una ciudad devastada**.
  Debe reconstruirla, mejorar sus habilidades y expandir su reino. La mazmorra da
  recursos a la ciudad y la ciudad hace más fuerte al rey.
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
| Ojos | ojo | Visión: con uno, menos precisión; sin los dos, ciego |
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

## 6. Sistema de batalla provisional (demo)

Reglas **provisionales** para probar el sistema de cuerpo. Se ajustarán cuando
definamos armas y daño.

- **Vida:** el héroe tiene **100**. Rivales de la demo: Bandido 80, Orco 105 y
  Lancero 95.
- **Tres tipos de arma:**

| Tipo | Arma de la demo | Característica provisional |
|---|---|---|
| Cortante | Espada | Más daño en extremidades y cuello; menos en el cráneo |
| Contundente | Maza | Más daño en el cráneo; aturde y desarma con más facilidad; puede fracturar |
| Punzante | Lanza | Más precisa con partes pequeñas (ojos, cuello, manos); más daño en tórax y abdomen |

- **Acciones:** Atacar (zona → parte), Defender (se defiende mejor y recibe la
  mitad de daño), cambiar o recoger el arma, y Huir.
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
- **Puntería:** cada ataque fallado seguido da **+10%** de acierto al siguiente;
  se pierde al acertar. Vale para todos y se ve en los botones y en el panel
  ("Puntería +10%"). Así casi no hay rachas largas de fallos.

### 6.2 Daño: combates más largos

- Cada arma tiene una **fuerza de golpe** con un rango estrecho (espada 14–17,
  maza 15–19, lanza 12–16), para que el daño dependa poco de la suerte.
- Cada parte convierte esa fuerza, por separado, en:
  - **vida perdida:** poca en brazos y piernas, más en torso y cabeza;
  - **desgaste de la parte:** brazos y piernas se inutilizan en 3 a 7 golpes,
    según el arma (la lanza tarda más). El botón muestra cuántos faltan, por
    ejemplo "Inutilizar: 4–5 golpes", contando la guardia y las lesiones de
    cuello.
- Así atacar los brazos tiene sentido aunque quiten poca vida: abren la defensa y
  debilitan al rival.
- Los combates duran unos **18 a 24 turnos** (antes, unos 11).

### 6.3 Efectos provisionales de las funciones (B.2)

- Visión baja: menos precisión.
- Movimiento de piernas bajo: esquiva menos y le cuesta huir.
- Movimiento del brazo del arma bajo: pega más débil (con el brazo inutilizado, un
  25% menos).
- Golpe en la mano del arma: puede soltarla. Si el brazo del arma ya no puede
  sostenerla (también por una lesión en el cuello), la suelta siempre. Si la mano
  dominante queda inutilizada, recoge el arma con la otra mano ("mano torpe":
  menos precisión y daño).
- Sin arma se pelea con los puños, que aturden y desarman mucho menos. Sin
  brazos útiles, a **patadas** (dependen de las piernas).
- Golpe en el cráneo: puede aturdir (pierde un turno). Si la conciencia baja
  demasiado, se desmaya y pierde el combate.
- Las heridas se registran por tipo (corte, contusión, perforación, fractura) para
  conectarlas después con el sangrado, el dolor y las infecciones.

### 6.4 Rivales

Cada rival sigue un plan según su personalidad y a veces improvisa (25%):

- **Bandido (astuto):** va por la mano de tu arma para desarmarte.
- **Orco (bruto):** quiere tu cráneo. Si su acierto ahí es menor de 40%,
  primero ataca tu brazo del arma para abrir tu guardia.
- **Lancero (preciso):** igual, pero quiere tu cuello.

### 6.5 Equilibrio (simulado)

Victorias del rey en miles de combates simulados, promedio de las tres armas,
según cómo elige a qué atacar:

| Cómo ataca el rey | Bandido | Lancero | Orco |
|---|---|---|---|
| Inutiliza el brazo del arma y luego va al cuerpo | 98% | 93% | 78% |
| Inutiliza los dos brazos y luego va al cuerpo | 95% | 87% | 77% |
| La parte del torso que más daña | 90% | 68% | 51% |
| Como la IA de los rivales | 85% | 56% | 39% |
| Siempre al abdomen | 81% | 52% | 35% |
| Siempre al cráneo | 62% | 41% | 38% |
| Siempre al cuello | 56% | 34% | 22% |
| Primero las piernas | 32% | 10% | 8% |
| Partes al azar | 17% | 4% | 1% |

Combates con una racha de 4 o más fallos seguidos del rey:

| Cómo ataca el rey | Sin puntería | Con puntería |
|---|---|---|
| Inutiliza el brazo del arma y luego va al cuerpo | 41% | 8% |
| Como la IA de los rivales | 53% | 16% |
| Siempre al abdomen | 79% | 21% |

- Inutilizar primero el brazo del arma rinde mucho más que ir directo al
  abdomen, y contra cada rival atacar siempre la misma parte rinde menos que
  abrir la guardia.
- Dificultad de los rivales: bandido fácil, lancero medio, orco difícil.

## 7. Pendientes

- Armas y daño definitivos; armaduras por zona.
- Integración del sangrado con la vida; recuperación después del combate.
- Ambidiestros.
- ¿Quién baja a la mazmorra: solo el rey, el rey con compañeros o héroes enviados?
- ¿Hay límite de tiempo o amenazas periódicas sobre la ciudad?
- ¿Qué devastó la ciudad?
- Estilo visual (propuesta: pixel art retro).
- Enemigos visibles en el mapa o encuentros al azar.
- Nombre del juego.
