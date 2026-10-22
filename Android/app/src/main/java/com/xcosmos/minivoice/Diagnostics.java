package com.xcosmos.minivoice;

import android.content.Context;
import android.os.Build;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.zip.*;

/** Bounded, app-private diagnostics. No library index, credentials or music contents are exported. */
final class Diagnostics {
    private static File directory;
    private static final int LIMIT=128*1024;
    static synchronized void install(Context context){
        if(directory!=null)return;directory=new File(context.getFilesDir(),"diagnostics");directory.mkdirs();
        Thread.UncaughtExceptionHandler previous=Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((thread,error)->{
            try{StringWriter stack=new StringWriter();error.printStackTrace(new PrintWriter(stack));writeCrash("thread="+thread.getName()+"\n"+stack);}catch(Throwable ignored){}
            if(previous!=null)previous.uncaughtException(thread,error);
            else{android.os.Process.killProcess(android.os.Process.myPid());System.exit(10);}
        });event("process started");
    }
    static String scrub(String value){return value.replaceAll("(?:content|file)://[^\\s]+","[uri]").replaceAll("/(?:storage|sdcard|data/user)/[^\\s]+","[path]");}
    private static synchronized void writeCrash(String value)throws IOException{
        if(directory==null)return;
        File file=new File(directory,"crash-"+System.currentTimeMillis()+".txt");
        write(file,environment()+"\n"+scrub(value));
        File[] files=directory.listFiles((dir,name)->name.startsWith("crash-"));if(files!=null){Arrays.sort(files,Comparator.comparing(File::getName));for(int i=0;i<files.length-5;i++)files[i].delete();}
    }
    static synchronized void event(String value){if(directory==null)return;try{
        File file=new File(directory,"events.txt");if(file.length()>64*1024){File old=new File(directory,"events-previous.txt");old.delete();file.renameTo(old);}
        try(FileOutputStream out=new FileOutputStream(file,true)){out.write((new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS",Locale.ROOT).format(new Date())+" "+scrub(value)+"\n").getBytes(StandardCharsets.UTF_8));}
    }catch(Exception ignored){}}
    static void failure(String stage,Throwable failure){StringWriter stack=new StringWriter();failure.printStackTrace(new PrintWriter(stack));String detail=stack.toString();event(stage+"\n"+detail.substring(0,Math.min(detail.length(),12000)));}
    static synchronized int crashCount(){File[] files=directory==null?null:directory.listFiles((d,n)->n.startsWith("crash-"));return files==null?0:files.length;}
    private static String environment(){return "MiniVoice diagnostics v1\nAndroid="+Build.VERSION.RELEASE+" API="+Build.VERSION.SDK_INT+"\nDevice="+Build.MANUFACTURER+" "+Build.MODEL+"\nApp="+BuildConfigInfo.version()+"\n";}
    private static void write(File file,String text)throws IOException{byte[] bytes=text.getBytes(StandardCharsets.UTF_8);try(FileOutputStream out=new FileOutputStream(file)){out.write(bytes,0,Math.min(LIMIT,bytes.length));}}
    static synchronized void export(Context context,OutputStream output)throws IOException{
        try(ZipOutputStream zip=new ZipOutputStream(output)){
            zip.putNextEntry(new ZipEntry("environment.txt"));zip.write((environment()+"\nMemoryMax="+Runtime.getRuntime().maxMemory()+"\nCaptured="+new Date()+"\nLogs omit the music index and settings. Exception text may still contain file names; review before sharing.\n").getBytes(StandardCharsets.UTF_8));zip.closeEntry();
            File[] files=directory==null?null:directory.listFiles();if(files!=null)for(File file:files)if(file.isFile()&&file.getName().endsWith(".txt")){
                zip.putNextEntry(new ZipEntry(file.getName()));try(InputStream in=new FileInputStream(file)){byte[] buffer=new byte[8192];int count,total=0;while(total<LIMIT&&(count=in.read(buffer,0,Math.min(buffer.length,LIMIT-total)))>0){zip.write(buffer,0,count);total+=count;}}zip.closeEntry();
            }
        }
    }
    // Kept independent of Gradle-generated BuildConfig: the shell builder uses the manifest version.
    private static final class BuildConfigInfo {static String version(){return "1.0.0";}}
}
