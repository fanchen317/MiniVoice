package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.Callable;

/** The existing covers directory contains derived image groups, never library/user data. */
final class CoverDiskCache {
    private static final long TOUCH_INTERVAL=60_000;
    private final File root;
    private final long limit,age;
    private final Map<String,Entry> entries=new HashMap<>();
    private boolean loaded;
    private long bytes,generation,clock;
    private static final class Entry {
        final Map<File,Long> files=new HashMap<>();long bytes,access,persisted,order;
    }
    CoverDiskCache(File root,long limit,long age){this.root=root;this.limit=Math.max(0,limit);this.age=age;}
    synchronized long generation(){return generation;}
    private File file(String key,String extension)throws IOException{
        if(!key.matches("v3-[a-f0-9]{64}")||!extension.matches("jpg|stamp|none|faces"))throw new IOException("无效的主封面缓存身份");
        File target=new File(root,key+"."+extension);validate(target);return target;
    }
    private void validate(File file)throws IOException{
        if(Files.isSymbolicLink(root.toPath())||Files.isSymbolicLink(file.toPath())||!file.getCanonicalFile().getParentFile().equals(root.getCanonicalFile()))throw new IOException("主封面缓存路径不可用");
    }
    private void load()throws IOException{
        if(loaded)return;file("v3-"+String.join("",Collections.nCopies(64,"0")),"jpg");
        if(!root.isDirectory()&&!root.mkdirs())throw new IOException("无法创建主封面缓存");
        File[] files=root.listFiles();if(files==null)throw new IOException("无法读取主封面缓存");
        entries.clear();bytes=0;
        for(File file:files){
            if(!file.isFile()||Files.isSymbolicLink(file.toPath()))continue;
            String name=file.getName();if(!name.matches("v3-[a-f0-9]{64}\\.(jpg|stamp|none|faces)"))continue;
            validate(file);String key=name.substring(0,name.lastIndexOf('.'));Entry entry=entries.computeIfAbsent(key,unused->new Entry());
            long size=file.length();entry.files.put(file,size);entry.bytes+=size;bytes+=size;entry.access=Math.max(entry.access,file.lastModified());entry.persisted=entry.access;entry.order=++clock;
        }
        loaded=true;prune(System.currentTimeMillis(),null);
    }
    synchronized void initialize()throws IOException{load();}
    synchronized byte[] read(String key,String extension){try{
        File file=file(key,extension);load();if(!file.isFile())return null;
        if(file.length()>(extension.equals("jpg")?32L*1024*1024:64L*1024))return null;
        byte[] data=Files.readAllBytes(file.toPath());refresh(key);Entry entry=entries.get(key);long now=System.currentTimeMillis();
        if(entry!=null){entry.access=now;entry.order=++clock;if(now-entry.persisted>=TOUCH_INTERVAL){for(File member:entry.files.keySet())if(!Files.isSymbolicLink(member.toPath()))member.setLastModified(now);entry.persisted=now;}}
        return data;
    }catch(IOException ignored){return null;}}
    private void refresh(String key)throws IOException{
        Entry previous=entries.remove(key);if(previous!=null)bytes-=previous.bytes;
        Entry entry=new Entry();for(String extension:new String[]{"jpg","stamp","none","faces"}){
            File file=file(key,extension);if(!file.isFile())continue;long size=file.length();entry.files.put(file,size);entry.bytes+=size;entry.access=Math.max(entry.access,file.lastModified());
        }
        entry.persisted=entry.access;entry.order=++clock;if(!entry.files.isEmpty()){entries.put(key,entry);bytes+=entry.bytes;}
    }
    synchronized boolean write(String key,String extension,byte[] data,long revision)throws IOException{
        if(revision!=generation||data.length>limit)return false;
        File target=file(key,extension);load();Entry group=entries.get(key);long previous=group==null?0:group.files.getOrDefault(target,0L);
        if(data.length>(extension.equals("jpg")?32L*1024*1024:64L*1024)||(group==null?0:group.bytes)-previous+data.length>limit)return false;
        File temporary=File.createTempFile("cover-",".tmp",root);
        try{try(FileOutputStream output=new FileOutputStream(temporary)){output.write(data);}
            Files.move(temporary.toPath(),target.toPath(),StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);
            refresh(key);if(bytes>limit)prune(System.currentTimeMillis(),key);return true;
        }finally{temporary.delete();}
    }
    synchronized boolean remove(String key,long revision)throws IOException{
        if(revision!=generation)return false;load();return removeGroup(key);
    }
    private boolean removeGroup(String key)throws IOException{
        // Validate the entire group before deleting any member, including replaced links.
        for(String extension:new String[]{"jpg","stamp","none","faces"})file(key,extension);
        for(String extension:new String[]{"jpg","stamp","none","faces"}){File member=file(key,extension);if(member.exists()&&!member.delete())throw new IOException("无法淘汰主封面缓存");}
        Entry old=entries.remove(key);if(old!=null)bytes-=old.bytes;return true;
    }
    private void prune(long now,String protect){
        long target=bytes>limit?limit*7/8:limit;List<Map.Entry<String,Entry>> sorted=new ArrayList<>(entries.entrySet());sorted.sort(Comparator.<Map.Entry<String,Entry>>comparingLong(entry->entry.getValue().access).thenComparingLong(entry->entry.getValue().order));
        for(Map.Entry<String,Entry> entry:sorted){if(entry.getKey().equals(protect)||entry.getValue().access>=now-age&&bytes<=target)continue;try{removeGroup(entry.getKey());}catch(IOException ignored){}}
    }
    synchronized void retain(Set<String> keys)throws IOException{
        load();for(String key:new ArrayList<>(entries.keySet()))if(!keys.contains(key))try{removeGroup(key);}catch(IOException ignored){}prune(System.currentTimeMillis(),null);
    }
    synchronized <T>T maintenance(Callable<T> operation)throws Exception{
        generation++;try{return operation.call();}finally{loaded=false;entries.clear();bytes=0;}
    }
    synchronized long sizeBytes(){return bytes;}
}
