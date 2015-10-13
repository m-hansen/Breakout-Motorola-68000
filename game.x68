*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:
    
ALL_REG                     reg     D0-D7/A0-A6
ALL_REG_SIZE_IN_BYTES       equ     60

DISABLE_DOUBLE_BUFFERING    equ     16
ENABLE_DOUBLE_BUFFERING     equ     17
CLEAR_SCREEN_MAGIC_NUMBER   equ     $FF00

* TRAP commands
CLEAR_SCREEN_TRAP           equ     11
KEY_PRESS_TRAP              equ     19
OUTPUT_WINDOW_TRAP          equ     33
SET_PEN_COLOR_TRAP          equ     80
SET_FILL_COLOR_TRAP         equ     81
DRAW_RECTANGLE_TRAP         equ     87
DRAW_ELLIPSE_TRAP           equ     88
SET_DRAWING_MODE_TRAP       equ     92
REPAINT_SCREEN_TRAP         equ     94
DRAW_STRING_GRAPHIC_TRAP    equ     95

OUTPUT_WINDOW_WIDTH         equ     1024
OUTPUT_WINDOW_HEIGHT        equ     768

* Colors
COLOR_BLACK                 equ     $00000000
COLOR_BLUE                  equ     $00FF0000
COLOR_RED                   equ     $000000FF
COLOR_WHITE                 equ     $00FFFFFF

PEN_COLOR                   equ     (ALL_REG_SIZE_IN_BYTES+4)
FILL_COLOR                  equ     (ALL_REG_SIZE_IN_BYTES+4)

PADDLE_WIDTH                equ     125
PADDLE_HEIGHT               equ     15
PADDLE_SPEED                equ     1
INITIAL_PADDLE_POSITION_X   equ     ((OUTPUT_WINDOW_WIDTH>>1)-(PADDLE_WIDTH>>1))
INITIAL_PADDLE_POSITION_Y   equ     (OUTPUT_WINDOW_HEIGHT-20)

BRICK_WIDTH                 equ     128
BRICK_HEIGHT                equ     40
NUMBER_OF_BRICK_ROWS        equ     4

BALL_DIAMETER               equ     20

LEFT_ARROW_KEY_CODE         equ     $25
UP_ARROW_KEY_CODE           equ     $26
RIGHT_ARROW_KEY_CODE        equ     $27
DOWN_ARROW_KEY_CODE         equ     $28
SPACEBAR_KEY_CODE           equ     $32

* Argument stack offsets for use with collision detection function
COLLISION_OBJ_A_LEFT        equ     (ALL_REG_SIZE_IN_BYTES+32)
COLLISION_OBJ_A_TOP         equ     (ALL_REG_SIZE_IN_BYTES+28)
COLLISION_OBJ_A_RIGHT       equ     (ALL_REG_SIZE_IN_BYTES+24)
COLLISION_OBJ_A_BOTTOM      equ     (ALL_REG_SIZE_IN_BYTES+20)
COLLISION_OBJ_B_LEFT        equ     (ALL_REG_SIZE_IN_BYTES+16)
COLLISION_OBJ_B_TOP         equ     (ALL_REG_SIZE_IN_BYTES+12)
COLLISION_OBJ_B_RIGHT       equ     (ALL_REG_SIZE_IN_BYTES+8)
COLLISION_OBJ_B_BOTTOM      equ     (ALL_REG_SIZE_IN_BYTES+4)

* Stack offset for drawing bricks
BRICK_POSITION_X            equ     (ALL_REG_SIZE_IN_BYTES+8)
BRICK_POSITION_Y            equ     (ALL_REG_SIZE_IN_BYTES+4)

initialize:
    * Resize output window
    move.l      #OUTPUT_WINDOW_WIDTH,d1
    swap.w      d1
    move.w      #OUTPUT_WINDOW_HEIGHT,d1
    move.w      #OUTPUT_WINDOW_TRAP,d0
    TRAP        #15

    * Enable double buffering
    move.l      #SET_DRAWING_MODE_TRAP,d0
    move.b      #ENABLE_DOUBLE_BUFFERING,d1
    TRAP        #15
    
    * Display loading text
    move.l      #DRAW_STRING_GRAPHIC_TRAP,d0
    lea         LoadingText,a1              ; Location of the string to draw
    move.w      #20,d1                      ; X position to draw at
    move.w      #20,d2                      ; Y position to draw at
    TRAP        #15
    jsr         swapBuffers
    
    * Load the background bitmap
    jsr Begin
    jsr         swapBuffers
    
    * Draw a circle
    move.l      #COLOR_WHITE,-(sp)
    jsr         setPenColorA
    add.l       #4,sp
    
    move.l      #COLOR_RED,-(sp)
    jsr         setFillColor
    add.l       #4,sp
    
    * Initialize ball position and velocity
    jsr         resetBall
    jsr         drawBall

    move.l      #INITIAL_PADDLE_POSITION_X,PaddlePositionX
    
    jsr         drawPaddle
    jsr         swapBuffers
    
    *jmp         END

