package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.LruCache;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;

/** Scan prepares disk artwork and a resident preview for every song; drawing never reads audio. */
final class ArtworkCache {
    private static final LruCache<String,Bitmap> detail=new LruCache<String,Bitmap>(32*1024*1024){
        @Override protected int sizeOf(String key,Bitmap value){return value.getByteCount();}
    };
    private static final LruCache<String,Bitmap> focusDetail=new LruCache<String,Bitmap>(24*1024*1024){@Override protected int sizeOf(String key,Bitmap value){return value.getByteCount();}};
    private static String key(Song song){
        String source=song.uri.toString();
        try{byte[] hash=MessageDigest.getInstance("SHA-256").digest(source.getBytes(StandardCharsets.UTF_8));StringBuilder out=new StringBuilder("v3-");for(byte b:hash)out.append(String.format(java.util.Locale.ROOT,"%02x",b&255));return out.toString();}
        catch(Exception impossible){throw new IllegalStateException(impossible);}
    }
    static void prepare(Context context,List<Song> songs,ScanProgress progress){
        // Keep all wall previews resident within roughly 24 MiB, rather than evicting them on every pan.
        int size=CoverPreviewBudget.side(songs.size());
        progress.update(0,songs.size(),"正在缓存封面");
        for(int i=0;i<songs.size();i++){
            Song song=songs.get(i);prepareSong(context,song,size);
            progress.update(i+1,songs.size(),"缓存封面 · "+song.title);
        }
    }
    private static synchronized void prepareSong(Context context,Song song,int previewSize){
        if(song.artworkPrepared)return;
        String key=key(song);song.artworkCacheKey=key;
        File directory=LibraryCache.directory(context,"covers"),file=new File(directory,key+".jpg");
        LibraryCache.migrate(new File(new File(context.getCacheDir(),"covers"),key+".jpg"),file);
        File stamp=new File(directory,key+".stamp");String version=song.artworkUri+"\n"+song.artworkVersion;
        try{String previous=stamp.isFile()?new String(java.nio.file.Files.readAllBytes(stamp.toPath()),StandardCharsets.UTF_8):"";
            boolean same=previous.equals(version)||previous.equals(version+"\nquality-v2");
            boolean repairSmall=file.isFile()&&CoverQuality.repairSmall(imageSide(file),previous.endsWith("\nquality-v2"));
            if(!same||repairSmall){file.delete();new File(directory,key+".none").delete();detail.remove(key+":640");focusDetail.remove(key+":1600");}
        }catch(Exception ignored){file.delete();}
        File missing=new File(directory,key+".none");
        if(missing.isFile()){song.artworkPrepared=true;return;}
        Bitmap preview=file.isFile()?decode(file,previewSize):null;
        if(preview==null){
            Bitmap image=Artwork.load(context,song,1600);
            if(image!=null){
                Bitmap scaled=scale(image,1600);if(scaled!=image)image.recycle();
                File temporary=null;
                try{if(!directory.isDirectory()&&!directory.mkdirs())throw new java.io.IOException("无法创建封面缓存");
                    temporary=File.createTempFile("cover-",".tmp",directory);
                    try(FileOutputStream out=new FileOutputStream(temporary)){if(!scaled.compress(Bitmap.CompressFormat.JPEG,95,out))throw new java.io.IOException("封面编码失败");}
                    if(!temporary.renameTo(file))throw new java.io.IOException("无法保存封面缓存");
                }catch(Exception ignored){if(temporary!=null)temporary.delete();focusDetail.put(key+":1600",scaled);}
                preview=scale(scaled,previewSize);if(preview!=scaled&&focusDetail.get(key+":1600")!=scaled)scaled.recycle();
            }else{try{directory.mkdirs();missing.createNewFile();}catch(Exception ignored){}}
        }
        try{directory.mkdirs();java.nio.file.Files.write(stamp.toPath(),(version+"\nquality-v2").getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
        song.artworkPreview=preview;song.artworkFile=file.isFile()?file:null;song.artworkPrepared=true;
    }
    static Bitmap peek(Song song){Bitmap high=peek(song,1600);return high!=null?high:peek(song,640);}
    static Bitmap peek(Song song,int side){if(song.artworkCacheKey==null)return null;Bitmap result=(side>640?focusDetail:detail).get(song.artworkCacheKey+":"+side);if(result==null&&side<=640)result=focusDetail.get(song.artworkCacheKey+":1600");return result;}
    static Bitmap load(Context context,Song song){return load(context,song,1600);}
    static Bitmap load(Context context,Song song,int side){
        if(!song.artworkPrepared)prepareSong(context,song,96);
        Bitmap cached=peek(song,side);if(cached!=null)return cached;
        File file=song.artworkFile;
        if(file!=null&&!file.isFile()){File moved=new File(LibraryCache.directory(context,"covers"),key(song)+".jpg");if(moved.isFile()){file=moved;song.artworkFile=moved;}}
        if(file==null)return song.artworkPreview;
        Bitmap result=decode(file,side);
        if(result==null){synchronized(ArtworkCache.class){song.artworkPrepared=false;file.delete();prepareSong(context,song,96);}file=song.artworkFile;if(file!=null)result=decode(file,side);}
        if(result!=null)(side>640?focusDetail:detail).put(song.artworkCacheKey+":"+side,result);
        return result==null?song.artworkPreview:result;
    }
    private static int imageSide(File file){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeFile(file.getAbsolutePath(),options);return Math.max(options.outWidth,options.outHeight);}
    private static Bitmap decode(File file,int size){
        BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeFile(file.getAbsolutePath(),options);
        if(options.outWidth<=0||options.outHeight<=0)return null;
        options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>size*2)options.inSampleSize*=2;options.inJustDecodeBounds=false;
        Bitmap raw=BitmapFactory.decodeFile(file.getAbsolutePath(),options);if(raw==null)return null;
        Bitmap result=scale(raw,size);if(result!=raw)raw.recycle();return result;
    }
    private static Bitmap scale(Bitmap bitmap,int side){float ratio=Math.min(1,side/(float)Math.max(bitmap.getWidth(),bitmap.getHeight()));return Bitmap.createScaledBitmap(bitmap,Math.max(1,Math.round(bitmap.getWidth()*ratio)),Math.max(1,Math.round(bitmap.getHeight()*ratio)),true);}
    static void prune(Context context,List<Song> songs){
        java.util.Set<String> keep=new java.util.HashSet<>();for(Song song:songs){String name=key(song);keep.add(name+".jpg");keep.add(name+".none");keep.add(name+".stamp");}
        File[] files=LibraryCache.directory(context,"covers").listFiles();if(files!=null)for(File file:files)if(!keep.contains(file.getName()))file.delete();
        File[] legacy=new File(context.getCacheDir(),"covers").listFiles();if(legacy!=null)for(File file:legacy)if(file.isFile())file.delete();
    }
    static void clear(){detail.evictAll();focusDetail.evictAll();}
}
