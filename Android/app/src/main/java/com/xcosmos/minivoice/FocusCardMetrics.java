package com.xcosmos.minivoice;

/** Geometry is computed in screen pixels after zoom, so glyphs and touch targets agree. */
final class FocusCardMetrics {
    final float contentScale,padding,button,title,artist,badge,headerBottom,lyricsTop,lyricsBottom,controlsTop,timeY,trackY,iconScale,lyricText,lyricGap;
    final boolean inlineTime;
    FocusCardMetrics(float width,float height,float density){
        padding=Math.min(22*density,Math.max(10*density,width*.045f));
        contentScale=Math.min(1.2f,FocusCardPresentation.contentScale(width,density));
        float typeScale=Math.max(.75f,Math.min(1.12f,contentScale));
        title=24*density*typeScale;artist=13*density*typeScale;badge=26*density*contentScale;
        float content=width-2*padding;
        button=Math.min(44*density,Math.max(28*density,(content-16*density)/5));
        iconScale=Math.max(.75f,Math.min(1.15f,button/(44*density)));
        inlineTime=content>=420*density;
        headerBottom=padding+badge+12*density*contentScale+title+8*density+artist;
        trackY=height-padding-12*density;
        controlsTop=trackY-button-(inlineTime?24:32)*density;
        timeY=inlineTime?controlsTop+button*.64f:trackY-22*density;
        lyricsTop=headerBottom+10*density;lyricsBottom=controlsTop-10*density;
        lyricText=Math.max(13*density,Math.min(22*density,19*density*typeScale));
        lyricGap=Math.max(6*density,Math.min(14*density,lyricText*.6f));
    }
    float buttonLeft(int index,float width){
        float content=width-2*padding;
        if(inlineTime)return padding+index*(button+6*(button/44));
        return padding+index*Math.max(button,(content-button)/4);
    }
}
