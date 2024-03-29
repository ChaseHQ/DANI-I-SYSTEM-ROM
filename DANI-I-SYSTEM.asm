;-------------------------------------------------
;-------------DANI-I-SYSTEM-ROM-------------------
;-------------------------------------------------

;$0000 - $7FFF => SRAM    32k b0.xxxxxxxxxxxxxxx   -- Implemented
;$8000 - $8FFF => VRAM    04k b1000.xxxxxxxxxxxx   -- Implemented
;$9000 - $90FF => VIA      1b b10010000.xxxxxxxx   -- Implemented
;$9100 - $91FF => ACIA     1b b10010001.xxxxxxxx
;$9200 - $92FF => PIA      1b b10010010.xxxxxxxx
;$C000 - $FFFF => ROM     16k b11.xxxxxxxxxxxxxx   -- Implemented

;40x30 Characters

DEBUG .SET 0 ; Debug on = 1, Debug off = 0
    
    .OPT Proc65c02
    
;-------------EQUATES-----------------------------
VIA:              .SET $9000
TIMER_COUNT:      .SET $1E            ; Timer Counter (1F is free to be used as GSB Timer Count)
;-------------EO-EQUATES--------------------------
    .START START
    .ORG $C000
    
    .INCLUDE ".\DANI-MATH.asm"           ; Math Subroutines and Helpers
    .INCLUDE ".\SYS\DANI-I-SYS.asm"      ; Main DANI-I-SYSTEM - (Includes String Functions, Input System, and VGA System)
    .INCLUDE ".\SYS\DANI-I-DRTC.asm"     ; DANI-I DRIVE & RTC
    .INCLUDE ".\DANI-I-COMMANDER.asm"    ; Main Commander Program
    .INCLUDE ".\BASIC\DANI-EH-BASIC.asm" ; ehBasi
    
RESET:
    LDX #$FF              ; Initialize the Stack Pointer
    TXS                   ; Transfer X to Stack 
START:
    JSR SYS_INIT          ; Initialize the System
    JSR DVGA_DRAWLOGO     ; Draw the DANI-I Logo
    JMP DANI_CMD_MAIN     ; Main Program

;----------SUB-ROUTINES--------------------------------------------------------------------------------------------
    
;----------System Initialization -----------------
;-- Parameters - VOID
;-------------------------------------------------
SYS_INIT:
    JSR SYS_INIT6522                         ; Init and setup the 6522 
    JSR DVGA_LOADDEFCHARACTERS               ; Load the Default Character set
    JSR DVGA_BLANKSCREEN                     ; Blank the Screen
    CLI                                      ; Enable Interrupts
    RTS

;----------System Setup 6522----------------------
;-- Parameters - VOID
;-------------------------------------------------
SYS_INIT6522:
    LDA #@00000000           ; Set all Pins to input
    STA VIA+$02              ; And Set DDR to that on Port B
    M_DRTC_SET_OUT           ; Set Drive to Output Mode
    LDA #@00001000           ; Negative Active PB & Handshake on CA2
    STA VIA+$0C
    ; Now Set up Timer
    LDA #$FF
    STA VIA+$04              ; Lo Byte Counter FF
    LDA #$FF
    STA VIA+$05              ; Hi Byte Counter FF
    LDA #@01000011           ; Enable Continuas Interrupts on T1 & LATCH on PA & PB
    STA VIA+$0B              ; Put it in ACR
    ; Enable Interrupts
    LDA #@11010000           ; Enable Interrupt on Timer1 AND CB1
    STA VIA+$0E
    RTS
    
;----------Interrupt Request----------------------
;-- Parameters - VOID
;-------------------------------------------------
SYS_IRQ:
    PHA
    ; Did a Timer go off or Is Data on PortB
    LDA #@00010000   ; Test for CB1
    BIT VIA+$0D      ; Flag Register of VIA
    BEQ .checkTimer1 ; CB1 didn't interrupt Check Timer
    LDA VIA+$00      ; Read from PortB of the VIA
    STA INPUT_CBUF   ; Store it in input Buffer 
.checkTimer1
    LDA #@01000000   ; Check Timer1 Bit
    BIT VIA+$0D      ; Flag Register of VIA
    BEQ .done        ; Not the Timer1 Bit calling Interrupt goto Done
    LDA VIA+$04      ; Read from T1L to clear bit
    INC TIMER_COUNT  ; Increase the Timer
    ; Done checking on the VIA
.done
    PLA
    RTI

;---------VECTORS----------------------------------
VECTORS:
    .ORG $FFFA     ; 6502 Starts reading its vectors here
    .word RESET    ; NMI
    .word RESET    ; RESET
    .WORD SYS_IRQ  ; IRQ-BRK

   .END