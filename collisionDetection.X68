* Check to see if objectB has intersected with objectA
* Previous contents of d0 are trashed and the return value (0 [false] or 1 [true]) will be stored in its place
checkForCollision:
    movem.l     ALL_REG,-(sp)
    
    * Object A bounds
    move.l      COLLISION_OBJ_A_LEFT(sp),d0
    move.l      COLLISION_OBJ_A_TOP(sp),d1
    move.l      COLLISION_OBJ_A_RIGHT(sp),d2
    move.l      COLLISION_OBJ_A_BOTTOM(sp),d3
    
    * Object B bounds
    move.l      COLLISION_OBJ_B_LEFT(sp),d4
    move.l      COLLISION_OBJ_B_TOP(sp),d5
    move.l      COLLISION_OBJ_B_RIGHT(sp),d6
    move.l      COLLISION_OBJ_B_BOTTOM(sp),d7
    
checkHorizontalBounds:
    cmp.l       d0,d6               ; Compare objectB's right side with objectA's left side
    blt         noCollision         ; If objectB's right side is less than objectA's left side, there can't be any collisions
    cmp.l       d2,d4               ; Compare objectB's left side with objectA's right side
    bgt         noCollision         ; If objectB's left side is greater than objectA's right side, there can't be any collisions
    
checkVerticalBounds:
    cmp.l       d1,d7               ; Compare objectB's bottom side with objectA's top side
    blt         noCollision         ; If objectB's bottom side is less than objectA's top side, there can't be any collisions
    cmp.l       d3,d5               ; Compare objectB's top side with objectA's bottom side
    bgt         noCollision         ; If objectB's top side is greater than objectA's bottom side, there can't be any collisions

* A collision must have occured since we did not have a single case where the two objects were completely outside the bounds the other
collisionOccured:
    movem.l     (sp)+,ALL_REG
    move.l      #1,d0               ; Trash the old value in d0 and use it for the return value
    rts

noCollision:
    movem.l     (sp)+,ALL_REG
    move.l      #0,d0               ; Trash the old value in d0 and use it for the return value
    rts






*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
