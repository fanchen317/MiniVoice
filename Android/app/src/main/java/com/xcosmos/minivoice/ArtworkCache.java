package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.LruCache;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.Callable;

/** Native consumers keep a bounded working set; scanning never decodes the whole catalog. */
final class ArtworkCache {
    private static final Object MEMORY_LOCK=new Object(),DISK_LOCK=new Object();
    private static long memoryGeneration;
    private static CoverDiskCache disk;
    private static final LruCache<String,Bitmap> detail=new LruCache<String,Bitmap>((int)Math.max(8L*1024*1024,Math.min(24L*1024*1024,Runtime.getRuntime().maxMemory()/12))){
        @Override protected int sizeOf(String key,Bitmap value){return value.getByteCount();}
    };
    private static final LruCache<String,Bitmap> focusDetail=new LruCache<String,Bitmap>((int)Math.max(8L*1024*1024,Math.min(20L*1024*1024,Runtime.getRuntime().maxMemory()/12))){@Override protected int sizeOf(String key,Bitmap value){return value.getByteCount();}};
    private static CoverDiskCache disk(Context context){synchronized(DISK_LOCK){if(disk==null)disk=new CoverDiskCache(LibraryCache.directory(context,"covers"),256L*1024*1024,30L*24*60*60*1000);return disk;}}
    private static String key(Song song){
        String source=song.uri.toString(),art=String.valueOf(song.artworkUri),version=String.valueOf(song.artworkVersion);
        // Old/new Song instances can coexist while a rescan or edit completes.
        // Their extracted pixels must never share one mutable master file.
        return "v3-"+LibraryCache.key("master-version-v1\n"+source.length()+":"+source+art.length()+":"+art+version.length()+":"+version);
    }
    private static String legacyKey(Song song){return "v3-"+LibraryCache.key(song.uri.toString());}
    private static boolean matchesVersion(String stamp,String version){return stamp.equals(version)||stamp.equals(version+"\nquality-v2");}
    private static String memoryKey(Song song,int side){return song.artworkCacheKey+":"+LibraryCache.key(song.artworkUri+"\n"+song.artworkVersion)+":"+side;}
    private static long memoryRevision(){synchronized(MEMORY_LOCK){return memoryGeneration;}}
    private static boolean remember(Song song,int side,Bitmap image,long revision){synchronized(MEMORY_LOCK){if(revision!=memoryGeneration)return false;(side>640?focusDetail:detail).put(memoryKey(song,side),image);return true;}}
    static void prepare(Context context,List<Song> songs,ScanProgress progress){
        // The catalog owns identities, never decoded pixels. A rescan does not
        // regenerate evicted 1600px masters or keep one bitmap per song alive.
        progress.update(0,songs.size(),"正在准备封面索引");
        for(int i=0;i<songs.size();i++){Song song=songs.get(i);song.artworkCacheKey=key(song);song.artworkPreview=null;song.artworkPrepared=false;if(i%100==0||i+1==songs.size())progress.update(i+1,songs.size(),"准备封面索引 · "+song.title);}
        try{disk(context).initialize();}catch(IOException ignored){/* Derived cache availability never prevents catalog use. */}
    }
    private static synchronized Bitmap prepareSong(Context context,Song song,long revision,long memoryRevision){
        if(song.artworkPrepared)return null;
        CoverDiskCache store=disk(context);if(store.generation()!=revision)return null;String key=key(song);song.artworkCacheKey=key;song.artworkPreview=null;
        String version=song.artworkUri+"\n"+song.artworkVersion;
        byte[] stamp=store.read(key,"stamp"),existing=store.read(key,"jpg");String previous=stamp==null?"":new String(stamp,StandardCharsets.UTF_8);
        boolean same=matchesVersion(previous,version),migrating=false,missing=same&&store.read(key,"none")!=null;
        if(!same||existing!=null&&CoverQuality.repairSmall(imageSide(existing),previous.endsWith("\nquality-v2"))){try{store.remove(key,revision);}catch(IOException ignored){}existing=null;missing=false;}
        if(existing==null&&!missing){
            // URI-only files from previous versions are reusable only when their
            // recorded artwork identity matches exactly. They are never rewritten.
            String oldKey=legacyKey(song);byte[] oldStamp=store.read(oldKey,"stamp");String oldVersion=oldStamp==null?"":new String(oldStamp,StandardCharsets.UTF_8);
            if(matchesVersion(oldVersion,version)){
                byte[] oldImage=store.read(oldKey,"jpg");
                if(oldImage!=null&&imageSide(oldImage)>0&&!CoverQuality.repairSmall(imageSide(oldImage),oldVersion.endsWith("\nquality-v2"))){existing=oldImage;previous=oldVersion;migrating=true;}
                else if(store.read(oldKey,"none")!=null){missing=true;migrating=true;previous=oldVersion;}
            }
        }
        File file=new File(LibraryCache.directory(context,"covers"),key+".jpg");
        if(existing!=null&&imageSide(existing)>0){
            boolean persisted=!migrating;
            if(migrating)try{persisted=store.write(key,"jpg",existing,revision)&&store.write(key,"stamp",previous.getBytes(StandardCharsets.UTF_8),revision);}catch(IOException ignored){}
            if(store.generation()!=revision)return null;
            song.artworkFile=persisted?file:null;song.artworkPrepared=persisted;
            if(!persisted){Bitmap ready=decode(existing,1600);if(ready!=null)remember(song,1600,ready,memoryRevision);return ready;}
            return null;
        }
        if(missing){
            if(migrating)try{store.write(key,"none",new byte[0],revision);store.write(key,"stamp",previous.getBytes(StandardCharsets.UTF_8),revision);}catch(IOException ignored){}
            if(store.generation()==revision){song.artworkFile=null;song.artworkPrepared=true;}return null;
        }
        if(store.generation()!=revision)return null;
        Bitmap image=Artwork.load(context,song,1600),scaled=null;
        try{
            if(image!=null){
                scaled=scale(image,1600);if(scaled!=image)image.recycle();image=null;
                ByteArrayOutputStream output=new ByteArrayOutputStream();if(!scaled.compress(Bitmap.CompressFormat.JPEG,95,output))throw new IOException("主封面编码失败");
                boolean persisted=store.write(key,"jpg",output.toByteArray(),revision);
                store.write(key,"stamp",(version+"\nquality-v2").getBytes(StandardCharsets.UTF_8),revision);
                if(store.generation()!=revision)return null;
                song.artworkFile=persisted?file:null;song.artworkPrepared=persisted;
                // A full/unavailable disk does not fail a usable high-quality image.
                remember(song,1600,scaled,memoryRevision);Bitmap ready=scaled;scaled=null;return ready;
            }else{
                store.write(key,"none",new byte[0],revision);store.write(key,"stamp",(version+"\nquality-v2").getBytes(StandardCharsets.UTF_8),revision);
                if(store.generation()==revision){song.artworkFile=null;song.artworkPrepared=true;}
            }
        }catch(IOException ignored){if(scaled!=null&&store.generation()==revision){remember(song,1600,scaled,memoryRevision);Bitmap ready=scaled;scaled=null;return ready;}}
        finally{if(image!=null)image.recycle();if(scaled!=null)scaled.recycle();}
        return null;
    }
    static Bitmap peek(Song song){Bitmap high=peek(song,1600);return high!=null?high:peek(song,640);}
    static Bitmap peek(Song song,int side){
        if(song.artworkCacheKey==null)return null;
        Bitmap result=(side>640?focusDetail:detail).get(memoryKey(song,side));
        if(result==null&&side<512)result=detail.get(memoryKey(song,512));if(result==null&&side<640)result=detail.get(memoryKey(song,640));
        if(result==null&&side<1600)result=focusDetail.get(memoryKey(song,1600));return result;
    }
    static Bitmap load(Context context,Song song){return load(context,song,1600);}
    static Bitmap load(Context context,Song song,int side){
        String identity=key(song);
        if(!identity.equals(song.artworkCacheKey)){song.artworkCacheKey=identity;song.artworkFile=null;song.artworkPrepared=false;song.artworkPreview=null;}
        Bitmap cached=peek(song,side);if(cached!=null)return cached;
        CoverDiskCache store=disk(context);long revision=store.generation(),memoryRevision=memoryRevision();
        Bitmap prepared=!song.artworkPrepared?prepareSong(context,song,revision,memoryRevision):null;if(store.generation()!=revision)return null;if(prepared!=null)return prepared;
        cached=peek(song,side);if(cached!=null)return cached;
        byte[] bytes=store.read(song.artworkCacheKey,"jpg");Bitmap result=bytes==null?null:decode(bytes,side);
        if(result==null&&!(song.artworkPrepared&&song.artworkFile==null&&store.read(song.artworkCacheKey,"none")!=null)){
            synchronized(ArtworkCache.class){song.artworkPrepared=false;try{store.remove(song.artworkCacheKey,revision);}catch(IOException ignored){}prepared=prepareSong(context,song,revision,memoryRevision);}
            if(store.generation()!=revision)return null;if(prepared!=null)return prepared;cached=peek(song,side);if(cached!=null)return cached;bytes=store.read(song.artworkCacheKey,"jpg");if(bytes!=null)result=decode(bytes,side);
        }
        if(result!=null)remember(song,side,result,memoryRevision);return result;
    }
    private static int imageSide(byte[] bytes){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);return Math.max(options.outWidth,options.outHeight);}
    private static Bitmap decode(byte[] bytes,int size){
        BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);if(options.outWidth<=0||options.outHeight<=0)return null;
        options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>size*1.5f)options.inSampleSize*=2;options.inJustDecodeBounds=false;
        Bitmap raw=BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);if(raw==null)return null;Bitmap result=scale(raw,size);if(result!=raw)raw.recycle();return result;
    }
    private static Bitmap scale(Bitmap bitmap,int side){float ratio=Math.min(1,side/(float)Math.max(bitmap.getWidth(),bitmap.getHeight()));return Bitmap.createScaledBitmap(bitmap,Math.max(1,Math.round(bitmap.getWidth()*ratio)),Math.max(1,Math.round(bitmap.getHeight()*ratio)),true);}
    static void prune(Context context,List<Song> songs){
        Set<String> keep=new HashSet<>();for(Song song:songs){keep.add(key(song));keep.add(legacyKey(song));}try{disk(context).retain(keep);}catch(IOException ignored){}
        File[] legacy=new File(context.getCacheDir(),"covers").listFiles();if(legacy!=null)for(File file:legacy)if(file.isFile()&&!java.nio.file.Files.isSymbolicLink(file.toPath()))file.delete();
    }
    static <T>T maintenance(Context context,Callable<T> operation)throws Exception{return disk(context).maintenance(()->{clear();return operation.call();});}
    static void clear(){synchronized(MEMORY_LOCK){memoryGeneration++;detail.evictAll();focusDetail.evictAll();}}
    static long retainedBytes(){synchronized(MEMORY_LOCK){return (long)detail.size()+focusDetail.size();}}
}
