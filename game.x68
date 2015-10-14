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
GET_TIME_TRAP               equ     8
CLEAR_SCREEN_TRAP           equ     11
KEY_PRESS_TRAP              equ     19
RETURN_CYCLE_COUNT_TRAP     equ     31
OUTPUT_WINDOW_TRAP          equ     33
SET_PEN_COLOR_TRAP          equ     80
SET_FILL_COLOR_TRAP         equ     81
DRAW_RECTANGLE_TRAP         equ     87
DRAW_ELLIPSE_TRAP           equ     88
SET_DRAWING_MODE_TRAP       equ     92
REPAINT_SCREEN_TRAP         equ     94
DRAW_STRING_GRAPHIC_TRAP    equ     95

OUTPUT_WINDOW_WIDTH         equ     1280
OUTPUT_WINDOW_HEIGHT        equ     720

* Colors
COLOR_BLACK                 equ     $00000000
COLOR_BLUE                  equ     $00FF0000
COLOR_PURPLE                equ     $00800080
COLOR_RED                   equ     $000000FF
COLOR_WHITE                 equ     $00FFFFFF

PEN_COLOR                   equ     (ALL_REG_SIZE_IN_BYTES+4)
FILL_COLOR                  equ     (ALL_REG_SIZE_IN_BYTES+4)

PADDLE_WIDTH                equ     125
PADDLE_HEIGHT               equ     15
PADDLE_SPEED                equ     1
PADDLE_BORDER_COLOR         equ     COLOR_BLACK
PADDLE_FILL_COLOR           equ     COLOR_WHITE
INITIAL_PADDLE_POSITION_X   equ     ((OUTPUT_WINDOW_WIDTH>>1)-(PADDLE_WIDTH>>1))
INITIAL_PADDLE_POSITION_Y   equ     (OUTPUT_WINDOW_HEIGHT-20)

BRICK_WIDTH                 equ     128
BRICK_HEIGHT                equ     30
NUMBER_OF_BRICK_ROWS        equ     4

BALL_DIAMETER               equ     20
BALL_BORDER_COLOR           equ     COLOR_WHITE
BALL_FILL_COLOR             equ     COLOR_PURPLE

LEFT_ARROW_KEY_CODE         equ     $25
UP_ARROW_KEY_CODE           equ     $26
RIGHT_ARROW_KEY_CODE        equ     $27
DOWN_ARROW_KEY_CODE         equ     $28
SPACEBAR_KEY_CODE           equ     ' '

LARGE_NUMBER_FOR_SEED       equ     $5678

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
    jsr         LoadBitmap
    jsr         swapBuffers
    
    * Initialize ball position and velocity
    lea         BallVelocityX,a5
    lea         BallVelocityY,a6
    jsr         resetBall

    * Initialize paddle position
    move.l      #INITIAL_PADDLE_POSITION_X,PaddlePositionX
    
    * Display the bricks
    jsr         seedRandomNumber
    jsr         drawAllBricks

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
    
* Calculate the inval rect   
calculateBallInvalRect:
    movem.l     ALL_REG,-(sp)
    move.l      #1,d0               ; Used as padding around the inval rectangle
    
    * Adjust padding for each side
    sub.l       d0,d1
    sub.l       d0,d2
    add.l       d0,d3
    add.l       d0,d4
    
    * Draw the image
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d4,-(sp)
    move.l      d3,-(sp)
    move.l      #BITMAP_LEFT_X,-(sp)
    move.l      #BITMAP_TOP_Y,-(sp)
    jsr         drawBitmap
    add.l       #24,sp
    
    movem.l     (sp)+,ALL_REG
    rts
    
calculatePaddleInvalRect:
    movem.l     ALL_REG,-(sp)
    move.l      #1,d0               ; Used as padding around the inval rectangle

    * Get the paddle coordinates
    move.l      PaddlePositionX,d1
    move.l      #INITIAL_PADDLE_POSITION_Y,d2
    move.l      d1,d3
    add.l       #PADDLE_WIDTH,d3
    move.l      d2,d4
    add.l       #PADDLE_HEIGHT,d4
    
    * Adjust padding for each side
    sub.l       d0,d1
    sub.l       d0,d2
    add.l       d0,d3
    add.l       d0,d4
    
    * Draw the image
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d4,-(sp)
    move.l      d3,-(sp)
    move.l      #BITMAP_LEFT_X,-(sp)
    move.l      #BITMAP_TOP_Y,-(sp)
    jsr         drawBitmap
    add.l       #24,sp
    movem.l     (sp)+,ALL_REG
    rts
    
    movem.l     (sp)+,ALL_REG
    rts
    
