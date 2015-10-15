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
DRAW_LINE_TRAP              equ     84
DRAW_RECTANGLE_TRAP         equ     87
DRAW_ELLIPSE_TRAP           equ     88
SET_DRAWING_MODE_TRAP       equ     92
SET_PEN_WIDTH_TRAP          equ     93
REPAINT_SCREEN_TRAP         equ     94
DRAW_STRING_GRAPHIC_TRAP    equ     95

FRACTIONAL_BITS             equ     8
FRACTIONAL_MULTIPLIER       equ     256

OUTPUT_WINDOW_WIDTH         equ     1280
OUTPUT_WINDOW_HEIGHT        equ     720

* Colors
COLOR_BLACK                 equ     $00000000
COLOR_BLUE                  equ     $00FF0000
COLOR_PURPLE                equ     $00800080
COLOR_RED                   equ     $000000FF
COLOR_WHITE                 equ     $00FFFFFF

PEN_COLOR                   equ     (ALL_REG_SIZE_IN_BYTES+4)
PEN_WIDTH                   equ     (ALL_REG_SIZE_IN_BYTES+4)
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
NUMBER_OF_BRICK_COLUMNS     equ     10
BRICK_OFFSET_X              equ     0
BRICK_OFFSET_Y              equ     4
BRICK_OFFSET_ACTIVE         equ     8

BALL_SPEED                  equ     384                 ; 256 * 1.5
BALL_DIAMETER               equ     20
BALL_BORDER_COLOR           equ     COLOR_WHITE
BALL_FILL_COLOR             equ     COLOR_PURPLE

LED_POSITION_X              equ     (OUTPUT_WINDOW_WIDTH-40)
LED_POSITION_Y              equ     (OUTPUT_WINDOW_HEIGHT-40)
LED_SEGMENT_LENGTH          equ     10
LED_PEN_SIZE                equ     3

LEFT_ARROW_KEY_CODE         equ     $25
UP_ARROW_KEY_CODE           equ     $26
RIGHT_ARROW_KEY_CODE        equ     $27
DOWN_ARROW_KEY_CODE         equ     $28
SPACEBAR_KEY_CODE           equ     $20

LARGE_NUMBER_FOR_SEED       equ     $5678

LOADING_TEXT_X              equ     20
LOADING_TEXT_Y              equ     20

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
    move.w      #LOADING_TEXT_X,d1
    move.w      #LOADING_TEXT_Y,d2
    TRAP        #15
    jsr         swapBuffers
    
    * Load the background bitmap
    jsr         LoadBitmap
    jsr         swapBuffers
    
    * Initialize paddle position and velocity
    move.l      #INITIAL_PADDLE_POSITION_X,PaddlePositionX
    move.l      #PADDLE_SPEED,PaddleVelocityX
    
    move.l      #5,Lives
    
    * Display the bricks
    jsr         seedRandomNumber
    jsr         drawAllBricks
    
    * Initialize ball position and velocity
    move.l      #0,d6
    move.l      #0,d7
    move.l      #((OUTPUT_WINDOW_WIDTH>>1)-(BALL_DIAMETER>>1))<<FRACTIONAL_BITS,d1
    move.l      #((OUTPUT_WINDOW_HEIGHT>>1)-(BALL_DIAMETER>>1))<<FRACTIONAL_BITS,d2
    move.l      d1,d3
    add.l       #BALL_DIAMETER<<FRACTIONAL_BITS,d3
    move.l      d2,d4
    add.l       #BALL_DIAMETER<<FRACTIONAL_BITS,d4
    move.l      d1,BallPositionX
    move.l      d2,BallPositionY
    move.l      d6,BallVelocityX
    move.l      d7,BallVelocityY

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
    move.l      #3,d0               ; Used as padding around the inval rectangle
    
    * Get the ball's coordinates
    move.l      BallPositionX,d1
    move.l      BallPositionY,d2
    asr.l       #FRACTIONAL_BITS,d1
    asr.l       #FRACTIONAL_BITS,d2
    move.l      d1,d3
    move.l      d2,d4
    add.l       #BALL_DIAMETER,d3
    add.l       #BALL_DIAMETER,d4

    * Adjust padding for each side
    sub.l       d0,d1
    sub.l       d0,d2
    add.l       d0,d3
    add.l       d0,d4
    
    * Keep the inval rectangle within the bounds of the screen
    cmpi.l      #0,d1
    bgt         skipLeftBoundFix
    move.l      #0,d1
