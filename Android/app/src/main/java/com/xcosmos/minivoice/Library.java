package com.xcosmos.minivoice;

import android.content.ContentUris;
import android.content.Context;
import android.database.Cursor;
import android.provider.MediaStore;
import java.util.ArrayList;
import java.util.List;

final class Library {
    static List<Song> load(Context context,ScanProgress progress) {
        List<Song> songs = new ArrayList<>();
        String[] columns = {MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE, MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM, MediaStore.Audio.Media.ALBUM_ID, MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.RELATIVE_PATH,MediaStore.Audio.Media.DISPLAY_NAME,MediaStore.Audio.Media.DATE_MODIFIED,MediaStore.Audio.Media.SIZE};
        try (Cursor cursor = context.getContentResolver().query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                columns, MediaStore.Audio.Media.IS_MUSIC + " != 0", null, MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC")) {
            if (cursor == null) throw new IllegalStateException("无法读取系统音乐库");
            while (cursor.moveToNext()) {
                progress.update(cursor.getPosition(),cursor.getCount(),"读取系统音乐库");
                long id=cursor.getLong(0), albumId=cursor.getLong(4), duration=cursor.getLong(5);
                android.net.Uri uri=ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,id);
                String filename=cursor.getString(7);String[] fallback=AudioTags.filename(filename);
                AudioTags tags=AudioTags.read(context,uri,false);
                String title=AudioTags.choose(tags.title,clean(cursor.getString(1))),artist=AudioTags.choose(tags.artist,clean(cursor.getString(2))),album=AudioTags.choose(tags.album,clean(cursor.getString(3)));
                if(!AudioTags.valid(cursor.getString(1))||title.equals(filename)||title.equals(filename==null?"":filename.replaceFirst("\\.[^.]+$", "")))title=AudioTags.choose(tags.title,fallback[0]);
                if(!AudioTags.valid(artist))artist=fallback[1];
                android.media.MediaMetadataRetriever retriever=new android.media.MediaMetadataRetriever();
                try{retriever.setDataSource(context,uri);
                    title=AudioTags.choose(tags.title,AudioTags.choose(retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_TITLE),title));
                    artist=AudioTags.choose(tags.artist,AudioTags.choose(retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_ARTIST),artist));
                    album=AudioTags.choose(tags.album,AudioTags.choose(retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_ALBUM),album));
                }catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
                Song song=new Song(id,duration,albumId,title,artist,
                    album,clean(cursor.getString(6)),
                    ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,id));
                song.artworkVersion=cursor.getLong(8)+":"+cursor.getLong(9);songs.add(song);
            }
        }
        songs.sort((a,b)->a.title.compareToIgnoreCase(b.title));
        progress.update(songs.size(),songs.size(),"扫描完成");
        return songs;
    }
    private static String clean(String text) { return text == null || text.equals("<unknown>") ? "未知" : text; }
}
