package com.xcosmos.minivoice;

final class FocusCardPresentation {
    static boolean compact(float wallScale,boolean expanded){return !expanded&&wallScale<.7f;}
    static int cardLyricCount(float height,float size,float gap){return height>=size*6.25f+gap*4?5:3;}
    static int cardActiveLines(float height,float size,float gap,int neighbors){return Math.max(1,Math.min(3,(int)((height-neighbors*(size*1.25f+gap))/(size*1.25f))));}
    static float expandedLyricStep(float availableHeight,float tallest,float density){
        // Leave breathing room above/below the full-screen lyric group, then
        // spread five entries through the central 73% of the available panel.
        float region=availableHeight*.73f;
        return Math.max(tallest+8*density,Math.min(88*density,(region-tallest)/4));
    }
    static float contentScale(float width,float density){return Math.max(.1f,Math.min(2,width/(352*density)));}
}
