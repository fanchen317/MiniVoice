package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Typeface;
import android.text.Layout;
import android.view.*;
import android.widget.*;
import java.util.*;
import java.util.function.IntConsumer;

/** Recycled lyric rows. Only the active visible row ticks while playing. */
final class NativeLyricsView extends FrameLayout {
    private final ListView list;private final TextView empty;private final IntConsumer seek;
    private final Runnable edit;private final BaseAdapter adapter;
    private List<Lyrics.Line> lines=Collections.emptyList();private int active=-1,position,duration;
    private boolean playing;private long sampledAt,manualUntil;private AppAppearance.Palette colors=new AppAppearance.Palette(false);
    private final Runnable tick=new Runnable(){public void run(){if(!isShown()||!hasWindowFocus()||!playing)return;refresh();postDelayed(this,80);}};
    NativeLyricsView(Context context,IntConsumer seek,Runnable edit){
        super(context);this.seek=seek;this.edit=edit;
        list=new ListView(context);list.setDivider(null);list.setVerticalScrollBarEnabled(false);list.setClipToPadding(false);list.setPadding(dp(12),dp(32),dp(12),dp(32));list.setCacheColorHint(0);addView(list,new LayoutParams(-1,-1));
        empty=new TextView(context);empty.setGravity(Gravity.CENTER);empty.setTextSize(16);empty.setText("暂无歌词\n点按添加歌词");empty.setOnClickListener(v->edit.run());addView(empty,new LayoutParams(-1,-1));list.setEmptyView(empty);
        adapter=new BaseAdapter(){public int getCount(){return lines.size();}public Object getItem(int i){return lines.get(i);}public long getItemId(int i){return i;}public View getView(int i,View recycled,ViewGroup parent){LyricRow row=recycled instanceof LyricRow?(LyricRow)recycled:new LyricRow(context);row.bind(i);return row;}};
        list.setAdapter(adapter);list.setOnItemClickListener((parent,view,index,id)->{if(lines.get(index).ms>=0){manualUntil=0;seek.accept((int)Math.min(Integer.MAX_VALUE,lines.get(index).ms));}});
        list.setOnItemLongClickListener((parent,view,index,id)->{edit.run();return true;});
        list.setOnScrollListener(new AbsListView.OnScrollListener(){public void onScrollStateChanged(AbsListView view,int state){if(state==SCROLL_STATE_TOUCH_SCROLL||state==SCROLL_STATE_FLING)manualUntil=android.os.SystemClock.uptimeMillis()+4000;}public void onScroll(AbsListView v,int first,int visible,int total){}});
    }
    private int dp(float n){return Math.round(n*getResources().getDisplayMetrics().density);}
    void palette(AppAppearance.Palette value){colors=value;empty.setTextColor(colors.secondary);adapter.notifyDataSetChanged();}
    void status(String value){empty.setText(value+(value.equals("暂无歌词")?"\n点按添加歌词":""));}
    void lyrics(List<Lyrics.Line> value){if(lines==value)return;lines=value;active=-1;adapter.notifyDataSetChanged();refresh();}
    void playback(int value,int total,boolean play){position=value;duration=total;sampledAt=android.os.SystemClock.uptimeMillis();playing=play;refresh();wake();}
    private int clock(){return position+(playing?(int)Math.min(1000,android.os.SystemClock.uptimeMillis()-sampledAt):0);}
    private void refresh(){
        if(lines.isEmpty())return;int time=clock(),next=0;for(int i=0;i<lines.size();i++){if(lines.get(i).ms>time)break;if(lines.get(i).ms>=0)next=i;}
        boolean changed=active!=next;active=next;
        for(int i=0;i<list.getChildCount();i++){View child=list.getChildAt(i);if(child instanceof LyricRow){LyricRow row=(LyricRow)child;if(changed)row.bind(row.index);else if(row.index==active)row.invalidate();}}
        if(changed&&android.os.SystemClock.uptimeMillis()>=manualUntil)list.post(()->{if(active>=0){int top=Math.max(dp(20),list.getHeight()/2-dp(28));if(android.animation.ValueAnimator.areAnimatorsEnabled())list.smoothScrollToPositionFromTop(active,top,300);else list.setSelectionFromTop(active,top);}});
    }
    private void wake(){removeCallbacks(tick);if(playing&&isShown()&&hasWindowFocus())postDelayed(tick,80);}
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused){refresh();wake();}else removeCallbacks(tick);}
    @Override protected void onVisibilityChanged(View view,int visible){super.onVisibilityChanged(view,visible);if(list!=null){if(isShown()){refresh();wake();}else removeCallbacks(tick);}}
    @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){super.onSizeChanged(w,h,oldw,oldh);if(h>0&&h!=oldh)list.post(()->{if(active>=0&&android.os.SystemClock.uptimeMillis()>=manualUntil)list.setSelectionFromTop(active,Math.max(dp(20),list.getHeight()/2-dp(28)));});}
    @Override protected void onDetachedFromWindow(){removeCallbacks(tick);super.onDetachedFromWindow();}
    private final class LyricRow extends TextView {
        int index;
        LyricRow(Context context){super(context);setTextSize(21);setLineSpacing(dp(3),1);setPadding(dp(12),dp(14),dp(12),dp(14));setIncludeFontPadding(false);}
        void bind(int value){index=value;String valueText=lines.get(value).text;if(!valueText.contentEquals(getText()))setText(valueText.isEmpty()?"•••":valueText);setTypeface(null,index==active?Typeface.BOLD:Typeface.NORMAL);setTextColor(colors.secondary);setAlpha(index==active?1:.7f);invalidate();}
        @Override protected void onDraw(Canvas canvas){
            super.onDraw(canvas);if(index!=active||index>=lines.size())return;Layout layout=getLayout();if(layout==null)return;
            Lyrics.Line line=lines.get(index);long next=index+1<lines.size()?lines.get(index+1).ms:duration;
            float chars=LyricSweep.characters(line,next,duration,clock());int whole=Math.min(line.text.length(),(int)chars);float fraction=chars-whole;
            int original=getCurrentTextColor();getPaint().setColor(colors.text);
            int save=canvas.save();canvas.translate(getCompoundPaddingLeft(),getExtendedPaddingTop());
            for(int row=0;row<layout.getLineCount();row++){int start=layout.getLineStart(row),end=layout.getLineEnd(row);if(chars<=start)break;int caret=Math.min(end,whole);float x=layout.getPrimaryHorizontal(caret);if(fraction>0&&caret<end)x+=(layout.getPrimaryHorizontal(caret+1)-x)*fraction;int clip=canvas.save();canvas.clipRect(layout.getLineLeft(row),layout.getLineTop(row),chars>=end?layout.getLineRight(row):x,layout.getLineBottom(row));layout.draw(canvas);canvas.restoreToCount(clip);}
            canvas.restoreToCount(save);getPaint().setColor(original);
        }
    }
}
