package com.xcosmos.minivoice;
/** Platform model conversion; lyric timing is owned by Shared/Core. */
final class LyricSweep {
    static float characters(Lyrics.Line line,long next,long duration,long position){
        int count=line.words.size();long[] starts=new long[count],ends=new long[count];String[] words=new String[count];
        for(int i=0;i<count;i++){Lyrics.Word word=line.words.get(i);starts[i]=word.ms;ends[i]=word.endMs;words[i]=word.text;}
        return (float)SharedCore.sweep(line.ms,line.text,starts,ends,words,next,duration,position);
    }
}
