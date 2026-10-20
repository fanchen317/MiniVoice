package com.xcosmos.minivoice;

import java.io.*;
import java.nio.file.*;

/** Move legacy derived data without deleting a source until its destination is complete. */
final class CacheMigration {
    static void moveTree(File source,File target)throws IOException{
        if(!source.exists())return;
        if(source.isDirectory()){
            if(!target.isDirectory()&&!target.mkdirs())throw new IOException("Cannot create "+target);
            File[] children=source.listFiles();if(children==null)throw new IOException("Cannot read "+source);
            for(File child:children)moveTree(child,new File(target,child.getName()));
            if(!source.delete())throw new IOException("Cannot remove migrated directory "+source);
        }else{
            copyIfMissing(source,target);
            if(!source.delete())throw new IOException("Cannot remove migrated file "+source);
        }
    }
    static void copyIfMissing(File source,File target)throws IOException{
        if(target.isFile()||!source.isFile())return;
        File parent=target.getParentFile();if(!parent.isDirectory()&&!parent.mkdirs())throw new IOException("Cannot create "+parent);
        File temporary=File.createTempFile("migration-",".tmp",parent);
        try{
            try(InputStream input=new FileInputStream(source);FileOutputStream output=new FileOutputStream(temporary)){
                byte[] bytes=new byte[32768];int count;while((count=input.read(bytes))!=-1)output.write(bytes,0,count);output.getFD().sync();
            }
            if(temporary.length()!=source.length())throw new IOException("Incomplete migration");
            try{Files.move(temporary.toPath(),target.toPath(),StandardCopyOption.ATOMIC_MOVE);}catch(AtomicMoveNotSupportedException unsupported){Files.move(temporary.toPath(),target.toPath());}
        }finally{temporary.delete();}
    }
}
