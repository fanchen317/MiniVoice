package com.xcosmos.minivoice;

import java.util.*;

public final class SongSelectionTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        SongSelection s=new SongSelection();List<Long> page=Arrays.asList(7L,9L,12L);
        s.toggle(9);check(s.size()==1&&s.contains(9),"toggle selects stable ID");
        s.retain(Arrays.asList(12L,9L,7L));check(s.contains(9),"sorting preserves selected identity");
        s.toggleAll(page);check(s.size()==3&&s.all(page),"select all includes the filtered page");
        s.retain(Arrays.asList(9L,12L));check(s.size()==2&&!s.contains(7),"filter or removal discards invisible selections");
        s.toggleAll(Arrays.asList(9L,12L));check(s.size()==0,"toggle all deselects complete selection");
        s.toggleAll(Arrays.asList(7L,7L,12L));check(s.size()==2,"duplicates never count twice");
        s.retain(Collections.emptyList());check(s.size()==0&&!s.all(Collections.emptyList()),"empty pages cannot have all selected");
        s.toggle(42);s.clear();check(s.size()==0,"navigation can reset selection");
        System.out.println("PASS: stable multi-selection survives sorting and is bounded to visible filtered songs");
    }
}
