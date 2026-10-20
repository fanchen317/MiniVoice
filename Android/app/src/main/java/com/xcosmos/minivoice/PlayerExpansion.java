package com.xcosmos.minivoice;

/** Artwork may cover system bars; interactive content stays inside their safe bounds. */
final class PlayerExpansion {
    static float mix(float from,float to,float amount){return from+(to-from)*Math.max(0,Math.min(1,amount));}
    static WallReflow.Frame content(float width,float height,float left,float top,float right,float bottom){return new WallReflow.Frame(left,top,Math.max(1,width-left-right),Math.max(1,height-top-bottom));}
}
