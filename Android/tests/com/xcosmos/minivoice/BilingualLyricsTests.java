package com.xcosmos.minivoice;
import java.util.*;
public final class BilingualLyricsTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        List<Lyrics.Line> lines=Lyrics.parse("[00:01.00]<00:01.00>Hello <00:02.00>world<00:03.00>\n[00:01.00]你好，世界\n[00:05.00]Next\n[00:05.00]下一句");
        check(lines.size()==2,"Translations must share the source row, not replace the active row");
        check(lines.get(0).translation.equals("你好，世界"),"Bilingual translation missing");
        check(lines.get(0).words.size()==2,"Word timing lost during translation merge");
        check(lines.get(0).displayText().equals("Hello world\n你好，世界"),"Original and translation must be separate lines");
        check(LyricSweep.characters(lines.get(0),5000,6000,3500)==11,"Terminal word timestamp must stop the sweep");
        lines=Lyrics.parse("[offset:-100]\n[1000,4000](1000,500,0)你(2000,500,0)好\n[00:01.000]Hello\n[6000,1000](6000,500,0)呀");
        check(lines.get(0).ms==900,"YRC offset ignored");
        check(lines.get(0).words.get(0).endMs==1400,"YRC word duration ignored");
        check(lines.get(0).translation.equals("Hello"),"Mixed YRC and translated LRC did not merge");
        check(LyricSweep.characters(lines.get(0),5900,7000,1700)==1,"Word gap must hold the previous word");
        check(Math.abs(LyricSweep.characters(lines.get(0),5900,7000,2150)-1.5f)<.01,"YRC timed word interpolation");
        check(Lyrics.parse("[00:01]A\n[00:01]A").get(0).translation.isEmpty(),"Duplicate row is not a translation");
        check(Lyrics.parse("[1,2]plain").size()==1,"YRC line without words should still display");
        System.out.println("PASS: bilingual grouping, original word timing, enhanced LRC terminal timestamps, YRC durations/pauses and offsets");
    }
}
