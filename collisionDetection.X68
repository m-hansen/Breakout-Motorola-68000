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
    
CheckLeftSideIntersect:
    cmp.l       d0,d4
    blt         CheckTopSideIntersect
    cmp.l       d1,d4
    blt         CheckTopSideIntersect
    cmp.l       d2,d4
    bgt         CheckTopSideIntersect
    cmp.l       d3,d4
    ble         CollisionOccured
    
CheckTopSideIntersect:
    cmp.l       d0,d5
    blt         CheckRightSideIntersect
    cmp.l       d1,d5
    blt         CheckRightSideIntersect
    cmp.l       d2,d5
    bgt         CheckRightSideIntersect
    cmp.l       d3,d5
    ble         CollisionOccured
    
CheckRightSideIntersect:
    cmp.l       d0,d6
    blt         CheckBottomSideIntersect
    cmp.l       d1,d6
    blt         CheckBottomSideIntersect
    cmp.l       d2,d6
    bgt         CheckBottomSideIntersect
    cmp.l       d3,d6
    ble         CollisionOccured
    
CheckBottomSideIntersect:
    cmp.l       d0,d7
    blt         NoCollision
    cmp.l       d1,d7
    blt         NoCollision
    cmp.l       d2,d7
    bgt         NoCollision
    cmp.l       d3,d7
    ble         CollisionOccured
    
NoCollision:
    movem.l     (sp)+,ALL_REG
    move.l      #0,d0
    rts
    
CollisionOccured:
    movem.l     (sp)+,ALL_REG
    move.l      #1,d0
    rts
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
