package com.xcosmos.minivoice;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;

/** Bounded encoded resources; identical readers share work without holding the cache lock during I/O. */
final class ByteRequestCache {
    private final int limit;
    private final LinkedHashMap<String,byte[]> entries=new LinkedHashMap<>(16,.75f,true);
    private final Map<String,Flight> flights=new HashMap<>();
    private static final class Flight {
        final FutureTask<byte[]> task;final long generation,memoryGeneration;
        Flight(Callable<byte[]> loader,long generation,long memoryGeneration){task=new FutureTask<>(loader);this.generation=generation;this.memoryGeneration=memoryGeneration;}
    }
    private long generation,memoryGeneration;
    private int bytes;
    ByteRequestCache(int limit){this.limit=Math.max(0,limit);}
    byte[] data(String key,boolean retain,Callable<byte[]> loader)throws Exception{
        final Flight flight;final boolean owner;
        synchronized(this){
            byte[] cached=entries.get(key);if(cached!=null)return cached;
            Flight existing=flights.get(key);owner=existing==null;
            flight=owner?new Flight(loader,generation,memoryGeneration):existing;if(owner)flights.put(key,flight);
        }
        if(owner)flight.task.run();
        try{
            byte[] result=flight.task.get();
            synchronized(this){
                if(generation!=flight.generation)throw new IOException("封面缓存已失效，请重试");
                if(retain&&memoryGeneration==flight.memoryGeneration&&result!=null&&result.length<=limit){
                    byte[] previous=entries.put(key,result);if(previous!=null)bytes-=previous.length;bytes+=result.length;
                    Iterator<byte[]> oldest=entries.values().iterator();while(bytes>limit&&oldest.hasNext()){bytes-=oldest.next().length;oldest.remove();}
                }
            }
            return result;
        }catch(ExecutionException error){Throwable cause=error.getCause();if(cause instanceof Exception)throw (Exception)cause;throw error;}
        finally{synchronized(this){if(flight.task.isDone()&&flights.get(key)==flight)flights.remove(key);}}
    }
    synchronized void trimMemory(){memoryGeneration++;entries.clear();bytes=0;}
    synchronized void invalidate(){generation++;trimMemory();flights.clear();}
    synchronized int sizeBytes(){return bytes;}
}
