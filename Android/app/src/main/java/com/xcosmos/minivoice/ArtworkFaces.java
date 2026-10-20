package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.*;
import android.media.FaceDetector;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** On-device face detection; no camera permission, network request or main-thread analysis. */
final class ArtworkFaces {
    private static final android.util.LruCache<String,ArtworkFraming.Face[]> cache=new android.util.LruCache<>(192);
    private static final Set<String> pending=ConcurrentHashMap.newKeySet();
    private static final ExecutorService detector=Executors.newSingleThreadExecutor();
    private static String key(Song song){return LibraryCache.key("faces-v1\n"+song.uri+"\n"+song.artworkVersion+"\n"+song.artworkUri);}
    static ArtworkFraming.Face[] peek(Song song){return cache.get(key(song));}
    static void request(Context context,Song song,Bitmap image,Runnable ready){
        String key=key(song);if(cache.get(key)!=null||!pending.add(key))return;
        detector.execute(()->{try{
            File file=new File(LibraryCache.directory(context,"covers"),song.artworkCacheKey+".faces");ArtworkFraming.Face[] faces=read(file,key);
            if(faces==null){faces=detect(image);write(file,key,faces);}cache.put(key,faces);ready.run();
        }finally{pending.remove(key);}});
    }
    private static ArtworkFraming.Face[] detect(Bitmap image){
        Bitmap sample=null;try{
            float scale=Math.min(1,480f/Math.max(image.getWidth(),image.getHeight()));int width=Math.max(2,Math.round(image.getWidth()*scale));width-=width%2;int height=Math.max(2,Math.round(image.getHeight()*scale));
            sample=Bitmap.createBitmap(width,height,Bitmap.Config.RGB_565);new Canvas(sample).drawBitmap(image,null,new Rect(0,0,width,height),new Paint(Paint.FILTER_BITMAP_FLAG));
            FaceDetector.Face[] found=new FaceDetector.Face[8];int count=new FaceDetector(width,height,found.length).findFaces(sample,found);List<ArtworkFraming.Face> result=new ArrayList<>();
            for(int i=0;i<count;i++){FaceDetector.Face face=found[i];if(face==null||face.confidence()<.4f)continue;PointF eyes=new PointF();face.getMidPoint(eyes);float d=face.eyesDistance();result.add(new ArtworkFraming.Face((eyes.x-d*1.45f)/width,(eyes.y-d*2.1f)/height,(eyes.x+d*1.45f)/width,(eyes.y+d*2.4f)/height,face.confidence()));}
            return result.toArray(new ArtworkFraming.Face[0]);
        }catch(RuntimeException|LinkageError failure){android.util.Log.w("MiniVoice","Face analysis unavailable; using conservative crop",failure);return new ArtworkFraming.Face[0];}
        finally{if(sample!=null)sample.recycle();}
    }
    private static ArtworkFraming.Face[] read(File file,String key){try(BufferedReader reader=new BufferedReader(new InputStreamReader(new FileInputStream(file),StandardCharsets.UTF_8))){if(!key.equals(reader.readLine()))return null;List<ArtworkFraming.Face> result=new ArrayList<>();String row;while((row=reader.readLine())!=null){String[] v=row.split(",");if(v.length!=5)return null;result.add(new ArtworkFraming.Face(Float.parseFloat(v[0]),Float.parseFloat(v[1]),Float.parseFloat(v[2]),Float.parseFloat(v[3]),Float.parseFloat(v[4])));}return result.toArray(new ArtworkFraming.Face[0]);}catch(Exception ignored){return null;}}
    private static void write(File file,String key,ArtworkFraming.Face[] faces){File temporary=null;try{File parent=file.getParentFile();parent.mkdirs();temporary=File.createTempFile("faces-",".tmp",parent);try(Writer out=new OutputStreamWriter(new FileOutputStream(temporary),StandardCharsets.UTF_8)){out.write(key+"\n");for(ArtworkFraming.Face face:faces)out.write(face.left+","+face.top+","+face.right+","+face.bottom+","+face.confidence+"\n");}temporary.renameTo(file);}catch(Exception ignored){}finally{if(temporary!=null)temporary.delete();}}
}
