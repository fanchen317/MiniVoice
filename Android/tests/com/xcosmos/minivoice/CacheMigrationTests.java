package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;

public final class CacheMigrationTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args)throws Exception{
        File root=Files.createTempDirectory("minivoice-storage-").toFile();
        try{
            File legacy=new File(root,"old"),current=new File(root,"files/library");new File(legacy,"covers").mkdirs();
            Files.writeString(new File(legacy,"index-v1.json").toPath(),"existing index");Files.write(new File(legacy,"covers/a.jpg").toPath(),new byte[]{3,4,5});
            CacheMigration.moveTree(legacy,current);
            check(!legacy.exists(),"successful migration removes old cache tree");check(Files.readString(new File(current,"index-v1.json").toPath()).equals("existing index"),"index is retained");
            check(java.util.Arrays.equals(Files.readAllBytes(new File(current,"covers/a.jpg").toPath()),new byte[]{3,4,5}),"cover bytes are unchanged");
            legacy.mkdirs();Files.writeString(new File(legacy,"index-v1.json").toPath(),"stale index");CacheMigration.moveTree(legacy,current);
            check(Files.readString(new File(current,"index-v1.json").toPath()).equals("existing index"),"new destination wins on retry");
            File failed=new File(root,"retry"),blocked=new File(root,"not-directory");failed.mkdirs();Files.writeString(new File(failed,"keep").toPath(),"safe");Files.writeString(blocked.toPath(),"blocked");
            boolean rejected=false;try{CacheMigration.moveTree(failed,blocked);}catch(IOException expected){rejected=true;}
            check(rejected&&new File(failed,"keep").exists(),"failure preserves original data");
            File config=new File(root,"files/config/settings.json");config.getParentFile().mkdirs();Files.writeString(config.toPath(),"settings");LibraryCache.clearRoot(current);
            check(config.isFile()&&!current.exists(),"cache rebuild preserves configuration");
            System.out.println("PASS: cache migration preserves index/cover bytes, retries safely, protects source on failure and retains configuration on rebuild");
        }finally{LibraryCache.clearRoot(root);}
    }
}
