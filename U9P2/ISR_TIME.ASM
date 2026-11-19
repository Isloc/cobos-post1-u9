; ISR_TIME.ASM - Mide el intervalo entre interrupciones de teclado leyendo el
; contador de ticks del BIOS en 0040h:006Ch
; Compila: nasm -f bin ISR_TIME.ASM -o ISR_TIME.COM
;
; El contador de 32 bits en 0040h:006Ch se incrementa ~18,2 veces por segundo
; (IRQ0). Se usa solo la palabra baja: la resta de 16 bits da el intervalo
; correcto aunque la palabra desborde entre dos pulsaciones.
;
; Cambios respecto a la guia:
;  - Se ignoran las interrupciones de tecla soltada (break), que llegan casi
;    junto a las de tecla presionada y darian intervalos de 0 ticks.
;  - Se conserva DS con PUSH/POP alrededor de LDS al restaurar el vector.
;  - El EOI se envia justo despues de leer y calcular el intervalo, antes de
;    imprimir (ver la decision tecnica sobre el EOI en el README).

[BITS 16]
[ORG 0x100]

MAX_KEYS    EQU 5
KBD_DATA    EQU 60h
PIC_CMD     EQU 20h
EOI         EQU 20h
BREAK_BIT   EQU 80h
BIOS_SEG    EQU 0040h           ; segmento del area de datos del BIOS
TICK_OFF    EQU 006Ch           ; desplazamiento del contador de ticks

section .text
start:
    ; Guardar el vector original de INT 09h
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    ; Inicializar ticks_prev con la lectura actual del contador
    MOV  AX, BIOS_SEG
    MOV  ES, AX
    MOV  AX, [ES:TICK_OFF]
    MOV  [ticks_prev], AX

    ; Instalar el ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr
    MOV  AX, 2509h
    INT  21h
    POP  DS

    STI

.esperar:
    CMP  WORD [contador], MAX_KEYS
    JB   .esperar

    ; Restaurar el handler original
    CLI
    PUSH DS
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AH, 4Ch
    INT  21h

; ---- ISR propio con medicion de intervalo ---------------------------
mi_isr:
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH DS
    PUSH ES

    MOV  AX, CS
    MOV  DS, AX

    IN   AL, KBD_DATA           ; leer el scancode (libera el 8042)
    TEST AL, BREAK_BIT
    JNZ  .solo_eoi              ; tecla soltada: solo EOI

    ; Leer el contador de ticks actual (palabra baja de 0040h:006Ch)
    MOV  AX, BIOS_SEG
    MOV  ES, AX
    MOV  AX, [ES:TICK_OFF]
    MOV  BX, AX
    SUB  BX, [ticks_prev]       ; BX = ticks desde la interrupcion anterior
    MOV  [ticks_prev], AX

    ; EOI antes de imprimir: el hardware ya fue atendido
    MOV  AL, EOI
    OUT  PIC_CMD, AL

    MOV  AH, 09h
    MOV  DX, msg_ticks
    INT  21h
    MOV  AX, BX
    CALL imprimir_decimal

    INC  WORD [contador]
    JMP  .salir

.solo_eoi:
    MOV  AL, EOI
    OUT  PIC_CMD, AL

.salir:
    POP  ES
    POP  DS
    POP  DX
    POP  BX
    POP  AX
    IRET

; Subrutina: imprime AX en decimal (sin signo)
imprimir_decimal:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    XOR  CX, CX
.divide:
    XOR  DX, DX
    DIV  BX
    PUSH DX
    INC  CX
    TEST AX, AX
    JNZ  .divide
.imprimir:
    POP  DX
    ADD  DL, 30h
    MOV  AH, 02h
    INT  21h
    LOOP .imprimir
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

section .data
old_isr     DD 0
ticks_prev  DW 0                ; ultima lectura de la palabra baja del contador
contador    DW 0
msg_ticks   DB 0Dh, 0Ah, 'Ticks desde la interrupcion anterior: $'
msg_fin     DB 0Dh, 0Ah, 'ISR_TIME restaurado. Fin del programa.', 0Dh, 0Ah, '$'
