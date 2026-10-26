package com.xcosmos.minivoice;

import android.content.Context;
import android.content.ContentUris;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import java.io.InputStream;

final class Artwork {
    /** Original encoded source bytes, without thumbnail resize, crop or JPEG recompression. */
    static byte[] original(Context context,Song song){
        byte[] bytes=AudioTags.read(context,song.uri,true).picture;
        if(validOriginal(bytes))return bytes;
        MediaMetadataRetriever retriever=new MediaMetadataRetriever();
        try{retriever.setDataSource(context,song.uri);bytes=retriever.getEmbeddedPicture();if(validOriginal(bytes))return bytes;}catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
        if(song.artworkUri!=null)try(InputStream input=context.getContentResolver().openInputStream(song.artworkUri);java.io.ByteArrayOutputStream output=new java.io.ByteArrayOutputStream()){byte[] buffer=new byte[16384];int count;while((count=input.read(buffer))>=0){if(output.size()+count>32*1024*1024)return null;output.write(buffer,0,count);}bytes=output.toByteArray();if(validOriginal(bytes))return bytes;}catch(Exception ignored){}
        return null;
    }
    private static boolean validOriginal(byte[] bytes){if(bytes==null||bytes.length>32*1024*1024)return false;BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);return options.outWidth>0&&options.outHeight>0;}
    static Bitmap load(Context context,Song song,int size){
        byte[] bytes=null;MediaMetadataRetriever retriever=new MediaMetadataRetriever();
        try{retriever.setDataSource(context,song.uri);bytes=retriever.getEmbeddedPicture();}
        catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
        if(bytes==null)bytes=AudioTags.read(context,song.uri,true).picture;
        Bitmap image=decode(bytes,size);
        // Embedded pictures can be tiny thumbnails even when a full-size sidecar exists.
        if(image==null||Math.max(image.getWidth(),image.getHeight())<Math.min(size,1024)){
            image=better(image,decode(AudioTags.read(context,song.uri,true).picture,size));
            if(song.artworkUri!=null)image=better(image,read(context,song.artworkUri,size));
        }
        if(image==null&&song.albumId>0)image=read(context,ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"),song.albumId),size);
        return image;
    }
    private static Bitmap decode(byte[] bytes,int size){if(bytes==null)return null;BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);sample(options,size);return BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);}
    private static Bitmap better(Bitmap first,Bitmap second){if(first==null)return second;if(second==null)return first;if((long)second.getWidth()*second.getHeight()>(long)first.getWidth()*first.getHeight()){first.recycle();return second;}second.recycle();return first;}
    private static void sample(BitmapFactory.Options options,int size){
        options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>size*1.5f)options.inSampleSize*=2;options.inJustDecodeBounds=false;
    }
    private static Bitmap read(Context context,Uri uri,int size){
        try{BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;
            try(InputStream input=context.getContentResolver().openInputStream(uri)){BitmapFactory.decodeStream(input,null,options);}sample(options,size);
            try(InputStream input=context.getContentResolver().openInputStream(uri)){return BitmapFactory.decodeStream(input,null,options);}
        }catch(Exception ignored){return null;}
    }
}
