; TECLGUIA.ASM - Version literal de TECL.ASM tal como aparece en la guia (sin CLI/STI)
; Se conserva unicamente para documentar que el polling con las interrupciones
; habilitadas no termina en DOSBox: el handler de INT 09h consume el scancode
; antes de que el bucle observe OBF=1.
; Compila: nasm -f bin TECLGUIA.ASM -o TECLGUIA.COM

[BITS 16]
[ORG 0x100]

start:
.poll:
    IN  AL, 64h
    TEST AL, 01h
    JZ  .poll

    IN  AL, 60h
    MOV BL, AL

    MOV AH, 02h
    MOV DL, BL
    SHR DL, 4
    ADD DL, 30h
    CMP DL, 3Ah
    JL  .printH
    ADD DL, 07h
.printH:
    INT 21h

    MOV DL, BL
    AND DL, 0Fh
    ADD DL, 30h
    CMP DL, 3Ah
    JL  .printL
    ADD DL, 07h
.printL:
    INT 21h

    MOV AH, 02h
    MOV DL, 0Dh
    INT 21h
    MOV DL, 0Ah
    INT 21h

    MOV AH, 4Ch
    INT 21h
