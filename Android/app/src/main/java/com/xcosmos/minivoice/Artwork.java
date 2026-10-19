package com.xcosmos.minivoice;

import android.content.Context;
import android.content.ContentUris;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import java.io.InputStream;

final class Artwork {
    static Bitmap load(Context context,Song song,int size){
        byte[] bytes=null;MediaMetadataRetriever retriever=new MediaMetadataRetriever();
        try{retriever.setDataSource(context,song.uri);bytes=retriever.getEmbeddedPicture();}
        catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}
        if(bytes==null)bytes=AudioTags.read(context,song.uri,true).picture;
        Bitmap image=null;
        if(bytes!=null){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;
            BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);sample(options,size);
            image=BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);
        }
        if(image==null&&song.artworkUri!=null)image=read(context,song.artworkUri,size);
        if(image==null&&song.albumId>0)image=read(context,ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"),song.albumId),size);
        return image;
    }
    private static void sample(BitmapFactory.Options options,int size){
        options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>size*2)options.inSampleSize*=2;options.inJustDecodeBounds=false;
    }
    private static Bitmap read(Context context,Uri uri,int size){
        try{BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;
            try(InputStream input=context.getContentResolver().openInputStream(uri)){BitmapFactory.decodeStream(input,null,options);}sample(options,size);
            try(InputStream input=context.getContentResolver().openInputStream(uri)){return BitmapFactory.decodeStream(input,null,options);}
        }catch(Exception ignored){return null;}
    }
}
