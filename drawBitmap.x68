    ORG    $1000
    
ALL_REGS                REG     D0-D7/A0-A6
ALL_REGS_BYTES          EQU     60

OUTPUT_WINDOW_TRAP_CODE EQU     33
PEN_COLOR_TRAP_CODE     EQU     80
DRAW_PIXEL_TRAP_CODE    EQU     82

OUTPUT_WINDOW_WIDTH     EQU     1024
OUTPUT_WINDOW_HEIGHT    EQU     768

BITMAP_TYPE             EQU     $424D           ; All bitmaps should contain this hex value in the first 2 bytes
BITMAP_LEFT_X           EQU     10             ; The leftmost coordinate for drawing the bitmap
BITMAP_TOP_Y            EQU     10             ; The topmost coordinate for drawing the bitmap

BITS_IN_BYTE                EQU     8
NUMBER_OF_COLOR_CHANNELS    EQU     3

* For use in drawBitmap
CLIP_LEFT       EQU     84
CLIP_TOP        EQU     80
CLIP_BOTTOM     EQU     76
CLIP_RIGHT      EQU     72
POS_X           EQU     68
POS_Y           EQU     64

drawBitmap:
    movem.l     ALL_REGS,-(sp)          ; Preserve the contents of each register
    *add.l       d3,CLIP_LEFT(sp)
    *add.l       d2,CLIP_TOP(sp)
    *add.l       d2,CLIP_BOTTOM(sp)
    *add.l       d3,CLIP_RIGHT(sp)
    
    move.l      a6,a0 ; Get the initial location of the bitmap
    add.l       d4,a0 ; Add the offset to the bitmap address
    
    * Store the position to start drawing on the horizontal axis
    lea         StartingXDraw,a4
    move.l      POS_X(sp),d3
    add.l       CLIP_LEFT(sp),d3
    move.l      d3,(a4)
    
    * Calculate the number of horizontal pixels that need to be drawn
    *move.l      CLIP_RIGHT(sp),d3
    *sub.l       CLIP_LEFT(sp),d3
    
    * Calculate the number of vertical pixels that need to be drawn
    *move.l      CLIP_BOTTOM(sp),d5
    *sub.l       CLIP_TOP(sp),d5
    
    move.l      POS_Y(sp),d2
    add.l       CLIP_BOTTOM(sp),d2
    
    * Calculate the initial vertical color data offset
    move.l      d7,d1                           ; Copy the bitmap height
    sub.l       CLIP_BOTTOM(sp),d1              ; Subtract the clipping bottom from the bitmap height
    mulu.w      d6,d1                           ; Multiply by the bitmap width
    move.l      d1,d0                           ; Make a copy of the current offset
    lsl.l       #1,d1                           ; Multiply by 2
    add.l       d0,d1                           ; And add the current offset (for a total multiplication of 3, the number of color channels)
    *mulu.w      #NUMBER_OF_COLOR_CHANNELS,d1    ; Multiply by the number of color channels
    
    * Offset horizontal pixel color data that comes before the left clipping side
    move.l      CLIP_LEFT(sp),d0
    mulu.w      #NUMBER_OF_COLOR_CHANNELS,d0
    add.l       d0,d1
    
    add.l       d1,a0                           ; Increment the address for the bitmap data
    
    move.l      POS_X(sp),d5
    add.l       CLIP_RIGHT(sp),d5                ; Add the leftmost position to the image width
    
    *add.l       d7,d2                       ; The vertical pen position should now start at the bottom of the bitmap to draw bottom to top
    *subi.l      #1,d2                       ; Subtract 1 from the vertical pen position, since we should have added 1 less than the bitmap height

