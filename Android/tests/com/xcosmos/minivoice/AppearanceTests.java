package com.xcosmos.minivoice;

public final class AppearanceTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        check(AppAppearance.styleValue(null).equals("wall"),"missing preference keeps music wall");
        check(AppAppearance.styleValue("other").equals("wall"),"invalid style falls back");
        for(String style:new String[]{"simple","library","wall"})check(AppAppearance.styleValue(style).equals(style),"all three styles remain selectable");
        check(!AppAppearance.darkValue("light",true),"explicit light overrides dark system");
        check(AppAppearance.darkValue("dark",false),"explicit dark overrides light system");
        check(AppAppearance.darkValue("system",true)&&!AppAppearance.darkValue("system",false),"system preference follows UI mode");
        check(AppAppearance.darkValue(null,true)&&!AppAppearance.darkValue("bad",false),"missing or invalid theme follows system");
        check(new AppAppearance.Palette(true).background!=new AppAppearance.Palette(false).background,"theme palettes differ");
        System.out.println("PASS: appearance defaults, all player styles, manual/system theme precedence and palettes");
    }
}
