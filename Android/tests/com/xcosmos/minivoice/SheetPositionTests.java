package com.xcosmos.minivoice;

public final class SheetPositionTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        check(SheetPosition.collapsed(800)==200,"initial sheet exposes 75% window");
        check(SheetPosition.drag(200,-400,760)==0,"upward drag stops at safe top");
        check(SheetPosition.drag(200,1000,760)==760,"downward overscroll remains bounded");
        check(SheetPosition.expand(80,200,0,false,false,1),"release above midpoint expands");
        check(!SheetPosition.expand(160,200,0,false,true,1),"release below midpoint collapses");
        check(SheetPosition.expand(190,200,-1900,false,false,3),"upward fling respects density");
        check(!SheetPosition.expand(10,200,1900,false,true,3),"downward fling collapses");
        check(SheetPosition.expand(180,200,900,true,true,1),"canceled expanded drag restores anchor");
        check(!SheetPosition.expand(0,200,-900,true,false,1),"canceled collapsed drag restores anchor");
        check(SheetPosition.drag(125,0,760)==125,"interrupted motion resumes from visible position");
        System.out.println("PASS: sheet resting heights, safe drag bounds, velocity, canceled gestures and interruption geometry");
    }
}
