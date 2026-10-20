package com.xcosmos.minivoice;

public final class CoverAtmosphereTests {
    static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    static int red(int c){return c>>16&255;}static int blue(int c){return c&255;}
    public static void main(String[] args){
        int warm=CoverAtmosphereColors.bright(0xFFC84828),cool=CoverAtmosphereColors.bright(0xFF2848C8);
        check(red(warm)>blue(warm)&&blue(cool)>red(cool),"changing artwork changes backdrop hue");
        check(red(CoverAtmosphereColors.soft(0xFF202020))>red(CoverAtmosphereColors.bright(0xFF202020)),"gradient soft end preserves contrast over dark artwork");
        check(CoverAtmosphereColors.bright(0xFFFFFFFF)==0xFFFFFFFF&&CoverAtmosphereColors.soft(0xFFFFFFFF)==0xFFFFFFFF,"white artwork remains neutral");
        int neutral=CoverAtmosphereColors.bright(0xFF505050);check(red(neutral)==blue(neutral),"monochrome artwork introduces no colour cast");
        check(Math.abs(red(CoverAtmosphereColors.bright(0xFF000000))-158)<=1,"Mac palette brightness for black artwork");
        System.out.println("PASS: cover changes drive warm/cool atmosphere, neutral artwork and dark-cover contrast match Mac palette");
    }
}
