package com.xcosmos.minivoice;

public final class WallReflowTests {
    private static void near(float a,float b){if(Math.abs(a-b)>.005f)throw new AssertionError(a+" != "+b);}
    private static void same(WallReflow.Frame a,WallReflow.Frame b){near(a.x,b.x);near(a.y,b.y);near(a.width,b.width);near(a.height,b.height);}
    public static void main(String[] args){
        WallReflow.Frame selected=new WallReflow.Frame(140,170,160,90);
        WallReflow.Frame neighbor=new WallReflow.Frame(305,170,100,90);
        WallReflow.Transform first=WallReflow.focused(selected,352,5);
        WallReflow.Frame enlarged=first.apply(selected),moved=first.apply(neighbor);
        near(enlarged.width,352);near(enlarged.height,352);near(enlarged.centerX(),selected.centerX());near(enlarged.centerY(),selected.centerY());
        near(moved.x-enlarged.x-enlarged.width,5);
        WallReflow.Transform second=WallReflow.focused(neighbor,352,5);
        for(float progress:new float[]{0,.17f,.5f,.93f,1}){
            WallReflow.Transform visible=WallReflow.between(WallReflow.IDENTITY,first,progress);
            WallReflow.Transform interrupted=WallReflow.between(visible,second,0);
            same(interrupted.apply(selected),visible.apply(selected));same(interrupted.apply(neighbor),visible.apply(neighbor));
            same(WallReflow.between(visible,second,1).apply(neighbor),second.apply(neighbor));
        }
        // Recenter a dragged card: the transform must remain exactly expanded throughout travel.
        for(float progress:new float[]{0,.1f,.5f,1})same(WallReflow.between(first,first,progress).apply(selected),enlarged);
        WallReflow.Frame far=new WallReflow.Frame(-12000,8000,75,220);
        same(WallReflow.between(first,second,0).apply(far),first.apply(far));
        System.out.println("PASS: focus size/center, neighbor spacing, interrupted focus continuity, repeat recenter preserves expanded shape");
    }
}
