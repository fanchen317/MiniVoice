package com.xcosmos.minivoice;

import android.content.ContentUris;
import android.content.Context;
import android.database.Cursor;
import android.provider.MediaStore;
import java.util.ArrayList;
import java.util.List;

final class Library {
    static List<Song> load(Context context) {
        List<Song> songs = new ArrayList<>();
        String[] columns = {MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE, MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM, MediaStore.Audio.Media.ALBUM_ID, MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.RELATIVE_PATH};
        try (Cursor cursor = context.getContentResolver().query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                columns, MediaStore.Audio.Media.IS_MUSIC + " != 0", null, MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC")) {
            if (cursor == null) return songs;
            while (cursor.moveToNext()) {
                long id=cursor.getLong(0), albumId=cursor.getLong(4), duration=cursor.getLong(5);
                songs.add(new Song(id,duration,albumId,clean(cursor.getString(1)),clean(cursor.getString(2)),
                    clean(cursor.getString(3)),clean(cursor.getString(6)),
                    ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,id)));
            }
        }
        return songs;
    }
    private static String clean(String text) { return text == null || text.equals("<unknown>") ? "未知" : text; }
}
