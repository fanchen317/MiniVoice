package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.Callable;

/** Regenerable web artwork only. Indexing happens once, never by enumerating on every tile request. */
final class ArtworkDiskCache {
    private static final long TOUCH_INTERVAL=60_000;
    private static final int MAX_RESOURCE=32*1024*1024;
    private final File root;
    private final long limit,age;
    private final Map<File,Entry> entries=new HashMap<>();
    private boolean loaded;
    private long bytes,generation;
    private static final class Entry {long bytes,access,persisted;Entry(long bytes,long access){this.bytes=bytes;this.access=access;persisted=access;}}
    ArtworkDiskCache(File root,long limit,long age){this.root=root;this.limit=Math.max(0,limit);this.age=age;}
    synchronized long generation(){return generation;}
    private File file(String key)throws IOException{
        if(!key.matches("[a-f0-9]{64}"))throw new IOException("无效的封面缓存键");
        File target=new File(root,key+".img");
        if(Files.isSymbolicLink(root.toPath())||Files.isSymbolicLink(target.toPath())||!target.getCanonicalFile().getParentFile().equals(root.getCanonicalFile()))throw new IOException("封面缓存路径不可用");
        return target;
    }
    private void load()throws IOException{
        if(loaded)return;file("0000000000000000000000000000000000000000000000000000000000000000");
        if(!root.isDirectory()&&!root.mkdirs())throw new IOException("无法创建封面缓存");
        File[] files=root.listFiles();if(files==null)throw new IOException("无法读取封面缓存");
        entries.clear();bytes=0;
        for(File file:files)if(file.isFile()&&!Files.isSymbolicLink(file.toPath())&&file.getName().matches("[a-f0-9]{64}\\.img")){Entry entry=new Entry(file.length(),file.lastModified());entries.put(file,entry);bytes+=entry.bytes;}
        loaded=true;prune(System.currentTimeMillis(),null);
    }
    synchronized byte[] read(String key){try{
        File file=file(key);load();if(!file.isFile()){Entry missing=entries.remove(file);if(missing!=null)bytes-=missing.bytes;return null;}
        if(file.length()>MAX_RESOURCE)return null;
        byte[] result=Files.readAllBytes(file.toPath());long now=System.currentTimeMillis();Entry entry=entries.get(file);
        if(entry==null){entry=new Entry(result.length,now);entries.put(file,entry);bytes+=result.length;}
        entry.access=now;if(now-entry.persisted>=TOUCH_INTERVAL){if(file.setLastModified(now))entry.persisted=now;}
        return result;
    }catch(IOException ignored){return null;}}
    synchronized boolean write(String key,byte[] data,long revision)throws IOException{
        if(revision!=generation||data.length>limit||data.length>MAX_RESOURCE)return false;
        File destination=file(key);load();File temporary=File.createTempFile("art-",".tmp",root);
        try{try(FileOutputStream out=new FileOutputStream(temporary)){out.write(data);}
            Files.move(temporary.toPath(),destination.toPath(),StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);
            Entry previous=entries.remove(destination);if(previous!=null)bytes-=previous.bytes;
            entries.put(destination,new Entry(data.length,System.currentTimeMillis()));bytes+=data.length;
            if(bytes>limit)prune(System.currentTimeMillis(),destination);return true;
        }finally{temporary.delete();}
    }
    private void prune(long now,File protect){
        long target=bytes>limit?limit*7/8:limit;
        List<Map.Entry<File,Entry>> sorted=new ArrayList<>(entries.entrySet());sorted.sort(Comparator.comparingLong(entry->entry.getValue().access));
        for(Map.Entry<File,Entry> entry:sorted){File file=entry.getKey();if(file.equals(protect)||entry.getValue().access>=now-age&&bytes<=target)continue;
            if(Files.isSymbolicLink(file.toPath()))continue;
            if(file.exists()&&!file.delete())continue;bytes-=entry.getValue().bytes;entries.remove(file);
        }
    }
    synchronized <T>T maintenance(Callable<T> operation)throws Exception{
        generation++;
        try{return operation.call();}finally{loaded=false;entries.clear();bytes=0;}
    }
    synchronized long sizeBytes(){return bytes;}
}
