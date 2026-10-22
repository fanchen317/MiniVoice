package com.xcosmos.minivoice;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.Handler;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.IntConsumer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Native canvas port of MiniVoice's repeatable wall scene and camera. */
final class WallView extends View {
    interface OnPlay { void play(Song song); }
    private static final class Hit { final RectF bounds;final WallLayout.Instance instance;Hit(RectF bounds,WallLayout.Instance instance){this.bounds=bounds;this.instance=instance;} }
    private final OnPlay onPlay;
    private final Runnable onToggle;
    private final IntConsumer onSeek;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
    private final GestureDetector gestures;
    private final ScaleGestureDetector scaleDetector;
    private final Handler main=new Handler();
    private final ExecutorService covers=Executors.newFixedThreadPool(2);
    private final java.util.Map<String,Long> requested=new java.util.HashMap<>();
    private long requestSerial;private java.util.concurrent.Future<?> focusTask;private String focusTaskKey;
    private final ExecutorService focusCovers=Executors.newSingleThreadExecutor();
    private final CoverWorkingSet<Bitmap> visibleCovers=new CoverWorkingSet<>(Math.max(24L*1024*1024,Math.min(64L*1024*1024,Runtime.getRuntime().maxMemory()/4)));
    private final Set<String> visibleCoverSources=new HashSet<>();
    private final java.util.Map<String,java.util.concurrent.Future<?>> normalTasks=new java.util.HashMap<>();
    private int dataGeneration;
    private RectF faceCropFrom,faceCropTo;private String faceCropKey;private long faceCropAt;
    private ArtworkFraming.Plan cachedFacePlan;private ArtworkFraming.Face[] cachedFaces;private String cachedFacePlanKey;
    private List<WallLayout.Instance> visibleTiles;private WallLayout visibleScene;private float visibleX,visibleY,visibleScale;private int visibleWidth,visibleHeight;private boolean visibleFocused;
    private boolean renderingActive=true;
    private final Runnable frameTick=()->{if(renderingActive&&isShown()&&hasWindowFocus())invalidate();};
    private final android.graphics.RenderNode wallNode=new android.graphics.RenderNode("MiniVoice wall scene");
    private boolean sceneRecorded,manualGesture,focusInterrupted;
    private WallLayout.Instance tapCandidate;
    private final java.util.Map<String,Long> coverRetryUntil=new java.util.HashMap<>();
    private final List<Hit> hits=new ArrayList<>();
    interface CardActions {void previous();void next();void favorite(Song song);void immersive(boolean expanded);}
    private CardActions cardActions;
    private final FocusCardRenderer card;
    private Set<String> favorites=new HashSet<>();
    private int playbackDuration;
    private boolean expanded,controlTouch;
    private float expansionAmount;
    private ValueAnimator expansionAnimator;
    private int safeTop,safeBottom;
    private WallViewport viewport;
    private boolean scanning;
    void setScanning(boolean value){if(scanning==value)return;scanning=value;invalidate();}
    void setViewport(WallViewport value){
        boolean changed=viewport==null||viewport.width!=value.width||viewport.height!=value.height||viewport.focusX!=value.focusX||viewport.focusY!=value.focusY||viewport.focusSide!=value.focusSide;
        viewport=value;if(changed){if(focus!=null){cancelMotion();layoutFocusedCard(focus);}invalidate();}
    }
    private float anchorX(){return viewport==null?getWidth()/2f:viewport.focusX;}
    private float preferredSide(){return viewport==null?Math.max(180*density,Math.min(520*density,Math.min(getWidth()-24*density,getHeight()-safeTop-safeBottom-180*density))):viewport.focusSide;}

    void setCardActions(CardActions actions){cardActions=actions;}
    void setCardState(Set<String> favorites,int mode,int duration){if(this.favorites.equals(favorites)&&playbackDuration==duration)return;this.favorites=new HashSet<>(favorites);playbackDuration=duration;invalidate();}
    void setSafeInsets(int top,int bottom){if(safeTop==top&&safeBottom==bottom)return;safeTop=top;safeBottom=bottom;invalidate();}
    boolean collapse(){if(!expanded&&expansionAmount<=0)return false;setExpanded(false);return true;}
    private void setExpanded(boolean value){
        if(focus==null||expanded==value&&expansionAnimator!=null&&expansionAnimator.isRunning())return;
        expanded=value;card.clear();cancelMotion();
        if(expansionAnimator!=null){expansionAnimator.removeAllListeners();expansionAnimator.cancel();}
        if(value&&cardActions!=null)cardActions.immersive(true);
        expansionAnimator=ValueAnimator.ofFloat(expansionAmount,value?1:0);expansionAnimator.setDuration(420);
        expansionAnimator.setInterpolator(new android.view.animation.PathInterpolator(.22f,1,.36f,1));
        expansionAnimator.addUpdateListener(animation->{expansionAmount=(float)animation.getAnimatedValue();invalidate();});
        expansionAnimator.addListener(new android.animation.AnimatorListenerAdapter(){@Override public void onAnimationEnd(android.animation.Animator animation){if(!expanded&&cardActions!=null)cardActions.immersive(false);}});expansionAnimator.start();
    }
    private void resetExpansion(){
        if(expansionAnimator!=null){expansionAnimator.removeAllListeners();expansionAnimator.cancel();}
        boolean wasExpanded=expanded||expansionAmount>0;expanded=false;expansionAmount=0;if(wasExpanded&&cardActions!=null)cardActions.immersive(false);
    }

