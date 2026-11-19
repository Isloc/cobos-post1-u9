; POLL_T.ASM - Polling con timeout para el puerto de estado del teclado
; Compila:  nasm -f bin POLL_T.ASM -o POLL_T.COM
; Timeout:  nasm -f bin POLL_T.ASM -dMAX_RETRY=5 -o POLL_T.COM
;
; MAX_RETRY es el numero maximo de iteraciones del bucle de espera. Puede
; sobrescribirse en la linea de comandos con -dMAX_RETRY=valor para forzar el
; timeout sin editar el archivo.
;
; Igual que en TECL.ASM, se usa CLI/STI para que el handler del BIOS no
; consuma el scancode antes de que el bucle lo observe, y se ignoran los
; scancodes de tecla soltada (bit 7 en 1), que cuentan como un reintento mas.

[BITS 16]
[ORG 0x100]

%ifndef MAX_RETRY
MAX_RETRY   EQU 0FFFFh          ; numero maximo de reintentos por defecto
%endif

STATUS_KBD  EQU 64h
DATA_KBD    EQU 60h
OBF_MASK    EQU 01h
BREAK_BIT   EQU 80h

section .text
start:
    CLI
    MOV  CX, MAX_RETRY

.poll:
    IN   AL, STATUS_KBD
    TEST AL, OBF_MASK
    JNZ  .dato_listo
.siguiente:
    LOOP .poll                  ; decrementa CX; salta si CX distinto de 0

    ; Timeout: CX llego a 0 sin dato
    STI
    MOV  AH, 09h
    MOV  DX, msg_timeout
    INT  21h
    JMP  .fin

.dato_listo:
    IN   AL, DATA_KBD
    TEST AL, BREAK_BIT          ; tecla soltada: ignorar y contar un reintento
    JNZ  .siguiente
    STI
    MOV  BL, AL
    MOV  AH, 09h
    MOV  DX, msg_dato
    INT  21h
    ; Mostrar el scancode leido en hexadecimal
    MOV  AH, 02h
    MOV  DL, BL
    SHR  DL, 4
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .hi
    ADD  DL, 07h
.hi:
    INT  21h
    MOV  DL, BL
    AND  DL, 0Fh
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .lo
    ADD  DL, 07h
.lo:
    INT  21h

.fin:
    MOV  AH, 4Ch
    INT  21h

section .data
msg_timeout DB 'Timeout: sin respuesta del dispositivo', 0Dh, 0Ah, '$'
msg_dato    DB 'Dato listo. Scancode leido: $'
