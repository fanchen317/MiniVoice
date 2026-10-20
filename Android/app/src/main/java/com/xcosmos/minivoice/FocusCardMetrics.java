package com.xcosmos.minivoice;

/** Screen-space geometry shared by the focused card's drawing and touch targets. */
final class FocusCardMetrics {
    final float contentScale,padding,button,title,artist,badge,headerBottom,lyricsTop,lyricsBottom,controlsTop,timeY,trackY;
    final boolean inlineTime;
    FocusCardMetrics(float width,float height,float density){
        padding=Math.min(22*density,Math.max(14*density,width*.05f));
        contentScale=FocusCardPresentation.contentScale(width,density);
        title=Math.min(28*density,Math.max(20*density,width*.058f))*contentScale;artist=13*density*contentScale;badge=26*density*contentScale;
        button=44*density;inlineTime=width-2*padding>=420*density;
        headerBottom=padding+badge+12*density*contentScale+title+8*density+artist;
        trackY=height-padding-12*density;
        controlsTop=trackY-(inlineTime?68:76)*density;
        timeY=inlineTime?controlsTop+27*density:trackY-22*density;
        lyricsTop=headerBottom+14*density;lyricsBottom=controlsTop-8*density;
    }
    float buttonLeft(int index,float width){
        float content=width-2*padding;
        if(index==4)return width-padding-button-(inlineTime?128*(button/44):0);
        return padding+index*(inlineTime?button:Math.min(48*(button/44),content/5));
    }
}
