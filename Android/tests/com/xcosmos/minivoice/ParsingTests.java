package com.xcosmos.minivoice;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.List;

/** JVM regression tests; no emulator or third-party test runner required. */
public final class ParsingTests {
    private static void equal(Object actual,Object expected){if(!expected.equals(actual))throw new AssertionError(actual+" != "+expected);}
    public static void main(String[] args)throws Exception{
        List<Lyrics.Line> lines=Lyrics.parse("[offset:-100]\n[ti:星晴]\n[00:00.000]<00:00.000>星<00:00.202><00:00.202>晴<00:00.404>\n[00:02.840]<00:02.840>词<00:03.408>\n[00:05.680][00:08.00]曲");
        equal(lines.size(),4);equal(lines.get(0).text,"星晴");equal(lines.get(0).ms,0L);equal(lines.get(1).text,"词");equal(lines.get(1).ms,2740L);equal(lines.get(3).ms,7900L);
        equal(Lyrics.parse("<00:03.20>你好<00:04.0>").get(0).ms,3200L);
        equal(Lyrics.parse("[00:99.0]invalid\n[ar:artist]").size(),0);
        equal(Lyrics.parse("[ti:歌名]\n第一句\n第二句").get(0).text,"第一句");
        equal(AudioTags.filename("026 - 许嵩 - 安琪.mp3")[0],"安琪");equal(AudioTags.filename("026 - 许嵩 - 安琪.mp3")[1],"许嵩");
        equal(AudioTags.filename("2002.flac")[0],"2002");
        equal(AudioTags.choose("安琪","026 - 许嵩 - 安琪"),"安琪");equal(AudioTags.choose("<unknown>","安琪"),"安琪");
        ByteArrayOutputStream frames=new ByteArrayOutputStream();
        for(String[] field:new String[][]{{"TIT2","安琪"},{"TPE1","许嵩"},{"TALB","早期单曲"}}){
            byte[] text=field[1].getBytes(StandardCharsets.UTF_16);DataOutputStream out=new DataOutputStream(frames);out.writeBytes(field[0]);out.writeInt(text.length+1);out.writeShort(0);out.writeByte(1);out.write(text);
        }
        ByteArrayOutputStream file=new ByteArrayOutputStream();file.write(new byte[]{'I','D','3',3,0,0,0,0,(byte)(frames.size()>>7),(byte)(frames.size()&127)});file.write(frames.toByteArray());
        AudioTags tags=AudioTags.read(new ByteArrayInputStream(file.toByteArray()),true);equal(tags.title,"安琪");equal(tags.artist,"许嵩");equal(tags.album,"早期单曲");
        equal(AudioTags.read(new ByteArrayInputStream(new byte[10]),false).title==null,true);
        if(args.length>0){
            try(InputStream input=new FileInputStream(args[0])){AudioTags real=AudioTags.read(input,true);equal(real.title,"安琪");equal(real.artist,"许嵩");equal(real.picture!=null,true);}
        }
        if(args.length>1){
            String raw=java.nio.file.Files.readString(java.nio.file.Path.of(args[1]));List<Lyrics.Line> real=Lyrics.parse(raw);
            equal(real.isEmpty(),false);equal(real.get(0).text,"星晴 - 周杰伦 (Jay Chou)");
            for(Lyrics.Line line:real)if(line.text.matches(".*<\\d+:.*"))throw new AssertionError("Unparsed word timestamp: "+line.text);
        }
        if(args.length>2){List<Lyrics.Line> wish=Lyrics.parse(java.nio.file.Files.readString(java.nio.file.Path.of(args[2])));equal(wish.isEmpty(),false);equal(wish.get(0).text.startsWith("I wish"),true);equal(wish.get(0).ms,0L);}
        System.out.println("PASS: lyric timing/offset, ID3 UTF-16, metadata precedence, filename fallback, malformed tags");
    }
}