update:
    * Check if paddle is moving
    *move.l      PaddleVelocityX,d6
    *cmpi.l      #0,d6
    *beq         noUpdateFromPaddle
    *jsr         calculatePaddleInvalRect
*noUpdateFromPaddle:

    * Update the ball position
    move.l      BallVelocityX,d6
    move.l      BallVelocityY,d7
    
    * Check if the ball is moving
    cmpi.l      #0,d6
    bne         updateNeededFromBall
    cmpi.l      #0,d7
    beq         noUpdateFromBall
updateNeededFromBall:
    jsr calculateBallInvalRect
noUpdateFromBall:  
    
    * Check if the ball is within the bounds of the screen
    cmp.l       #0,d2
    blt         ballReflectTopBound
    cmp.l       #0,d1
    blt         ballReflectLeftBound
    cmp.l       #(OUTPUT_WINDOW_WIDTH-BALL_DIAMETER),d1
    bgt         ballReflectRightBound
    cmp.l       #(OUTPUT_WINDOW_HEIGHT-BALL_DIAMETER),d2
    bgt         loseLife
    
    add.l       d6,d1
    add.l       d7,d2
    
    * Keep the paddle within the bounds of the screen
    lea         PaddlePositionX,a4
    cmpi.l      #0,(a4)                                     ; Check to see if the paddle has exceeded the left bounds
    blt         positionPaddleOnLeft
    cmp.l       #(OUTPUT_WINDOW_WIDTH-PADDLE_WIDTH),(a4)    ; Check to see if the paddle has exceeded the right bounds
    ble         paddleInBounds
    move.l      #(OUTPUT_WINDOW_WIDTH-PADDLE_WIDTH),(a4)    ; Re-position the paddle on the right side of the screen
    jmp         paddleInBounds
positionPaddleOnLeft:
    move.l      #0,(a4)                                     ; Re-position the paddle on the left side of the screen
paddleInBounds:
    
    * Check for a collision between the ball and paddle
    * Pass in the location of the paddle as objectA
    move.l      (a4),d0                                     ; Make a copy of PaddlePositionX
    move.l      d0,-(sp)
    move.l      #INITIAL_PADDLE_POSITION_Y,-(sp)
    add.l       #PADDLE_WIDTH,d0
    move.l      d0,-(sp)
    move.l      #(INITIAL_PADDLE_POSITION_Y+PADDLE_HEIGHT),-(sp)
    * Pass in the location of the ball as objectB
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d1,d3                   ; Copy the X position
    addi.l      #BALL_DIAMETER,d3       ; Account for the size
    move.l      d3,-(sp)
    move.l      d2,d4                   ; Copy the y position
    addi.l      #BALL_DIAMETER,d4       ; Account for the size
    move.l      d4,-(sp)
    jsr         checkForCollision
    add.l       #32,sp
    
    cmpi.l      #1,d0                   ; The return value from the collision check will be located in register d0, 1 indicates a collision occurred
    bne         skipCollide
    jsr         resetBall
skipCollide:

    rts
    
resetBall:
    move.l      #0,BallVelocityX
    move.l      #0,BallVelocityY
    move.w      #((OUTPUT_WINDOW_WIDTH>>1)-(BALL_DIAMETER>>1)),d1
    move.w      #((OUTPUT_WINDOW_HEIGHT>>1)-(BALL_DIAMETER>>1)),d2
    move.w      d1,d3
    add.l       #BALL_DIAMETER,d3
    move.w      d2,d4
    add.l       #BALL_DIAMETER,d4
    rts
    
ballReflectLeftBound:
    muls.w      #-1,d6
    move.l      d6,BallVelocityX
    move.l      #0,d1
    rts
    
ballReflectRightBound:
    muls.w      #-1,d6
    move.l      d6,BallVelocityX
    move.l      #(OUTPUT_WINDOW_WIDTH-BALL_DIAMETER),d1
    rts
    
ballReflectTopBound:
    muls.w      #-1,d7
    move.l      d7,BallVelocityY
    move.l      #0,d2
    rts
    
loseLife:
* TODO decrement lives, end game if zero, reset ball and paddle position
    muls.w      #-1,d7
    move.l      d7,BallVelocityY
    move.l      #(OUTPUT_WINDOW_HEIGHT-BALL_DIAMETER),d2
    rts
    
draw:
    jsr drawBall
    jsr drawPaddle
    rts
    
