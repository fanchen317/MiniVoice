package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/** Synthetic bytes only: bounded memory/disk, concurrent readers and clear-during-I/O races. */
public final class ArtworkRequestCacheTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    private static String key(char value){char[] chars=new char[64];Arrays.fill(chars,value);return new String(chars);}
    public static void main(String[] args)throws Exception{
        ByteRequestCache memory=new ByteRequestCache(8);AtomicInteger loads=new AtomicInteger();
        byte[] first=memory.data("a",true,()->{loads.incrementAndGet();return new byte[4];});
        check(memory.data("a",true,()->{throw new AssertionError("memory miss");})==first,"Repeated tiles reuse encoded bytes");
        memory.data("b",true,()->new byte[4]);memory.data("a",true,()->new byte[4]);memory.data("c",true,()->new byte[4]);
        memory.data("b",true,()->{loads.incrementAndGet();return new byte[4];});check(loads.get()==2&&memory.sizeBytes()==8,"Memory evicts least-recent resource within byte budget");
        memory.data("large",true,()->new byte[9]);check(memory.sizeBytes()<=8,"Oversized original cannot exceed memory budget");
        ExecutorService pool=Executors.newFixedThreadPool(3);
        try{
            CountDownLatch started=new CountDownLatch(1),release=new CountDownLatch(1);AtomicInteger reads=new AtomicInteger();
            Callable<byte[]> reader=()->memory.data("shared",true,()->{reads.incrementAndGet();started.countDown();release.await();return new byte[]{7};});
            Future<byte[]> one=pool.submit(reader);check(started.await(5,TimeUnit.SECONDS),"First reader started");
            Future<byte[]> two=pool.submit(reader);Thread.sleep(30);release.countDown();check(one.get(5,TimeUnit.SECONDS)==two.get(5,TimeUnit.SECONDS)&&reads.get()==1,"Concurrent same-key reads share one extraction");
            CountDownLatch cancelStarted=new CountDownLatch(1),cancelRelease=new CountDownLatch(1),cancelExited=new CountDownLatch(1);
            Future<byte[]> sharedOwner=pool.submit(()->memory.data("cancel-shared",true,()->{cancelStarted.countDown();cancelRelease.await();return new byte[]{3};}));
            check(cancelStarted.await(5,TimeUnit.SECONDS),"Cancelable shared reader started");
            AtomicReference<Thread> cancelThread=new AtomicReference<>();
            Future<byte[]> canceledWaiter=pool.submit(()->{cancelThread.set(Thread.currentThread());try{return memory.data("cancel-shared",true,()->{throw new AssertionError("Canceled reader duplicated extraction");});}finally{cancelExited.countDown();}});
            long cancelDeadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);while((cancelThread.get()==null||cancelThread.get().getState()!=Thread.State.WAITING)&&System.nanoTime()<cancelDeadline)Thread.sleep(1);
            check(cancelThread.get()!=null&&cancelThread.get().getState()==Thread.State.WAITING,"Second reader joined shared flight");canceledWaiter.cancel(true);check(cancelExited.await(5,TimeUnit.SECONDS),"Interrupted reader exited");
            AtomicReference<Thread> thirdThread=new AtomicReference<>();
            Future<byte[]> nextWaiter=pool.submit(()->{thirdThread.set(Thread.currentThread());return memory.data("cancel-shared",true,()->{throw new AssertionError("Interrupted waiter removed live shared flight");});});
            long thirdDeadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);while((thirdThread.get()==null||thirdThread.get().getState()!=Thread.State.WAITING)&&!nextWaiter.isDone()&&System.nanoTime()<thirdDeadline)Thread.sleep(1);
            check(!nextWaiter.isDone(),"Later reader still waits for original extraction");cancelRelease.countDown();check(sharedOwner.get(5,TimeUnit.SECONDS)==nextWaiter.get(5,TimeUnit.SECONDS),"Canceling one reader preserves other shared readers");
            CountDownLatch staleStarted=new CountDownLatch(1),finishStale=new CountDownLatch(1);
            Future<byte[]> stale=pool.submit(()->memory.data("stale",true,()->{staleStarted.countDown();finishStale.await();return new byte[]{9};}));
            check(staleStarted.await(5,TimeUnit.SECONDS),"Stale reader started");memory.invalidate();finishStale.countDown();boolean rejected=false;
            try{stale.get(5,TimeUnit.SECONDS);}catch(ExecutionException expected){rejected=expected.getCause() instanceof IOException;}
            check(rejected&&memory.sizeBytes()==0,"Clear rejects in-flight old bytes and prevents resurrection");
            AtomicInteger attempts=new AtomicInteger();try{memory.data("retry",true,()->{attempts.incrementAndGet();throw new IOException("temporary");});}catch(IOException expected){}
            check(memory.data("retry",true,()->{attempts.incrementAndGet();return new byte[]{1};})[0]==1&&attempts.get()==2,"Failure is retried rather than cached as success");
            CountDownLatch trimming=new CountDownLatch(1),complete=new CountDownLatch(1);
            Future<byte[]> ongoing=pool.submit(()->memory.data("trim",true,()->{trimming.countDown();complete.await();return new byte[]{1,2};}));
            check(trimming.await(5,TimeUnit.SECONDS),"Trim reader started");memory.trimMemory();
            AtomicReference<Thread> waiterThread=new AtomicReference<>();
            Future<byte[]> joinedAfterTrim=pool.submit(()->{waiterThread.set(Thread.currentThread());return memory.data("trim",true,()->{throw new AssertionError("Post-trim reader must join existing flight");});});
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
            while((waiterThread.get()==null||waiterThread.get().getState()!=Thread.State.WAITING)&&System.nanoTime()<deadline)Thread.sleep(1);
            check(waiterThread.get()!=null&&waiterThread.get().getState()==Thread.State.WAITING,"Reader joined old in-flight request after trim");
            complete.countDown();check(ongoing.get(5,TimeUnit.SECONDS)==joinedAfterTrim.get(5,TimeUnit.SECONDS)&&memory.sizeBytes()==0,"Memory pressure prevents a late-joining reader from repopulating old bytes");
        }finally{pool.shutdownNow();}
        Path folder=Files.createTempDirectory("minivoice-artwork-cache-");
        try{
            ArtworkDiskCache disk=new ArtworkDiskCache(folder.toFile(),16,30L*86400*1000);long generation=disk.generation();
            check(disk.write(key('a'),new byte[]{1,2,3,4,5,6},generation),"First disk write");
            check(Arrays.equals(disk.read(key('a')),new byte[]{1,2,3,4,5,6}),"Encoded disk round trip");
            check(disk.write(key('b'),new byte[6],generation)&&disk.write(key('c'),new byte[6],generation)&&disk.sizeBytes()<=16,"Disk budget prunes oldest derived resources");
            disk.maintenance(()->{for(File file:folder.toFile().listFiles())Files.delete(file.toPath());return null;});
            check(!disk.write(key('d'),new byte[4],generation)&&disk.read(key('d'))==null,"Clear generation prevents stale disk recreation");
            check(disk.write(key('e'),new byte[4],disk.generation()),"A current visible resource rebuilds after clearing");
            ArtworkDiskCache reopened=new ArtworkDiskCache(folder.toFile(),16,30L*86400*1000);check(reopened.read(key('e')).length==4,"Disk cache survives process restart");
            boolean denied=false;try{disk.write("../music",new byte[]{1},disk.generation());}catch(IOException expected){denied=true;}check(denied,"Cache key cannot escape directory");
            Path original=folder.resolveSibling(folder.getFileName()+"-original");Files.write(original,new byte[]{99});
            try{Files.createSymbolicLink(folder.resolve(key('f')+".img"),original);check(disk.read(key('f'))==null,"Derived image read does not follow a symlink");check(Files.readAllBytes(original)[0]==99,"Original stays untouched");}finally{Files.deleteIfExists(original);}
        }finally{try(java.util.stream.Stream<Path> paths=Files.walk(folder)){paths.sorted(Comparator.reverseOrder()).forEach(path->{try{Files.deleteIfExists(path);}catch(IOException ignored){}});}}
        System.out.println("PASS Android artwork cache: byte budgets, LRU, same-key coalescing, clear/trim races, retry, disk restart, path/symlink isolation");
    }
}
