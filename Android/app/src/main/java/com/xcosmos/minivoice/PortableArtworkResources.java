package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.io.*;
import java.util.concurrent.*;

/** Android WebView encoded-image pipeline, independent of the notification bitmap cache. */
final class PortableArtworkResources {
    private static final ByteRequestCache memory=new ByteRequestCache(8*1024*1024);
    private static final Semaphore slots=new Semaphore(2,true),wallSlot=new Semaphore(1,true);
    private static ArtworkDiskCache disk;
    private static synchronized ArtworkDiskCache disk(Context context){if(disk==null)disk=new ArtworkDiskCache(LibraryCache.directory(context,"web-artwork"),256L*1024*1024,30L*24*60*60*1000);return disk;}
    static byte[] read(Context context,Song song,int side)throws Exception{
        String key=LibraryCache.key("web-v1\n"+song.uri+"\n"+song.artworkUri+"\n"+song.artworkVersion+"\n"+side);
        ArtworkDiskCache store=disk(context);
        return memory.data(key,side!=0,()->{
            long revision=store.generation();byte[] stored=store.read(key);if(stored!=null)return stored;
            // A wall read uses at most one decode slot, preserving capacity for the focused card.
            boolean wall=side>0&&side<=320;if(wall)wallSlot.acquire();
            byte[] encoded;
            try{slots.acquire();try{
                if(side==0)encoded=Artwork.original(context,song);
                else{
                    // Cold wall thumbnails must not first create/decode a 1600px
                    // master. Their own disk tier already provides offline warm reads.
                    boolean ownsBitmap=wall||side>1600;
                    Bitmap bitmap=ownsBitmap?Artwork.load(context,song,side):ArtworkCache.load(context,song,side);
                    if(bitmap==null)return null;
                    int longest=Math.max(bitmap.getWidth(),bitmap.getHeight());float ratio=Math.min(1f,side/(float)longest);
                    Bitmap output=ratio<1?Bitmap.createScaledBitmap(bitmap,Math.max(1,Math.round(bitmap.getWidth()*ratio)),Math.max(1,Math.round(bitmap.getHeight()*ratio)),true):bitmap;
                    try(ByteArrayOutputStream bytes=new ByteArrayOutputStream()){if(!output.compress(Bitmap.CompressFormat.JPEG,side<=320?86:92,bytes))throw new IOException("封面编码失败");encoded=bytes.toByteArray();}
                    finally{if(output!=bitmap)output.recycle();if(ownsBitmap)bitmap.recycle();}
                }
            }finally{slots.release();}}finally{if(wall)wallSlot.release();}
            if(encoded!=null){try{if(!store.write(key,encoded,revision)&&store.generation()!=revision)throw new IOException("封面缓存已失效，请重试");}catch(IOException failure){if(store.generation()!=revision)throw failure;/* A full/unavailable cache must not fail a usable image. */}}
            return encoded;
        });
    }
    static String mime(byte[] data){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(data,0,data.length,options);return options.outMimeType==null?"image/jpeg":options.outMimeType;}
    static void trimMemory(){memory.trimMemory();}
    static <T>T maintenance(Context context,Callable<T> operation)throws Exception{
        // One lock order for both stores. Source decoding never holds either disk lock.
        return ArtworkCache.maintenance(context,()->disk(context).maintenance(()->{memory.invalidate();return operation.call();}));
    }
}
