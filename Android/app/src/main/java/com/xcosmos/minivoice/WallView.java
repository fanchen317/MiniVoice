package com.xcosmos.minivoice;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.util.LruCache;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Native canvas port of MiniVoice's repeatable wall scene and camera. */
final class WallView extends View {
    interface OnPlay { void play(Song song); }
    private static final class Hit { final RectF bounds;final WallLayout.Instance instance;Hit(RectF bounds,WallLayout.Instance instance){this.bounds=bounds;this.instance=instance;} }
    private final OnPlay onPlay;
    private final Runnable onToggle;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
    private final GestureDetector gestures;
    private final ScaleGestureDetector scaleDetector;
    private final Handler main=new Handler();
    private final ExecutorService covers=Executors.newFixedThreadPool(2);
    private final LruCache<Long,Bitmap> bitmaps=new LruCache<Long,Bitmap>(48*1024*1024){@Override protected int sizeOf(Long key,Bitmap value){return value.getByteCount();}};
    private final Set<Long> requested=new HashSet<>();
    private final List<Hit> hits=new ArrayList<>();
    private List<Song> songs=new ArrayList<>();
    private WallLayout scene;
    private float cameraX,cameraY,scale=1,focusAmount,focusSide;
    private long playingId=Long.MIN_VALUE;
    private List<Lyrics.Line> playingLyrics=new ArrayList<>();
    private int playbackPosition;
    private boolean playbackPlaying;
    private WallLayout.Instance focus;
    private WallLayout.Instance pressed;
    private boolean cameraReady;
    private ValueAnimator motion;
    private final float density;
    WallView(Context context,OnPlay onPlay,Runnable onToggle){
        super(context);this.onPlay=onPlay;this.onToggle=onToggle;density=getResources().getDisplayMetrics().density;setLayerType(View.LAYER_TYPE_HARDWARE,null);
        scene=new WallLayout(0,density);
        gestures=new GestureDetector(context,new GestureDetector.SimpleOnGestureListener(){
            @Override public boolean onDown(MotionEvent event){cancelMotion();return true;}
            @Override public boolean onScroll(MotionEvent start,MotionEvent end,float dx,float dy){if(scaleDetector.isInProgress())return false;cameraX-=dx;cameraY-=dy;invalidate();return true;}
            @Override public boolean onFling(MotionEvent start,MotionEvent end,float vx,float vy){animateCamera(cameraX+vx*.20f,cameraY+vy*.20f,420);return true;}
            @Override public boolean onSingleTapConfirmed(MotionEvent event){Hit hit=hit(event.getX(),event.getY());if(hit!=null){
                if(focus!=null&&same(hit.instance,focus)&&focusAmount>.65f)playOrToggle(hit.instance);
                else focus(hit.instance);
            }return hit!=null;}
            @Override public boolean onDoubleTap(MotionEvent event){Hit hit=hit(event.getX(),event.getY());if(hit!=null&&hit.instance.tile.index<songs.size())playOrToggle(hit.instance);return hit!=null;}
        });
        scaleDetector=new ScaleGestureDetector(context,new ScaleGestureDetector.SimpleOnScaleGestureListener(){
            @Override public boolean onScaleBegin(ScaleGestureDetector detector){cancelMotion();return true;}
            @Override public boolean onScale(ScaleGestureDetector detector){float old=scale;scale=Math.max(.6f,Math.min(1.2f,scale*detector.getScaleFactor()));
                float fx=detector.getFocusX(),fy=detector.getFocusY();cameraX=fx-(fx-cameraX)*scale/old;cameraY=fy-(fy-cameraY)*scale/old;invalidate();return true;}
        });
    }
    void setSongs(List<Song> value){cancelMotion();songs=new ArrayList<>(value);scene=new WallLayout(songs.size(),density);focus=null;pressed=null;focusAmount=0;cameraReady=false;invalidate();}
    void locateSong(long id){
        if(getWidth()==0||getHeight()==0){addOnLayoutChangeListener(new OnLayoutChangeListener(){
            @Override public void onLayoutChange(View view,int left,int top,int right,int bottom,int oldLeft,int oldTop,int oldRight,int oldBottom){
                if(right>left&&bottom>top){removeOnLayoutChangeListener(this);locateSong(id);}
            }
        });return;}
        for(int i=0;i<songs.size();i++)if(songs.get(i).id==id){
            WallLayout.Instance target=scene.nearest(i,cameraX,cameraY,scale,getWidth(),getHeight());
            if(target!=null)focus(target);return;
        }
    }
    private void playOrToggle(WallLayout.Instance instance){Song song=songs.get(instance.tile.index);if(song.id==playingId)onToggle.run();else onPlay.play(song);}
    void setPlayback(long id,boolean playing,int position){if(playingId!=id)playingLyrics=new ArrayList<>();playingId=id;playbackPlaying=playing;playbackPosition=position;invalidate();}
    void setLyrics(long id,List<Lyrics.Line> lines){if(playingId==id){playingLyrics=new ArrayList<>(lines);invalidate();}}
    void resetCamera(){cancelMotion();focus=null;focusAmount=0;cameraReady=false;centerInitial();invalidate();}
    void zoom(float factor){float old=scale;scale=Math.max(.6f,Math.min(1.2f,scale*factor));cameraX=getWidth()/2f-(getWidth()/2f-cameraX)*scale/old;cameraY=getHeight()/2f-(getHeight()/2f-cameraY)*scale/old;invalidate();}
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){super.onSizeChanged(w,h,oldW,oldH);if(!cameraReady)centerInitial();}
    private void centerInitial(){if(scene.tiles.isEmpty()||getWidth()==0||getHeight()==0)return;
        scale=1;cameraX=12*density;cameraY=80*density;cameraReady=true;}
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);canvas.drawColor(Color.BLACK);if(scene.tiles.isEmpty()){
        paint.setShader(null);paint.setColor(0xFF9DA8A1);paint.setTextSize(18*density);String message="添加音乐文件夹，开始浏览音乐墙";canvas.drawText(message,Math.max(20,(getWidth()-paint.measureText(message))/2),getHeight()/2f,paint);return;}
        if(!cameraReady)centerInitial();hits.clear();
        List<WallLayout.Instance> visible=scene.visible(cameraX,cameraY,scale,getWidth(),getHeight(),(focus==null?400:1100)*density);
        WallLayout.Instance focusedInstance=null;
        for(WallLayout.Instance instance:visible){if(focus!=null&&same(instance,focus)){focusedInstance=instance;continue;}drawTile(canvas,instance,false);}
        if(focusedInstance!=null)drawTile(canvas,focusedInstance,true);
    }
    private boolean same(WallLayout.Instance a,WallLayout.Instance b){return a.tile.index==b.tile.index&&a.column==b.column&&a.row==b.row;}
    private RectF frame(WallLayout.Instance instance){
        float x=instance.x,y=instance.y,w=instance.tile.width,h=instance.tile.height;
        if(focus!=null&&focusAmount>0){float gap=5*density;
            float nx=coordinate(x,focus.x,focus.x+focus.tile.width+gap,focusSide+gap);
            float right=coordinate(x+w+gap,focus.x,focus.x+focus.tile.width+gap,focusSide+gap);
            float ny=coordinate(y,focus.y,focus.y+focus.tile.height+gap,focusSide+gap);
            float bottom=coordinate(y+h+gap,focus.y,focus.y+focus.tile.height+gap,focusSide+gap);
            x+=(nx-x)*focusAmount;y+=(ny-y)*focusAmount;w+=(right-nx-gap-w)*focusAmount;h+=(bottom-ny-gap-h)*focusAmount;
        }
        return new RectF(cameraX+x*scale,cameraY+y*scale,cameraX+(x+w)*scale,cameraY+(y+h)*scale);
    }
    private float coordinate(float value,float lower,float upper,float length){float delta=(Math.max(1,length)-(upper-lower))/2;
        if(value<=lower)return value-delta;if(value>=upper)return value+delta;
        return lower-delta+(value-lower)*Math.max(1,length)/(upper-lower);
    }
    private void drawTile(Canvas canvas,WallLayout.Instance instance,boolean selected){
        RectF rect=frame(instance);if(rect.right<0||rect.left>getWidth()||rect.bottom<0||rect.top>getHeight())return;
        if(pressed!=null&&same(pressed,instance)&&!selected)rect.inset(rect.width()*.02f,rect.height()*.02f);
        Song song=songs.get(instance.tile.index);
        int save=canvas.save();canvas.clipRect(rect);
        paint.setShader(new LinearGradient(rect.left,rect.top,rect.right,rect.bottom,new int[]{0xFF33443D,0xFF151A20,0xFF49382E},null,Shader.TileMode.CLAMP));
        canvas.drawRect(rect,paint);paint.setShader(null);
        Bitmap image=cover(song);if(image!=null){float ratio=Math.max(rect.width()/image.getWidth(),rect.height()/image.getHeight());
            int srcWidth=Math.min(image.getWidth(),Math.round(rect.width()/ratio)),srcHeight=Math.min(image.getHeight(),Math.round(rect.height()/ratio));
            Rect src=new Rect((image.getWidth()-srcWidth)/2,(image.getHeight()-srcHeight)/2,(image.getWidth()+srcWidth)/2,(image.getHeight()+srcHeight)/2);
            paint.setColor(Color.WHITE);canvas.drawBitmap(image,src,rect,paint);
        }else{paint.setColor(0x66FFFFFF);paint.setTextSize(Math.min(rect.width(),rect.height())*.25f);canvas.drawText("♫",rect.centerX()-paint.measureText("♫")/2,rect.centerY(),paint);}
        if(selected){paint.setShader(new LinearGradient(0,rect.top,0,rect.bottom,new int[]{0x1F000000,0x33000000,0xE0000000},null,Shader.TileMode.CLAMP));canvas.drawRect(rect,paint);paint.setShader(null);
            paint.setColor(0x99000000);canvas.drawRect(rect.left,rect.top,rect.left+rect.width()*.55f,rect.bottom,paint);
        }else{paint.setShader(new LinearGradient(0,rect.top,0,rect.bottom,new int[]{0x47000000,0x47000000,0xD4000000},null,Shader.TileMode.CLAMP));canvas.drawRect(rect,paint);paint.setShader(null);
            if(playingId!=Long.MIN_VALUE&&song.id!=playingId){paint.setColor(0x1F000000);canvas.drawRect(rect,paint);}}
        float inset=Math.min(14*density,Math.max(8*density,instance.tile.width*.06f*scale));
        if(rect.width()>95*density){
            float titleSize=Math.min(30*density,Math.max(18*density,instance.tile.width*.105f*scale));
            float artistSize=Math.min(13*density,Math.max(10*density,instance.tile.width*.045f*scale));
            paint.setTypeface(android.graphics.Typeface.create("sans-serif",android.graphics.Typeface.BOLD));paint.setTextSize(titleSize);
            float titleY=rect.bottom-inset-3*density-artistSize-7*density;
            if(selected)titleY=rect.bottom-inset-artistSize-30*density;
            float textWidth=rect.width()-2*inset-(selected?56*density:0);
            paint.setColor(0xE6FFFFFF);canvas.drawText(shorten(song.title,textWidth),rect.left+inset,titleY,paint);
            paint.setTypeface(android.graphics.Typeface.DEFAULT);paint.setTextSize(artistSize);paint.setColor(0xA6FFFFFF);
            canvas.drawText(shorten(song.artist,textWidth),rect.left+inset,titleY+artistSize+5*density,paint);
            if(!selected){paint.setTypeface(android.graphics.Typeface.MONOSPACE);paint.setTextSize(10*density*scale);paint.setColor(0xCCFFFFFF);
                String number=String.format(java.util.Locale.ROOT,"%03d",instance.tile.index+1);float pad=6*density*scale,numberWidth=paint.measureText(number);
                paint.setColor(0x73000000);canvas.drawRect(rect.left+10*density*scale,rect.top+10*density*scale,rect.left+10*density*scale+numberWidth+2*pad,rect.top+32*density*scale,paint);
                paint.setColor(0xCCFFFFFF);canvas.drawText(number,rect.left+10*density*scale+pad,rect.top+25*density*scale,paint);}
            else {float radius=Math.min(24*density,rect.width()*.09f);float cx=rect.right-inset-radius,cy=rect.bottom-inset-radius;
                paint.setColor(0xF0FFFFFF);canvas.drawCircle(cx,cy,radius,paint);paint.setColor(0xFF222222);paint.setTextSize(radius*.95f);paint.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
                String play=song.id==playingId&&playbackPlaying?"Ⅱ":"▶";canvas.drawText(play,cx-paint.measureText(play)/2,cy+radius*.35f,paint);}
        }
        if(selected&&song.id==playingId&&focusAmount>.8f)drawLyrics(canvas,rect,inset);
        if(song.id==playingId){paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(3*density);paint.setColor(0xD91BBC87);canvas.drawRect(rect,paint);paint.setStyle(Paint.Style.FILL);}
        canvas.restoreToCount(save);hits.add(new Hit(rect,instance));
    }
    private void drawLyrics(Canvas canvas,RectF rect,float inset){
        float centerY=rect.top+rect.height()*.46f;
        paint.setTypeface(android.graphics.Typeface.create("sans-serif",android.graphics.Typeface.BOLD));
        if(playingLyrics.isEmpty()){paint.setTextSize(16*density);paint.setColor(0xA6FFFFFF);canvas.drawText("暂无歌词",rect.left+inset,centerY,paint);return;}
        int active=0;for(int i=0;i<playingLyrics.size();i++){if(playingLyrics.get(i).ms>playbackPosition)break;active=i;}
        float row=Math.max(33*density,Math.min(48*density,rect.height()*.13f));
        for(int relative=-2;relative<=2;relative++){int index=active+relative;if(index<0||index>=playingLyrics.size())continue;
            float y=centerY+relative*row;if(y<rect.top+30*density||y>rect.bottom-90*density)continue;
            paint.setTextSize(relative==0?Math.min(24*density,rect.width()*.068f):Math.min(19*density,rect.width()*.055f));
            paint.setColor(relative==0?Color.WHITE:Math.abs(relative)==1?0x88FFFFFF:0x55FFFFFF);
            canvas.drawText(shorten(playingLyrics.get(index).text,rect.width()-2*inset),rect.left+inset,y,paint);
        }
    }
    private String shorten(String value,float width){if(value==null)return "";if(paint.measureText(value)<=width)return value;String result=value;while(result.length()>1&&paint.measureText(result+"…")>width)result=result.substring(0,result.length()-1);return result+"…";}
    private Bitmap cover(Song song){Bitmap cached=bitmaps.get(song.id);if(cached!=null)return cached;
        if(requested.add(song.id))covers.submit(()->{
            File folder=new File(getContext().getCacheDir(),"covers"),file=new File(folder,song.id+".jpg");
            Bitmap bitmap=file.isFile()?BitmapFactory.decodeFile(file.getAbsolutePath()):null;
            if(bitmap==null){MediaMetadataRetriever retriever=new MediaMetadataRetriever();try{retriever.setDataSource(getContext(),song.uri);byte[] bytes=retriever.getEmbeddedPicture();
                if(bytes!=null){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);
                    int longest=Math.max(options.outWidth,options.outHeight);options.inSampleSize=1;while(longest/options.inSampleSize>1280)options.inSampleSize*=2;options.inJustDecodeBounds=false;
                    Bitmap raw=BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);if(raw!=null){float ratio=Math.min(1,640f/Math.max(raw.getWidth(),raw.getHeight()));
                    bitmap=Bitmap.createScaledBitmap(raw,Math.max(1,Math.round(raw.getWidth()*ratio)),Math.max(1,Math.round(raw.getHeight()*ratio)),true);
                    folder.mkdirs();try(FileOutputStream out=new FileOutputStream(file)){bitmap.compress(Bitmap.CompressFormat.JPEG,85,out);}catch(Exception ignored){}
                }}
            }catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}}
            Bitmap result=bitmap;if(result!=null)main.post(()->{bitmaps.put(song.id,result);invalidate();});
        });
        return null;
    }
    private Hit hit(float x,float y){for(int i=hits.size()-1;i>=0;i--)if(hits.get(i).bounds.contains(x,y))return hits.get(i);return null;}
    private void focus(WallLayout.Instance instance){focus=instance;focusAmount=0;
        float preferred=Math.min(520*density,Math.max(320*density,(getHeight()-150*density)*.85f));
        focusSide=Math.max(180*density,Math.min(preferred,Math.min(getWidth()-40*density,getHeight()-150*density)));
        cancelMotion();float startX=cameraX,startY=cameraY,targetX=getWidth()/2f-(instance.x+instance.tile.width/2)*scale,targetY=getHeight()/2f-(instance.y+instance.tile.height/2)*scale;
        motion=ValueAnimator.ofFloat(0,1);motion.setDuration(520);motion.addUpdateListener(animation->{float t=(float)animation.getAnimatedValue();float eased=focusProgress(t);cameraX=startX+(targetX-startX)*eased;cameraY=startY+(targetY-startY)*eased;focusAmount=reflowProgress(t*520);invalidate();});motion.start();
    }
    private void animateCamera(float x,float y,long duration){cancelMotion();float sx=cameraX,sy=cameraY;motion=ValueAnimator.ofFloat(0,1);motion.setDuration(duration);motion.addUpdateListener(animation->{float t=(float)animation.getAnimatedValue();float eased=1-(float)Math.pow(1-t,3);cameraX=sx+(x-sx)*eased;cameraY=sy+(y-sy)*eased;invalidate();});motion.start();}
    private float focusProgress(float progress){if(progress<=0)return 0;if(progress>=1)return 1;float lower=0,upper=1;
        for(int i=0;i<18;i++){float t=(lower+upper)/2,a=1-t,x=3*a*a*t*.22f+3*a*t*t*.36f+t*t*t;if(x<progress)lower=t;else upper=t;}
        return 1-(float)Math.pow(1-(lower+upper)/2,3);
    }
    private float reflowProgress(float elapsed){if(elapsed<=0)return 0;if(elapsed>=520)return 1;
        double t=elapsed/1000.0,w=Math.sqrt(11);return (float)Math.min(1,Math.max(0,1-Math.exp(-17*t)*(Math.cos(w*t)+17/w*Math.sin(w*t))));
    }
    private void cancelMotion(){if(motion!=null){motion.cancel();motion=null;}}
    @Override public boolean onTouchEvent(MotionEvent event){
        if(event.getActionMasked()==MotionEvent.ACTION_DOWN){Hit target=hit(event.getX(),event.getY());pressed=target==null?null:target.instance;invalidate();}
        else if(event.getActionMasked()==MotionEvent.ACTION_UP||event.getActionMasked()==MotionEvent.ACTION_CANCEL||event.getActionMasked()==MotionEvent.ACTION_POINTER_DOWN){pressed=null;invalidate();}
        scaleDetector.onTouchEvent(event);gestures.onTouchEvent(event);return true;
    }
    @Override protected void onDetachedFromWindow(){covers.shutdownNow();super.onDetachedFromWindow();}
}
