package com.xcosmos.minivoice;

import java.util.*;

/** Selection follows stable song IDs, and is bounded to the visible page/filter. */
final class SongSelection {
    private final Set<Long> selected=new LinkedHashSet<>();
    boolean contains(long id){return selected.contains(id);}
    int size(){return selected.size();}
    void clear(){selected.clear();}
    void toggle(long id){if(!selected.add(id))selected.remove(id);}
    void retain(Collection<Long> visible){selected.retainAll(new HashSet<>(visible));}
    boolean all(Collection<Long> visible){return !visible.isEmpty()&&selected.containsAll(visible);}
    void toggleAll(Collection<Long> visible){if(all(visible))selected.removeAll(visible);else selected.addAll(visible);retain(visible);}
}
