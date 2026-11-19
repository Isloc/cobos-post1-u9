; ISR_KB.ASM - ISR personalizado para IRQ1 (teclado)
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
;
; 1) guarda el vector original de INT 09h, 2) instala el ISR propio,
; 3) espera MAX_KEYS pulsaciones, 4) restaura el handler original.
;
; Cambios respecto a la guia:
;  - Cada pulsacion genera dos interrupciones (make al presionar y break al
;    soltar, con el bit 7 del scancode en 1). El ISR ignora los break para que
;    "5 teclas" signifique 5 pulsaciones y no 2.5.
;  - LDS modifica DS. Se guarda con PUSH DS y se recupera con POP DS antes de
;    imprimir el mensaje final; sin eso DS apunta al segmento del handler
;    original y el mensaje saldria con basura.

[BITS 16]
[ORG 0x100]

MAX_KEYS    EQU 5
KBD_DATA    EQU 60h             ; puerto de datos del 8042
PIC_CMD     EQU 20h             ; puerto de comando del PIC maestro
EOI         EQU 20h             ; comando End Of Interrupt no especifico
BREAK_BIT   EQU 80h             ; bit 7 del scancode: tecla soltada

section .text
start:
    ; Guardar el vector original de INT 09h
    MOV  AX, 3509h              ; AH=35h: obtener vector
    INT  21h                    ; ES:BX = handler actual
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    ; Instalar el ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr             ; DS:DX = nuevo handler
    MOV  AX, 2509h              ; AH=25h: fijar vector
    INT  21h
    POP  DS

    STI                         ; asegurar interrupciones habilitadas

.esperar:
    CMP  WORD [contador], MAX_KEYS
    JB   .esperar               ; espera activa hasta MAX_KEYS pulsaciones

    ; Restaurar el handler original
    CLI
    PUSH DS                     ; LDS destruye DS: guardarlo
    LDS  DX, [old_isr]          ; DS:DX = handler original
    MOV  AX, 2509h
    INT  21h
    POP  DS                     ; recuperar DS del programa
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AH, 4Ch
    INT  21h

; ---- ISR propio -----------------------------------------------------
mi_isr:
    PUSH AX
    PUSH DX
    PUSH DS

    MOV  AX, CS
    MOV  DS, AX                 ; DS apunta al segmento del programa

    IN   AL, KBD_DATA           ; leer el scancode (libera el buffer del 8042)
    TEST AL, BREAK_BIT
    JNZ  .eoi                   ; tecla soltada: no se cuenta ni se muestra

    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h
    INC  WORD [contador]

.eoi:
    NOP                         ; DEMO: se omite el EOI a proposito

    POP  DS
    POP  DX
    POP  AX
    IRET

section .data
contador    DW 0                ; numero de teclas atendidas
old_isr     DD 0                ; SEG:OFF del handler original
msg_tecla   DB 0Dh, 0Ah, 'Tecla detectada por ISR propio$'
msg_fin     DB 0Dh, 0Ah, 'ISR restaurado. Fin del programa.', 0Dh, 0Ah, '$'
