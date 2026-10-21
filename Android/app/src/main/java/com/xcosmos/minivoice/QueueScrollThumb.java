package com.xcosmos.minivoice;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.view.MotionEvent;
import android.view.View;
import android.widget.ScrollView;

/** Queue thumb stays within the visible portion of the translated bottom sheet. */
final class QueueScrollThumb extends View {
    private final ScrollView scroll;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Rect visible=new Rect();
    private float top,height,grab,track;
    private boolean dragging;
    QueueScrollThumb(ScrollView scroll){super(scroll.getContext());this.scroll=scroll;paint.setColor(0xFF51D5AA);setContentDescription("拖动滚动播放队列");scroll.setOnScrollChangeListener((v,x,y,oldX,oldY)->postInvalidateOnAnimation());}
    private float dp(float value){return value*getResources().getDisplayMetrics().density;}
    private int range(){return scroll.getChildCount()==0?0:Math.max(0,scroll.getChildAt(0).getHeight()-scroll.getHeight()+scroll.getPaddingTop()+scroll.getPaddingBottom());}
    private void geometry(){getGlobalVisibleRect(visible);track=Math.max(0,Math.min(getHeight(),visible.height())-dp(24));height=Math.min(track,Math.max(dp(36),Math.min(dp(64),track*scroll.getHeight()/Math.max(1f,scroll.getHeight()+range()))));if(!dragging)top=dp(12)+(track-height)*scroll.getScrollY()/Math.max(1f,range());}
    @Override protected void onDraw(Canvas canvas){if(range()==0)return;geometry();float x=getWidth()/2f;canvas.drawRoundRect(x-dp(5),top,x+dp(5),top+height,dp(5),dp(5),paint);}
    @Override public boolean onTouchEvent(MotionEvent e){
        int action=e.getActionMasked();if(action==MotionEvent.ACTION_DOWN){if(range()==0)return false;geometry();grab=e.getY()>=top&&e.getY()<=top+height?e.getY()-top:height/2;dragging=true;scroll.fling(0);getParent().requestDisallowInterceptTouchEvent(true);}
        if(!dragging)return false;
        if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_MOVE){top=Math.max(dp(12),Math.min(dp(12)+track-height,e.getY()-grab));scroll.scrollTo(0,Math.round((top-dp(12))/Math.max(1,track-height)*range()));postInvalidateOnAnimation();}
        if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){dragging=false;getParent().requestDisallowInterceptTouchEvent(false);invalidate();}return true;
    }
}