skipLeftBoundFix:
    cmpi.l      #0,d2
    bgt         skipTopBoundFix
    move.l      #0,d2
skipTopBoundFix:
    cmpi.l      #OUTPUT_WINDOW_WIDTH,d3
    blt         skipRightBoundFix
    move.l      #OUTPUT_WINDOW_WIDTH,d3
skipRightBoundFix:
    cmpi.l      #OUTPUT_WINDOW_HEIGHT,d4
    blt         skipBottomBoundFix
    move.l      #OUTPUT_WINDOW_HEIGHT,d4
skipBottomBoundFix:

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
    
* Redraw the bitmap over the LED position
clearLED:
    movem.l     ALL_REG,-(sp)
    
    move.l      #LED_POSITION_X-1,d1
    move.l      #LED_POSITION_Y-1,d2
    move.l      #(LED_POSITION_X+LED_SEGMENT_LENGTH+1),d3
    move.l      #(LED_POSITION_Y+(LED_SEGMENT_LENGTH*2)+1),d4
    
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
    
displayLED:
    movem.l     ALL_REG,-(sp)
    lea         SevenSegmentTable,a5
    move.l      #0,d6                   ; Initialize counter
    clr.l       d2
    move.l      Lives,d1
    move.b      (a5,d1),d2              ; Hex value from seven segment table                  
drawSegments:
    btst.l      d6,d2
    beq         noSegmentDraw
    jsr         drawLEDSegment
noSegmentDraw:
    addi.l      #1,d6
    cmpi.l      #7,d6
    blt         drawSegments
    movem.l     (sp)+,ALL_REG
    rts
    
drawLEDSegment:
    movem.l     ALL_REG,-(sp)
    
    move.l      #COLOR_RED,-(sp)
    jsr         setPenColor
    add.l       #4,sp

    lea         LEDSegments,a3
    move.l      #DRAW_LINE_TRAP,d0
    asl.l       #4,d6                   ; Multiply the counter by 16 to account for the offset for longwords
    move.l      0(a3,d6),d1
    move.l      4(a3,d6),d2
    move.l      8(a3,d6),d3
    move.l      12(a3,d6),d4
    TRAP        #15
    
    movem.l     (sp)+,ALL_REG
    rts

updateBall:
    movem.l     ALL_REG,-(sp)
    
    move.l      BallPositionX,d1
    move.l      BallPositionY,d2
    
    move.l      BallVelocityX,d6
    move.l      BallVelocityY,d7
    
    * Multiply the velocity by delta time
    *muls.w      d0,d6
    *muls.w      d0,d7
    
    add.l       d6,d1       ; Update the X position
    add.l       d7,d2       ; Update the Y position
    
    * Check if the ball is within the bounds of the screen
    cmp.l       #0,d1
    blt         ballReflectLeftBound
    cmp.l       #0,d2
    blt         ballReflectTopBound
    cmp.l       #(OUTPUT_WINDOW_WIDTH-BALL_DIAMETER)<<FRACTIONAL_BITS,d1
    bgt         ballReflectRightBound
    cmp.l       #(OUTPUT_WINDOW_HEIGHT-BALL_DIAMETER)<<FRACTIONAL_BITS,d2
    bgt         loseLife
    jmp         endUpdateBall
    
ballReflectLeftBound:
    muls.w      #-1,d6
    move.l      #0,d1
    jmp         endUpdateBall
    
ballReflectRightBound:
    muls.w      #-1,d6
    move.l      #(OUTPUT_WINDOW_WIDTH-BALL_DIAMETER)<<FRACTIONAL_BITS,d1
    jmp         endUpdateBall
    
ballReflectTopBound:
    muls.w      #-1,d7
    move.l      #0,d2
    jmp         endUpdateBall
    
loseLife:
    move.l      Lives,d0
    subi.l      #1,d0
    move.l      d0,Lives
    cmpi.l      #0,d0               ; Check if out of lives
    ble         initialize          ; Reset game when no lives left
    jsr         resetBall
    
