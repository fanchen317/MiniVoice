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
            if(m.inlineTime)check(m.buttonLeft(4,width*density)+m.button+120*density<=width*density-m.padding,"time overlaps buttons");
            else check(m.timeY>m.controlsTop+m.button,"narrow card time must wrap");
        }
        check(FocusCardPresentation.compact(.69f,false),"below 70% must hide full card controls");
        check(!FocusCardPresentation.compact(.7f,false),"70% retains full controls");
        check(!FocusCardPresentation.compact(.6f,true),"expanded player restores usable controls");
        for(float density:new float[]{1,2,3}){
            float large=new FocusCardMetrics(352*density,352*density,density).badge;
            float small=new FocusCardMetrics(211.2f*density,211.2f*density,density).badge;
            check(Math.abs(small/large-.6f)<.001f,"badge must scale in proportion to card");
        }
        check(PlaybackModes.valid(-1)==1&&PlaybackModes.valid(5)==1,"invalid modes fall back to list play");
        for(int i=0;i<PlaybackModes.NAMES.length;i++)check(PlaybackModes.valid(i)==i&&!PlaybackModes.DETAILS[i].isEmpty(),"all five modes are selectable and explained");
        System.out.println("PASS: focused card header, wrapped lyrics, five touch targets, timestamps and seek geometry at phone/tablet widths and densities");
    }
}
