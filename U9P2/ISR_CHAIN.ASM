; ISR_CHAIN.ASM - ISR para IRQ1 encadenado con el handler original
; Compila: nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
;
; El ISR cuenta las pulsaciones y despues llama al handler original con
; PUSHF + CALL FAR, simulando una interrupcion. Como el handler original envia
; el EOI y procesa la tecla, este ISR NO envia EOI.
;
; Para comprobar que el sistema sigue respondiendo, al terminar se vacia el
; buffer de teclado del BIOS (INT 16h) y se muestran las teclas que el handler
; original proceso.

[BITS 16]
[ORG 0x100]

MAX_KEYS    EQU 5
KBD_DATA    EQU 60h
BREAK_BIT   EQU 80h

section .text
start:
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr_chain
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

    ; Mostrar las teclas que el handler original dejo en el buffer del BIOS
    MOV  AH, 09h
    MOV  DX, msg_eco
    INT  21h
.vaciar:
    MOV  AH, 01h                ; INT 16h AH=01h: hay tecla en el buffer?
    INT  16h
    JZ   .listo                 ; ZF=1: buffer vacio
    MOV  AH, 00h                ; INT 16h AH=00h: leer tecla (AL = ASCII)
    INT  16h
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h                    ; eco del caracter
    JMP  .vaciar
.listo:
    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AH, 4Ch
    INT  21h

; ---- ISR con encadenamiento -----------------------------------------
mi_isr_chain:
    PUSH AX
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    IN   AL, KBD_DATA           ; leer el scancode (sigue disponible para el BIOS)
    TEST AL, BREAK_BIT
    JNZ  .encadenar             ; break: no se cuenta
    INC  WORD [contador]
.encadenar:
    POP  DS
    POP  AX
    PUSHF                       ; simular INT: guardar flags y llamar con CALL FAR
    CALL FAR [CS:old_isr]       ; handler original (procesa la tecla y envia EOI)
    IRET

section .data
contador    DW 0
old_isr     DD 0
msg_eco     DB 0Dh, 0Ah, 'Teclas procesadas por el handler original (eco): $'
msg_fin     DB 0Dh, 0Ah, 'ISR_CHAIN restaurado. Fin del programa.', 0Dh, 0Ah, '$'
