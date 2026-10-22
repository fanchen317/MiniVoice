package com.xcosmos.minivoice;

/** Android/JVM adapter only. The implementation and wire model live in Shared/Core. */
final class SharedCore {
    static {System.loadLibrary("minivoice_core");}
    static final class Word {final long ms,endMs;final String text;Word(long ms,long endMs,String text){this.ms=ms;this.endMs=endMs;this.text=text;}}
    static final class Line {final long ms;final String text,translation;final Word[] words;Line(long ms,String text,String translation,Word[] words){this.ms=ms;this.text=text;this.translation=translation;this.words=words;}}
    static native Line[] parseLyrics(String raw);
    static native String artistKey(String value);
    static native String canonicalArtist(String value,String[] keys,String[] values);
    static native boolean reusable(String previous,String current);
    static native int[] restoreAnchor(String[] items,String identity,int index,int offset);
    static native boolean canSnapshot(String[] rendered,String[] current,int first,int last);
    static native double sweep(long ms,String text,long[] starts,long[] ends,String[] words,long next,long duration,long position);
    static native String execute(String request);
}
