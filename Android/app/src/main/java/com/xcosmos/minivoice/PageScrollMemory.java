package com.xcosmos.minivoice;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Per-page anchors survive rebuilding a grid/list and preserve the first visible item's offset. */
final class PageScrollMemory {
    static final class Position {
        final int index,offset;
        Position(int index,int offset){this.index=index;this.offset=offset;}
    }
    private static final class Anchor {
        final String item;final int index,offset;
        Anchor(String item,int index,int offset){this.item=item;this.index=index;this.offset=offset;}
    }
    static boolean canSnapshot(List<String> rendered,List<String> current,int first,int last){
        return first>=0&&last>=first&&last<current.size()&&rendered.equals(current);
    }
    private final Map<String,Anchor> pages=new HashMap<>();
    void save(String page,List<String> items,int first,int offset){
        if(page==null||first<0||first>=items.size())return;
        pages.put(page,new Anchor(items.get(first),first,offset));
    }
    Position restore(String page,List<String> items){
        Anchor anchor=pages.get(page);if(anchor==null||items.isEmpty())return null;
        int index=items.indexOf(anchor.item);if(index<0)index=Math.min(anchor.index,items.size()-1);
        return new Position(index,anchor.offset);
    }
}
