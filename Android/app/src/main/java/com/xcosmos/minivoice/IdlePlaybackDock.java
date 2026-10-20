package com.xcosmos.minivoice;

import android.animation.*;
import android.content.Context;
import android.graphics.*;
import android.view.*;
import android.widget.*;
import java.util.function.Consumer;

/** Idle capsule morphs into a corner button. Only an explicit tap expands it again. */
final class IdlePlaybackDock extends FrameLayout {
    private final View content;
    private final Meter meter;
    private final Consumer<Float> progress;
    private final float density;
    private ValueAnimator motion;
    private float amount=1;
    private int expandedWidth;
    private boolean eligible,touching,compact,idlePaused;
    private final Runnable idle=()->{if(eligible&&!idlePaused&&!touching&&hasWindowFocus())setCompact(true,true);};
    IdlePlaybackDock(Context context,View content,Consumer<Float> progress){
        super(context);this.content=content;this.progress=progress;density=getResources().getDisplayMetrics().density;
        setClipChildren(true);setClipToPadding(true);addView(content,new LayoutParams(-1,dp(84),Gravity.LEFT|Gravity.CENTER_VERTICAL));
        meter=new Meter(context);meter.setContentDescription("展开播放条");meter.setOnClickListener(v->setCompact(false,true));ButtonFeedback.install(meter);addView(meter,new LayoutParams(dp(56),dp(56),Gravity.LEFT|Gravity.CENTER_VERTICAL));meter.setVisibility(INVISIBLE);
    }
    private int dp(float value){return Math.round(value*density);}
    void configure(int width,boolean allowed){expandedWidth=Math.max(dp(56),width);eligible=allowed;if(!allowed){removeCallbacks(idle);setCompact(false,false);}else{apply(amount);schedule();}}
    void setPlaying(boolean playing){if(meter.playing==playing)return;meter.playing=playing;meter.invalidate();}
    void setIdlePaused(boolean paused){idlePaused=paused;removeCallbacks(idle);if(!paused)schedule();}
    void interaction(boolean down){touching=down;removeCallbacks(idle);if(!down)schedule();}
    private void schedule(){removeCallbacks(idle);if(eligible&&!idlePaused&&!compact&&!touching&&isShown()&&hasWindowFocus())postDelayed(idle,3000);}
    private void setCompact(boolean value,boolean animated){
        compact=value;removeCallbacks(idle);if(motion!=null){motion.removeAllListeners();motion.cancel();motion=null;}setScaleX(1);setScaleY(1);
        float target=value?0:1;if(!animated||Math.abs(target-amount)<.001f){apply(target);if(!value)schedule();return;}
        float start=amount;boolean grow=!value&&start<.01f;
        motion=ValueAnimator.ofFloat(0,1);motion.setDuration(value?440:600);
        motion.addUpdateListener(a->{float t=(float)a.getAnimatedValue();float travel=grow?Math.max(0,(t-.3f)/.7f):t;float eased=1-(float)Math.pow(1-travel,3);apply(start+(target-start)*eased);float pulse=grow?(t<.3f?t/.3f:Math.max(0,1-(t-.3f)/.7f)):0;setPivotX(dp(28));setPivotY(getHeight()/2f);setScaleX(1+.1f*pulse);setScaleY(1+.1f*pulse);});
        motion.addListener(new AnimatorListenerAdapter(){@Override public void onAnimationEnd(Animator a){if(a!=motion)return;motion=null;apply(target);setScaleX(1);setScaleY(1);if(!compact)schedule();}});motion.start();
    }
    private void apply(float value){
        amount=value;if(expandedWidth==0)return;
        android.view.ViewGroup.LayoutParams params=getLayoutParams();int width=Math.round(dp(56)+(expandedWidth-dp(56))*amount),height=Math.round(dp(56)+dp(28)*amount);
        if(params!=null&&(params.width!=width||params.height!=height)){params.width=width;params.height=height;setLayoutParams(params);}
        LayoutParams inner=(LayoutParams)content.getLayoutParams();if(inner.width!=expandedWidth){inner.width=expandedWidth;content.setLayoutParams(inner);}
        content.setAlpha(Math.max(0,(amount-.35f)/.65f));content.setVisibility(amount>.35f?VISIBLE:INVISIBLE);content.setImportantForAccessibility(amount>.99f?IMPORTANT_FOR_ACCESSIBILITY_AUTO:IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        meter.setAlpha(Math.max(0,1-amount*2));meter.setVisibility(amount<.5f?VISIBLE:INVISIBLE);meter.setEnabled(compact&&amount<.01f);progress.accept(amount);
    }
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused){schedule();meter.invalidate();}else removeCallbacks(idle);}
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();apply(compact?0:1);schedule();}
    @Override protected void onDetachedFromWindow(){removeCallbacks(idle);if(motion!=null){motion.removeAllListeners();motion.cancel();motion=null;}super.onDetachedFromWindow();}
    private final class Meter extends View {
        boolean playing;final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
        Meter(Context context){super(context);setFocusable(true);}
        @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);paint.setColor(Color.WHITE);paint.setStyle(Paint.Style.FILL);float x=getWidth()/2f,y=getHeight()/2f;
            if(playing){for(int i=0;i<3;i++){float height=dp(22)*PlaybackBars.height(i,android.os.SystemClock.uptimeMillis(),true);float left=x+dp((i-1)*7)-dp(2);canvas.drawRoundRect(left,y-height/2,left+dp(4),y+height/2,dp(1.5f),dp(1.5f),paint);}if(hasWindowFocus())postInvalidateDelayed(50);}
            else{Path triangle=new Path();triangle.moveTo(x-dp(6),y-dp(10));triangle.lineTo(x+dp(10),y);triangle.lineTo(x-dp(6),y+dp(10));triangle.close();canvas.drawPath(triangle,paint);}
        }
    }
}
