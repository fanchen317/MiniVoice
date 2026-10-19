package com.xcosmos.minivoice;

/** Deduplicate in-flight reads without treating an abandoned or failed read as a loaded lyric. */
final class LyricsLoadState {
    private long song=Long.MIN_VALUE,retryAfter;
    private String source="";
    private boolean failed;
    private int generation;
    int begin(long id,String key,long now){
        boolean same=song==id&&source.equals(key);
        if(same&&(!failed||now<retryAfter))return 0;
        song=id;source=key;failed=false;retryAfter=0;return ++generation;
    }
    boolean current(int ticket){return ticket!=0&&ticket==generation;}
    void fail(int ticket,long now){if(current(ticket)){failed=true;retryAfter=now+3000;}}
    void reset(){song=Long.MIN_VALUE;source="";failed=false;retryAfter=0;++generation;}
}