handleInput:
    movem.l     ALL_REG,-(sp)
    move.l      #KEY_PRESS_TRAP,d0
    move.l      #(LEFT_ARROW_KEY_CODE<<24+RIGHT_ARROW_KEY_CODE<<16+SPACEBAR_KEY_CODE<<8+'R'),d1
    TRAP        #15
    cmpi.l      #0,d1
    beq         noInput
checkLeftMovement:
    btst.l      #24,d1
    beq         checkRightMovement
    jsr         calculatePaddleInvalRect
    move.l      -PaddleVelocityX,d0
    add.l       d0,PaddlePositionX
checkRightMovement:
    btst.l      #16,d1
    beq         checkLaunchKey
    jsr         calculatePaddleInvalRect
    move.l      PaddleVelocityX,d0
    add.l       d0,PaddlePositionX
checkLaunchKey:
    btst.l      #8,d1
    beq         checkResetKey
    move.l      #1,d0
    move.l      d0,BallVelocityX
    move.l      d0,BallVelocityY
checkResetKey:
    btst.l      #0,d1
    bne         initialize        
noInput:
    movem.l     (sp)+,ALL_REG
    rts
    
setPenColor:
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
    
    * Set the ball border color
    move.l      #BALL_BORDER_COLOR,-(sp)
    jsr         setPenColor
    add.l       #4,sp
    
    * Set the ball fill color
    move.l      #BALL_FILL_COLOR,-(sp)
    jsr         setFillColor
    add.l       #4,sp
    
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
drawBrick:
    movem.l     ALL_REG,-(sp)
    
    * Set the paddle border color
    move.l      #COLOR_WHITE,-(sp)
    jsr         setPenColor
    add.l       #4,sp
    
    * Set the paddle fill color
    jsr         getRandomLongIntoD6
    lsl.l       #BITS_IN_BYTE,d6                ; Shift left (then right in the next instruction) to clear the alpha value
    lsr.l       #BITS_IN_BYTE,d6                ; This gives a more balanced result than immediately shifting right due to the nature of the random function
    move.l      d6,-(sp)
    jsr         setFillColor
    add.l       #4,sp
    
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
    
    * Set the paddle border color
    move.l      #PADDLE_BORDER_COLOR,-(sp)
    jsr         setPenColor
    add.l       #4,sp
    
    * Set the paddle fill color
    move.l      #PADDLE_FILL_COLOR,-(sp)
    jsr         setFillColor
    add.l       #4,sp
    
    * Draw the paddle
    move.l      #DRAW_RECTANGLE_TRAP,d0
    move.l      PaddlePositionX,d1
    move.w      #INITIAL_PADDLE_POSITION_Y,d2
    move.w      d1,d3                                               ; Copy the X paddle position
    addi.w      #PADDLE_WIDTH,d3
    move.w      #(INITIAL_PADDLE_POSITION_Y+PADDLE_HEIGHT),d4
    TRAP        #15
    
    movem.l     (sp)+,ALL_REG
    rts
    
seedRandomNumber
    movem.l     ALL_REG,-(sp)
    clr.l       d6
    move.b      #GET_TIME_TRAP,d0
    TRAP        #15
    move.l      d1,d6
    mulu        #LARGE_NUMBER_FOR_SEED,d6
    move.l      d6,RandomNumberSeed
    movem.l     (sp)+,ALL_REG
    rts

getRandomLongIntoD6:
    movem.l     d0,-(sp)
    movem.l     d1,-(sp)
    move.l      RandomNumberSeed,d6
    mulu        #LARGE_NUMBER_FOR_SEED,d6
    move.l      #RETURN_CYCLE_COUNT_TRAP,d0
    TRAP        #15
    mulu        d1,d6
    bcs         nocarry
    add.l       #1,d6
nocarry:
    move.l      d6,RandomNumberSeed
    movem.l     (sp)+,d1
    movem.l     (sp)+,d0
    rts

END:
    SIMHALT             ; halt simulator

* Put variables and constants here
    
LoadingText         dc.l    'Loading...',0
RandomNumberSeed    ds.l    1
BallPositionX       ds.l    1
BallPositionY       ds.l    1
BallVelocityX       ds.l    1
BallVelocityY       ds.l    1
PaddlePositionX     ds.l    1
PaddleVelocityX     dc.l    1
WasKeyPressed       ds.b    1
SevenSegmentTable   dc.b    $3F,$06,$5B,$4F,$66,$6D,$7D,$27,$7F,$6F
                    ds.l    0
                    include     "drawBitmap.x68"
                    include     "collisionDetection.x68"

    END    START        ; last line of source














*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
