package com.xcosmos.minivoice;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class PageScrollMemoryTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        PageScrollMemory memory=new PageScrollMemory();List<String> artists=Arrays.asList("A","B","C","D");
        memory.save("歌手\n",artists,2,-31);
        memory.save("歌手\nC",Arrays.asList("1","2","3"),1,-17);
        memory.save("专辑\n",artists,1,-22);
        PageScrollMemory.Position parent=memory.restore("歌手\n",artists);
        check(parent.index==2&&parent.offset==-31,"Child navigation lost the artist grid anchor");
        PageScrollMemory.Position child=memory.restore("歌手\nC",Arrays.asList("1","2","3"));
        check(child.index==1&&child.offset==-17,"Reopening a group lost its song position");
        check(memory.restore("专辑\n",artists).offset==-22,"Album and artist pages shared scroll state");
        check(memory.restore("歌手\n",Arrays.asList("C","A","B","D")).index==0,"Sorting failed to retain the visible identity");
        check(memory.restore("歌手\n",Arrays.asList("A","B")).index==1,"Removed item fallback went out of bounds");
        memory.save("歌手\n",Collections.emptyList(),0,0);
        check(memory.restore("歌手\n",artists).offset==-31,"An unlaid-out empty page overwrote its anchor");
        check(memory.restore("歌手\n",Collections.emptyList())==null,"Empty page requested an invalid selection");
        System.out.println("PASS: independent artist/album/group scroll anchors, pixel offsets, stable identities after sorting and empty/rebuilt list protection");
    }
}
