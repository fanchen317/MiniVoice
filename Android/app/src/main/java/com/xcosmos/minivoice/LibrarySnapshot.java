package com.xcosmos.minivoice;

import android.content.Context;
import android.net.Uri;
import android.util.AtomicFile;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Durable scan result. Reopening the app restores this index without reopening audio files. */
final class LibrarySnapshot {
    private static List<Song> resident;private static String residentSource;
    private static AtomicFile file(Context context){return new AtomicFile(new File(LibraryCache.root(context),"index-v1.json"));}
    static synchronized void forgetResident(){resident=null;residentSource=null;}
    static synchronized void invalidate(Context context){resident=null;residentSource=null;file(context).delete();}
    static String source(Set<String> folders,boolean recursive){return new TreeSet<>(folders).toString()+"\n"+recursive;}
    private static Uri uri(String value){return value.isEmpty()?null:Uri.parse(value);}
    static synchronized List<Song> read(Context context,String source){if(source.equals(residentSource)&&resident!=null)return new ArrayList<>(resident);try{
        JSONObject root=new JSONObject(new String(file(context).readFully(),StandardCharsets.UTF_8));
        if(root.getInt("version")!=1||!source.equals(root.getString("source")))return null;
        List<Song> songs=new ArrayList<>();JSONArray rows=root.getJSONArray("songs");
        for(int i=0;i<rows.length();i++){JSONObject row=rows.getJSONObject(i);
            Song song=new Song(row.getLong("id"),row.getLong("duration"),row.getLong("albumId"),row.getString("title"),row.getString("artist"),row.getString("album"),row.getString("path"),Uri.parse(row.getString("uri")),uri(row.optString("lyricUri")));
            song.sourceAdded=row.optLong("sourceAdded",0);song.updated=row.optLong("updated",0);
            song.artworkUri=uri(row.optString("artworkUri"));song.artworkVersion=row.optString("artworkVersion");
            song.lyricsRaw=row.optString("lyrics");song.lyricsEmbedded=row.optBoolean("embedded");song.lyricsPrepared=row.optBoolean("lyricsPrepared");song.embeddedLyricsChecked=true;songs.add(song);
        }resident=new ArrayList<>(songs);residentSource=source;return songs;
    }catch(Exception ignored){return null;}}
    static synchronized void write(Context context,String source,List<Song> songs)throws Exception{
        JSONObject root=new JSONObject().put("version",1).put("source",source);JSONArray rows=new JSONArray();
        for(Song song:songs)rows.put(new JSONObject().put("id",song.id).put("sourceAdded",song.sourceAdded).put("updated",song.updated).put("duration",song.duration).put("albumId",song.albumId).put("title",song.title).put("artist",song.artist).put("album",song.album).put("path",song.path).put("uri",song.uri.toString()).put("lyricUri",song.lyricUri==null?"":song.lyricUri.toString()).put("artworkUri",song.artworkUri==null?"":song.artworkUri.toString()).put("artworkVersion",song.artworkVersion).put("lyrics",song.lyricsRaw).put("embedded",song.lyricsEmbedded).put("lyricsPrepared",song.lyricsPrepared&&song.lyricsError==null&&!song.lyricReadFailed));
        root.put("songs",rows);LibraryCache.root(context).mkdirs();AtomicFile cache=file(context);FileOutputStream out=null;
        try{out=cache.startWrite();out.write(root.toString().getBytes(StandardCharsets.UTF_8));cache.finishWrite(out);resident=new ArrayList<>(songs);residentSource=source;}catch(Exception failure){if(out!=null)cache.failWrite(out);throw failure;}
    }
}
