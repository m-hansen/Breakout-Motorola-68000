*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

CLEAR_SCREEN_TRAP           equ     11
REPAINT_SCREEN_TRAP         EQU     94

CLEAR_SCREEN_MAGIC_NUMBER   equ     $FF00

COLOR_BLACK                 equ     $00000000
COLOR_WHITE                 equ     $00FFFFFF

gameLoop:
    jsr clearScreen
    jsr swapBuffers
    jsr update
    jsr draw
    jsr gameLoop
   
clearScreen:
    move.l      #CLEAR_SCREEN_TRAP,d0
    move.w      #CLEAR_SCREEN_MAGIC_NUMBER,d1
    TRAP        #15
    rts
    
swapBuffers:
    move.l      #REPAINT_SCREEN_TRAP,d0
    TRAP        #15
    rts
    
update:
    rts
    
draw:
    rts

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
