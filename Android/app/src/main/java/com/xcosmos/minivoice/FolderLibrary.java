package com.xcosmos.minivoice;

import android.content.Context;
import android.database.Cursor;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.provider.DocumentsContract;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.HashSet;
import java.util.HashMap;
import java.util.Map;
import java.util.Locale;

final class FolderLibrary {
    private static final class Entry { final String id,name,mime,version;Entry(String id,String name,String mime,long modified,long size){this.id=id;this.name=name;this.mime=mime;this.version=modified+":"+size;} }
    static List<Song> scan(Context context,Set<String> folders,boolean recursive,ScanProgress progress){
        List<Song> songs=new ArrayList<>();
        Set<String> seen=new HashSet<>();
        List<Runnable> jobs=new ArrayList<>();
        for(String value:folders){Uri tree=Uri.parse(value);walk(context,tree,DocumentsContract.getTreeDocumentId(tree),recursive,songs,seen,jobs,progress,new LyricIndex<Uri>());}
        for(int i=0;i<jobs.size();i++){progress.update(i,jobs.size(),"读取歌曲信息与封面");jobs.get(i).run();}
        progress.update(jobs.size(),jobs.size(),"扫描完成");
        songs.sort((left,right)->left.title.compareToIgnoreCase(right.title));return songs;
    }
    private static void walk(Context context,Uri tree,String documentId,boolean recursive,List<Song> songs,Set<String> seen,List<Runnable> jobs,ScanProgress progress,LyricIndex<Uri> rootLyrics){
        if(!seen.add("dir:"+tree.getAuthority()+":"+documentId))return;
        progress.update(0,0,"正在查找音乐文件（已发现 "+jobs.size()+" 首）");
        Uri children=DocumentsContract.buildChildDocumentsUriUsingTree(tree,documentId);
        String[] projection={DocumentsContract.Document.COLUMN_DOCUMENT_ID,DocumentsContract.Document.COLUMN_DISPLAY_NAME,DocumentsContract.Document.COLUMN_MIME_TYPE,DocumentsContract.Document.COLUMN_LAST_MODIFIED,DocumentsContract.Document.COLUMN_SIZE};
        List<Entry> entries=new ArrayList<>();
        try(Cursor cursor=context.getContentResolver().query(children,projection,null,null,null)){
            if(cursor==null)throw new IllegalStateException("无法读取音乐文件夹");
            while(cursor.moveToNext())entries.add(new Entry(cursor.getString(0),cursor.getString(1),cursor.getString(2),cursor.getLong(3),cursor.getLong(4)));
        }catch(Exception failure){throw new IllegalStateException("无法读取音乐文件夹",failure);}
        Map<String,Uri> lyrics=new HashMap<>(),artworks=new HashMap<>();
        for(Entry entry:entries){String lower=entry.name==null?"":entry.name.toLowerCase(Locale.ROOT);
            Uri item=DocumentsContract.buildDocumentUriUsingTree(tree,entry.id);
            if(lower.endsWith(".lrc")){lyrics.put(key(entry.name),item);rootLyrics.add(entry.name,item);}
            if(lower.matches(".*\\.(jpg|jpeg|png|webp)$"))artworks.put(lower.replaceFirst("\\.[^.]+$", ""),item);
        }
        for(Entry entry:entries)if(DocumentsContract.Document.MIME_TYPE_DIR.equals(entry.mime)&&"lrc".equalsIgnoreCase(entry.name)){
            Uri lrcChildren=DocumentsContract.buildChildDocumentsUriUsingTree(tree,entry.id);
            try(Cursor cursor=context.getContentResolver().query(lrcChildren,projection,null,null,null)){
                if(cursor==null)rootLyrics.readFailed=true;
                if(cursor!=null)while(cursor.moveToNext()){
                    String name=cursor.getString(1),mime=cursor.getString(2);
                    if(name!=null&&name.toLowerCase(Locale.ROOT).endsWith(".lrc")&&!DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)){
                        Uri lyric=DocumentsContract.buildDocumentUriUsingTree(tree,cursor.getString(0));lyrics.putIfAbsent(key(name),lyric);rootLyrics.add(name,lyric);
                    }
                }
            }catch(Exception ignored){rootLyrics.readFailed=true;}
        }
        for(Entry entry:entries){
                String id=entry.id,name=entry.name,mime=entry.mime;
                if(DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)){if(recursive&& !"lrc".equalsIgnoreCase(name))walk(context,tree,id,true,songs,seen,jobs,progress,rootLyrics);continue;}
                if(!isAudio(name,mime))continue;
                Uri uri=DocumentsContract.buildDocumentUriUsingTree(tree,id);
                if(!seen.add(tree.getAuthority()+":"+id))continue;
                jobs.add(()->{
                    AudioTags tags=AudioTags.read(context,uri,false);String[] fallback=AudioTags.filename(name);
                    String title=AudioTags.choose(tags.title,fallback[0]),artist=AudioTags.choose(tags.artist,fallback[1]),album="未知专辑";long duration=0;
                    MediaMetadataRetriever retriever=new MediaMetadataRetriever();
                    try{retriever.setDataSource(context,uri);
                        title=AudioTags.choose(tags.title,AudioTags.choose(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),title));
                        artist=AudioTags.choose(tags.artist,AudioTags.choose(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),artist));
                        album=AudioTags.choose(tags.album,AudioTags.choose(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),album));
                        duration=number(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
                    }catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
                    long stableId=-(Integer.toUnsignedLong(uri.toString().hashCode())+1);
                    Uri lyric=lyrics.get(key(name));if(lyric==null)lyric=lyrics.get(key(title));if(lyric==null)lyric=rootLyrics.find(name,title,artist);
                    Song song=new Song(stableId,duration,0,title,artist,album,name,uri,lyric);
                    song.artworkUri=artworks.get(strip(name).toLowerCase(Locale.ROOT));
                    if(song.artworkUri==null)for(String cover:new String[]{"cover","folder","front","album"}){song.artworkUri=artworks.get(cover);if(song.artworkUri!=null)break;}
                    song.lyricReadFailed=rootLyrics.readFailed;
                    song.artworkVersion=entry.version;
                    if(song.artworkUri!=null)for(Entry image:entries)if(song.artworkUri.equals(DocumentsContract.buildDocumentUriUsingTree(tree,image.id))){song.artworkVersion+="/"+image.version;break;}
                    songs.add(song);
                    progress.update(songs.size(),jobs.size(),name);
                });
        }
    }
    private static String key(String filename){if(filename==null)return "";String value=filename.trim().toLowerCase(Locale.ROOT);
        return value.replaceFirst("\\.(lrc|mp3|flac|m4a|aac|wav|aiff|ogg)$","").trim();}
    private static boolean isAudio(String name,String mime){
        String lower=name==null?"":name.toLowerCase(java.util.Locale.ROOT);
        return mime!=null&&mime.startsWith("audio/")||lower.endsWith(".mp3")||lower.endsWith(".flac")||lower.endsWith(".m4a")||lower.endsWith(".aac")||lower.endsWith(".wav")||lower.endsWith(".aiff")||lower.endsWith(".ogg");
    }
    private static String strip(String name){return name==null?"未知歌曲":name.replaceFirst("\\.[^.]+$","");}
    private static long number(String value){try{return Long.parseLong(value);}catch(Exception ignored){return 0;}}
}
