package com.xcosmos.minivoice;

import android.content.Context;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

final class LibraryCache {
    static File root(Context context){return new File(context.getFilesDir(),"library-cache");}
    static File directory(Context context,String name){return new File(root(context),name);}
    static String key(String source){try{byte[] digest=MessageDigest.getInstance("SHA-256").digest(source.getBytes(StandardCharsets.UTF_8));StringBuilder result=new StringBuilder();for(byte b:digest)result.append(String.format(java.util.Locale.ROOT,"%02x",b&255));return result.toString();}catch(Exception impossible){throw new IllegalStateException(impossible);}}
    static void migrate(File legacy,File destination){
        if(destination.exists()||!legacy.isFile())return;
        File temporary=null;try{File directory=destination.getParentFile();if(!directory.isDirectory()&&!directory.mkdirs())return;temporary=File.createTempFile("migrate-",".tmp",directory);
            try(java.io.InputStream in=new java.io.FileInputStream(legacy);java.io.OutputStream out=new java.io.FileOutputStream(temporary)){byte[] buffer=new byte[8192];int count;while((count=in.read(buffer))!=-1)out.write(buffer,0,count);}
            if(!temporary.renameTo(destination))temporary.delete();
        }catch(Exception ignored){if(temporary!=null)temporary.delete();}
    }
    static void clear(Context context)throws java.io.IOException{clearRoot(root(context));}
    static void clearRoot(File root)throws java.io.IOException{remove(root);}
    private static void remove(File file)throws java.io.IOException{if(!file.exists())return;if(file.isDirectory()){File[] children=file.listFiles();if(children==null)throw new java.io.IOException("无法读取缓存目录");for(File child:children)remove(child);}if(!file.delete())throw new java.io.IOException("无法清理缓存："+file.getName());}
}
