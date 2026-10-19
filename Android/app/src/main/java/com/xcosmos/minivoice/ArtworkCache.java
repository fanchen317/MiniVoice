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
    private static String key(Song song){
        String source=song.uri.toString()+"\n"+song.artworkUri+"\n"+song.artworkVersion;
        try{byte[] hash=MessageDigest.getInstance("SHA-256").digest(source.getBytes(StandardCharsets.UTF_8));StringBuilder out=new StringBuilder("v2-");for(byte b:hash)out.append(String.format(java.util.Locale.ROOT,"%02x",b&255));return out.toString();}
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
        File directory=new File(context.getCacheDir(),"covers"),file=new File(directory,key+".jpg");
        Bitmap preview=file.isFile()?decode(file,previewSize):null;
        if(preview==null){
            Bitmap image=Artwork.load(context,song,640);
            if(image!=null){
                Bitmap scaled=scale(image,640);if(scaled!=image)image.recycle();
                File temporary=null;
                try{if(!directory.isDirectory()&&!directory.mkdirs())throw new java.io.IOException("无法创建封面缓存");
                    temporary=File.createTempFile("cover-",".tmp",directory);
                    try(FileOutputStream out=new FileOutputStream(temporary)){if(!scaled.compress(Bitmap.CompressFormat.JPEG,85,out))throw new java.io.IOException("封面编码失败");}
                    if(!temporary.renameTo(file))throw new java.io.IOException("无法保存封面缓存");
                }catch(Exception ignored){if(temporary!=null)temporary.delete();detail.put(key,scaled);}
                preview=scale(scaled,previewSize);if(preview!=scaled&&detail.get(key)!=scaled)scaled.recycle();
            }
        }
        song.artworkPreview=preview;song.artworkFile=file.isFile()?file:null;song.artworkPrepared=true;
    }
    static Bitmap peek(Song song){return song.artworkCacheKey==null?null:detail.get(song.artworkCacheKey);}
    static Bitmap load(Context context,Song song){
        if(!song.artworkPrepared)prepareSong(context,song,96);
        Bitmap cached=peek(song);if(cached!=null)return cached;
        File file=song.artworkFile;if(file==null)return song.artworkPreview;
        Bitmap result=decode(file,640);if(result!=null)detail.put(song.artworkCacheKey,result);
        return result==null?song.artworkPreview:result;
    }
    private static Bitmap decode(File file,int size){
        BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeFile(file.getAbsolutePath(),options);
        if(options.outWidth<=0||options.outHeight<=0)return null;
        options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>size*2)options.inSampleSize*=2;options.inJustDecodeBounds=false;
        Bitmap raw=BitmapFactory.decodeFile(file.getAbsolutePath(),options);if(raw==null)return null;
        Bitmap result=scale(raw,size);if(result!=raw)raw.recycle();return result;
    }
    private static Bitmap scale(Bitmap bitmap,int side){float ratio=Math.min(1,side/(float)Math.max(bitmap.getWidth(),bitmap.getHeight()));return Bitmap.createScaledBitmap(bitmap,Math.max(1,Math.round(bitmap.getWidth()*ratio)),Math.max(1,Math.round(bitmap.getHeight()*ratio)),true);}
    static void clear(){detail.evictAll();}
}
