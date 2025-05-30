
;
;  Project     : Serial-to-MIDI Converter (RS-232 to MPU-401)
;  Author      : Jimmy Söderman Sers
;  Created     : 2010
;  Description : Real-time, two-way MIDI bridge between a PC’s RS-232
;                serial port and an MPU-401 interface (intelligent mode
;                not required). Uses a circular buffer, no lag, and no dropped events.
;                Runs headless from bootable media, no monitor or keyboard needed.
;
;  License     : Copyright © 2010 Jimmy Söderman Sers
;
; To-host MIDI Standard:
; Used by Yamaha, Roland, Korg, Alesis, and others. Common around 1995–2005.
; Uses a mini-DIN connector with RS-232 settings:
;   38400 baud, 8 data bits, 1 start bit, 1 stop bit, no parity.
;
; Supported Sound Modules and Keyboards:
;   Roland : SoundCanvas 55, SoundCanvas 88
;   Yamaha : TG100, MU50, MU80, MU5, MU10, MU15, QY100,
;            MU90 / MU90R, MU100 / MU100R, MU128,
;            CBX-K1XG, Disklavier
;   Kawai  : GMega, K5000
;   Korg   : 05R/W, X5, NS5R
;   Alesis : QuadraSynth, S4 Plus, QS series
;

; 10 bytes
%macro WAITVBL 0
%%retrace_start:
IN AL,DX
AND AL,8                ; Test the 4th bit
JZ %%retrace_start
%%retrace_end:
IN AL,DX
AND AL,8
JNZ %%retrace_end
%endmacro

JMP over                ; 3 bytes (fill with NOP)
ModeInfoTable           ; 256 byte table
TIMES 40 db 0           ;
LFB dd 0                ; Physical 0000:7c2b
TIMES 212 db 0          ;
                        ; 0x7c0 instead of 0
over:
ORG 7C00h
BITS 16
; section .text
JMP 0:$+5               ; CS=0:EIP points next instruction
PUSH    CS              ; 1 byte
PUSH    CS              ; 1 byte
POP     DS              ; 1 byte
POP     ES              ; 1 byte
Cylinder                ; 1 byte

CLI                     ; 1 byte
MOV     AX,0x9000       ; 3-5 bytes
MOV     SS,AX           ; 2 bytes
MOV     SP,0xffff       ; 3-5 bytes
STI                     ; 1 byte

; Disable NMI
IN      AL,70h
OR      AL,80h          ; Disables NMI (use AND AL,7Fh to enable NMI)
OUT     70h,AL
; OR 40, AND BF

MOV DI, ModeInfoTable   ; 3 bytes
MOV AX,04f01h           ; 3 bytes
MOV CX,4114h            ; 3 bytes 4115 = 32-bit
INT 10h                 ; 2 bytes
MOV AX,04F02h           ; 3 bytes
MOV BX,4114h            ; 3 bytes
INT 10h                 ; 2 bytes

; Enable A20
MOV     AL,0D1h         ; 2 bytes
OUT     64h,AL          ; 2 bytes
MOV     AL,0DFh         ; 2 bytes
OUT     60h,AL          ; 2 bytes

; Enable PS/2 A20
MOV     AL,2            ; 2 bytes
OUT     92h,AL          ; 2 bytes
MOV     [BDRV],DL       ; 3-5 bytes
LGDT    [GDT]           ; LIDT, IDTR 5 bytes
MOV     EAX,1           ; Zero-based sector, after MBR

L0:
PUSH    EAX             ; 1 byte
CALL    Read            ; Read from disk to ES:7E00h 2-5 bytes
CALL    Copy            ; Copy from buffer to protected mode 2-5 bytes
POP     EAX             ; 1 byte (2 bytes if rmode) 1 byte
INC     EAX             ; Next sector 2 byte (1 if 32-bit pmode) 1 byte
DEC     WORD [SECT]     ; Check if ended 3 bytes
JNZ     L0              ; 2 bytes

