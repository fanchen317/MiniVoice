package com.xcosmos.minivoice;

public final class PlayerWorkspaceTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        for(float density:new float[]{1,2,3.5f})for(int[] view:new int[][]{{320,340},{393,580},{600,700},{820,140},{1024,500}}){
            PlayerWorkspaceMetrics m=new PlayerWorkspaceMetrics(Math.round(view[0]*density),Math.round(view[1]*density),density);
            check(m.artwork>0&&m.hero>0,"nonempty hero");
            if(m.wide){check(m.hero<=view[0]*density*.41f,"landscape reserves lyric column");check(m.artwork<=view[1]*density*.61f+1,"short landscape cover respects available height");}
            else{check(m.hero<=view[1]*density*.56f+1,"portrait reserves at least 44% for lyrics");check(m.artwork<=view[0]*density,"portrait cover stays inside viewport");}
        }
        System.out.println("PASS: native player portrait/landscape layouts reserve lyric space after system and dock insets");
    }
}
