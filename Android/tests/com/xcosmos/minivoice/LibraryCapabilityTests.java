package com.xcosmos.minivoice;
import java.util.*;
public final class LibraryCapabilityTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        check(IncrementalScan.reusable("1000:4096","1000:4096"),"Unchanged file must reuse metadata");
        check(!IncrementalScan.reusable("1000:4096","1001:4096"),"Edited tags must invalidate metadata");
        check(!IncrementalScan.reusable("1000:4096","1000:4097"),"Changed size must invalidate metadata");
        check(!IncrementalScan.reusable("0:4096","0:4096"),"Unknown modification date must not hide changes");
        check(!IncrementalScan.reusable("1000:0","1000:0"),"Unknown size must not hide changes");
        check(!IncrementalScan.reusable("","1000:4096"),"Old snapshot must be upgraded by reading metadata");
        check(ArtistNames.key("  ＪＡＹ　 Chou ").equals("jay chou"),"Unicode/case/space normalization");
        Map<String,String> aliases=new HashMap<>();aliases.put("jay chou","周杰伦");
        check(ArtistNames.canonical("JAY CHOU",aliases).equals("周杰伦"),"Explicit alias merge");
        check(!ArtistNames.key("A / B").equals(ArtistNames.key("A")),"Collaborating artists must not be silently split");
        aliases.put("周杰伦","Jay Chou");check(!ArtistNames.canonical("Jay Chou",aliases).isEmpty(),"Alias cycle must terminate");
        check(ArtistNames.similarDuration(200000,201999),"Duplicate candidate duration tolerance");
        check(!ArtistNames.similarDuration(200000,230000),"Different versions must not be silently merged");
        check(ArtistNames.duplicateKey("Song","未知歌手",200000).isEmpty(),"Unknown artists are not reliable duplicate matches");
        System.out.println("PASS: incremental invalidation, unknown provider metadata, artist aliases/cycles, conservative duplicate candidates");
    }
}
