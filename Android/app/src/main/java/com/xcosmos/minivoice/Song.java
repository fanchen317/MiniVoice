package com.xcosmos.minivoice;

import android.net.Uri;

final class Song {
    final long id, duration, albumId;
    final String title, artist, album, path;
    final Uri uri;
    Song(long id, long duration, long albumId, String title, String artist, String album, String path, Uri uri) {
        this.id=id; this.duration=duration; this.albumId=albumId; this.title=title; this.artist=artist; this.album=album; this.path=path; this.uri=uri;
    }
}
