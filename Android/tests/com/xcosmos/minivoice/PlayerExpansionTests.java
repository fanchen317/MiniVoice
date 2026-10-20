package com.xcosmos.minivoice;

public final class PlayerExpansionTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    private static void near(float a,float b){check(Math.abs(a-b)<.001f,a+" != "+b);}
    public static void main(String[] args){
        WallReflow.Frame safe=PlayerExpansion.content(393,852,0,28,0,24);
        near(safe.y,28);near(safe.y+safe.height,828);near(safe.width,393);
        for(float progress:new float[]{0,.2f,.5f,.8f,1}){
            float top=PlayerExpansion.mix(180,0,progress),bottom=PlayerExpansion.mix(532,852,progress);
            check(top>=0&&bottom<=852,"artwork transition outside viewport");
            near(PlayerExpansion.mix(top,0,0),top); // A reversal starts at the visible frame, not an endpoint.
        }
        near(PlayerExpansion.mix(16,0,1),0);near(PlayerExpansion.mix(368,393,1),393);
        near(PlayerExpansion.mix(0,16,1),16);near(PlayerExpansion.mix(393,368,1),368);
        WallReflow.Frame landscape=PlayerExpansion.content(852,393,28,0,36,0);
        near(landscape.x,28);near(landscape.x+landscape.width,816);
        System.out.println("PASS: edge-to-edge expansion, safe status/navigation content, collapse endpoints and reversal continuity");
    }
}