* Begin processing the bitmap's image data in order to set the pen color
SetPenColor:
    * D1.L is used by the TRAP code that sets the pen color
    move.l      #0,d1
    move.b      (a0)+,d1                    ; Store the hex value for the color blue
    swap        d1
    move.b      (a0)+,d1                    ; Store the hex value for the color green
    rol.w       #BITS_IN_BYTE,d1
    move.b      (a0)+,d1                    ; Store the hex value for the color red
    
    * D1.L is now be in the format 0x00BBGGRR and is ready for use with the TRAP code that sets the pen color
    move.l      #PEN_COLOR_TRAP_CODE,d0     ; Load the TRAP code used to set the pen color
    TRAP        #15
    
    move.l      #DRAW_PIXEL_TRAP_CODE,d0    ; Load the TRAP code used to draw pixels in the pen color
    *add.l       (a4),d3
    *add.l       POS_X(sp),d3
    move.l      d3,d1                       ; Store the horizontal position for use with the draw pixel TRAP code
    *add.l       CLIP_LEFT(sp),d1
    *add.l       POS_Y(sp),d5
    *move.w      d5,d2                                        ; Note: the vertical position is already in the proper register for the draw TRAP code
    *add.l       CLIP_LEFT(sp),d2

* Begin drawing pixels in the specified color     
DrawHorizontalPixels:
    TRAP        #15
    addi.l      #1,d3                       ; Increment the horizontal position by 1 pixel
    cmp.l       d5,d3                       ; Compare the horizontal position with the bitmap width and horizontal offset
    blt         SetPenColor

* Move up a row and continue drawing pixels
DrawVerticalPixels:
    move.l      StartingXDraw,d3                   ; Reset the horizontal position back to its initial x position

    * Offset horizontal color data
    move.l      d6,d1                       ; Copy the bitmap width
    sub.l       CLIP_RIGHT(sp),d1
    add.l       CLIP_LEFT(sp),d1
    mulu.w      #NUMBER_OF_COLOR_CHANNELS,d1
    add.l       d1,a0

    subi.l      #1,d2 
    move.l      POS_Y(sp),d0
    add.l       CLIP_TOP(sp),d0
    cmp.l       d0,d2                       ; Compare the vertical position with the bitmap height and vertical offset
    bgt         SetPenColor

    movem.l     (sp)+,ALL_REGS          ; Restore the contents of each register
    rts

* Reverse all bytes in d0, changing the register's endianness
reverseBytes:
    rol.w       #BITS_IN_BYTE,d0
    swap        d0
    rol.w       #BITS_IN_BYTE,d0
    rts  

Start:
    lea         BitmapFile,a0       ; Load the address of the BitmapFile
    move.l      a0,a6               ; Save a copy of the original location of the bitmap
    
* Read the header data in the bitmap
ReadBitmapHeader:
    move.w      (a0)+,d0            ; Load the filetype into a data register
    cmp.w       #BITMAP_TYPE,d0     ; Verify the file is a bitmap
    bne         ErrorNotBitmap      ; Stop reading header data if the file is not a bitmap
    move.l      (a0)+,d3            ; Load the file size, in bytes
    move.w      a0,a1               ; Store address for reserved1 data into an address register
    add.l       #2,a0               ; Increment the address for the BitmapFile
    move.w      a0,a2               ; Store address for reserved2 data
    add.l       #2,a0               ; Increment the address for the BitmapFile
    
    * Load the offset to image data, in bytes, and change its endianness
    move.l      (a0)+,d0
    jsr         reverseBytes
    move.l      d0,d4
    
* typedef struct {
*    unsigned int size;               /* Header size in bytes      */
*    int width,height;                /* Width and height of image */
*    unsigned short int planes;       /* Number of colour planes   */
*    unsigned short int bits;         /* Bits per pixel            */
*    unsigned int compression;        /* Compression type          */
*    unsigned int imagesize;          /* Image size in bytes       */
*    int xresolution,yresolution;     /* Pixels per meter          */
*    unsigned int ncolours;           /* Number of colours         */
*    unsigned int importantcolours;   /* Important colours         */
* } INFOHEADER;
ReadBitmapInformationHeader:
    move.l      (a0)+,d5            ; Load the size of the header, in bytes, into a data register
    
    * Store the bitmap width and change its endianness
    move.l      (a0)+,d0
    jsr         reverseBytes
    move.l      d0,d6
    
    * Store the bitmap height and change its endianness
    move.l      (a0)+,d0
    jsr         reverseBytes
    move.l      d0,d7
    
    add.l      d4,a0

