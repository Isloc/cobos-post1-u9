; LPT1_OUT.ASM - Envio de un caracter al puerto paralelo LPT1 (protocolo centronics)
; Compila: nasm -f bin LPT1_OUT.ASM -o LPT1_OUT.COM
;
; Nota: la guia nombra este programa LPT1.ASM, pero LPT1 es un nombre reservado
; de dispositivo en DOS y en Windows (no se puede crear un archivo LPT1.ASM ni
; LPT1.COM). Por eso el archivo se llama LPT1_OUT.
; Registros del puerto paralelo:
;   378h  Data Register     D0-D7 hacia el conector
;   379h  Status Register   bit 7 BUSY#, bit 6 ACK#, bit 5 PE, bit 4 SELECT, bit 3 ERROR#
;   37Ah  Control Register  bit 0 STROBE, bit 1 AUTOFEED, bit 2 INIT, bit 3 SELECT_IN
;
; Se agrega a la guia la lectura y visualizacion del byte de estado (379h) para
; dejar evidencia de lo que DOSBox devuelve en ese puerto.

[BITS 16]
[ORG 0x100]

DATA_PORT   EQU 0378h
STATUS_PORT EQU 0379h
CTRL_PORT   EQU 037Ah
BUSY_MASK   EQU 80h             ; bit 7 del registro de estado

section .text
start:
    ; Esperar BUSY=1 (impresora lista)
.wait_ready:
    MOV  DX, STATUS_PORT
    IN   AL, DX
    MOV  BL, AL                 ; conservar el byte de estado para mostrarlo
    TEST AL, BUSY_MASK
    JZ   .wait_ready

    ; Enviar el caracter "A" (41h)
    MOV  DX, DATA_PORT
    MOV  AL, 41h
    OUT  DX, AL                 ; colocar el dato en el bus de datos

    ; Pulso STROBE (bit 0 del control)
    MOV  DX, CTRL_PORT
    IN   AL, DX
    AND  AL, 0FEh               ; STROBE = 0
    OUT  DX, AL

    ; Retardo minimo (~1 us)
    MOV  CX, 0Fh
.delay:
    LOOP .delay

    OR   AL, 01h                ; STROBE = 1 (inactivo)
    OUT  DX, AL

    ; Informar el resultado
    MOV  AH, 09h
    MOV  DX, msg_estado
    INT  21h
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
    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch
    INT  21h

section .data
msg_estado  DB 'Estado de LPT1 (puerto 379h): $'
msg_fin     DB 'h', 0Dh, 0Ah, 'Caracter enviado a LPT1 sin bloqueo.', 0Dh, 0Ah, '$'
