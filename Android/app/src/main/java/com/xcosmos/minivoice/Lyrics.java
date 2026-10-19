package com.xcosmos.minivoice;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class Lyrics {
    static final class Line { final long ms; final String text; Line(long ms,String text){this.ms=ms;this.text=text;} }
    private static final Pattern STAMP=Pattern.compile("\\[(\\d{1,3}):(\\d{2})(?:[.:](\\d{1,3}))?\\]");
    static List<Line> parse(String raw) {
        List<Line> result=new ArrayList<>();
        if(raw==null) return result;
        for(String row:raw.split("\\R")) {
            Matcher matcher=STAMP.matcher(row); int end=0; List<Long> times=new ArrayList<>();
            while(matcher.find()) {
                long fraction=0;
                if(matcher.group(3)!=null) fraction=Long.parseLong((matcher.group(3)+"000").substring(0,3));
                times.add(Long.parseLong(matcher.group(1))*60000+Long.parseLong(matcher.group(2))*1000+fraction);
                end=matcher.end();
            }
            String text=row.substring(end).trim();
            if(!text.isEmpty()) for(Long time:times) result.add(new Line(time,text));
        }
        result.sort(Comparator.comparingLong(line->line.ms)); return result;
    }
}
