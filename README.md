# Post 9 - Entrada y Salida Avanzados: Puertos, Polling e Interrupciones en NASM sobre DOSBox

**Estudiante:** Isabella Cobos Lizarazo (codigo 1152507) - UFPS, Arquitectura de Computadores.
**Entorno:** DOSBox 0.74-3 (3000 ciclos), NASM 2.16.03 ejecutado dentro de DOSBox, formato `-f bin` (`.COM`).

Este repositorio reune los ocho programas del Post 9. La Parte 1 (`U9P1/`, trabajada en `C:\U9P1\`) estudia la entrada y salida por polling sobre puertos: el controlador de teclado 8042, el puerto paralelo LPT1 y el polling combinado. La Parte 2 (`U9P2/`, trabajada en `C:\U9P2\`) estudia las interrupciones: instalacion de un ISR para IRQ1, enmascaramiento con el PIC 8259A, encadenamiento con el handler original y medicion de tiempo con los ticks del BIOS. Todas las capturas de `capturas/` fueron tomadas en DOSBox con `Ctrl+F5` durante las ejecuciones descritas aqui.

## Contenido

| Carpeta | Programa | Descripcion |
|---|---|---|
| `U9P1/` | `TECL.ASM/.COM` | Polling del puerto 64h (bit OBF) y lectura del scancode en 60h |
| `U9P1/` | `POLL_T.ASM/.COM` | Polling con timeout por numero de reintentos (`MAX_RETRY`) |
| `U9P1/` | `LPT1_OUT.ASM/.COM` | Envio de un caracter a LPT1 con el protocolo centronics |
| `U9P1/` | `MULTI_ST.ASM/.COM` | Polling combinado de teclado y LPT1 con OR de banderas |
| `U9P1/` | `TECLGUIA.ASM/.COM` | Version literal de la guia de `TECL`, conservada solo como evidencia de un cuelgue |
| `U9P2/` | `ISR_KB.ASM/.COM` | ISR propio de IRQ1: guarda, instala, cuenta 5 teclas y restaura el vector |
| `U9P2/` | `MASK_KB.ASM/.COM` | Enmascara IRQ1 en el IMR (puerto 21h) durante unos 3 s |
| `U9P2/` | `ISR_CHAIN.ASM/.COM` | ISR que cuenta y encadena al handler original con `PUSHF` + `CALL FAR` |
| `U9P2/` | `ISR_TIME.ASM/.COM` | ISR que mide ticks entre pulsaciones leyendo `0040h:006Ch` |
| `U9P2/` | `ISR_NEOI.ASM/.COM` | Demostracion: `ISR_KB` con el EOI eliminado a proposito |

Cada `.COM` fue ensamblado dentro de DOSBox con `nasm -f bin X.ASM -o X.COM`. `POLL_T.COM` se ensamblo con `-dMAX_RETRY=5` para forzar el timeout.

## Parte 1 - Polling sobre puertos

### Registros utilizados

- **Controlador de teclado 8042.** El puerto 64h es el registro de estado; su bit 0 (OBF, *output buffer full*) vale 1 cuando hay un byte disponible. El puerto 60h es el registro de datos y entrega el scancode. Al presionar una tecla se genera el codigo *make*; al soltarla, el mismo codigo con el bit 7 en 1 (*break*).
- **Puerto paralelo LPT1.** El puerto 378h es el registro de datos (D0-D7), 379h el registro de estado (bit 7 = BUSY#, bit 6 = ACK#, bit 5 = PE, bit 4 = SELECT, bit 3 = ERROR#) y 37Ah el registro de control (bit 0 = STROBE).
- **Protocolo centronics.** El programa espera que la impresora este lista (BUSY# en 1), escribe el byte en 378h y genera un pulso de STROBE en 37Ah (bit 0 en 1 y luego en 0) para que la impresora lo capture.

### Checkpoints

1. **CP1 - TECL.** `TECL.COM` hace polling de 64h, lee 60h e imprime el scancode en hexadecimal. Al pulsar `a` imprime `1E` (`capturas/p1_cp1_c_ejecuta_tecl.png`).
2. **CP2 - POLL_T.** Con `MAX_RETRY=5` el programa agota los reintentos sin que llegue ninguna tecla e imprime `Timeout: sin respuesta del dispositivo` (`p1_cp2_b_timeout.png`).
3. **CP3 - LPT1_OUT.** Envia `A` (41h) a LPT1 sin bloquearse y muestra el byte de estado leido en 379h, que en DOSBox fue `87h` (`p1_cp3_b_ejecuta_lpt1_out.png`).
4. **CP4 - MULTI_ST.** Combina las banderas OBF y BUSY#. Sin pulsar teclas termina de inmediato con `LPT1 listo (BUSY#=1).` (`p1_cp4_b_ejecuta_multi_st.png`).
5. **CP5 - Decisiones tecnicas** y evidencia de puertos (`p1_cp5_a_puertos_debug.png`, `p1_cp5_c_teclguia_colgado.png`), mas abajo.

### Desviaciones respecto a la guia (Parte 1)

- **`LPT1.ASM` se llama `LPT1_OUT.ASM`.** `LPT1` es un nombre reservado de dispositivo en DOS y en Windows; no se puede crear un archivo con ese nombre.
- **Se agregaron `CLI` y `STI` en `TECL`, `POLL_T` y `MULTI_ST`.** Con las interrupciones habilitadas, el handler de INT 09h del BIOS atiende IRQ1 y lee el puerto 60h antes de que el bucle observe OBF=1. La version literal de la guia (`TECLGUIA.COM`, sin `CLI`) fue ejecutada en DOSBox: tras pulsar dos teclas durante unos 4 s no imprimio nada ni regreso al prompt (`p1_cp5_c_teclguia_colgado.png`), y hubo que cerrar DOSBox. La explicacion del mecanismo es la descrita arriba; la observacion del cuelgue es la evidencia medida.
- **Se filtran los scancodes break (bit 7 en 1).** En la primera ejecucion de `TECL` el programa imprimio `9C`, que es el codigo de soltar `Enter` (1Ch con el bit 7 activo), porque el `Enter` que lanza el programa se suelta ya con el programa en ejecucion (`p1_cp1_d_primer_intento_9C.png`). Con el filtro, la siguiente ejecucion imprimio `1E`.
- **`LPT1_OUT` muestra el byte de estado**, para dejar constancia de lo que devuelve DOSBox. Con `debug` se leyeron los puertos directamente: `i 379` devolvio `87` (dos lecturas) e `i 64` devolvio `1C` con el buffer del teclado vacio (`p1_cp5_a_puertos_debug.png`). Como 87h tiene el bit 7 en 1, DOSBox siempre simula la impresora como lista.
- **Los archivos fuente se escribieron en la carpeta del anfitrion montada como `C:`** y se ensamblaron dentro de DOSBox; no se escribieron con el editor de DOSBox. El ensamblado y la ejecucion si ocurrieron en DOSBox (capturas de compilacion y ejecucion).
- Una primera ejecucion de `POLL_T` quedo con una tecla perdida en el prompt (`acls: Illegal command`); se limpio la linea y se repitio la compilacion y ejecucion, que son las capturas incluidas.

## Parte 2 - Interrupciones

### Conceptos aplicados

- **Vector de interrupcion.** IRQ1 llega por INT 09h. `INT 21h` funcion 35h (`AX=3509h`) devuelve el vector actual en ES:BX y la funcion 25h (`AX=2509h`, DS:DX) lo instala. El vector original se guarda en `old_isr` y se restaura al terminar.
- **PIC 8259A.** El IMR del maestro esta en el puerto 21h: un bit en 1 enmascara la IRQ (bit 1 = IRQ1). El EOI se envia como `20h` al puerto 20h; mientras no se envie, el PIC no entrega mas interrupciones de igual o menor prioridad.
- **Ticks del BIOS.** El contador de 32 bits de `0040h:006Ch` crece unas 18,2 veces por segundo (IRQ0); se usa su palabra baja y una resta de 16 bits.
- **Encadenamiento.** `PUSHF` seguido de `CALL FAR [CS:old_isr]` simula una interrupcion hacia el handler original, que envia su propio EOI; por eso el ISR encadenado no envia otro.

### Checkpoints

1. **CP1 - ISR_KB.** Con `MAX_KEYS=5`, el programa imprime `Tecla detectada por ISR propio` por cada pulsacion contada, restaura el vector e imprime `ISR restaurado. Fin del programa.` (`p2_cp1_a..c`).
2. **CP2 - MASK_KB.** Imprime `IRQ1 enmascarado (teclado deshabilitado)...`, espera 55 ticks y restaura el IMR (`IRQ1 restaurado.`). Las teclas `asd` pulsadas durante el enmascaramiento no aparecieron mientras IRQ1 estuvo enmascarada, pero si aparecieron en el prompt al restaurar la mascara (`p2_cp2_c_mask_kb_restaurado.png`): DOSBox conserva los scancodes en cola hasta que IRQ1 se desenmascara.
3. **CP3 - ISR_CHAIN.** Tras 5 pulsaciones se restaura el vector y se vacia el buffer del BIOS: el eco fue `hola`, es decir, el handler original proceso las teclas mientras el ISR propio las contaba (`p2_cp3_c_ejecuta_isr_chain.png`).
4. **CP4 - ISR_TIME.** Imprime los ticks entre interrupciones: `37, 20, 19, 38, 1` (`p2_cp4_c_isr_time_final.png`). Con 18,2 ticks/s, 20 ticks son cerca de 1,1 s, que coincide con las pulsaciones separadas 1 s; 38 ticks son cerca de 2 s, la espera previa al capturar; y 1 tick (cerca de 55 ms) corresponde a una pulsacion inmediata.
5. **CP5 - Decisiones tecnicas** y la demostracion sin EOI (`p2_cp5_b_isr_neoi_sin_eoi.png`), mas abajo.

### Desviaciones respecto a la guia (Parte 2)

- **Se ignoran los scancodes break** en `ISR_KB`, `ISR_CHAIN` e `ISR_TIME`, para que "5 teclas" signifique 5 pulsaciones y no 2,5.
- **El atajo `Ctrl+F5` de captura de DOSBox cuenta como una pulsacion.** El ISR cuenta cualquier codigo make, y la tecla `Ctrl` del atajo llega al teclado emulado. Por eso en `ISR_KB` la captura intermedia muestra 3 detecciones tras pulsar `a`, `s` y `Ctrl`, y en `ISR_TIME` el intervalo de 38 ticks termina en el `Ctrl` y el de 1 tick va desde `Ctrl` hasta la tecla `f`. No es un defecto del programa, sino una consecuencia de como se tomaron las capturas.
- **Se conserva `DS` alrededor de `LDS`** al restaurar el vector (`PUSH DS` / `POP DS`); sin eso, `DS` apuntaba al segmento del handler original y el mensaje final se imprimia con datos erroneos.
- **`MASK_KB` usa aritmetica sin signo** (`SUB` + `JB`) para medir la espera; la guia usaba una comparacion con signo que falla al cruzar `8000h` o desbordar `0FFFFh` en la palabra baja de los ticks.
- **`ISR_CHAIN` vacia el buffer del BIOS** al terminar para mostrar que el handler original si recibio las teclas.
- **Nombre 8.3.** DOSBox muestra `ISR_CHAIN.ASM` como `ISR_CH~1.ASM`, porque el nombre tiene 9 caracteres; `nasm isr_chain.asm` fallo con "No such file or directory" (`p2_cp3_a_error_nombre_8_3.png`). Para ensamblar dentro de DOSBox se uso una copia con nombre corto (`ISR_CHN.ASM`, contenido identico) y se genero `ISR_CHN.COM` (214 bytes). El `ISR_CHAIN.COM` del repositorio es ese mismo binario: se ensamblo `ISR_CHAIN.ASM` con NASM y `cmp` confirmo que ambos archivos son identicos byte a byte.
- **`ISR_NEOI`** no esta en la guia: es `ISR_KB` con las dos instrucciones del EOI reemplazadas por un `NOP`, y existe solo para ilustrar la decision sobre el EOI.

## Decisiones tecnicas

### Decision 1 (Parte 1): polling sin limite o con timeout

`TECL` espera indefinidamente a que OBF valga 1; `POLL_T` limita el bucle a `MAX_RETRY` iteraciones. El polling sin limite es mas simple y no pierde ningun evento, pero si el dispositivo nunca responde el programa queda bloqueado: es lo que ocurrio con `TECLGUIA`, que no volvio al prompt y obligo a cerrar DOSBox. Con timeout el programa siempre termina y puede informar el fallo, como mostro `POLL_T` con `MAX_RETRY=5`. Sin embargo, un contador de iteraciones no es tiempo real: depende de la velocidad del CPU y de los ciclos configurados en DOSBox, de modo que el mismo valor representa microsegundos en una maquina y milisegundos en otra. Una espera acotada en tiempo real debe medirse con el contador de ticks de `0040h:006Ch`, como hace `MASK_KB`. Ademas, un `MAX_RETRY` demasiado pequeno produce falsos timeouts: el usuario aun no pulsa la tecla y el programa ya se rindio. Por eso la decision razonable fue conservar el polling sin limite para la lectura interactiva de teclado y usar un limite generoso, o mejor basado en ticks, cuando el dispositivo puede no existir.

### Decision 2 (Parte 1): combinar banderas con OR o examinarlas por separado

En `MULTI_ST` la salida del bucle se decide con el OR de la bandera del teclado (BL) y la del puerto paralelo (BH): el bucle termina en cuanto cualquiera de los dos dispositivos esta listo, sin quedarse bloqueado en uno solo. Esa es la ventaja del OR frente a esperar un dispositivo despues de otro. Su costo es que el resultado ya no indica quien estaba listo, por lo que al salir hay que volver a examinar BL y BH por separado para decidir que mensaje imprimir. Ademas, con DOSBox el puerto 379h devuelve siempre 87h (BUSY# en 1, confirmado con `i 379` en DEBUG), asi que LPT1 esta permanentemente listo y el OR termina en la primera iteracion: en la ejecucion no se pulso ninguna tecla y el programa imprimio solo `LPT1 listo (BUSY#=1).`. En ese caso el OR no sirve para esperar al teclado, y habria que usar AND si se necesita que ambos dispositivos esten listos (un punto de encuentro). La eleccion depende de la semantica buscada: OR para atender al primero que responda, AND para esperar a todos, y en ambos casos reexaminar cada bandera.

### Decision 3 (Parte 2): donde enviar el EOI

El EOI avisa al PIC que la interrupcion termino. `ISR_KB` lo envia al final, justo antes de `IRET`; `ISR_TIME` lo envia apenas lee los ticks y calcula el intervalo, antes de imprimir. En estos programas la diferencia no cambia lo que se entrega, porque ningun ISR ejecuta `STI`: con IF=0 toda interrupcion enmascarable queda diferida hasta el `IRET`, de modo que ni IRQ1 puede reentrar ni IRQ0 (el reloj) puede atenderse durante la rutina, enviando el EOI antes o despues. La eleccion importa si el ISR habilita interrupciones para no perder ticks durante una impresion lenta con `INT 21h`: con el EOI enviado temprano, una nueva IRQ1 podria reentrar al mismo ISR y corromper el contador; con el EOI enviado tarde, el PIC bloquea IRQ1 y las de menor prioridad pero deja pasar IRQ0, que tiene mayor prioridad. Por eso se recomienda enviar el EOI en cuanto termina el trabajo que depende del hardware cuando el ISR es corto y no habilita interrupciones, y reservar el EOI tardio para ISR que hacen STI y necesitan impedir la reentrada. Omitirlo es siempre un error, y se comprobo con `ISR_NEOI`: sin EOI el programa no imprimio nada en toda la prueba, incluso tras pulsar cinco teclas, porque el PIC dejo de entregar IRQ1 (el primer evento que recibio fue probablemente el de soltar `Enter`, que el ISR ignora, y ya no hubo segundo). Con EOI (`ISR_KB`, `ISR_TIME`) las pulsaciones se contaron sin perdida.

### Decision 4 (Parte 2): polling o interrupciones

El polling mantiene al CPU ejecutando el bucle al 100 % mientras espera; en DOSBox eso se nota en que `TECL` y `POLL_T` consumen todo el tiempo del programa para detectar una sola tecla, y para dispositivos esporadicos como un teclado, donde pasan segundos entre eventos, ese esfuerzo es casi todo desperdicio. Tiene a favor una latencia predecible y un codigo muy simple, sin tocar la tabla de vectores ni el PIC, y por eso es adecuado para esperas muy cortas o dispositivos que responden de inmediato, como el puerto paralelo. Las interrupciones invierten el costo: el CPU queda libre hasta que el dispositivo avisa, a cambio de mas complejidad (guardar y restaurar el vector, preservar registros, `IRET`, EOI, no tocar `DS` por error). `ISR_TIME` muestra otra ventaja: al medirse el tiempo de llegada de cada evento (37, 20, 19, 38 y 1 ticks) se obtiene la latencia entre pulsaciones sin ningun bucle activo, y una pulsacion inmediata se detecta como 1 tick. Para un dispositivo esporadico como el teclado, la interrupcion es la opcion adecuada; el polling se justifica cuando se espera una respuesta inmediata o cuando no hay otra forma de saber el estado, como el 379h del LPT1.

## Mapa de capturas

| Checkpoint | Capturas |
|---|---|
| P1-CP1 (TECL) | `p1_cp1_a_entorno`, `p1_cp1_b_compila_tecl`, `p1_cp1_c_ejecuta_tecl`, `p1_cp1_d_primer_intento_9C` |
| P1-CP2 (POLL_T) | `p1_cp2_a_compila_poll_t`, `p1_cp2_b_timeout` |
| P1-CP3 (LPT1_OUT) | `p1_cp3_a_compila_lpt1_out`, `p1_cp3_b_ejecuta_lpt1_out` |
| P1-CP4 (MULTI_ST) | `p1_cp4_a_compila_multi_st`, `p1_cp4_b_ejecuta_multi_st` |
| P1-CP5 (decisiones) | `p1_cp5_a_puertos_debug`, `p1_cp5_b_compila_teclguia`, `p1_cp5_c_teclguia_colgado` |
| P2-CP1 (ISR_KB) | `p2_cp1_a_compila_isr_kb`, `p2_cp1_b_isr_kb_en_ejecucion`, `p2_cp1_c_isr_kb_final` |
| P2-CP2 (MASK_KB) | `p2_cp2_a_compila_mask_kb`, `p2_cp2_b_mask_kb_enmascarado`, `p2_cp2_c_mask_kb_restaurado` |
| P2-CP3 (ISR_CHAIN) | `p2_cp3_a_error_nombre_8_3`, `p2_cp3_b_compila_isr_chain`, `p2_cp3_c_ejecuta_isr_chain` |
| P2-CP4 (ISR_TIME) | `p2_cp4_a_compila_isr_time`, `p2_cp4_b_isr_time_en_ejecucion`, `p2_cp4_c_isr_time_final` |
| P2-CP5 (decisiones) | `p2_cp5_a_compila_isr_neoi`, `p2_cp5_b_isr_neoi_sin_eoi`, y las de `ISR_TIME` y `MASK_KB` |

## Como reproducir

En DOSBox, con NASM disponible (`path z:\;c:\` y `cwsdpmi -p` si se usa NASM en modo protegido):

```
cd u9p1
nasm -f bin tecl.asm -o tecl.com
tecl
cd ..
cd u9p2
nasm -f bin isr_kb.asm -o isr_kb.com
isr_kb
```

Los demas programas siguen el mismo patron. `POLL_T` admite `-dMAX_RETRY=5`. En DOSBox, `ISR_CHAIN.ASM` debe copiarse a un nombre de 8 caracteres o menos antes de ensamblarse.