endUpdateBall:
    move.l      d1,BallPositionX
    move.l      d2,BallPositionY
    move.l      d6,BallVelocityX
    move.l      d7,BallVelocityY
    movem.l     (sp)+,ALL_REG
    rts
    
resetBall:
    jsr         calculateBallInvalRect
    move.l      #0,d6
    move.l      #0,d7
    move.l      #((OUTPUT_WINDOW_WIDTH>>1)-(BALL_DIAMETER>>1))<<FRACTIONAL_BITS,d1
    move.l      #((OUTPUT_WINDOW_HEIGHT>>1)-(BALL_DIAMETER>>1))<<FRACTIONAL_BITS,d2
    move.l      d1,d3
    add.l       #BALL_DIAMETER<<FRACTIONAL_BITS,d3
    move.l      d2,d4
    add.l       #BALL_DIAMETER<<FRACTIONAL_BITS,d4
    rts
    
update:
    lea         BallPositionX,a5
    lea         BallPositionY,a6
    
    * Save off the previous time
    move.l      CurrentTime,d0
    move.l      d0,PreviousTime
    * Get the current time
    move.l      #GET_TIME_TRAP,d0
    TRAP        #15
    move.l      d1,CurrentTime
    * Calculate delta time
    sub.l       PreviousTime,d1
    lsl.l       #2,d1
    move.l      d1,DeltaTime
    
    move.l      d1,d0               ; Delta time is stored in d0 for the update function
  
    * Check if the ball is moving
    cmpi.l      #0,BallVelocityX
    bne         updateNeededFromBall
    cmpi.l      #0,BallVelocityY
    beq         noUpdateFromBall
updateNeededFromBall:
    jsr         updateBall
    move.l      BallPositionX,d1
    move.l      BallPositionY,d2
    jsr         calculateBallInvalRect
    
    * Check for a collision between the ball and paddle
    * Pass in the location of the paddle as objectA
    move.l      (a4),d0                                     ; Make a copy of PaddlePositionX
    asl.l       #FRACTIONAL_BITS,d0
    move.l      d0,-(sp)
    move.l      #INITIAL_PADDLE_POSITION_Y<<FRACTIONAL_BITS,-(sp)
    add.l       #PADDLE_WIDTH<<FRACTIONAL_BITS,d0
    move.l      d0,-(sp)
    move.l      #(INITIAL_PADDLE_POSITION_Y+PADDLE_HEIGHT)<<FRACTIONAL_BITS,-(sp)
    * Pass in the location of the ball as objectB
    move.l      d1,-(sp)
    move.l      d2,-(sp)
    move.l      d1,d3                   ; Copy the X position
    addi.l      #BALL_DIAMETER<<FRACTIONAL_BITS,d3       ; Account for the size
    move.l      d3,-(sp)
    move.l      d2,d4                   ; Copy the y position
    addi.l      #BALL_DIAMETER<<FRACTIONAL_BITS,d4       ; Account for the size
    move.l      d4,-(sp)
    jsr         checkForCollision
    add.l       #32,sp
    
    cmpi.l      #1,d0                   ; The return value from the collision check will be located in register d0, 1 indicates a collision occurred
    bne         skipPaddleCollide

    * Ball collided with paddle - Reverse the ball's Y velocity
    move.l      BallVelocityY,d7
    addi.l      #16,d7
    muls.w      #-1,d7
    move.l      d7,BallVelocityY
    move.l      #(INITIAL_PADDLE_POSITION_Y-BALL_DIAMETER-1)<<FRACTIONAL_BITS,d2
    move.l      #(INITIAL_PADDLE_POSITION_Y-1)<<FRACTIONAL_BITS,d4
    
skipPaddleCollide:
    jsr         checkForCollisionWithBricks
noUpdateFromBall:  
    
    * Keep the paddle within the bounds of the screen
    lea         PaddlePositionX,a4
    cmpi.l      #1,(a4)                                     ; Check to see if the paddle has exceeded the left bounds
    ble         positionPaddleOnLeft
    cmp.l       #(OUTPUT_WINDOW_WIDTH-PADDLE_WIDTH),(a4)    ; Check to see if the paddle has exceeded the right bounds
    ble         paddleInBounds
    move.l      #(OUTPUT_WINDOW_WIDTH-PADDLE_WIDTH),(a4)    ; Re-position the paddle on the right side of the screen
    jmp         paddleInBounds
