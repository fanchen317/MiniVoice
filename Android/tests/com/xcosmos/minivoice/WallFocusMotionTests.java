package com.xcosmos.minivoice;

public final class WallFocusMotionTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        WallFocusMotion motion=new WallFocusMotion();
        check(motion.shouldStart(-200,300,40,60,0,true,1),"first focus must animate");motion.started(40,60);
        for(float progress:new float[]{0,.2f,.8f,1})check(!motion.shouldStart(-200+240*progress,300-240*progress,40,60,progress,false,1),"same destination must not restart animation");
        motion.clear();
        for(int click=0;click<20;click++)check(!motion.shouldStart(40,60,40,60,1,false,1),"second click must not nudge the settled card");
        check(!motion.shouldStart(40.2f,59.7f,40,60,.99999f,false,1),"rounding noise must not cause a second correction");
        check(motion.shouldStart(100,60,40,60,1,false,1),"manual pan must allow recenter");motion.started(40,60);
        check(motion.shouldStart(70,60,40,90,.5f,false,1),"changed viewport needs new destination");
        check(motion.shouldStart(40,60,40,60,1,true,1),"different focus must still reflow even with same camera destination");
        motion.clear();check(motion.shouldStart(100,60,40,60,.5f,false,1),"interrupted trip must be resumable");
        System.out.println("PASS: first focus, repeated in-flight clicks, settled double locate, rounding tolerance, pan/resize and interrupted retry");
    }
}
