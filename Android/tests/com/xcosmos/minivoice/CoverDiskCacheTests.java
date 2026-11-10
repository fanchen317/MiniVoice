package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Synthetic derived files only; no Android or real library dependencies. */
public final class CoverDiskCacheTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    private static String key(char digit){return "v3-"+String.join("",Collections.nCopies(64,String.valueOf(digit)));}
    public static void main(String[] args)throws Exception{
        Path directory=Files.createTempDirectory("minivoice-cover-groups-");
        try{
            CoverDiskCache cache=new CoverDiskCache(directory.toFile(),20,30L*86400*1000);long revision=cache.generation();
            check(cache.write(key('a'),"jpg",new byte[7],revision)&&cache.write(key('a'),"stamp",new byte[2],revision)&&cache.write(key('a'),"faces",new byte[1],revision),"Grouped master and metadata write");
            check(cache.write(key('b'),"jpg",new byte[8],revision),"Second master");cache.read(key('a'),"jpg");
            check(cache.write(key('c'),"jpg",new byte[8],revision),"Third master");
            check(cache.sizeBytes()<=20&&cache.read(key('b'),"jpg")==null,"Byte budget evicts the least recent group");
            // The whole a group must be removed, including its version/missing/face records.
            cache.read(key('c'),"jpg");cache.write(key('d'),"jpg",new byte[12],revision);
            check(cache.read(key('a'),"jpg")==null&&cache.read(key('a'),"stamp")==null&&cache.read(key('a'),"faces")==null,"Eviction removes every member of a cover group");
            check(!cache.write(key('d'),"stamp",new byte[9],revision)&&cache.sizeBytes()<=20,"Protected group metadata cannot exceed the total byte budget");
            CoverDiskCache reopened=new CoverDiskCache(directory.toFile(),20,30L*86400*1000);check(reopened.read(key('d'),"jpg").length==12,"Master survives process restart");
            for(File file:directory.toFile().listFiles())file.setLastModified(System.currentTimeMillis()-40L*86400*1000);
            CoverDiskCache expired=new CoverDiskCache(directory.toFile(),20,30L*86400*1000);check(expired.read(key('d'),"jpg")==null,"Unused entire groups expire");
            check(cache.write(key('e'),"jpg",new byte[4],revision),"Current master write");
            cache.maintenance(()->{for(File file:directory.toFile().listFiles())Files.delete(file.toPath());return null;});
            check(!cache.write(key('e'),"jpg",new byte[4],revision)&&cache.read(key('e'),"jpg")==null,"Old extraction cannot recreate a cleared master");
            check(!cache.write(key('e'),"stamp",new byte[4],revision)&&!cache.write(key('e'),"none",new byte[0],revision),"Old metadata and negative markers cannot recreate a cleared group");
            check(cache.write(key('f'),"jpg",new byte[4],cache.generation()),"Current request regenerates the missing master");
            cache.retain(Collections.singleton(key('a')));check(cache.read(key('f'),"jpg")==null,"Removed library identity is pruned");
            Path source=directory.resolveSibling(directory.getFileName()+"-original");Files.write(source,new byte[]{99});
            try{
                Files.createSymbolicLink(directory.resolve(key('a')+".jpg"),source);check(cache.read(key('a'),"jpg")==null,"Read rejects image symlink");
                boolean rejected=false;try{cache.write(key('a'),"jpg",new byte[]{0},cache.generation());}catch(IOException expected){rejected=true;}check(rejected&&Files.readAllBytes(source)[0]==99,"Write does not replace or follow a substituted link");
                rejected=false;try{cache.write("../music","jpg",new byte[1],cache.generation());}catch(IOException expected){rejected=true;}check(rejected,"Group cannot escape cache root");
            }finally{Files.deleteIfExists(source);}
            Path linked=directory.resolveSibling(directory.getFileName()+"-linked");Files.createSymbolicLink(linked,directory);
            try{CoverDiskCache invalid=new CoverDiskCache(linked.toFile(),20,30L*86400*1000);check(invalid.read(key('f'),"jpg")==null,"Read rejects symlink cache root");}finally{Files.deleteIfExists(linked);}
        }finally{try(java.util.stream.Stream<Path> paths=Files.walk(directory)){paths.sorted(Comparator.reverseOrder()).forEach(path->{try{Files.deleteIfExists(path);}catch(IOException ignored){}});}}
        System.out.println("PASS covers grouped byte LRU, metadata accounting, restart, expiry, clear generations, library pruning and symlink boundaries");
    }
}
