package com.xcosmos.minivoice;

/** Sheet geometry in window pixels. Height stays fixed while dragging. */
final class SheetPosition {
    static float collapsed(int height){return Math.max(0,height*.25f);}
    static float drag(float start,float delta,int height){return Math.max(0,Math.min(height,start+delta));}
    static boolean expand(float position,float collapsed,float velocity,boolean canceled,boolean wasExpanded,float density){
        if(canceled)return wasExpanded;
        if(velocity< -600*density)return true;
        if(velocity>600*density)return false;
        return position<collapsed/2;
    }
}
