package com.xcosmos.minivoice;
import java.io.*;import java.nio.file.*;import java.util.*;
public final class PortableTagCodecTests {
 static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
 public static void main(String[] args)throws Exception{
  File root=Files.createTempDirectory("minivoice-tags-").toFile();
  try{
   for(String format:new String[]{"mp3","flac","m4a"})for(String version:new String[]{"3","4"}){
    File original=new File(args[0],format+version+"."+format),edited=new File(root,"edit-"+format+version+"."+format),again=new File(root,"again-"+format+version+"."+format);
    String lyrics="[translation:5L2g5aW9]\n[00:01.000]<00:01.000>第一<00:01.400>行";
    PortableTagCodec.rewrite(original,edited,format,"新歌名 ✓","歌手 / Artist","专辑",lyrics);
    AudioTags tags;try(InputStream in=new FileInputStream(edited)){tags=AudioTags.read(in,false);}check("新歌名 ✓".equals(tags.title)&&"歌手 / Artist".equals(tags.artist)&&lyrics.equals(tags.lyrics),"Tag roundtrip: "+format+version);
    PortableTagCodec.rewrite(edited,again,format,"再次修改","","","");try(InputStream in=new FileInputStream(again)){tags=AudioTags.read(in,false);}check("再次修改".equals(tags.title)&&(tags.artist==null||tags.artist.isEmpty())&&(tags.lyrics==null||tags.lyrics.isEmpty()),"Repeated edit/clear");
    Process decode=new ProcessBuilder(args[1],"-v","error","-i",original.toString(),"-map","0:a:0","-f","hash","-hash","sha256","-").start();String before=new String(decode.getInputStream().readAllBytes());check(decode.waitFor()==0,"Original decode");
    Process verify=new ProcessBuilder(args[1],"-v","error","-i",again.toString(),"-map","0:a:0","-f","hash","-hash","sha256","-").start();String after=new String(verify.getInputStream().readAllBytes());check(verify.waitFor()==0&&before.equals(after),"Audio changed while editing "+format+version);
    Process probe=new ProcessBuilder(args[2],"-v","error","-show_entries","format_tags=comment","-of","default=noprint_wrappers=1:nokey=1",again.toString()).start();String comment=new String(probe.getInputStream().readAllBytes());check(probe.waitFor()==0&&comment.contains("preserve me"),"Unrelated tags were lost");
    System.out.println("PASS "+format+version+" Unicode, bilingual/word lyrics, repeated edit/clear, exact decoded audio hash");
   }
   File invalid=new File(root,"invalid.mp3");Files.write(invalid.toPath(),new byte[]{'I','D','3',4,0,(byte)128,0,0,0,0});boolean rejected=false;try{PortableTagCodec.rewrite(invalid,new File(root,"bad.mp3"),"mp3","x","","","");}catch(IOException expected){rejected=true;}check(rejected,"Special tag flags must reject");
  }finally{for(File file:Objects.requireNonNull(root.listFiles()))file.delete();root.delete();}
 }
}