gameLoop:
    *jsr clearScreen
    jsr swapBuffers
    
    jsr handleInput
    
    jsr update
    jsr draw
    
    jmp gameLoop
   
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
    * Update the ball position
    add.l       d6,d1
    add.l       d7,d2
    add.l       d6,d3
    add.l       d7,d4
    
    * Check for collision between ball and paddle
    * Pass in the bounds of the ball
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d3,-(sp)
    move.l      d4,-(sp)
    * Pass in the bounds of the paddle
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d3,-(sp)
    move.l      d4,-(sp)
    jsr         checkForCollision
    add.l       #32,sp
    
    * Check if the ball is within the bounds of the screen
    cmp.l       #0,d2
    blt         ballReflectTopBound
    cmp.l       #0,d1
    blt         ballReflectLeftBound
    cmp.l       #OUTPUT_WINDOW_WIDTH,d3
    bgt         ballReflectRightBound
    cmp.l       #OUTPUT_WINDOW_HEIGHT,d4
    bgt         loseLife
    
    * Check for a collision between the ball and paddle
    * Pass in the location of the paddle as objectA
    move.l      PaddlePositionX,d0
    move.l      d0,-(sp)
    move.l      #INITIAL_PADDLE_POSITION_Y,-(sp)
    add.l       #PADDLE_WIDTH,d0
    move.l      d0,-(sp)
    move.l      #(INITIAL_PADDLE_POSITION_Y+PADDLE_HEIGHT),-(sp)
    * Pass in the location of the ball as objectB
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d3,-(sp)
    move.l      d4,-(sp)
    jsr         checkForCollision
    add.l       #32,sp
    
    cmpi.l      #1,d0
    bne         skipCollide
    jsr         resetBall
skipCollide:
    rts
    
resetBall:
    move.l      BallVelocityX,d6
    move.l      BallVelocityY,d7
    move.w      #((OUTPUT_WINDOW_WIDTH>>1)-(BALL_DIAMETER>>1)),d1
    move.w      #((OUTPUT_WINDOW_HEIGHT>>1)-(BALL_DIAMETER>>1)),d2
    move.w      d1,d3
    add.l       #BALL_DIAMETER,d3
    move.w      d2,d4
    add.l       #BALL_DIAMETER,d4
    rts
    
reverseBallVelocityX:
    muls.w      #-1,d7
    move.l      #OUTPUT_WINDOW_WIDTH,d4
    rts
    
ballReflectLeftBound:
    muls.w      #-1,d6
    move.l      #0,d1
    rts
    
ballReflectRightBound:
    muls.w      #-1,d6
    move.l      #OUTPUT_WINDOW_WIDTH,d3
    rts
    
ballReflectTopBound:
    muls.w      #-1,d7
    move.l      #0,d4
    rts
    
loseLife:
* TODO decrement lives, end game if zero, reset ball and paddle position
    muls.w      #-1,d7
    move.l      #OUTPUT_WINDOW_HEIGHT,d4
    rts
    
draw:
    jsr drawBall
    jsr drawPaddle
    jsr drawAllBricks
    rts
    
handleInput:
    movem.l     ALL_REG,-(sp)
    move.l      #KEY_PRESS_TRAP,d0
    move.l      #(LEFT_ARROW_KEY_CODE<<24+RIGHT_ARROW_KEY_CODE<<16+SPACEBAR_KEY_CODE<<8),d1
    TRAP        #15
    cmpi.l      #0,d1
    beq         noInput
checkLeftMovement:
    btst.l      #24,d1
    beq         checkRightMovement
    move.l      -PaddleVelocityX,d0
    add.l       d0,PaddlePositionX
