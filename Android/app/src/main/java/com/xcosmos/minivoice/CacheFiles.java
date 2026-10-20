package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;

/** Restricts cache management to explicit derived-data roots, excluding config and music. */
final class CacheFiles {
    static final class Entry {
        final File file;final String name;final long bytes,modified;
        Entry(File file,String name){this.file=file;this.name=name;bytes=file.length();modified=file.lastModified();}
    }
    static List<Entry> list(Map<String,File> roots)throws IOException{
        List<Entry> result=new ArrayList<>();Set<String> seen=new HashSet<>();
        for(Map.Entry<String,File> root:roots.entrySet())walk(root.getValue(),root.getValue(),root.getKey(),result,seen);
        result.sort(Comparator.comparing(entry->entry.name));return result;
    }
    private static void walk(File root,File file,String label,List<Entry> entries,Set<String> seen)throws IOException{
        if(!file.exists()||Files.isSymbolicLink(file.toPath()))return;
        if(file.isDirectory()){File[] children=file.listFiles();if(children==null)throw new IOException("无法读取 "+file);for(File child:children)walk(root,child,label,entries,seen);}
        else if(seen.add(file.getCanonicalPath()))entries.add(new Entry(file,label+"/"+root.toPath().relativize(file.toPath())));
    }
    static long delete(Collection<Entry> entries,Collection<File> roots)throws IOException{
        long removed=0;
        for(Entry entry:entries){File file=entry.file;if(!file.exists())continue;boolean allowed=false;
            for(File root:roots)if(file.getCanonicalPath().startsWith(root.getCanonicalPath()+File.separator)){allowed=true;break;}
            if(!allowed||Files.isSymbolicLink(file.toPath())||!file.isFile())throw new IOException("不允许删除缓存目录以外的文件");
            long bytes=file.length();if(!file.delete())throw new IOException("删除失败："+file.getName());removed+=bytes;
        }
        return removed;
    }
}
