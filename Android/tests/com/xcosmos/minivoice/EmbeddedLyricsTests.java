package com.xcosmos.minivoice;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

public final class EmbeddedLyricsTests {
    private static void check(boolean condition,String label){if(!condition)throw new AssertionError(label);}
    private static byte[] atom(String name,byte[] data)throws Exception{ByteArrayOutputStream bytes=new ByteArrayOutputStream();DataOutputStream out=new DataOutputStream(bytes);out.writeInt(data.length+8);out.write(name.getBytes(StandardCharsets.ISO_8859_1));out.write(data);return bytes.toByteArray();}
    private static byte[] join(byte[] a,byte[] b)throws Exception{ByteArrayOutputStream out=new ByteArrayOutputStream();out.write(a);out.write(b);return out.toByteArray();}
    private static void little(DataOutputStream out,int n)throws Exception{out.writeInt(Integer.reverseBytes(n));}
    public static void main(String[] args)throws Exception{
        String lyric="[00:00.00]内嵌歌词\n[00:03.20]第二句";
        ByteArrayOutputStream body=new ByteArrayOutputStream();DataOutputStream frame=new DataOutputStream(body);frame.writeByte(1);frame.writeBytes("eng");frame.write(new byte[]{(byte)255,(byte)254,0,0});frame.write(lyric.getBytes(StandardCharsets.UTF_16));
        ByteArrayOutputStream frames=new ByteArrayOutputStream();DataOutputStream writer=new DataOutputStream(frames);writer.writeBytes("USLT");writer.writeInt(body.size());writer.writeShort(0);writer.write(body.toByteArray());
        int size=frames.size();byte[] id3=join(new byte[]{'I','D','3',3,0,0,(byte)(size>>21),(byte)((size>>14)&127),(byte)((size>>7)&127),(byte)(size&127)},frames.toByteArray());
        check(lyric.equals(EmbeddedLyrics.read(new ByteArrayInputStream(id3))),"ID3 UTF-16 USLT");
        ByteArrayOutputStream comments=new ByteArrayOutputStream();DataOutputStream c=new DataOutputStream(comments);little(c,0);little(c,2);
        for(String value:new String[]{"TITLE=内嵌歌曲","LYRICS="+lyric}){byte[] text=value.getBytes(StandardCharsets.UTF_8);little(c,text.length);c.write(text);}
        int length=comments.size();byte[] flac=join(new byte[]{'f','L','a','C',(byte)132,(byte)(length>>16),(byte)(length>>8),(byte)length},comments.toByteArray());
        check(lyric.equals(EmbeddedLyrics.read(new ByteArrayInputStream(flac))),"FLAC Vorbis LYRICS");
        byte[] mp4=atom("moov",atom("udta",atom("meta",join(new byte[4],atom("ilst",atom("©lyr",atom("data",join(new byte[8],lyric.getBytes(StandardCharsets.UTF_8)))))))));
        check(lyric.equals(EmbeddedLyrics.read(new ByteArrayInputStream(mp4))),"M4A lyrics atom");
        check(EmbeddedLyrics.read(new ByteArrayInputStream(atom("mdat",new byte[100]))).isEmpty(),"missing embedded lyrics");
        Song song=new Song(1,0,0,"歌曲","歌手","专辑","song.mp3",null);song.lyricsRaw=lyric;song.lyricsEmbedded=true;
        check(lyric.equals(LyricsRepository.select(song,"手动歌词")),"embedded wins over imported lyrics");song.lyricsEmbedded=false;
        check("手动歌词".equals(LyricsRepository.select(song,"手动歌词")),"manual fallback without embedded lyrics");
        File directory=java.nio.file.Files.createTempDirectory("minivoice-cache-test").toFile();File old=new File(directory,"legacy.jpg"),next=new File(directory,"persistent/cover.jpg");
        try(FileOutputStream out=new FileOutputStream(old)){out.write(new byte[]{1,2,3});}LibraryCache.migrate(old,next);
        check(Arrays.equals(java.nio.file.Files.readAllBytes(next.toPath()),new byte[]{1,2,3}),"migrate existing cache on upgrade");
        try(FileOutputStream out=new FileOutputStream(old)){out.write(9);}LibraryCache.migrate(old,next);check(next.length()==3,"reuse rather than overwrite persistent cache");next.delete();next.getParentFile().delete();old.delete();directory.delete();
        System.out.println("PASS: MP3/FLAC/M4A embedded lyrics, embedded precedence, missing lyrics, upgrade cache migration and reuse");
    }
}
