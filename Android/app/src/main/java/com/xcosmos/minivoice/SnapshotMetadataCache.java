package com.xcosmos.minivoice;

import java.util.UUID;
import java.util.concurrent.Callable;

/** Cold snapshot fields share a revision independently of the playback position. */
final class SnapshotMetadataCache<T> {
    private Object key;
    private T cached;
    private String revision=UUID.randomUUID().toString();
    void invalidate(){key=null;cached=null;revision=UUID.randomUUID().toString();}
    T value(Object nextKey,Callable<T> build)throws Exception{
        if(cached==null||!nextKey.equals(key)){T next=build.call();key=nextKey;cached=next;revision=UUID.randomUUID().toString();}
        return cached;
    }
    String revision(){return revision;}
}
