package com.xcosmos.minivoice;

/** Adaptive table columns. Narrow phones retain the two-line song row. */
final class LibraryColumns {
    final int artist,album;
    LibraryColumns(float width,float density){
        float dp=width/density;
        artist=dp>=560?Math.round(Math.min(180,dp*.20f)*density):0;
        album=dp>=760?Math.round(Math.min(240,dp*.22f)*density):0;
    }
}
