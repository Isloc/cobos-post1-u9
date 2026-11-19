; MASK_KB.ASM - Enmascarar y desenmascarar IRQ1 con el IMR del PIC 8259A
; Compila: nasm -f bin MASK_KB.ASM -o MASK_KB.COM
;
; El IMR del PIC maestro esta en el puerto 21h: un bit en 1 enmascara la IRQ.
; El bit 1 corresponde a IRQ1 (teclado).
;
; Cambio respecto a la guia: la espera compara el tiempo transcurrido con
; aritmetica sin signo (SUB + JB). La guia comparaba DX con JL (con signo) y
; fallaba cuando la palabra baja del contador de ticks cruzaba 8000h o
; desbordaba 0FFFFh durante la espera.

[BITS 16]
[ORG 0x100]

IMR_PORT    EQU 21h
IRQ1_MASK   EQU 02h
ESPERA_TICKS EQU 55             ; ~3 s (18,2 ticks por segundo)

section .text
start:
    ; Leer el IMR actual y conservarlo
    IN   AL, IMR_PORT
    PUSH AX

    ; Enmascarar IRQ1 (bit 1 del IMR)
    OR   AL, IRQ1_MASK
    OUT  IMR_PORT, AL

    MOV  AH, 09h
    MOV  DX, msg_mask
    INT  21h

    ; Leer el contador de ticks inicial con el BIOS (INT 1Ah, AH=00h)
    MOV  AH, 00h
    INT  1Ah                    ; CX:DX = ticks
    MOV  BX, DX                 ; BX = ticks al inicio

.wait:
    MOV  AH, 00h
    INT  1Ah
    MOV  AX, DX
    SUB  AX, BX                 ; ticks transcurridos (con wrap de 16 bits)
    CMP  AX, ESPERA_TICKS
    JB   .wait

    ; Restaurar el IMR original
    POP  AX
    OUT  IMR_PORT, AL

    MOV  AH, 09h
    MOV  DX, msg_unmask
    INT  21h
    MOV  AH, 4Ch
    INT  21h

section .data
msg_mask    DB 'IRQ1 enmascarado (teclado deshabilitado)...$'
msg_unmask  DB 0Dh, 0Ah, 'IRQ1 restaurado.', 0Dh, 0Ah, '$'