checkRightMovement:
    btst.l      #16,d1
    beq         checkLaunchKey
    move.l      PaddleVelocityX,d0
    add.l       d0,PaddlePositionX
checkLaunchKey:
    btst.l      #8,d1
    beq         noInput
noInput:
    movem.l     (sp)+,ALL_REG
    rts
    
setPenColorA:
    movem.l     ALL_REG,-(sp)
    move.l      #SET_PEN_COLOR_TRAP,d0
    move.l      PEN_COLOR(sp),d1
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts
    
setFillColor:
    movem.l     ALL_REG,-(sp)
    move.l      #SET_FILL_COLOR_TRAP,d0
    move.l      FILL_COLOR(sp),d1
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts
    
drawBall:
    *movem.l     ALL_REG,-(sp)
    move.l      #DRAW_ELLIPSE_TRAP,d0
   * move.w      #0,d1
   * move.w      #0,d2
   * move.w      #BALL_DIAMETER,d3
   * move.w      #BALL_DIAMETER,d4
    TRAP        #15
    *movem.l     (sp)+,ALL_REG
    rts
    
drawAllBricks:
    movem.l     ALL_REG,-(sp)
    move.l      #(OUTPUT_WINDOW_WIDTH/BRICK_WIDTH),d6       ; Number of bricks to draw horizontally
    move.l      #NUMBER_OF_BRICK_ROWS,d7                    ; Number of bricks to draw vertically
    move.l      d6,d0                                       ; The horizontal counter to be decremented
    subi.l      #1,d0                                       ; Immediately dectement the horizontal loop counter so it won't exceed the bounds
    move.l      d7,d1                                       ; The vertical counter to be decremented
    subi.l      #1,d1                                       ; Immediately dectement the vertical loop counter so it won't exceed the bounds
    
drawHorizontalBricks:
    move.l      d0,d4                                       ; Copy the horizontal counter
    mulu.w      #BRICK_WIDTH,d4                             ; Multiply by the width to get the horizontal position
    move.l      d1,d5                                       ; Copy the vertical counter
    mulu.w      #BRICK_HEIGHT,d5                            ; Multiply by the height to get the vertical position
    move.l      d4,-(sp)
    move.l      d5,-(sp)
    jsr         drawBrick
    add.l       #8,sp
    dbra        d0,drawHorizontalBricks
    
drawVerticalBricks:
    move.l      d6,d0
    subi.l      #1,d0                                       ; Reset the horizontal counter
    dbra        d1,drawHorizontalBricks
    movem.l     (sp)+,ALL_REG
    rts

* Draw an individual brick
* d4 is used for the X position, d5 is used for the Y position
drawBrick:
    movem.l     ALL_REG,-(sp)
    move.l      #DRAW_RECTANGLE_TRAP,d0
    move.l      BRICK_POSITION_X(sp),d1
    move.l      BRICK_POSITION_Y(sp),d2
    move.l      d1,d3                           ; Copy the x position
    add.l       #BRICK_WIDTH,d3                 ; Add the width
    move.l      d2,d4                           ; Copy the y position
    add.l       #BRICK_HEIGHT,d4                ; Add the height
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts
    
drawPaddle:
    movem.l     ALL_REG,-(sp)
    move.l      #DRAW_RECTANGLE_TRAP,d0
    move.l      PaddlePositionX,d1
    move.w      #INITIAL_PADDLE_POSITION_Y,d2
    move.w      d1,d3                                               ; Copy the X paddle position
    addi.w      #PADDLE_WIDTH,d3
    move.w      #(INITIAL_PADDLE_POSITION_Y+PADDLE_HEIGHT),d4
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts

END:
    SIMHALT             ; halt simulator

* Put variables and constants here
    
LoadingText         dc.l    'Loading...',0
BallVelocityX       dc.l    1
BallVelocityY       dc.l    1
PaddlePositionX     ds.l    1
PaddleVelocityX     dc.l    1
WasKeyPressed       ds.b    1
SevenSegmentTable   dc.b    $3F
                    dc.b    $06
                    dc.b    $5B
                    dc.b    $4F
                    dc.b    $66
                    dc.b    $6D
                    dc.b    $7D
                    dc.b    $27
                    dc.b    $7F
                    dc.b    $6F
                    ds.l    0
                    include     "drawBitmap.x68"
                    include     "collisionDetection.x68"

    END    START        ; last line of source









*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
