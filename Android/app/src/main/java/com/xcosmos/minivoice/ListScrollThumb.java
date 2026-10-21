package com.xcosmos.minivoice;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.MotionEvent;
import android.view.View;
import android.widget.AbsListView;
import android.widget.ListView;
import java.util.function.Consumer;

/** A trackless thumb: pointer motion stays continuous instead of snapping to row indices. */
final class ListScrollThumb extends View {
    private final ListView list;
    private final ScrollThumbVisibility visibility;
    private final Consumer<Boolean> scrolling;
    private final Paint ink=new Paint(Paint.ANTI_ALIAS_FLAG);
    private float top,height,grab,dragRowHeight,dragRange,lastOffset;
    private int color;
    private boolean dragging,touchScrolling;
    ListScrollThumb(ListView list,int color,Consumer<Boolean> scrolling){
        super(list.getContext());this.list=list;this.color=color;this.scrolling=scrolling;visibility=new ScrollThumbVisibility(this);
        list.setFastScrollEnabled(false);list.setVerticalScrollBarEnabled(false);
        list.setOnScrollListener(new AbsListView.OnScrollListener(){
            int previousFirst,previousTop,previousCount;boolean observed;
            public void onScroll(AbsListView view,int first,int visible,int total){
                View child=list.getChildAt(0);int top=child==null?0:child.getTop();
                if(observed&&previousCount==total&&(first!=previousFirst||top!=previousTop)&&scrollable())visibility.pulse();
                observed=true;previousFirst=first;previousTop=top;previousCount=total;postInvalidateOnAnimation();
            }
            public void onScrollStateChanged(AbsListView view,int state){
                if(dragging)return;
                if(scrollable())visibility.hold(state!=SCROLL_STATE_IDLE);
                if(state==SCROLL_STATE_TOUCH_SCROLL){touchScrolling=true;scrolling.accept(true);}
                else if(state==SCROLL_STATE_IDLE&&touchScrolling){touchScrolling=false;scrolling.accept(false);}
            }
        });
        setContentDescription("拖动滚动列表");
    }
    void palette(int value){color=value;invalidate();}
    private float dp(float value){return value*getResources().getDisplayMetrics().density;}
    private float rowHeight(){
        int n=list.getChildCount();if(n==0)return 1;
        float total=0;for(int i=0;i<n;i++)total+=list.getChildAt(i).getHeight()+list.getDividerHeight();
        return Math.max(1,total/n);
    }
    private float viewport(){return Math.max(1,list.getHeight()-list.getPaddingTop()-list.getPaddingBottom());}
    private boolean scrollable(){return list.getCount()>0&&(list.canScrollVertically(-1)||list.canScrollVertically(1));}
    private void geometry(){
        if(dragging)return;
        float row=rowHeight(),content=row*list.getCount(),range=Math.max(1,content-viewport());
        height=Math.min(getHeight(),Math.max(dp(36),Math.min(dp(64),getHeight()*viewport()/Math.max(1,content))));
        View first=list.getChildAt(0);
        float offset=list.getFirstVisiblePosition()*row+(first==null?0:list.getPaddingTop()-first.getTop());
        float fraction=Math.max(0,Math.min(1,offset/range));
        if(!list.canScrollVertically(-1))fraction=0;else if(!list.canScrollVertically(1))fraction=1;
        top=(getHeight()-height)*fraction;
    }
    @Override protected void onDraw(Canvas canvas){
        if(!scrollable()&&!dragging)return;geometry();ink.setColor(color);float x=getWidth()/2f;
        canvas.drawRoundRect(x-dp(5),top,x+dp(5),top+height,dp(5),dp(5),ink);
    }
    @Override public boolean onTouchEvent(MotionEvent event){
        int action=event.getActionMasked();
        if(action==MotionEvent.ACTION_DOWN){
            if(!visibility.visible()||!scrollable())return false;
            visibility.hold(true);
            geometry();grab=event.getY()>=top&&event.getY()<=top+height?event.getY()-top:height/2;
            dragRowHeight=rowHeight();dragRange=Math.max(0,list.getCount()*dragRowHeight-viewport());
            lastOffset=top/Math.max(1,getHeight()-height)*dragRange;
            dragging=true;touchScrolling=false;scrolling.accept(true);list.smoothScrollBy(0,0);
            getParent().requestDisallowInterceptTouchEvent(true);
        }
        if(!dragging)return false;
        if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_MOVE){
            top=Math.max(0,Math.min(getHeight()-height,event.getY()-grab));
            float offset=top/Math.max(1,getHeight()-height)*dragRange;
            int delta=Math.round(offset-lastOffset);
            if(top<=0){list.setSelectionFromTop(0,0);lastOffset=offset;}
            else if(top>=getHeight()-height){list.setSelectionFromTop(list.getCount()-1,0);lastOffset=offset;}
            else if(Math.abs(delta)<=viewport()){
                // Normal drags scroll actual pixels, including through wrapped, uneven lyric rows.
                list.scrollListBy(delta);lastOffset+=delta;
            }else{
                // Large jumps still reach distant songs without laying out intervening rows.
                int index=Math.min(list.getCount()-1,(int)(offset/dragRowHeight));
                float fraction=offset/dragRowHeight-index;
                list.setSelectionFromTop(Math.max(0,index),-Math.round(fraction*dragRowHeight));lastOffset=offset;
            }
            postInvalidateOnAnimation();
        }
        if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){finishDrag();}
        return true;
    }
    private void finishDrag(){
        if(!dragging)return;dragging=false;scrolling.accept(false);visibility.hold(false);
        if(getParent()!=null)getParent().requestDisallowInterceptTouchEvent(false);postInvalidateOnAnimation();
    }
    @Override protected void onDetachedFromWindow(){finishDrag();visibility.clear();super.onDetachedFromWindow();}
}