positionPaddleOnLeft:
    move.l      #1,(a4)                                     ; Re-position the paddle on the left side of the screen
paddleInBounds:

    jsr         clearLED
    jsr         displayLED
    
    rts
    
checkForCollisionWithBricks:
    movem.l     ALL_REG,-(sp)
    lea         Bricks,a6
    move.l      #0,d7                               ; The counter
    move.l      #(BrickEnd-Bricks),d1
iterateOverBricks:
    move.l      d7,d6                               ; Copy the counter
    mulu.w      #12,d6                               ; Multiply counter by 12 for longword offset
    move.l      BRICK_OFFSET_ACTIVE(a6,d6),d4
    cmpi.l      #1,d4                               ; Check if the brick is active first
    bne         nextBrick
    move.l      BRICK_OFFSET_X(a6,d6),d2
    move.l      BRICK_OFFSET_Y(a6,d6),d3
    
    * Pass location of brick as objectA
    move.l      d2,-(sp)
    move.l      d3,-(sp)
    move.l      d2,d0
    add.l       #BRICK_WIDTH,d0
    move.l      d0,-(sp)
    move.l      d3,d0
    add.l       #BRICK_HEIGHT,d0
    move.l      d0,-(sp)
    * Pass location of ball as objectB
    move.l      BallPositionX,d5
    move.l      BallPositionY,d4
    lsr.l       #FRACTIONAL_BITS,d5
    lsr.l       #FRACTIONAL_BITS,d4
    move.l      d5,-(sp)
    move.l      d4,-(sp)
    add.l       #BALL_DIAMETER,d5
    move.l      d5,-(sp)
    add.l       #BALL_DIAMETER,d4
    move.l      d4,-(sp)
    jsr         checkForCollision
    add.l       #32,sp
    
    cmpi.l      #1,d0                               ; 1 if collision occured
    bne         nextBrick
    move.l      #0,BRICK_OFFSET_ACTIVE(a6,d6)       ; Collision occured, mark the brick as inactive
    
    * Calculate inval rect
    move.l      d2,-(sp)
    move.l      d3,-(sp)
    move.l      d3,d0
    add.l       #BRICK_HEIGHT,d0
    move.l      d0,-(sp)
    move.l      d2,d0
    add.l       #BRICK_WIDTH,d0
    move.l      d0,-(sp)
    move.l      #BITMAP_LEFT_X,-(sp)
    move.l      #BITMAP_TOP_Y,-(sp)
    jsr         drawBitmap
    add.l       #24,sp
    
    * Reverse ball velocity
    move.l      BallVelocityY,d0
    muls.w      #-1,d0
    move.l      d0,BallVelocityY
    
nextBrick:
    addi.l      #1,d7
    cmp.l       d1,d7
    blt         iterateOverBricks
    
    movem.l     (sp)+,ALL_REG
    rts
    
draw:
    jsr         drawBall
    jsr         drawPaddle
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
    *mulu.w      (a5),d0
    add.l       d0,PaddlePositionX
checkRightMovement:
    btst.l      #16,d1
    beq         checkLaunchKey
    jsr         calculatePaddleInvalRect
    move.l      PaddleVelocityX,d0
    *mulu.w      (a5),d0
    add.l       d0,PaddlePositionX
checkLaunchKey:
    btst.l      #8,d1
    beq         checkResetKey
    move.l      #BALL_SPEED,d0
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
    
setPenWidth:
    movem.l     d0,-(sp)
    movem.l     d1,-(sp)
    move.l      #SET_PEN_WIDTH_TRAP,d0
    move.l      PEN_WIDTH(sp),d1
    TRAP        #15
    movem.l     (sp)+,d1
    movem.l     (sp)+,d0
    rts
    
setFillColor:
    movem.l     ALL_REG,-(sp)
    move.l      #SET_FILL_COLOR_TRAP,d0
    move.l      FILL_COLOR(sp),d1
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts
    
