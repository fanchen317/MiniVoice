package com.xcosmos.minivoice;

public final class PlaybackBarsTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        for(int bar=0;bar<3;bar++){
            for(long time=0;time<10000;time+=17){float value=PlaybackBars.height(bar,time,true);check(value>=.3f&&value<=1,"animated bars remain inside glyph bounds");check(PlaybackBars.height(bar,time,false)==.38f,"paused bars stay motionless");}
            check(Math.abs(PlaybackBars.height(bar,0,true)-PlaybackBars.height(bar,180,true))>.01f,"playing bars change over time");
        }
        check(PlaybackBars.height(0,0,true)!=PlaybackBars.height(1,0,true),"bars have independent phases");
        System.out.println("PASS: animated playback bars remain bounded, vary independently and stop while paused");
    }
}
