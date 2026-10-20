package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.*;
import android.view.View;

/** Actual bars, never font glyphs (some Android fonts render block characters vertically). */
final class SidebarPlaybackIndicator extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);private boolean playing;
    SidebarPlaybackIndicator(Context context){super(context);setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);}
    void state(boolean active,boolean playing,int color,boolean selecting){this.playing=active&&playing;paint.setColor(color);setVisibility(selecting?GONE:active?VISIBLE:INVISIBLE);setContentDescription(active?(playing?"正在播放":"已暂停"):null);invalidate();}
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);float d=getResources().getDisplayMetrics().density,width=3*d,gap=2*d,left=(getWidth()-(width*5+gap*4))/2,bottom=getHeight()/2f+12*d;long time=android.os.SystemClock.uptimeMillis();for(int i=0;i<5;i++){float height=24*d*PlaybackBars.height(i,time,playing);canvas.drawRoundRect(left+i*(width+gap),bottom-height,left+i*(width+gap)+width,bottom,1.5f*d,1.5f*d,paint);}if(playing&&isShown()&&hasWindowFocus())postInvalidateDelayed(50);}
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused)invalidate();}
}
