package com.xcosmos.minivoice;

import android.animation.*;
import android.app.Activity;
import android.graphics.*;
import android.os.Handler;
import android.os.Looper;
import android.view.*;
import android.view.animation.LinearInterpolator;

/** One bounded snapshot; fragments reference it instead of allocating individual bitmaps. */
final class PlayerStyleTransition {
    private final Activity activity;
    private final ViewGroup root;
    private final Handler main=new Handler(Looper.getMainLooper());
    private boolean busy;
    private int generation;
    private Runnable queued;
    private Runnable finished=()->{};
    void setFinished(Runnable action){finished=action;}
    private Sweep sweep;
    PlayerStyleTransition(Activity activity,ViewGroup root){
        this.activity=activity;this.root=root;
        root.addOnAttachStateChangeListener(new View.OnAttachStateChangeListener(){
            public void onViewAttachedToWindow(View view){}
            public void onViewDetachedFromWindow(View view){cancel();}
        });
        root.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{if(r-l!=or-ol||b-t!=ob-ot)cancel();});
    }
    boolean isRunning(){return busy;}
    void run(View icon,Runnable change){
        if(busy){queued=queued==null?()->run(icon,change):null;return;}
        int width=root.getWidth(),height=root.getHeight();
        if(!ValueAnimator.areAnimatorsEnabled()||!root.isAttachedToWindow()||width<=0||height<=0){change.run();return;}
        busy=true;int token=++generation;
        int[] location=new int[2],iconLocation=new int[2];root.getLocationInWindow(location);icon.getLocationInWindow(iconLocation);
        float originX=iconLocation[0]-location[0]+icon.getWidth()/2f,originY=iconLocation[1]-location[1]+icon.getHeight()/2f;
        float resolution=Math.min(1,1000f/Math.max(width,height));
        final Bitmap snapshot;
        try{snapshot=Bitmap.createBitmap(Math.max(1,Math.round(width*resolution)),Math.max(1,Math.round(height*resolution)),Bitmap.Config.ARGB_8888);}
        catch(OutOfMemoryError failure){busy=false;change.run();return;}
        // PixelCopy preserves hardware-rendered music wall and glass surfaces.
        Runnable timeout=()->{if(token==generation&&busy&&sweep==null){generation++;busy=false;change.run();drain();}};
        main.postDelayed(timeout,350);
        try{
            PixelCopy.request(activity.getWindow(),new Rect(location[0],location[1],location[0]+width,location[1]+height),snapshot,result->{
                main.removeCallbacks(timeout);
                if(token!=generation){snapshot.recycle();return;}
                if(result!=PixelCopy.SUCCESS){snapshot.recycle();busy=false;change.run();drain();return;}
                sweep=new Sweep(snapshot,width,height,originX,originY);
                root.getOverlay().add(sweep);sweep.layout(0,0,width,height);
                change.run();sweep.start();
            },main);
        }catch(IllegalArgumentException failure){main.removeCallbacks(timeout);snapshot.recycle();busy=false;change.run();drain();}
    }
    void cancel(){boolean interrupted=busy;generation++;queued=null;busy=false;if(sweep!=null){Sweep old=sweep;sweep=null;old.dispose();}if(interrupted&&root.isAttachedToWindow())root.post(finished);}
    private void drain(){finished.run();Runnable next=queued;queued=null;if(next!=null)root.postOnAnimation(next);}
    private final class Sweep extends View {
        private final Bitmap bitmap;
        private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
        private final Rect source=new Rect();
        private final RectF target=new RectF();
        private final float width,height,originX,originY,density;
        private final int columns,rows;
        private ValueAnimator animator;
        private float elapsed;
        Sweep(Bitmap bitmap,int width,int height,float originX,float originY){
            super(activity);this.bitmap=bitmap;this.width=width;this.height=height;this.originX=originX;this.originY=originY;
            density=getResources().getDisplayMetrics().density;columns=StyleFragmentMotion.columns(width/density);rows=StyleFragmentMotion.rows(height/density);
            setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);setClickable(false);setFocusable(false);
        }
        void start(){
            animator=ValueAnimator.ofFloat(0,StyleFragmentMotion.DURATION);animator.setDuration(StyleFragmentMotion.DURATION);animator.setInterpolator(new LinearInterpolator());
            animator.addUpdateListener(a->{elapsed=(float)a.getAnimatedValue();invalidate();});
            animator.addListener(new AnimatorListenerAdapter(){@Override public void onAnimationEnd(Animator animation){if(sweep==Sweep.this){sweep=null;busy=false;dispose();drain();}}});animator.start();
        }
        void dispose(){if(animator!=null){animator.removeAllListeners();animator.cancel();}root.getOverlay().remove(this);bitmap.recycle();}
        @Override protected void onDraw(Canvas canvas){
            for(int row=0;row<rows;row++)for(int column=0;column<columns;column++){
                int index=row*columns+column;
                float left=column*width/columns,top=row*height/rows,right=(column+1)*width/columns,bottom=(row+1)*height/rows;
                float x=(left+right)/2,y=(top+bottom)/2,p=StyleFragmentMotion.progress(elapsed,x,y,originX,originY,width,height);
                if(p>=1)continue;
                float eased=StyleFragmentMotion.eased(p),angle=(float)Math.atan2(y-originY,x-originX),curl=(float)Math.sin(p*Math.PI)*(index%7-3)*6*density,distance=eased*140*density;
                int save=canvas.save();canvas.translate(x+(float)Math.cos(angle)*distance-(float)Math.sin(angle)*curl,y+(float)Math.sin(angle)*distance+(float)Math.cos(angle)*curl);
                canvas.rotate((index%9-4)*eased*8);float scale=1-eased*.65f;canvas.scale(scale,scale);paint.setAlpha(Math.round(255*(1-eased)));
                source.set(Math.round(column*bitmap.getWidth()/(float)columns),Math.round(row*bitmap.getHeight()/(float)rows),Math.round((column+1)*bitmap.getWidth()/(float)columns),Math.round((row+1)*bitmap.getHeight()/(float)rows));
                target.set(-(right-left)/2,-(bottom-top)/2,(right-left)/2,(bottom-top)/2);canvas.drawBitmap(bitmap,source,target,paint);canvas.restoreToCount(save);
            }
        }
    }
}
