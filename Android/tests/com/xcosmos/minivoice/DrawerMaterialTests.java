package com.xcosmos.minivoice;

public final class DrawerMaterialTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        String[] styles={"simple","library","wall"};
        for(boolean dark:new boolean[]{false,true})for(String from:styles)for(String to:styles){
            DrawerMaterialState state=new DrawerMaterialState();
            check(state.update(from,dark),"First material must be bound");
            check(state.update(to,dark)==!from.equals(to),"Wrong source refresh for "+from+" -> "+to);
            check(!state.update(to,dark),"Same-style navigation must keep its live material");
            check(DrawerMaterialState.liquid(to)==to.equals("wall"),"Wall needs button material; other styles need Gaussian backdrop");
        }
        DrawerMaterialState state=new DrawerMaterialState();
        for(int pass=0;pass<5;pass++)for(String style:styles)check(state.update(style,false),"Repeated style cycle retained its old source");
        for(String style:styles){
            state.update(style,false);
            check(state.update(style,true)==!style.equals("wall"),"Palette refresh is incorrect");
        }
        System.out.println("PASS: live drawer materials across all six style switch directions and repeated cycles; simple/library Gaussian, wall button glass; light/dark rebinding");
    }
}
