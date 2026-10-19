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
    private static final class Entry { final String id,name,mime;Entry(String id,String name,String mime){this.id=id;this.name=name;this.mime=mime;} }
    static List<Song> scan(Context context,Set<String> folders,boolean recursive){
        List<Song> songs=new ArrayList<>();
        Set<String> seen=new HashSet<>();
        for(String value:folders)try{Uri tree=Uri.parse(value);walk(context,tree,DocumentsContract.getTreeDocumentId(tree),recursive,songs,seen);}catch(Exception ignored){}
        songs.sort((left,right)->left.title.compareToIgnoreCase(right.title));return songs;
    }
    private static void walk(Context context,Uri tree,String documentId,boolean recursive,List<Song> songs,Set<String> seen){
        Uri children=DocumentsContract.buildChildDocumentsUriUsingTree(tree,documentId);
        String[] projection={DocumentsContract.Document.COLUMN_DOCUMENT_ID,DocumentsContract.Document.COLUMN_DISPLAY_NAME,DocumentsContract.Document.COLUMN_MIME_TYPE};
        List<Entry> entries=new ArrayList<>();
        try(Cursor cursor=context.getContentResolver().query(children,projection,null,null,null)){
            if(cursor==null)return;
            while(cursor.moveToNext())entries.add(new Entry(cursor.getString(0),cursor.getString(1),cursor.getString(2)));
        }catch(Exception ignored){return;}
        Map<String,Uri> lyrics=new HashMap<>();
        for(Entry entry:entries)if(DocumentsContract.Document.MIME_TYPE_DIR.equals(entry.mime)&&"lrc".equalsIgnoreCase(entry.name)){
            Uri lrcChildren=DocumentsContract.buildChildDocumentsUriUsingTree(tree,entry.id);
            try(Cursor cursor=context.getContentResolver().query(lrcChildren,projection,null,null,null)){
                if(cursor!=null)while(cursor.moveToNext()){
                    String name=cursor.getString(1),mime=cursor.getString(2);
                    if(name!=null&&name.toLowerCase(Locale.ROOT).endsWith(".lrc")&&!DocumentsContract.Document.MIME_TYPE_DIR.equals(mime))
                        lyrics.putIfAbsent(key(name),DocumentsContract.buildDocumentUriUsingTree(tree,cursor.getString(0)));
                }
            }catch(Exception ignored){}
        }
        for(Entry entry:entries){
                String id=entry.id,name=entry.name,mime=entry.mime;
                if(DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)){if(recursive&& !"lrc".equalsIgnoreCase(name))walk(context,tree,id,true,songs,seen);continue;}
                if(!isAudio(name,mime))continue;
                Uri uri=DocumentsContract.buildDocumentUriUsingTree(tree,id);
                if(!seen.add(tree.getAuthority()+":"+id))continue;
                MediaMetadataRetriever retriever=new MediaMetadataRetriever();
                try{retriever.setDataSource(context,uri);
                    String title=value(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),strip(name));
                    String artist=value(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),"未知歌手");
                    String album=value(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),"未知专辑");
                    long duration=number(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
                    long stableId=-(Integer.toUnsignedLong(uri.toString().hashCode())+1);
                    Uri lyric=lyrics.get(key(name));if(lyric==null)lyric=lyrics.get(key(title));
                    songs.add(new Song(stableId,duration,0,title,artist,album,name,uri,lyric));
                }catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
        }
    }
    private static String key(String filename){if(filename==null)return "";String value=filename.trim().toLowerCase(Locale.ROOT);
        return value.replaceFirst("\\.(lrc|mp3|flac|m4a|aac|wav|aiff|ogg)$","").trim();}
    private static boolean isAudio(String name,String mime){
        String lower=name==null?"":name.toLowerCase(java.util.Locale.ROOT);
        return mime!=null&&mime.startsWith("audio/")||lower.endsWith(".mp3")||lower.endsWith(".flac")||lower.endsWith(".m4a")||lower.endsWith(".aac")||lower.endsWith(".wav")||lower.endsWith(".aiff")||lower.endsWith(".ogg");
    }
    private static String value(String text,String fallback){return text==null||text.isBlank()?fallback:text;}
    private static String strip(String name){return name==null?"未知歌曲":name.replaceFirst("\\.[^.]+$","");}
    private static long number(String value){try{return Long.parseLong(value);}catch(Exception ignored){return 0;}}
}
