package com.xcosmos.minivoice;

public final class CoverWorkingSetTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        CoverWorkingSet<String> set=new CoverWorkingSet<>(100);
        set.beginFrame();set.visible("cover",0);set.offer("cover","high",1600,30,0);set.offer("cover","late preview",640,10,1);
        check(set.get("cover").value.equals("high"),"late low-quality completion must not replace high quality");
        set.beginFrame();set.visible("cover",2000);set.trim(2000,"cover");check(set.get("cover")!=null,"visible cover survives independent shared LRU eviction");
        set.offer("offscreen","large",1600,90,2000);set.trim(2001,"cover");check(set.get("cover")!=null&&set.get("offscreen")==null,"offscreen memory released before focused cover");
        set.visible("also-visible",2002);set.offer("also-visible","retained",640,90,2002);set.trim(2002,"cover");check(set.get("also-visible")!=null&&set.get("cover")!=null,"memory pressure cannot start a visible-image decode/evict cycle");
        set.offer("other-version","changed",640,20,2100);check(set.get("cover").value.equals("high"),"new source version does not mutate old source");
        set.beginFrame();set.trim(5000,null);check(set.get("cover")==null&&set.get("other-version")==null,"offscreen covers released after grace interval");
        set.offer("cover","fresh",640,20,6000);set.clear();check(set.get("cover")==null,"empty page releases working set");
        System.out.println("PASS: visible covers stay sharp, stale lower-quality results cannot downgrade, offscreen memory is reclaimed and new source versions remain isolated");
    }
}