MOV     DX,3F2h         ; Shut down the floppy motor to turn off the LED 3 bytes
MOV     AL,0Ch          ; 2 bytes
OUT     DX,AL           ; 1 byte
CLI                     ; 1 byte
                        ; LIGDT here
MOV     EAX,CR0         ; 3 bytes
OR      AL,1            ; acc, imm 2 bytes
MOV     CR0,EAX         ; Go to protected mode 3 bytes
JMP DWORD CSEG:00100000h ; Jump to copied code in 1MB 5 bytes

; Read from disk to ES:7E00h
; In:    EAX        - zero-based sector
;        [ES:7E00h] - 512 bytes buffer
Read:
CDQ                     ; EDX=0 2 bytes if rmode 1 byte
MOV     EBX,18          ; Sectors per track 3 bytes
DIV     EBX             ; EAX=Track, EDX=sector-1. 3 bytes
MOV     CX,DX           ; CL=Sector-1, CH=0. 2 bytes
INC     CX              ; CL=Sector number. 1 byte
XOR     DX,DX           ; 2 bytes
MOV     BL,2            ; Heads. 2 bytes
DIV     EBX             ; 3 bytes
MOV     DH,DL           ; Head. 2 bytes
MOV     DL,[BDRV]       ; Boot drive. 3-5 bytes
XCHG    CH,AL           ; CH=Low 8 bits of cylinder number, AL=0 2 bytes
SHR     AX,2            ; AL[6:7]=High two bits of cylinder, AH=0 3 bytes
OR      CL,AL           ; CX=Cylinder and sector 2 bytes
MOV     BP,3            ; Retry counter 3 bytes
MOV     BX,7E00h        ; Buffer 3 bytes
.Retry:
MOV     AX,0201h        ; AL=Sectors to read 3 bytes
INT     13h             ; 2 bytes
JC      .Error          ; 2 bytes
RET                     ; 1 byte
.Error:
DEC     BP              ; 1 byte
JNZ     .Retry          ; near 8 or 16 bits
JMP     SHORT $         ; 2 bytes

; Copy from buffer to protected mode
; In:    [0000:7E00h] - 512 bytes buffer
;        DWORD [ADDR] - address to copy
; Out:   DWORD [ADDR] - added 512
Copy:
CLI                     ; 1 byte
MOV     EAX,CR0         ; 3 bytes
OR      AL,1            ; 2 bytes
MOV     CR0,EAX         ; Go to pmode 3 bytes

MOV     AX,DSEG         ; Null selectors to read/write 3 bytes
MOV     DS,AX           ; 2 bytes
MOV     ES,AX           ; 2 bytes
MOV     ESI,7E00h       ; Buffer 3 bytes
MOV     EDI,[ADDR]      ; Address to copy 3 bytes
MOV     ECX,512         ; Bytes to copy 3 bytes
ADD     [ADDR],ECX      ; Next 512 bytes in the address 3 bytes
REP                     ;
A32                     ; Add32 for next instruction
MOVSB                   ; Copy 2 byte together with REP and A32
MOV     EAX,CR0         ; 3 bytes
AND     AL,0FEh         ; 2 byte
MOV     CR0,EAX         ; 3 bytes
PUSH    CS              ; 1 byte
PUSH    CS              ; 1 byte (Restore segments)
POP     DS              ; 1 byte
POP     ES              ; 1 byte
RET                     ; 1 byte

; Selectors
; BYTE - [0:1]RPL,[2:2]table indicator, 0=GDT 1=LDT,[3:15]GDT descriptor
NSEG:   EQU     8*0
CSEG:   EQU     8*1
DSEG:   EQU     8*2
GDT:

; Null segment (used for GDT start & length storage)
DW      .ENDD-GDT       ; limit 16-bit
DD      GDT             ; base 24-bit + type 8-bit
DW      0               ; limit 4 bits more + flags + base last bits 24-31

