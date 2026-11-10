package com.xcosmos.minivoice;

import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;

public final class SnapshotMetadataCacheTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args)throws Exception{
        SnapshotMetadataCache<Object> cache=new SnapshotMetadataCache<>();AtomicInteger builds=new AtomicInteger();
        Object first=cache.value(Arrays.asList(1,2,"song"),()->{builds.incrementAndGet();return new Object();});String revision=cache.revision();
        for(int i=0;i<100;i++)check(cache.value(Arrays.asList(1,2,"song"),()->{builds.incrementAndGet();return new Object();})==first,"Clock polling preserves cold metadata identity");
        check(builds.get()==1&&cache.revision().equals(revision),"Unchanged polls do not rebuild or change revision");
        Object changed=cache.value(Arrays.asList(2,2,"song"),()->{builds.incrementAndGet();return new Object();});check(changed!=first&&!cache.revision().equals(revision),"Preference changes revise cold fields");
        revision=cache.revision();cache.value(Arrays.asList(2,3,"song"),Object::new);check(!cache.revision().equals(revision),"Queue update revises cold fields");
        cache.invalidate();revision=cache.revision();cache.value(Arrays.asList(2,3,"next song"),Object::new);check(!cache.revision().equals(revision),"Current song or explicit invalidation rebuilds metadata");
        System.out.println("PASS Android snapshot cache: 100 playback polls reuse metadata, preferences/queue/song invalidation");
    }
}