    private List<Song> songs=new ArrayList<>();
    private WallLayout scene;
    private float cameraX,cameraY,scale=1,focusAmount,focusSide;
    private Runnable scaleListener=()->{};
    void setScaleListener(Runnable listener){scaleListener=listener;}
    private long playingId=Long.MIN_VALUE;
    private List<Lyrics.Line> playingLyrics=new ArrayList<>();
    private String lyricStatus="正在加载歌词…";
    private int playbackPosition;
    private long playbackSampledAt;
    private boolean playbackPlaying;
    private WallLayout.Instance focus;
    private WallLayout.Instance pressed;
    private boolean cameraReady,grouped;
    private ValueAnimator motion;
    private final WallFocusMotion focusMotion=new WallFocusMotion();
    private WallReflow.Transform reflowFrom=WallReflow.IDENTITY,reflowTo=WallReflow.IDENTITY;
    private long pendingLocate=Long.MIN_VALUE;private boolean pendingLocateAnimated;
    private final OnLayoutChangeListener locateAfterLayout=(view,left,top,right,bottom,oldLeft,oldTop,oldRight,oldBottom)->{
        if(right>left&&bottom>top&&pendingLocate!=Long.MIN_VALUE){long id=pendingLocate;pendingLocate=Long.MIN_VALUE;locateSong(id,pendingLocateAnimated);}
    };
    private java.util.function.Consumer<Song> songMenu;
    void setSongMenu(java.util.function.Consumer<Song> action){songMenu=action;}
    private final float density;
    WallView(Context context,OnPlay onPlay,Runnable onToggle,IntConsumer onSeek){
        super(context);this.onPlay=onPlay;this.onToggle=onToggle;this.onSeek=onSeek;density=getResources().getDisplayMetrics().density;card=new FocusCardRenderer(density,this::postInvalidateOnAnimation);
        scene=new WallLayout(0,density);addOnLayoutChangeListener(locateAfterLayout);
        gestures=new GestureDetector(context,new GestureDetector.SimpleOnGestureListener(){
            @Override public void onLongPress(MotionEvent event){Hit tapped=hit(event.getX(),event.getY());if(!grouped&&tapped!=null&&songMenu!=null){tapCandidate=null;performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS);songMenu.accept(songs.get(tapped.instance.tile.index));}}
            @Override public boolean onDown(MotionEvent event){manualGesture=false;return true;}
            @Override public boolean onScroll(MotionEvent start,MotionEvent end,float dx,float dy){if(expanded||expansionAmount>0||scaleDetector.isInProgress())return false;if(!manualGesture){interruptCamera();manualGesture=true;}cameraX-=dx;cameraY-=dy;invalidate();return true;}
            @Override public boolean onFling(MotionEvent start,MotionEvent end,float vx,float vy){if(expanded||expansionAmount>0)return false;animateCamera(cameraX+vx*.20f,cameraY+vy*.20f,420);return true;}
            @Override public boolean onSingleTapUp(MotionEvent event){if(!grouped&&card.seekLyric(event.getX(),event.getY())){tapCandidate=null;performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);return true;}Hit tapped=hit(event.getX(),event.getY());tapCandidate=tapped==null?null:tapped.instance;return tapped!=null;}
            @Override public boolean onSingleTapConfirmed(MotionEvent event){
                WallLayout.Instance target=tapCandidate;tapCandidate=null;if(target==null)return false;
                if(grouped){onPlay.play(songs.get(target.tile.index));return true;}
                if(!expanded&&expansionAmount==0)focus(target);return true;
            }
            @Override public boolean onDoubleTap(MotionEvent event){
                WallLayout.Instance target=tapCandidate;tapCandidate=null;if(target==null){Hit tapped=hit(event.getX(),event.getY());target=tapped==null?null:tapped.instance;}
                if(target==null||target.tile.index>=songs.size())return false;
                if(!grouped&&!expanded&&(focus==null||!same(target,focus)))focus(target);
                playOrToggle(target);performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);return true;
            }
        });
        scaleDetector=new ScaleGestureDetector(context,new ScaleGestureDetector.SimpleOnScaleGestureListener(){
            @Override public boolean onScaleBegin(ScaleGestureDetector detector){if(expanded||expansionAmount>0)return false;interruptCamera();return true;}
            @Override public boolean onScale(ScaleGestureDetector detector){setScaleAt(scale*detector.getScaleFactor(),detector.getFocusX(),detector.getFocusY());return true;}

        });
    }
    static final class CameraState {
        final float x,y,scale;final long focused;final int column,row;final boolean expanded;
        CameraState(float x,float y,float scale){this(x,y,scale,Long.MIN_VALUE,0,0,false);}
        CameraState(float x,float y,float scale,long focused,int column,int row,boolean expanded){this.x=x;this.y=y;this.scale=scale;this.focused=focused;this.column=column;this.row=row;this.expanded=expanded;}
    }
    CameraState cameraState(){return new CameraState(cameraX,cameraY,scale,focus==null?Long.MIN_VALUE:songs.get(focus.tile.index).id,focus==null?0:focus.column,focus==null?0:focus.row,expanded);}
    void restoreCamera(CameraState value){if(value==null)return;resetExpansion();cancelMotion();focus=null;focusAmount=0;reflowFrom=reflowTo=WallReflow.IDENTITY;cameraX=value.x;cameraY=value.y;scale=WallZoom.clamp(value.scale);cameraReady=true;
        if(!grouped&&value.focused!=Long.MIN_VALUE)for(WallLayout.Tile tile:scene.tiles)if(songs.get(tile.index).id==value.focused){
            focus=new WallLayout.Instance(tile,value.column,value.row,tile.x+value.column*scene.width,tile.y+value.row*scene.height);focusAmount=1;reflowFrom=reflowTo=WallReflow.focused(baseFrame(focus),preferredSide(),5*density);expanded=value.expanded;expansionAmount=expanded?1:0;if(cardActions!=null)cardActions.immersive(expanded);break;
        }
        scaleListener.run();invalidate();}
    void setGrouped(boolean value){if(grouped==value)return;grouped=value;resetExpansion();card.clear();focus=null;focusAmount=0;reflowFrom=reflowTo=WallReflow.IDENTITY;invalidate();}
    void setSongs(List<Song> value){
        boolean sameOrder=songs.size()==value.size();
        if(sameOrder)for(int i=0;i<songs.size();i++)if(songs.get(i).id!=value.get(i).id){sameOrder=false;break;}
        if(sameOrder){coverRetryUntil.clear();songs=new ArrayList<>(value);invalidate();return;}
        long focusedId=!grouped&&focus!=null?songs.get(focus.tile.index).id:Long.MIN_VALUE;
        dataGeneration++;for(java.util.concurrent.Future<?> task:normalTasks.values())task.cancel(false);normalTasks.clear();resetExpansion();card.clear();requested.clear();if(focusTask!=null)focusTask.cancel(false);focusTask=null;focusTaskKey=null;cancelMotion();if(value.isEmpty())visibleCovers.clear();songs=new ArrayList<>(value);scene=new WallLayout(songs.size(),density);focus=null;pressed=null;focusAmount=0;reflowFrom=reflowTo=WallReflow.IDENTITY;cameraReady=false;
        if(focusedId!=Long.MIN_VALUE)locateSongDirectly(focusedId);scaleListener.run();invalidate();
    }
    void locateSongDirectly(long id){locateSong(id,false);}
    void locateSong(long id){locateSong(id,true);}
    private void locateSong(long id,boolean animated){
        if(getWidth()==0||getHeight()==0){pendingLocate=id;pendingLocateAnimated=animated;return;}
        if(!cameraReady)centerInitial();
        for(int i=0;i<songs.size();i++)if(songs.get(i).id==id){
            WallLayout.Instance target=null;
            // Keep the visible focused repeat. Re-selecting a periodic copy can shift the wall again.
            if(focus!=null&&focus.tile.index==i){RectF visible=frame(focus);if(visible.right>0&&visible.left<getWidth()&&visible.bottom>safeTop&&visible.top<getHeight()-safeBottom)target=focus;}
            if(target==null)target=nearestRendered(i);
            if(target!=null){if(animated)focus(target);else focusDirectly(target);}return;
        }
    }
    private float anchorY(){return viewport==null?(safeTop+80*density+getHeight()-safeBottom-112*density)/2:viewport.focusY;}
    private WallLayout.Instance nearestRendered(int index){
        WallLayout.Instance seed=scene.nearest(index,cameraX,cameraY,scale,anchorX()*2,anchorY()*2);if(seed==null)return null;
        WallLayout.Instance best=seed;double distance=Double.POSITIVE_INFINITY;
        // Choose the closest visible repeat after reflow, rather than its old unexpanded position.
        for(int row=seed.row-1;row<=seed.row+1;row++)for(int column=seed.column-1;column<=seed.column+1;column++){
            WallLayout.Tile tile=seed.tile;WallLayout.Instance item=new WallLayout.Instance(tile,column,row,tile.x+column*scene.width,tile.y+row*scene.height);
            WallReflow.Frame frame=worldFrame(item);double dx=cameraX+frame.centerX()*scale-anchorX(),dy=cameraY+frame.centerY()*scale-anchorY();
            double candidate=dx*dx+dy*dy;if(candidate<distance){distance=candidate;best=item;}
        }
        return best;
    }
    private void playOrToggle(WallLayout.Instance instance){Song song=songs.get(instance.tile.index);if(grouped){onPlay.play(song);return;}if(song.id==playingId)onToggle.run();else onPlay.play(song);}
    void setPlayback(long id,boolean playing,int position){if(playingId==id&&playbackPlaying==playing&&playbackPosition==position)return;if(playingId!=id){playingLyrics=new ArrayList<>();lyricStatus="正在加载歌词…";}playingId=id;playbackPlaying=playing;playbackPosition=position;playbackSampledAt=android.os.SystemClock.elapsedRealtime();invalidate();}
    void setLyrics(long id,List<Lyrics.Line> lines){if(playingId==id){playingLyrics=new ArrayList<>(lines);lyricStatus="暂无歌词";invalidate();}}
    void setLyricsStatus(long id,String message){if(playingId==id){lyricStatus=message;invalidate();}}
    void resetCamera(){resetExpansion();cancelMotion();focus=null;focusAmount=0;reflowFrom=reflowTo=WallReflow.IDENTITY;cameraReady=false;scale=1;centerInitial();scaleListener.run();invalidate();}
    void zoomTo(float value){interruptCamera();setScaleAt(value,getWidth()/2f,getHeight()/2f);}
    void zoom(float factor){interruptCamera();setScaleAt(scale*factor,getWidth()/2f,getHeight()/2f);}
    private void setScaleAt(float value,float x,float y){float old=scale;scale=WallZoom.clamp(value);cameraX=x-(x-cameraX)*scale/old;cameraY=y-(y-cameraY)*scale/old;scaleListener.run();invalidate();}
    float scale(){return scale;}
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){super.onSizeChanged(w,h,oldW,oldH);if(!cameraReady)centerInitial();}
    private void centerInitial(){if(scene.tiles.isEmpty()||getWidth()==0||getHeight()==0)return;
        cameraX=12*density;cameraY=80*density;cameraReady=true;}
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);
        if(canvas.isHardwareAccelerated()){
            wallNode.setPosition(0,0,getWidth(),getHeight());Canvas sceneCanvas=wallNode.beginRecording(getWidth(),getHeight());drawScene(sceneCanvas);wallNode.endRecording();sceneRecorded=true;canvas.drawRenderNode(wallNode);
        }else drawScene(canvas);
    }
    boolean drawBackdrop(Canvas canvas){if(!sceneRecorded||!canvas.isHardwareAccelerated())return false;canvas.drawRenderNode(wallNode);return true;}
    private void drawScene(Canvas canvas){visibleCovers.beginFrame();visibleCoverSources.clear();canvas.drawColor(Color.BLACK);hits.clear();card.clear();if(scene.tiles.isEmpty()){
        paint.setShader(null);paint.setColor(0xFF9DA8A1);paint.setTextSize(18*density);String message=scanning?"正在载入音乐库…":"添加音乐文件夹，开始浏览音乐墙";canvas.drawText(message,Math.max(20,(getWidth()-paint.measureText(message))/2),getHeight()/2f,paint);return;}
        if(!cameraReady)centerInitial();
        List<WallLayout.Instance> visible=visibleTiles();
        WallLayout.Instance focusedInstance=null;
        for(WallLayout.Instance instance:visible){if(focus!=null&&same(instance,focus)){focusedInstance=instance;continue;}drawTile(canvas,instance,false);}
        if((expanded||expansionAmount>0)&&focus!=null){paint.setColor(((int)(191*expansionAmount))<<24);canvas.drawRect(0,0,getWidth(),getHeight(),paint);drawTile(canvas,focus,true);}
        else if(focusedInstance!=null)drawTile(canvas,focusedInstance,true);
        String focusKey=focus==null?null:coverSource(songs.get(focus.tile.index));visibleCovers.trim(android.os.SystemClock.uptimeMillis(),focusKey);
        java.util.Iterator<java.util.Map.Entry<String,java.util.concurrent.Future<?>>> tasks=normalTasks.entrySet().iterator();while(tasks.hasNext()){java.util.Map.Entry<String,java.util.concurrent.Future<?>> task=tasks.next();String source=task.getKey().substring(0,task.getKey().lastIndexOf("\n"));if(!visibleCoverSources.contains(source)){task.getValue().cancel(false);requested.remove(task.getKey());tasks.remove();}}
        removeCallbacks(frameTick);if(renderingActive&&hasWindowFocus()&&playbackPlaying&&focus!=null&&songs.get(focus.tile.index).id==playingId)postDelayed(frameTick,50);
    }
    private List<WallLayout.Instance> visibleTiles(){boolean focused=focus!=null;if(visibleTiles==null||visibleScene!=scene||visibleX!=cameraX||visibleY!=cameraY||visibleScale!=scale||visibleWidth!=getWidth()||visibleHeight!=getHeight()||visibleFocused!=focused){visibleTiles=scene.visible(cameraX,cameraY,scale,getWidth(),getHeight(),(focused?1100:400)*density);visibleScene=scene;visibleX=cameraX;visibleY=cameraY;visibleScale=scale;visibleWidth=getWidth();visibleHeight=getHeight();visibleFocused=focused;}return visibleTiles;}
    private boolean same(WallLayout.Instance a,WallLayout.Instance b){return a.tile.index==b.tile.index&&a.column==b.column&&a.row==b.row;}
    private RectF normalFrame(WallLayout.Instance instance){WallReflow.Frame frame=worldFrame(instance);return new RectF(cameraX+frame.x*scale,cameraY+frame.y*scale,cameraX+(frame.x+frame.width)*scale,cameraY+(frame.y+frame.height)*scale);}
    private RectF blend(RectF from,RectF to){return new RectF(PlayerExpansion.mix(from.left,to.left,expansionAmount),PlayerExpansion.mix(from.top,to.top,expansionAmount),PlayerExpansion.mix(from.right,to.right,expansionAmount),PlayerExpansion.mix(from.bottom,to.bottom,expansionAmount));}
    private RectF frame(WallLayout.Instance instance){
        RectF normal=normalFrame(instance);
        return focus!=null&&same(instance,focus)&&expansionAmount>0?blend(normal,new RectF(0,0,getWidth(),getHeight())):normal;
    }
    private RectF playerContent(WallLayout.Instance instance){
        float left=viewport==null?0:viewport.safeLeft,right=viewport==null?0:viewport.safeRight;
        WallReflow.Frame safe=PlayerExpansion.content(getWidth(),getHeight(),left,safeTop,right,safeBottom);
        return blend(normalFrame(instance),new RectF(safe.x,safe.y,safe.x+safe.width,safe.y+safe.height));
    }
    private WallReflow.Frame baseFrame(WallLayout.Instance instance){return new WallReflow.Frame(instance.x,instance.y,instance.tile.width,instance.tile.height);}
    private WallReflow.Frame worldFrame(WallLayout.Instance instance){return currentReflow().apply(baseFrame(instance));}
    private WallReflow.Transform currentReflow(){return WallReflow.between(reflowFrom,reflowTo,focusAmount);}
    private void drawTile(Canvas canvas,WallLayout.Instance instance,boolean selected){
        RectF rect=frame(instance);if(rect.right<0||rect.left>getWidth()||rect.bottom<0||rect.top>getHeight())return;
        if(pressed!=null&&same(pressed,instance)&&!selected)rect.inset(rect.width()*.02f,rect.height()*.02f);
        Song song=songs.get(instance.tile.index);
        int save=canvas.save();canvas.clipRect(rect);
        paint.setShader(new LinearGradient(rect.left,rect.top,rect.right,rect.bottom,new int[]{0xFF33443D,0xFF151A20,0xFF49382E},null,Shader.TileMode.CLAMP));
        canvas.drawRect(rect,paint);paint.setShader(null);
        Bitmap image=cover(song,selected,rect);if(image!=null){
            if(selected&&expansionAmount>0)drawExpandedArtwork(canvas,rect,normalFrame(instance),image,song);else drawCover(canvas,image,rect);
        }else{paint.setColor(0x66FFFFFF);paint.setTextSize(Math.min(rect.width(),rect.height())*.25f);canvas.drawText("♫",rect.centerX()-paint.measureText("♫")/2,rect.centerY(),paint);}
        if(selected){
            // Full-width, continuous shade: no hard vertical edge across the artwork.
            paint.setShader(new LinearGradient(0,rect.top,0,rect.bottom,new int[]{0x69000000,0x73000000,0xE6000000},new float[]{0,.55f,1},Shader.TileMode.CLAMP));canvas.drawRect(rect,paint);paint.setShader(null);
        }else{paint.setShader(new LinearGradient(0,rect.top,0,rect.bottom,new int[]{0x47000000,0x47000000,0xD4000000},null,Shader.TileMode.CLAMP));canvas.drawRect(rect,paint);paint.setShader(null);
            if(!grouped&&playingId!=Long.MIN_VALUE&&song.id!=playingId){paint.setColor(0x1F000000);canvas.drawRect(rect,paint);}}
        float inset=Math.min(14*density,Math.max(8*density,instance.tile.width*.06f*scale));
        if(!selected&&rect.width()>70*density){
            float titleSize=Math.min(23*density,Math.max(12*density,instance.tile.width*.08f*scale));
            float artistSize=Math.min(12*density,Math.max(9*density,instance.tile.width*.04f*scale));
            paint.setTypeface(android.graphics.Typeface.create("sans-serif",android.graphics.Typeface.BOLD));paint.setTextSize(titleSize);
            float titleY=rect.bottom-inset-3*density-artistSize-7*density;
            float textWidth=rect.width()-2*inset;
            paint.setColor(0xE6FFFFFF);canvas.drawText(shorten(song.title,textWidth),rect.left+inset,titleY,paint);
            paint.setTypeface(android.graphics.Typeface.DEFAULT);paint.setTextSize(artistSize);paint.setColor(0xA6FFFFFF);
            canvas.drawText(shorten(grouped?song.groupCount+" 首歌曲":song.artist,textWidth),rect.left+inset,titleY+artistSize+5*density,paint);
            if(!selected){paint.setTypeface(android.graphics.Typeface.MONOSPACE);paint.setTextSize(10*density*scale);paint.setColor(0xCCFFFFFF);
                String number=String.format(java.util.Locale.ROOT,"%03d",instance.tile.index+1);float pad=6*density*scale,numberWidth=paint.measureText(number);
                paint.setColor(0x73000000);canvas.drawRect(rect.left+10*density*scale,rect.top+10*density*scale,rect.left+10*density*scale+numberWidth+2*pad,rect.top+32*density*scale,paint);
                paint.setColor(0xCCFFFFFF);canvas.drawText(number,rect.left+10*density*scale+pad,rect.top+25*density*scale,paint);}
        }
        if(!grouped&&selected&&focusAmount>.8f){
            card.draw(canvas,playerContent(instance),song,song.id==playingId,playbackPlaying,Math.min(playbackDuration,playbackPosition+(playbackPlaying?(int)Math.min(750,android.os.SystemClock.elapsedRealtime()-playbackSampledAt):0)),playbackDuration,playingLyrics,lyricStatus,favorites.contains(Long.toString(song.id)),expanded||expansionAmount>0,scale,new FocusCardRenderer.Actions(){
                public void previous(){if(cardActions!=null)cardActions.previous();}
                public void toggle(){onToggle.run();}
                public void next(){if(cardActions!=null)cardActions.next();}
                public void favorite(){if(cardActions!=null)cardActions.favorite(song);}
                public void expand(){setExpanded(!expanded);}
                public void seek(int ms){onSeek.accept(ms);}
                public void play(){onPlay.play(song);}
            });
        }
        if(!grouped&&(selected||song.id==playingId&&focus==null)&&expansionAmount<1){paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(3*density);paint.setColor((((int)(217*(1-expansionAmount)))<<24)|0x1BBC87);canvas.drawRect(rect,paint);paint.setStyle(Paint.Style.FILL);}
        canvas.restoreToCount(save);hits.add(new Hit(rect,instance));
    }
    private RectF crop(Bitmap image,RectF destination){float ratio=Math.max(destination.width()/image.getWidth(),destination.height()/image.getHeight());float w=destination.width()/ratio,h=destination.height()/ratio;return new RectF((image.getWidth()-w)/2,(image.getHeight()-h)/2,(image.getWidth()+w)/2,(image.getHeight()+h)/2);}
    private void drawCover(Canvas canvas,Bitmap image,RectF destination){RectF source=crop(image,destination);paint.setColor(Color.WHITE);canvas.drawBitmap(image,new Rect(Math.round(source.left),Math.round(source.top),Math.round(source.right),Math.round(source.bottom)),destination,paint);}
    private void drawExpandedArtwork(Canvas canvas,RectF rect,RectF normal,Bitmap image,Song song){
        ArtworkFaces.request(getContext().getApplicationContext(),song,image,this::postInvalidateOnAnimation);
        ArtworkFraming.Face[] faces=ArtworkFaces.peek(song);String key=coverSource(song)+":"+getWidth()+":"+getHeight(),planKey=key+":"+image.getWidth()+":"+image.getHeight();
        if(cachedFacePlan==null||!planKey.equals(cachedFacePlanKey)||faces!=cachedFaces){cachedFacePlan=ArtworkFraming.plan(image.getWidth(),image.getHeight(),0,0,getWidth(),getHeight(),faces);cachedFacePlanKey=planKey;cachedFaces=faces;}
        ArtworkFraming.Plan plan=cachedFacePlan;RectF desired=new RectF(plan.sourceX/image.getWidth(),plan.sourceY/image.getHeight(),(plan.sourceX+plan.sourceWidth)/image.getWidth(),(plan.sourceY+plan.sourceHeight)/image.getHeight());long now=android.os.SystemClock.uptimeMillis();
        if(!key.equals(faceCropKey)){faceCropKey=key;faceCropFrom=faceCropTo=desired;faceCropAt=now;}
        else if(Math.abs(desired.left-faceCropTo.left)+Math.abs(desired.top-faceCropTo.top)+Math.abs(desired.right-faceCropTo.right)+Math.abs(desired.bottom-faceCropTo.bottom)>.001f){faceCropFrom=currentFaceCrop(now);faceCropTo=desired;faceCropAt=now;}
        RectF normalized=currentFaceCrop(now);RectF source=blend(crop(image,normal),new RectF(normalized.left*image.getWidth(),normalized.top*image.getHeight(),normalized.right*image.getWidth(),normalized.bottom*image.getHeight()));paint.setColor(Color.WHITE);canvas.drawBitmap(image,new Rect(Math.round(source.left),Math.round(source.top),Math.round(source.right),Math.round(source.bottom)),rect,paint);
        if(now-faceCropAt<280&&!faceCropFrom.equals(faceCropTo))postInvalidateDelayed(33);
    }
    private RectF currentFaceCrop(long now){float t=Math.min(1,(now-faceCropAt)/280f);t=1-(float)Math.pow(1-t,3);return new RectF(PlayerExpansion.mix(faceCropFrom.left,faceCropTo.left,t),PlayerExpansion.mix(faceCropFrom.top,faceCropTo.top,t),PlayerExpansion.mix(faceCropFrom.right,faceCropTo.right,t),PlayerExpansion.mix(faceCropFrom.bottom,faceCropTo.bottom,t));}
    private String shorten(String value,float width){if(value==null)return "";if(paint.measureText(value)<=width)return value;String result=value;while(result.length()>1&&paint.measureText(result+"…")>width)result=result.substring(0,result.length()-1);return result+"…";}
    private String coverSource(Song song){return song.uri+"\n"+song.artworkVersion+"|"+song.artworkUri;}
    private Bitmap cover(Song song,boolean selected,RectF rect){
        int detailSize=CoverQuality.side(Math.max(rect.width(),rect.height()),selected);String source=coverSource(song),key=source+"\n"+detailSize;long now=android.os.SystemClock.uptimeMillis();
        visibleCoverSources.add(source);visibleCovers.visible(source,now);CoverWorkingSet.Image<Bitmap> resident=visibleCovers.get(source);
        if(resident!=null&&resident.quality>=detailSize){if(selected)ArtworkFaces.request(getContext().getApplicationContext(),song,resident.value,this::postInvalidateOnAnimation);return resident.value;}
        Bitmap cached=ArtworkCache.peek(song,detailSize);if(cached!=null){visibleCovers.offer(source,cached,detailSize,cached.getAllocationByteCount(),now);if(selected)ArtworkFaces.request(getContext().getApplicationContext(),song,cached,this::postInvalidateOnAnimation);return cached;}
        Bitmap fallback=resident!=null?resident.value:song.artworkPreview;
        if(song.artworkPrepared&&song.artworkFile==null)return fallback;
        if(now>=coverRetryUntil.getOrDefault(key,0L)&&(selected||normalTasks.size()<4)&&!requested.containsKey(key)){
            if(selected&&focusTaskKey!=null&&!focusTaskKey.equals(key)&&focusTask!=null&&!focusTask.isDone()){focusTask.cancel(false);requested.remove(focusTaskKey);}
            final long ticket=++requestSerial;requested.put(key,ticket);
            final int generation=dataGeneration;
            java.util.concurrent.Future<?> task=(selected?focusCovers:covers).submit(()->{
                Bitmap loaded=null;try{loaded=ArtworkCache.load(getContext().getApplicationContext(),song,detailSize);}catch(RuntimeException|OutOfMemoryError failure){android.util.Log.w("MiniVoice","Cover detail decoding failed; keeping current image",failure);}final Bitmap result=loaded;
                main.post(()->{if(!isAttachedToWindow()||!java.util.Objects.equals(requested.get(key),ticket))return;requested.remove(key);normalTasks.remove(key);if(generation!=dataGeneration)return;
                    if(result!=null&&result!=song.artworkPreview){visibleCovers.offer(source,result,detailSize,result.getAllocationByteCount(),android.os.SystemClock.uptimeMillis());coverRetryUntil.remove(key);}else coverRetryUntil.put(key,android.os.SystemClock.uptimeMillis()+15000);invalidate();
                });
            });if(!selected)normalTasks.put(key,task);else{focusTask=task;focusTaskKey=key;}
        }
        return fallback;
    }
    private Hit hit(float x,float y){for(int i=hits.size()-1;i>=0;i--)if(hits.get(i).bounds.contains(x,y))return hits.get(i);return null;}
    private void focusDirectly(WallLayout.Instance instance){
        if(focus!=null&&same(instance,focus)&&focusAmount>=.9999f){
            WallReflow.Frame target=reflowTo.apply(baseFrame(instance));float x=anchorX()-target.centerX()*scale,y=anchorY()-target.centerY()*scale;
            if(Math.abs(cameraX-x)<=density&&Math.abs(cameraY-y)<=density)return;
            cancelMotion();cameraX=x;cameraY=y;invalidate();return;
        }
        cancelMotion();layoutFocusedCard(instance);
    }
    private void layoutFocusedCard(WallLayout.Instance instance){
        focus=instance;focusAmount=1;focusInterrupted=false;float side=preferredSide();
        reflowFrom=reflowTo=WallReflow.focused(baseFrame(instance),side,5*density);
        WallReflow.Frame target=reflowTo.apply(baseFrame(instance));cameraX=anchorX()-target.centerX()*scale;cameraY=anchorY()-target.centerY()*scale;cameraReady=true;invalidate();
    }
    private void focus(WallLayout.Instance instance){
        if(focus!=null&&same(instance,focus)&&!focusInterrupted){
            WallReflow.Frame target=reflowTo.apply(baseFrame(instance));
            animateFocus(target,false);return;
        }
        WallReflow.Transform visible=currentReflow();cancelMotion();
        focus=instance;focusAmount=0;focusInterrupted=false;reflowFrom=visible;
        focusSide=preferredSide();
        reflowTo=WallReflow.focused(baseFrame(instance),focusSide,5*density);
        animateFocus(reflowTo.apply(baseFrame(instance)),true);
    }
    private void animateFocus(WallReflow.Frame target,boolean newFocus){
        float startX=cameraX,startY=cameraY,startAmount=focusAmount;
        float targetX=anchorX()-target.centerX()*scale,targetY=anchorY()-target.centerY()*scale;
        if(!focusMotion.shouldStart(startX,startY,targetX,targetY,focusAmount,newFocus,density))return;
        cancelMotion();focusMotion.started(targetX,targetY);
        motion=ValueAnimator.ofFloat(0,1);motion.setDuration(newFocus?520:360);
        motion.addListener(new android.animation.AnimatorListenerAdapter(){@Override public void onAnimationEnd(android.animation.Animator animation){if(animation==motion)focusMotion.clear();}});
        motion.addUpdateListener(animation->{float t=(float)animation.getAnimatedValue(),eased=focusProgress(t);
            cameraX=startX+(targetX-startX)*eased;cameraY=startY+(targetY-startY)*eased;
            focusAmount=startAmount+(1-startAmount)*reflowProgress(t*520);invalidate();
        });motion.start();
    }
    private void animateCamera(float x,float y,long duration){cancelMotion();float sx=cameraX,sy=cameraY,startAmount=focusAmount;motion=ValueAnimator.ofFloat(0,1);motion.setDuration(duration);motion.addUpdateListener(animation->{float t=(float)animation.getAnimatedValue();float eased=1-(float)Math.pow(1-t,3);cameraX=sx+(x-sx)*eased;cameraY=sy+(y-sy)*eased;focusAmount=startAmount+(1-startAmount)*eased;invalidate();});motion.start();}
    private float focusProgress(float progress){if(progress<=0)return 0;if(progress>=1)return 1;float lower=0,upper=1;
        for(int i=0;i<18;i++){float t=(lower+upper)/2,a=1-t,x=3*a*a*t*.22f+3*a*t*t*.36f+t*t*t;if(x<progress)lower=t;else upper=t;}
        return 1-(float)Math.pow(1-(lower+upper)/2,3);
    }
    private float reflowProgress(float elapsed){if(elapsed<=0)return 0;if(elapsed>=520)return 1;
        double t=elapsed/1000.0,w=Math.sqrt(11);return (float)Math.min(1,Math.max(0,1-Math.exp(-17*t)*(Math.cos(w*t)+17/w*Math.sin(w*t))));
    }
    private void interruptCamera(){
        WallReflow.Transform visible=currentReflow();boolean partial=focus!=null&&focusAmount>0&&focusAmount<1;cancelMotion();
        if(partial){reflowFrom=reflowTo=visible;focusAmount=1;focusInterrupted=true;}
    }
    private void cancelMotion(){focusMotion.clear();if(motion!=null){motion.removeAllListeners();motion.cancel();motion=null;}}
    @Override public boolean onTouchEvent(MotionEvent event){
        int action=event.getActionMasked();
        if(action==MotionEvent.ACTION_DOWN&&card.down(event.getX(),event.getY())){interruptCamera();controlTouch=true;invalidate();return true;}
        if(controlTouch){
            if(action==MotionEvent.ACTION_MOVE)card.move(event.getX());
            if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL||action==MotionEvent.ACTION_POINTER_DOWN){boolean handled=card.up(event.getX(),event.getY(),action!=MotionEvent.ACTION_UP);if(handled&&action==MotionEvent.ACTION_UP)performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);controlTouch=false;}
            invalidate();return true;
        }

        if(event.getActionMasked()==MotionEvent.ACTION_DOWN){Hit target=hit(event.getX(),event.getY());pressed=target==null?null:target.instance;invalidate();}
        else if(event.getActionMasked()==MotionEvent.ACTION_UP||event.getActionMasked()==MotionEvent.ACTION_CANCEL||event.getActionMasked()==MotionEvent.ACTION_POINTER_DOWN){pressed=null;invalidate();}
        scaleDetector.onTouchEvent(event);gestures.onTouchEvent(event);return true;
    }
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);renderingActive=focused;removeCallbacks(frameTick);if(focused)invalidate();}
    @Override protected void onWindowVisibilityChanged(int visibility){super.onWindowVisibilityChanged(visibility);if(visibility!=VISIBLE)removeCallbacks(frameTick);}
    @Override protected void onDetachedFromWindow(){if(expansionAnimator!=null){expansionAnimator.removeAllListeners();expansionAnimator.cancel();}card.dispose();covers.shutdownNow();focusCovers.shutdownNow();main.removeCallbacksAndMessages(null);wallNode.discardDisplayList();visibleCovers.clear();removeCallbacks(frameTick);super.onDetachedFromWindow();}
}
