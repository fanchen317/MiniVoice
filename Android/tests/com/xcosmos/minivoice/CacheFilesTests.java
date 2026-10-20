package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public final class CacheFilesTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args)throws Exception{
        File base=Files.createTempDirectory("cache-browser-").toFile();
        try{
            File root=new File(base,"library"),covers=new File(root,"covers");covers.mkdirs();
            File cover=new File(covers,"a.jpg"),index=new File(root,"index.json"),config=new File(base,"config/settings.json");config.getParentFile().mkdirs();
            Files.write(cover.toPath(),new byte[]{1,2,3});Files.write(index.toPath(),new byte[]{4});Files.write(config.toPath(),new byte[]{5});
            Map<String,File> roots=new LinkedHashMap<>();roots.put("缓存",root);roots.put("重复目录",root);
            List<CacheFiles.Entry> entries=CacheFiles.list(roots);check(entries.size()==2,"overlapping roots do not duplicate files");
            CacheFiles.Entry image=entries.stream().filter(e->e.file.equals(cover)).findFirst().orElseThrow();
            check(image.name.equals("缓存/covers/a.jpg")&&image.bytes==3,"relative name and exact size");
            check(CacheFiles.delete(List.of(image),roots.values())==3&&!cover.exists()&&index.exists(),"delete selection without touching other files");
            boolean blocked=false;try{CacheFiles.delete(List.of(new CacheFiles.Entry(config,"config")),roots.values());}catch(IOException expected){blocked=true;}
            check(blocked&&config.exists(),"configuration outside cache roots is protected");
            File sibling=new File(base,"library-other/music.mp3");sibling.getParentFile().mkdirs();Files.write(sibling.toPath(),new byte[]{9});
            blocked=false;try{CacheFiles.delete(List.of(new CacheFiles.Entry(sibling,"music")),roots.values());}catch(IOException expected){blocked=true;}
            check(blocked&&sibling.exists(),"similar path prefix cannot escape cache root");
            Files.createSymbolicLink(new File(root,"outside-link").toPath(),config.toPath());check(CacheFiles.list(roots).size()==1,"symbolic links are excluded");
            CacheFiles.delete(CacheFiles.list(roots),roots.values());check(config.exists()&&sibling.exists(),"select all preserves configuration and original music");
            System.out.println("PASS: cache file listing, selected/all deletion, size accounting, duplicate roots, configuration isolation and symlink protection");
        }finally{try(java.util.stream.Stream<Path> paths=Files.walk(base.toPath())){paths.sorted(Comparator.reverseOrder()).forEach(path->{try{Files.deleteIfExists(path);}catch(IOException ignored){}});}}
    }
}
