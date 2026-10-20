package com.xcosmos.minivoice;

public final class FocusCardTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        for(float density:new float[]{1,2,2.75f,3.5f})for(int width:new int[]{296,320,352,393,480,600})for(int height:new int[]{width,760}){
            FocusCardMetrics m=new FocusCardMetrics(width*density,height*density,density);
            check(m.lyricsTop>=m.headerBottom,"lyrics overlap header");
            check(m.lyricsBottom>m.lyricsTop+36*density,"no room for lyrics");
            check(m.lyricsBottom<m.controlsTop,"lyrics intercept transport");
            check(m.controlsTop+m.button<m.trackY-18*density,"seek target overlaps buttons");
            check(m.trackY+12*density<=height*density,"seek target outside card");
            for(int i=0;i<5;i++){
                float left=m.buttonLeft(i,width*density);
                check(left>=m.padding,"button outside leading padding");
                check(left+m.button<=width*density-m.padding+.1f,"button outside trailing padding");
                if(i<4)check(left+m.button<=m.buttonLeft(i+1,width*density)+.1f,"button hit targets overlap");
            }
            check(!m.inlineTime,"clock consistently stays beside seek bar at every width");
            check(m.timeY>m.controlsTop+m.button+8*density,"clock clears button targets");
            check(m.trackY-m.timeY<=12*density,"clock stays close to seek bar");
            check(m.buttonLeft(1,width*density)-m.buttonLeft(0,width*density)-m.button<=8.01f*density,"wide screens must not stretch button gaps");
        }
        check(FocusCardPresentation.compact(.69f,false),"below 70% must hide full card controls");
        check(!FocusCardPresentation.compact(.7f,false),"70% retains full controls");
        check(!FocusCardPresentation.compact(.6f,true),"expanded player restores usable controls");
        for(float density:new float[]{1,2,3}){
            float large=new FocusCardMetrics(352*density,352*density,density).badge;
            float small=new FocusCardMetrics(211.2f*density,211.2f*density,density).badge;
            check(Math.abs(small/large-.6f)<.001f,"badge must scale in proportion to card");
        }
        for(float density:new float[]{1,2,3})for(int percent=60;percent<=120;percent+=5){
            float side=352*density*percent/100f;FocusCardMetrics m=new FocusCardMetrics(side,side,density);
            check(m.lyricText>=13*density&&m.lyricText<=22*density,"zoom preserves readable lyric type size");
            for(int i=0;i<4;i++)check(m.buttonLeft(i,side)+m.button<=m.buttonLeft(i+1,side)+.01f,"zoomed touch targets never overlap");
            check(m.buttonLeft(4,side)+m.button<=side-m.padding+.01f,"zoomed expand button remains inside card");
            check(m.title>=18*density&&m.artist>=9.75f*density,"small cards keep readable metadata");
            if(percent>=70)check(m.lyricsBottom-m.lyricsTop>=m.lyricText,"normal zoom retains at least one lyric line");
        }
        float previousIcon=0;
        for(int percent=60;percent<=120;percent+=5){
            float side=352*percent/100f;FocusCardMetrics m=new FocusCardMetrics(side,side,1);
            check(m.iconScale>previousIcon,"glyphs continuously grow with card zoom independently of touch size");previousIcon=m.iconScale;
        }
        for(float density:new float[]{1,2,3}){
            float step=FocusCardPresentation.expandedLyricStep(500*density,28*density,density);
            check(step>=80*density&&step<=88*density,"full-screen lyrics occupy broad central region");
            float narrow=FocusCardPresentation.expandedLyricStep(180*density,44*density,density);
            check(narrow>=52*density,"wrapped lyrics never overlap in short landscape viewport");
        }
        check(PlaybackModes.valid(-1)==1&&PlaybackModes.valid(5)==1,"invalid modes fall back to list play");
        for(int i=0;i<PlaybackModes.NAMES.length;i++)check(PlaybackModes.valid(i)==i&&!PlaybackModes.DETAILS[i].isEmpty(),"all five modes are selectable and explained");
        System.out.println("PASS: focused card header, wrapped lyrics, five touch targets, timestamps and seek geometry at phone/tablet widths and densities");
    }
}
