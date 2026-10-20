package com.xcosmos.minivoice;

/** Character position of the lyric ink. Plain LRC receives estimated line timing. */
final class LyricSweep {
    static float characters(Lyrics.Line line,long next,long duration,long position){
        if(line.ms<0)return line.text.length();
        long end=next>line.ms?next:duration>line.ms?duration:line.ms+4000;
        if(line.words.isEmpty())return line.text.length()*progress(position,line.ms,Math.min(end,line.ms+12000));
        int cursor=0;float visible=0;
        for(int i=0;i<line.words.size();i++){
            Lyrics.Word word=line.words.get(i);int start=line.text.indexOf(word.text,cursor);if(start<0)continue;
            long finish=i+1<line.words.size()?line.words.get(i+1).ms:end;
            if(position<word.ms)break;
            visible=start+word.text.length()*progress(position,word.ms,finish);cursor=start+word.text.length();
        }return Math.min(line.text.length(),visible);
    }
    private static float progress(long position,long start,long end){return Math.max(0,Math.min(1,(position-start)/(float)Math.max(1,end-start)));}
}
