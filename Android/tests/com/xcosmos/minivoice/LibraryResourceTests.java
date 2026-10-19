package com.xcosmos.minivoice;

public final class LibraryResourceTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        LyricIndex<String> index=new LyricIndex<>();
        index.add("843 - 前田爱 (AiM) - I wish (我希望).lrc","root/lrc/wish");
        check("root/lrc/wish".equals(index.find("843 - 前田爱 (AiM) - I wish (我希望).flac","I wish (我希望)","前田爱 (AiM)")),"numbered sidecar");
        check("root/lrc/wish".equals(index.find("I wish （我希望）.flac","I wish （我希望）","前田爱 (AiM)")),"normalized title fallback");
        index.add("Other artist - I wish (我希望).lrc","other");
        check(index.find("missing.mp3","I wish (我希望)","unknown")==null,"ambiguous title must not select wrong lyrics");
        check("root/lrc/wish".equals(index.find("843 - 前田爱 (AiM) - I wish (我希望).flac","ignored","ignored")),"exact name wins");
        LyricsLoadState state=new LyricsLoadState();int first=state.begin(1,"lrc:a",0);
        check(first!=0&&state.begin(1,"lrc:a",1)==0,"deduplicate in-flight read");
        state.reset();check(!state.current(first),"discard previous lifecycle result");
        int resumed=state.begin(1,"lrc:a",2);check(resumed!=0,"retry on returning to same song");
        state.fail(resumed,10);check(state.begin(1,"lrc:a",100)==0,"failure backoff");
        check(state.begin(2,"lrc:b",101)!=0,"new song bypasses old retry delay");
        int retry=state.begin(1,"lrc:a",102);state.fail(retry,103);check(state.begin(1,"lrc:a",3103)!=0,"retry after transient failure");
        check(state.begin(1,"lrc:updated",3104)!=0,"rescan source change reloads lyrics");
        for(int count:new int[]{1,100,843,1000,5000,50000}){
            int side=CoverPreviewBudget.side(count);check(side>0&&side<=96,"bounded preview size");
            check((long)side*side*4*count<=CoverPreviewBudget.BYTES,"resident previews exceed pixel memory budget");
        }
        System.out.println("PASS: lyric filename aliases/ambiguity, lifecycle retry and stale results, source updates, resident cover preview budget");
    }
}