; Code segment
; $-gdt, gdt2 label coming up next line
DW      0FFFFh
DW      0
DB      0
DB      10011010b       ; (9ah) type (11111010 CODE-USER)
DB      11001111b       ; (0CFh) last 4 bits are flags
DB      0

; Data & stack segments
DW      0FFFFh
DW      0
DB      0
DB      10010010b       ; (92h) present, ring0, data, expand up, writable (11110010 DATA & STACK-USER)
DB      11001111b       ; (cfh) page granular, 32-bit
DB      0

.ENDD:
ADDR:   DD      00100000h   ; Physical address to copy
SECT:   DW      100         ; Sectors to read from disk (w/o MBR)
BDRV:   DB      0           ; Boot drive
TIMES   510-($-$$) DB 0     ; Complete 510 bytes
DW      0AA55h              ; MBR end signature

; The 32-bit protected mode kernel code is loaded at 1 MB in physical RAM by the boot code
BITS 32

; Init MPU-401 & UART
; notyet:
; MOV DX,817
; IN AL,DX
; AND AL,64
; JNE notyet
MOV DX,817
MOV AL,63
OUT DX,AL

; OUT  1020,0           ; Interrupts off 
MOV DX,1019
MOV AL,128
OUT DX,AL

MOV DX,1016             ; 38400 baud word
MOV AL,3
OUT DX,AL
INC DX
MOV AL,0
OUT DX,AL

MOV DX,1019             ; 1 start bit, 8 data bits, 1 stop bit, no parity bit
MOV AL,3
OUT DX,AL

INC DX
MOV AL,11
OUT DX,AL
; OUT 1017,00h

MOV ECX,0
MOV EBX,128
MOV EDI,0
MOV ESI,128

mainloop:

; MPU READ
MOV DX,817
IN AL,DX
AND AL,128              ; AL=PEEK(817) AND 128
JNE SKIPMPUREAD         ; IF AL<>0 THEN GOTO SKIPMPUREAD
MOV DX,816
IN AL,DX
MOV [524288+ECX],AL     ; [BUFFER+ECX] = PEEK(816)
INC ECX
AND ECX,127             ; ECX=ECX+1 AND 127
SKIPMPUREAD:
CMP ECX,EBX
JE SKIPSERIALWRITE      ; IF ECX=EBX THEN GOTO SKIPSERIALWRITE

; SERIAL WRITE
MOV DX,1021
IN AL,DX
AND AL,32               ; AL=PEEK(1021) AND 32
JE SKIPSERIALWRITE      ; IF AL=0 THEN GOTO SKIPSERIALWRITE
MOV AL,[524288+EBX]     ; AL = [BUFFER+EBX]
INC EBX
AND EBX,127             ; EBX=EBX+1 AND 127
MOV DX,1016
OUT DX,AL               ; POKE 1016,AL
SKIPSERIALWRITE:

; SERIAL READ
MOV DX,1021
IN AL,DX
AND AL,1                ; AL=PEEK(1021) AND 1
JE SKIPSERIALREAD       ; IF AL=0 THEN GOTO SKIPSERIALREAD
MOV DX,1016
IN AL,DX
MOV [524416+EDI],AL     ; [BUFFER+128+EDI] = PEEK(1016)
INC EDI
AND EDI,127             ; EDI=EDI+1 AND 127
SKIPSERIALREAD:
CMP EDI,ESI
JE SKIPMPUWRITE         ; IF EDI=ESI THEN GOTO SKIPMPUWRITE

; MPU WRITE
MOV DX,817
IN AL,DX
AND AL,64               ; AL=PEEK(817) AND 64
JNE SKIPMPUWRITE        ; IF AL<>0 THEN GOTO SKIPMPUWRITE
MOV AL,[524416+ESI]     ; AL = [BUFFER+128+ESI]
INC ESI
AND ESI,127             ; ESI=ESI+1 AND 127
MOV DX,816
OUT DX,AL               ; POKE 816,AL
SKIPMPUWRITE:

JMP mainloop

TIMES 1474560-($-$$) DB 0 ; Complete 1.44 MB floppy-sized image