* Setup a window for the bitmap to be drawn in
SetupWindow:
    move.l      #OUTPUT_WINDOW_WIDTH,d1
    swap.w      d1
    move.w      #OUTPUT_WINDOW_HEIGHT,d1
    move.w      #OUTPUT_WINDOW_TRAP_CODE,d0
    TRAP        #15
    
LoadBitmapStartCoordinate:
    * Starting coordinate to begin drawing pixels at
    move.l      #BITMAP_LEFT_X,d3           ; Leftmost coordinate to begin drawing the bitmap at
    move.l      #BITMAP_TOP_Y,d2            ; Topmost coordinate to begin drawing thr bitmap at
    
DrawBitmapSections:   
    * Draw the top left quadrant
    move.l      #0,-(sp)                    ; Push the left clipping position onto the stack for use in the drawBitmap subroutine
    move.l      #0,-(sp)                    ; Push the top clipping position onto the stack
    move.l      d7,d1                       ; Copy the bitmap height
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the bottom clipping position onto the stack
    move.l      d6,d1                       ; Copy the bitmap width
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the right clipping position onto the stack
    move.l      #BITMAP_LEFT_X,-(sp)        ; Push the left coordinate to draw the bitmap onto the stack
    move.l      #BITMAP_TOP_Y,-(sp)         ; Push the top coordinate to draw the bitmap onto the stack
    jsr         drawBitmap
    add.l       #24,sp
    
    * Draw the top right quadrant
    move.l      d6,d1                       ; Copy the bitmap width
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the left clipping position onto the stack for use in the drawBitmap subroutine
    move.l      #0,-(sp)                    ; Push the top clipping position onto the stack
    move.l      d7,d1                       ; Copy the bitmap height
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the bottom clipping position onto the stack
    move.l      d6,d1                       ; Copy the bitmap width
    move.l      d1,-(sp)                    ; Push the right clipping position onto the stack
    move.l      #BITMAP_LEFT_X,-(sp)        ; Push the left coordinate to draw the bitmap onto the stack
    move.l      #BITMAP_TOP_Y,-(sp)         ; Push the top coordinate to draw the bitmap onto the stack
    jsr         drawBitmap
    add.l       #24,sp
    
    * Draw the bottom right quadrant
    move.l      d6,d1                       ; Copy the bitmap width
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the left clipping position onto the stack for use in the drawBitmap subroutine
    move.l      d7,d1                       ; Copy the bitmap height
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the top clipping position onto the stack
    move.l      d7,d1                       ; Copy the bitmap height
    move.l      d1,-(sp)                    ; Push the bottom clipping position onto the stack
    move.l      d6,d1                       ; Copy the bitmap width
    move.l      d1,-(sp)                    ; Push the right clipping position onto the stack
    move.l      #BITMAP_LEFT_X,-(sp)        ; Push the left coordinate to draw the bitmap onto the stack
    move.l      #BITMAP_TOP_Y,-(sp)         ; Push the top coordinate to draw the bitmap onto the stack
    jsr         drawBitmap
    add.l       #24,sp
    
    * Draw the bottom left quadrant
    move.l      #0,-(sp)                    ; Push the left clipping position onto the stack for use in the drawBitmap subroutine
    move.l      d7,d1                       ; Copy the bitmap height
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the top clipping position onto the stack
    move.l      d7,d1                       ; Copy the bitmap height
    move.l      d1,-(sp)                    ; Push the bottom clipping position onto the stack
    move.l      d6,d1                       ; Copy the bitmap width
    lsr.l       #1,d1                       ; Divide by two
    move.l      d1,-(sp)                    ; Push the right clipping position onto the stack
    move.l      #BITMAP_LEFT_X,-(sp)        ; Push the left coordinate to draw the bitmap onto the stack
    move.l      #BITMAP_TOP_Y,-(sp)         ; Push the top coordinate to draw the bitmap onto the stack
    jsr         drawBitmap
    add.l       #24,sp
    
* The file is not a bitmap, terminate the program
ErrorNotBitmap:

    SIMHALT             ; halt simulator

* Put variables and constants here
                        ds.l        0
BitmapFile              INCBIN      "OriBitmap.bmp"
StartingXDraw           ds.l        1

    END    START        ; last line of source















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