drawBall:
    movem.l     ALL_REG,-(sp)
    move.l      #DRAW_ELLIPSE_TRAP,d0
    
    * Set the ball border color
    move.l      #BALL_BORDER_COLOR,-(sp)
    jsr         setPenColor
    add.l       #4,sp
    
    * Set the ball fill color
    move.l      #BALL_FILL_COLOR,-(sp)
    jsr         setFillColor
    add.l       #4,sp
    
    move.l      BallPositionX,d1
    move.l      BallPositionY,d2
    asr.l       #FRACTIONAL_BITS,d1
    asr.l       #FRACTIONAL_BITS,d2
    move.l      d1,d3
    addi.l      #BALL_DIAMETER,d3
    move.l      d2,d4
    addi.l      #BALL_DIAMETER,d4
    TRAP        #15
    movem.l     (sp)+,ALL_REG
    rts
    
drawAllBricks:
    movem.l     ALL_REG,-(sp)
    move.l      #(OUTPUT_WINDOW_WIDTH/BRICK_WIDTH),d6       ; Number of bricks to draw horizontally
    move.l      #NUMBER_OF_BRICK_ROWS,d7                    ; Number of bricks to draw vertically
    move.l      d6,d0                                       ; The horizontal counter to be decremented
    subi.l      #1,d0                                       ; Immediately dectement the horizontal loop counter so it won't exceed the bounds
    move.l      d7,d1                                       ; The vertical counter to be decremented
    subi.l      #1,d1                                       ; Immediately dectement the vertical loop counter so it won't exceed the bounds
    lea         Bricks,a0
drawHorizontalBricks:
    move.l      d0,d4                                       ; Copy the horizontal counter
    mulu.w      #BRICK_WIDTH,d4                             ; Multiply by the width to get the horizontal position
    move.l      d1,d5                                       ; Copy the vertical counter
    mulu.w      #BRICK_HEIGHT,d5                            ; Multiply by the height to get the vertical position
    move.l      d0,d2
    mulu.w      d1,d2                                       ; Multiply the horizontal and vertical counters
    mulu.w      #12,d2                                      ; Multiply by the number of longwords stored per entry
    
    * Store brick information in table
    move.l      d4,BRICK_OFFSET_X(a0,d2)
    move.l      d5,BRICK_OFFSET_Y(a0,d2)
    move.l      #1,BRICK_OFFSET_ACTIVE(a0,d2)               ; Enable the brick by default
    
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
PreviousTime        dc.l    0
CurrentTime         dc.l    0
DeltaTime           dc.l    0
Lives               ds.l    1
Bricks              ds.l    NUMBER_OF_BRICK_ROWS*NUMBER_OF_BRICK_COLUMNS*3
BrickEnd            ds.l    0
LEDSegments         dc.l    LED_POSITION_X,LED_POSITION_Y,LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y
                    dc.l    LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y,LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y+LED_SEGMENT_LENGTH
                    dc.l    LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y+LED_SEGMENT_LENGTH,LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y+(LED_SEGMENT_LENGTH*2)
                    dc.l    LED_POSITION_X,LED_POSITION_Y+(LED_SEGMENT_LENGTH*2),LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y+(LED_SEGMENT_LENGTH*2)
                    dc.l    LED_POSITION_X,LED_POSITION_Y+LED_SEGMENT_LENGTH,LED_POSITION_X,LED_POSITION_Y+(LED_SEGMENT_LENGTH*2)
                    dc.l    LED_POSITION_X,LED_POSITION_Y,LED_POSITION_X,LED_POSITION_Y+LED_SEGMENT_LENGTH
                    dc.l    LED_POSITION_X,LED_POSITION_Y+LED_SEGMENT_LENGTH,LED_POSITION_X+LED_SEGMENT_LENGTH,LED_POSITION_Y+LED_SEGMENT_LENGTH
SevenSegmentTable   dc.b    $3F,$06,$5B,$4F,$66,$6D,$7D,$27,$7F,$6F
                    ds.l    0
                    include     "drawBitmap.x68"
                    include     "collisionDetection.x68"

    END    START        ; last line of source


















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
