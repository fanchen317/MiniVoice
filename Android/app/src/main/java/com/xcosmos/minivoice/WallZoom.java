package com.xcosmos.minivoice;

final class WallZoom {
    static final int MIN=60,MAX=120,DEFAULT=100;
    static int stepProgress(float scale){return Math.max(0,Math.min(6,Math.round((percent(scale)-MIN)/10f)));}
    static float stepScale(int progress){return scale(MIN+Math.max(0,Math.min(6,progress))*10);}
    static int snapProgress(int progress){int value=Math.max(0,Math.min(MAX-MIN,progress));int stop=Math.round(value/10f)*10;return Math.abs(value-stop)<=1?stop:value;}
    static int sliderProgress(float scale){return percent(scale)-MIN;}
    static float sliderScale(int progress){return scale(progress+MIN);}
    static float clamp(float scale){if(!Float.isFinite(scale)||scale<=0)return 1;return Math.max(MIN/100f,Math.min(MAX/100f,scale));}
    static int percent(float scale){return Math.round(clamp(scale)*100);}
    static float scale(int percent){return Math.max(MIN,Math.min(MAX,percent))/100f;}
}
