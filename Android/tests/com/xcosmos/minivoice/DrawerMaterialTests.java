package com.xcosmos.minivoice;

public final class DrawerMaterialTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        String[] styles={"simple","library","wall"};
        for(boolean dark:new boolean[]{false,true})for(String from:styles)for(String to:styles){
            DrawerMaterialState state=new DrawerMaterialState();state.applied(from,dark);
            boolean change=!from.equals(to);
            check(state.prepare(to,dark,true)==change,"Wrong snapshot policy for "+from+" -> "+to);
            if(change){
                check(!state.restore(true)&&state.pending(),"Drawer reopened over transition fragments");
                state.applied(to,dark);check(state.restore(false),"Drawer was not restored after transition");
                check(!state.restore(false),"Drawer reopened twice");
            }else check(!state.pending(),"Same-style navigation discarded a valid snapshot");
        }
        for(String style:styles){
            DrawerMaterialState state=new DrawerMaterialState();state.applied(style,false);
            check(state.prepare(style,true,true)==!style.equals("wall"),"Palette change reused an incompatible snapshot");
        }
        DrawerMaterialState closed=new DrawerMaterialState();closed.applied("simple",false);
        check(!closed.prepare("wall",true,false)&&!closed.restore(false),"Closed drawer opened by a style change");
        System.out.println("PASS: all six player-style switch directions in light/dark palettes, transition-gated single restore, stable category navigation and closed-drawer behaviour");
    }
}
