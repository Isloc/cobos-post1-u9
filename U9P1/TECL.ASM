; TECL.ASM - Lectura del estado del teclado 8042 por polling
; Compila: nasm -f bin TECL.ASM -o TECL.COM
;
; Puerto 64h (Status Register): bit 0 = OBF (Output Buffer Full).
; Puerto 60h (Data Port): ultimo scancode recibido.
;
; Cambios respecto a la guia:
;  1) CLI al inicio y STI despues de leer el scancode. Con las interrupciones
;     habilitadas, el handler de INT 09h del BIOS (IRQ1) lee el puerto 60h en
;     cuanto llega la tecla y deja OBF en 0 antes de que el bucle lo observe.
;  2) Se ignoran los scancodes de tecla soltada (bit 7 en 1). Al lanzar el
;     programa con Enter, la liberacion de Enter (9Ch) llega justo despues y
;     el bucle la leia como si fuera la tecla esperada.

[BITS 16]
[ORG 0x100]

STATUS_KBD  EQU 64h             ; registro de estado del 8042
DATA_KBD    EQU 60h             ; puerto de datos del 8042
OBF_MASK    EQU 01h             ; bit 0: Output Buffer Full
BREAK_BIT   EQU 80h             ; bit 7 del scancode: tecla soltada

section .text
start:
    CLI                         ; IRQ1 no debe consumir el scancode
.poll:
    IN   AL, STATUS_KBD         ; leer registro de estado del 8042
    TEST AL, OBF_MASK           ; comprobar bit OBF
    JZ   .poll                  ; OBF=0: no hay dato listo, repetir

    IN   AL, DATA_KBD           ; leer scancode del Data Port
    TEST AL, BREAK_BIT          ; tecla soltada (break code)?
    JNZ  .poll                  ; si: ignorar y seguir esperando una pulsacion
    MOV  BL, AL                 ; guardar scancode (make code) en BL
    STI                         ; scancode leido: rehabilitar interrupciones

    ; Mostrar el scancode en hexadecimal (conversion manual)
    MOV  AH, 02h                ; funcion DOS: imprimir caracter
    MOV  DL, BL
    SHR  DL, 4                  ; nibble alto
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .printH
    ADD  DL, 07h                ; ajuste para A-F
.printH:
    INT  21h

    MOV  DL, BL
    AND  DL, 0Fh                ; nibble bajo
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .printL
    ADD  DL, 07h
.printL:
    INT  21h

    MOV  AH, 02h
    MOV  DL, 0Dh                ; CR
    INT  21h
    MOV  DL, 0Ah                ; LF
    INT  21h

    MOV  AH, 4Ch
    INT  21h                    ; terminar programa
