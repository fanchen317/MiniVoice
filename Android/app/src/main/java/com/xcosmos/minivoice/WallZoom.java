package com.xcosmos.minivoice;

final class WallZoom {
    static final int MIN=60,MAX=120,DEFAULT=100;
    static float clamp(float scale){return Math.max(MIN/100f,Math.min(MAX/100f,scale));}
    static int percent(float scale){return Math.round(clamp(scale)*100);}
    static float scale(int percent){return Math.max(MIN,Math.min(MAX,percent))/100f;}
}
