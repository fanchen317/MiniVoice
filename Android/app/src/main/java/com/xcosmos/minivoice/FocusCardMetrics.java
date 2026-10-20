package com.xcosmos.minivoice;

/** Geometry is computed in screen pixels after zoom, so glyphs and touch targets agree. */
final class FocusCardMetrics {
    final float contentScale,padding,button,title,artist,badge,headerBottom,lyricsTop,lyricsBottom,controlsTop,timeY,trackY,iconScale,lyricText,lyricGap;
    final boolean inlineTime;
    private final float buttonStep;
    FocusCardMetrics(float width,float height,float density){
        padding=Math.min(22*density,Math.max(10*density,width*.045f));
        contentScale=Math.min(1.2f,FocusCardPresentation.contentScale(width,density));
        float typeScale=Math.max(.75f,Math.min(1.12f,contentScale));
        title=24*density*typeScale;artist=13*density*typeScale;badge=26*density*contentScale;
        float content=width-2*padding;
        // A stable two-row footer at every zoom: transport, then clock and seek.
        // Cap spacing on wide screens instead of stretching controls across the cover.
        inlineTime=false;
        button=Math.min(44*density,Math.max(28*density,(content-16*density)/5));
        buttonStep=button+Math.max(0,Math.min(8*density,(content-5*button)/4));
        iconScale=Math.max(.75f,Math.min(1.15f,button/(44*density)));

        headerBottom=padding+badge+12*density*contentScale+title+8*density+artist;
        trackY=height-padding-12*density;
        controlsTop=trackY-button-24*density;
        timeY=trackY-10*density;
        lyricsTop=headerBottom+10*density;lyricsBottom=controlsTop-10*density;
        lyricText=Math.max(13*density,Math.min(22*density,19*density*typeScale));
        lyricGap=Math.max(6*density,Math.min(14*density,lyricText*.6f));
    }
    float buttonLeft(int index,float width){
        return padding+index*buttonStep;
    }
}
