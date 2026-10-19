package com.xcosmos.minivoice;

import android.content.Context;
import android.net.Uri;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class Lyrics {
    static String read(Context context,Uri uri) throws Exception {
        try(InputStream stream=context.getContentResolver().openInputStream(uri)){
            if(stream==null)throw new java.io.IOException("无法打开歌词文件");
            ByteArrayOutputStream output=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int count;
            while((count=stream.read(buffer))!=-1){if(output.size()+count>1024*1024)throw new java.io.IOException("歌词文件超过 1 MB");output.write(buffer,0,count);}
            byte[] bytes=output.toByteArray();
            if(bytes.length>=2&&(bytes[0]&255)==255&&(bytes[1]&255)==254)return new String(bytes,2,bytes.length-2,StandardCharsets.UTF_16LE);
            if(bytes.length>=2&&(bytes[0]&255)==254&&(bytes[1]&255)==255)return new String(bytes,2,bytes.length-2,StandardCharsets.UTF_16BE);
            int offset=bytes.length>=3&&(bytes[0]&255)==239&&(bytes[1]&255)==187&&(bytes[2]&255)==191?3:0;
            try{return StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes,offset,bytes.length-offset)).toString();}
            catch(CharacterCodingException ignored){return new String(bytes,Charset.forName("GB18030"));}
        }
    }
    static final class Line { final long ms; final String text; Line(long ms,String text){this.ms=ms;this.text=text;} }
    private static final Pattern STAMP=Pattern.compile("\\[(\\d{1,3}):(\\d{2})(?:[.:](\\d{1,3}))?\\]");
    private static final Pattern WORD=Pattern.compile("<(\\d{1,3}):(\\d{2})(?:[.:](\\d{1,3}))?>");
    private static final Pattern OFFSET=Pattern.compile("(?im)^\\s*\\[offset:([+-]?\\d{1,9})\\]\\s*$");
    private static long time(Matcher match){
        String fraction=match.group(3);
        return Long.parseLong(match.group(1))*60000+Long.parseLong(match.group(2))*1000+
            (fraction==null?0:Long.parseLong((fraction+"000").substring(0,3)));
    }
    static List<Line> parse(String raw) {
        List<Line> result=new ArrayList<>();List<Line> plain=new ArrayList<>();
        if(raw==null) return result;
        Matcher offsetMatch=OFFSET.matcher(raw);long offset=offsetMatch.find()?Long.parseLong(offsetMatch.group(1)):0;
        for(String row:raw.replace("\uFEFF", "").split("\\R")) {
            Matcher matcher=STAMP.matcher(row); List<Long> times=new ArrayList<>();
            while(matcher.find()) if(Integer.parseInt(matcher.group(2))<60)times.add(time(matcher));
            String body=STAMP.matcher(row).replaceAll("");
            Matcher word=WORD.matcher(body);
            if(times.isEmpty()&&word.find()&&Integer.parseInt(word.group(2))<60)times.add(time(word));
            String text=WORD.matcher(body).replaceAll("").trim();
            if(times.isEmpty()&&!text.isEmpty()&&!row.trim().startsWith("[")&&!row.trim().startsWith("<"))plain.add(new Line(-1,text));
            if(!text.isEmpty()) for(Long timestamp:times) result.add(new Line(Math.max(0,timestamp+offset),text));
        }
        result.sort(Comparator.comparingLong(line->line.ms)); return result.isEmpty()?plain:result;
    }
}
