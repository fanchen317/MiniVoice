package com.xcosmos.minivoice;

public final class WallControlsTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        for(int value=60;value<=120;value++)check(WallZoom.percent(WallZoom.scale(value))==value,"slider percentage round trip");
        check(WallZoom.sliderProgress(1)==40,"100% slider offset");check(WallZoom.sliderScale(40)==1,"slider offset must not become minimum");
        for(int value=0;value<=60;value++)check(WallZoom.sliderProgress(WallZoom.sliderScale(value))==value,"zero-based slider round trip");
        check(WallZoom.clamp(Float.NaN)==1&&WallZoom.clamp(Float.POSITIVE_INFINITY)==1&&WallZoom.clamp(0)==1,"invalid scale samples cannot corrupt zoom state");
        check(WallZoom.percent(1)==100,"actual 100% must show 100%");check(WallZoom.percent(.6f)==60,"minimum");check(WallZoom.percent(1.2f)==120,"maximum");
        check(WallZoom.scale(0)==.6f&&WallZoom.scale(200)==1.2f,"clamp user input");
        check(WallSearchDismiss.shouldClose(true,0,false),"empty search closes on outside touch");
        check(!WallSearchDismiss.shouldClose(true,0,true),"inside touch keeps search open");
        check(!WallSearchDismiss.shouldClose(true,3,false),"nonempty query stays open");
        check(!WallSearchDismiss.shouldClose(false,0,false),"closed search does not restart collapse");
        System.out.println("PASS: absolute zoom slider/display mapping and empty-search outside dismissal");
    }
}
