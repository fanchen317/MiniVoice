package com.xcosmos.minivoice;

import java.util.*;

/** Strong references for the current viewport, independent of shared decode-cache eviction. */
final class CoverWorkingSet<T> {
    static final class Image<T> {
        final T value;final int quality,bytes;long seen;
        Image(T value,int quality,int bytes,long seen){this.value=value;this.quality=quality;this.bytes=bytes;this.seen=seen;}
    }
    private final LinkedHashMap<String,Image<T>> images=new LinkedHashMap<>(16,.75f,true);
    private final Set<String> visible=new HashSet<>();private final long budget;
    CoverWorkingSet(long budget){this.budget=budget;}
    void beginFrame(){visible.clear();}
    void visible(String key,long now){visible.add(key);Image<T> image=images.get(key);if(image!=null)image.seen=now;}
    Image<T> get(String key){return images.get(key);}
    void offer(String key,T image,int quality,int bytes,long now){Image<T> old=images.get(key);if(old!=null&&old.quality>quality)return;images.put(key,new Image<>(image,quality,bytes,now));}
    void trim(long now,String focused){
        images.entrySet().removeIf(e->!e.getKey().equals(focused)&&!visible.contains(e.getKey())&&now-e.getValue().seen>1500);
        long bytes=0;for(Image<T> item:images.values())bytes+=item.bytes;
        Iterator<Map.Entry<String,Image<T>>> iterator=images.entrySet().iterator();while(bytes>budget&&iterator.hasNext()){Map.Entry<String,Image<T>> entry=iterator.next();if(!entry.getKey().equals(focused)&&!visible.contains(entry.getKey())){bytes-=entry.getValue().bytes;iterator.remove();}}
        iterator=images.entrySet().iterator();while(bytes>budget&&iterator.hasNext()){Map.Entry<String,Image<T>> entry=iterator.next();if(!entry.getKey().equals(focused)){bytes-=entry.getValue().bytes;iterator.remove();}}
    }
    void clear(){images.clear();visible.clear();}
}
