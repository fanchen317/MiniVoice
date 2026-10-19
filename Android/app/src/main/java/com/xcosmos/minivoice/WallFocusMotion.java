package com.xcosmos.minivoice;

/** Repeated locate requests must neither restart a trip nor nudge an already settled card. */
final class WallFocusMotion {
    private boolean travelling;
    private float x,y;
    boolean shouldStart(float currentX,float currentY,float targetX,float targetY,float reflow,boolean newFocus,float tolerance){
        if(newFocus)return true;
        if(reflow>=.9999f&&near(currentX,targetX,tolerance)&&near(currentY,targetY,tolerance))return false;
        return !travelling||!near(x,targetX,tolerance)||!near(y,targetY,tolerance);
    }
    void started(float targetX,float targetY){travelling=true;x=targetX;y=targetY;}
    void clear(){travelling=false;}
    private static boolean near(float a,float b,float tolerance){return Math.abs(a-b)<=tolerance;}
}
