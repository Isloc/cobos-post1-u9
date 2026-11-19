; MULTI_ST.ASM - Polling combinado de dos puertos de estado (teclado + LPT1)
; Compila: nasm -f bin MULTI_ST.ASM -o MULTI_ST.COM
;
; Cada bandera se aisla y se normaliza a 0 o 1 en BL (teclado) y BH (LPT1).
; El OR de ambas solo vale 0 cuando ningun dispositivo esta listo. Al salir del
; bucle se examinan BL y BH por separado, porque el OR descarta cual de las dos
; banderas provoco la salida.
;
; Se agrega CLI/STI por la misma razon que en TECL.ASM.

[BITS 16]
[ORG 0x100]

STATUS_KBD  EQU 64h
STATUS_LPT  EQU 0379h
OBF_MASK    EQU 01h
LPT_READY   EQU 80h

section .text
start:
    CLI
.poll:
    ; Bandera de teclado: bit 0 (OBF) del registro de estado 64h
    IN   AL, STATUS_KBD
    AND  AL, OBF_MASK
    MOV  BL, AL                 ; BL = bandera_teclado (0 o 1)

    ; Bandera de LPT1: bit 7 (listo) del registro de estado 379h
    MOV  DX, STATUS_LPT
    IN   AL, DX
    AND  AL, LPT_READY
    SHR  AL, 7                  ; normaliza a 0 o 1
    MOV  BH, AL                 ; BH = bandera_lpt1 (0 o 1)

    MOV  AL, BL
    OR   AL, BH                 ; AL = bandera_teclado OR bandera_lpt1
    JZ   .poll                  ; ningun dispositivo listo: repetir

    STI

    ; Determinar cual(es) dispositivo(s) dispararon la condicion
    TEST BL, BL
    JZ   .soloLpt1
    MOV  AH, 09h
    MOV  DX, msg_tecl
    INT  21h

.soloLpt1:
    TEST BH, BH
    JZ   .fin
    MOV  AH, 09h
    MOV  DX, msg_lpt1
    INT  21h

.fin:
    MOV  AH, 4Ch
    INT  21h

section .data
msg_tecl    DB 'Teclado listo (OBF=1).', 0Dh, 0Ah, '$'
msg_lpt1    DB 'LPT1 listo (BUSY#=1).', 0Dh, 0Ah, '$'
