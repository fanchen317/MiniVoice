package com.xcosmos.minivoice;

/** Motion parameters shared with the Mac StyleFragmentMotion, in dp and ms. */
final class StyleFragmentMotion {
    static final int DURATION=680;
    static int columns(float width){return Math.max(6,Math.min(16,(int)Math.ceil(width/72)));}
    static int rows(float height){return Math.max(6,Math.min(14,(int)Math.ceil(height/72)));}
    static float progress(float elapsed,float x,float y,float originX,float originY,float width,float height){
        double delay=Math.min(1,Math.hypot(x-originX,y-originY)/Math.max(1,Math.hypot(width,height)))*200;
        return (float)Math.max(0,Math.min(1,(elapsed-delay)/480));
    }
    static float eased(float progress){return progress*progress*(3-2*progress);}
}
