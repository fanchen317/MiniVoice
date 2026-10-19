package com.xcosmos.minivoice;

import android.net.Uri;

final class Song {
    final long id, duration, albumId;
    final String title, artist, album, path;
    final Uri uri, lyricUri;
    boolean lyricReadFailed;
    Uri artworkUri;
    String artworkVersion="";
    volatile android.graphics.Bitmap artworkPreview;
    volatile java.io.File artworkFile;
    volatile String artworkCacheKey;
    volatile boolean artworkPrepared;
    Song(long id, long duration, long albumId, String title, String artist, String album, String path, Uri uri) {
        this(id,duration,albumId,title,artist,album,path,uri,null);
    }
    Song(long id, long duration, long albumId, String title, String artist, String album, String path, Uri uri, Uri lyricUri) {
        this.id=id; this.duration=duration; this.albumId=albumId; this.title=title; this.artist=artist; this.album=album; this.path=path; this.uri=uri; this.lyricUri=lyricUri;
    }
}
