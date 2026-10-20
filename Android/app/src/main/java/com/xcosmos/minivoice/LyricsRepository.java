package com.xcosmos.minivoice;

import android.content.Context;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.List;

/** Embedded tags first; selected-folder/lrc/<original audio stem>.lrc second. */
final class LyricsRepository {
    static void prepare(Context context,List<Song> songs,ScanProgress progress){
        for(int i=0;i<songs.size();i++){Song song=songs.get(i);progress.update(i,songs.size(),"读取歌词 · "+song.title);prepareSong(context,song);}progress.update(songs.size(),songs.size(),"歌词匹配完成");
    }
    static synchronized void prepareSong(Context context,Song song){
        if(song.lyricsPrepared)return;
        song.lyricsError=null;
        File directory=LibraryCache.directory(context,"lyrics");String key=LibraryCache.key(song.uri+"\n"+song.artworkVersion+"\n"+song.lyricUri);
        File file=new File(directory,key+".txt");
        try{if(file.isFile()){
            String cached=read(file);int separator=cached.indexOf('\n');
            if(separator>=0){String kind=cached.substring(0,separator);if(kind.equals("embedded")||kind.equals("sidecar")||kind.equals("none")){song.lyricsEmbedded=kind.equals("embedded");song.lyricsRaw=cached.substring(separator+1);song.lyricsPrepared=true;return;}}
        }}catch(Exception ignored){}
        String raw=song.embeddedLyrics;
        if(!valid(raw)&&!song.embeddedLyricsChecked)raw=EmbeddedLyrics.read(context,song.uri);
        song.lyricsEmbedded=valid(raw);
        if(!song.lyricsEmbedded){raw="";if(song.lyricUri!=null)try{raw=Lyrics.read(context,song.lyricUri);if(!valid(raw))song.lyricsError="暂无歌词";}catch(Exception failure){song.lyricsError="歌词暂时无法加载";}}
        song.lyricsRaw=raw==null?"":raw;song.lyricsPrepared=true;
        // Permission failures are retried on the next scan instead of persisted as a successful miss.
        if(song.lyricsError==null&&!song.lyricReadFailed){File temporary=null;try{
            if(!directory.isDirectory()&&!directory.mkdirs())return;
            temporary=File.createTempFile("lyrics-",".tmp",directory);
            try(FileOutputStream out=new FileOutputStream(temporary)){out.write(((song.lyricsEmbedded?"embedded":song.lyricUri!=null?"sidecar":"none")+"\n"+song.lyricsRaw).getBytes(StandardCharsets.UTF_8));}
            if(!temporary.renameTo(file))temporary.delete();
        }catch(Exception ignored){if(temporary!=null)temporary.delete();}}
    }
    static void prune(Context context,List<Song> songs){java.util.Set<String> keep=new java.util.HashSet<>();for(Song song:songs)keep.add(LibraryCache.key(song.uri+"\n"+song.artworkVersion+"\n"+song.lyricUri)+".txt");File[] files=LibraryCache.directory(context,"lyrics").listFiles();if(files!=null)for(File file:files)if(!keep.contains(file.getName()))file.delete();}
    private static boolean valid(String text){return text!=null&&!text.isBlank()&&!Lyrics.parse(text).isEmpty();}
    private static String read(File file)throws Exception{try(InputStream in=new FileInputStream(file);ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] bytes=new byte[8192];int count;while((count=in.read(bytes))>=0){if(out.size()+count>1024*1024+32)throw new IOException("歌词缓存过大");out.write(bytes,0,count);}return new String(out.toByteArray(),StandardCharsets.UTF_8);}}
    static String select(Song song,String manual){return song.lyricsEmbedded?song.lyricsRaw:manual!=null&&!manual.isEmpty()?manual:song.lyricsRaw;}
}
