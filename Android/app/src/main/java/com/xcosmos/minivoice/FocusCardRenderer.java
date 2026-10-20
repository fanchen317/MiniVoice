package com.xcosmos.minivoice;

import android.graphics.*;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Focused player: title above lyrics, compact transport below, without a split shade. */
final class FocusCardRenderer {
    interface Actions { void previous();void toggle();void next();void favorite();void expand();void seek(int ms);void play(); }
    private static final class Button {final RectF bounds;final Runnable action;Button(RectF bounds,Runnable action){this.bounds=bounds;this.action=action;}}
    private final float d;
    private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final TextPaint text=new TextPaint(Paint.ANTI_ALIAS_FLAG);
    private final List<Button> buttons=new ArrayList<>();
    private final List<Button> lyrics=new ArrayList<>();
    private RectF track;
    private int duration,scrub=-1;
    private Button pressed;
    private boolean scrubbing;
    private Actions actions;
    private final Runnable invalidate;
    private List<Lyrics.Line> lastLines;private int lastActive=-1;private float lastHeight,lyricOffset;private long lyricMotionAt;
    private android.animation.ValueAnimator feedback;
    private RectF feedbackBounds;
    private float feedbackAmount;
    private void animateFeedback(float target){
        if(feedback!=null)feedback.cancel();feedback=android.animation.ValueAnimator.ofFloat(feedbackAmount,target);feedback.setDuration(target>0?80:220);
        feedback.setInterpolator(target>0?new android.view.animation.DecelerateInterpolator():new android.view.animation.OvershootInterpolator(1.2f));
        feedback.addUpdateListener(animation->{feedbackAmount=(float)animation.getAnimatedValue();invalidate.run();});feedback.start();
    }
    void dispose(){if(feedback!=null)feedback.cancel();}

    FocusCardRenderer(float density,Runnable invalidate){d=density;this.invalidate=invalidate;p.setStrokeCap(Paint.Cap.ROUND);p.setStrokeJoin(Paint.Join.ROUND);}
    void clear(){buttons.clear();lyrics.clear();track=null;}
    void draw(Canvas canvas,RectF rect,Song song,boolean current,boolean playing,int position,int playbackDuration,List<Lyrics.Line> lines,String lyricStatus,boolean favorite,boolean expanded,float wallScale,Actions actions){
        clear();this.actions=actions;duration=Math.max(0,playbackDuration>0?playbackDuration:(int)Math.min(Integer.MAX_VALUE,song.duration));
        FocusCardMetrics m=new FocusCardMetrics(rect.width(),rect.height(),d);float left=rect.left+m.padding,right=rect.right-m.padding;
        float top=rect.top+m.padding;float statusD=d*m.contentScale;boolean compact=FocusCardPresentation.compact(wallScale,expanded);
        if(current){
            p.setColor(0x882C706A);p.setStyle(Paint.Style.FILL);RectF badge=new RectF(left,top,left+106*statusD,top+m.badge);canvas.drawRoundRect(badge,13*statusD,13*statusD,p);
            p.setColor(0xAA47DCC9);p.setStrokeWidth(statusD);p.setStyle(Paint.Style.STROKE);canvas.drawRoundRect(badge,13*statusD,13*statusD,p);p.setStyle(Paint.Style.FILL);
            p.setColor(0xFF4CDBC7);for(int i=0;i<3;i++){float h=(playing?new float[]{6,12,9}[i]:6)*statusD;canvas.drawRoundRect(left+(10+i*5)*statusD,top+(m.badge-h)/2,left+(13+i*5)*statusD,top+(m.badge+h)/2,statusD,statusD,p);}
            label(canvas,playing?"正在播放":"已暂停",left+32*statusD,top+17*statusD,11*statusD,0xFF4CDBC7,false,72*statusD);
            top+=m.badge+12*statusD;
        }
        label(canvas,song.title,left,top+m.title,m.title,Color.WHITE,true,right-left);
        label(canvas,song.artist,left,top+m.title+8*d+m.artist,m.artist,0xBFFFFFFF,false,right-left);
        if(compact){
            button(canvas,new RectF(right-44*d,rect.bottom-m.padding-44*d,right,rect.bottom-m.padding),"expand",false,actions::expand);
            return;
        }
        if(current){
            drawLyrics(canvas,new RectF(left,rect.top+m.lyricsTop,right,rect.top+m.lyricsBottom),lines,position,lyricStatus);
            String[] icons={"previous",playing?"pause":"play","next",favorite?"heartFill":"heart",expanded?"collapse":"expand"};
            Runnable[] commands={actions::previous,actions::toggle,actions::next,actions::favorite,actions::expand};
            for(int i=0;i<5;i++){float x=rect.left+m.buttonLeft(i,rect.width());RectF hit=new RectF(x,rect.top+m.controlsTop,x+m.button,rect.top+m.controlsTop+m.button);
                button(canvas,hit,icons[i],i==3&&favorite,commands[i]);}
            int display=scrub>=0?scrub:position;
            String clock=time(display)+" / "+time(duration);text.setTypeface(Typeface.MONOSPACE);text.setTextSize(10*d);text.setColor(0xBFFFFFFF);
            canvas.drawText(clock,right-text.measureText(clock),rect.top+m.timeY,text);
            float y=rect.top+m.trackY;p.setColor(0x66FFFFFF);p.setStrokeWidth(2*d);canvas.drawLine(left,y,right,y,p);
            float fraction=duration<=0?0:Math.max(0,Math.min(1,display/(float)duration));float x=left+(right-left)*fraction;
            p.setColor(Color.WHITE);canvas.drawLine(left,y,x,y,p);p.setStyle(Paint.Style.FILL);canvas.drawCircle(x,y,(scrubbing?5.5f:3.5f)*d,p);
            track=duration>0?new RectF(left,y-18*d,right,y+18*d):null;
        }else{
            RectF hit=new RectF(left,rect.bottom-m.padding-44*d,left+44*d,rect.bottom-m.padding);
            button(canvas,hit,"play",false,actions::play);
            if(expanded)button(canvas,new RectF(right-44*d,rect.bottom-m.padding-44*d,right,rect.bottom-m.padding),"collapse",false,actions::expand);
        }
    }
    private void label(Canvas c,String value,float x,float baseline,float size,int color,boolean bold,float width){
        text.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);text.setTextSize(size);text.setColor(color);
        c.drawText(android.text.TextUtils.ellipsize(value,text,Math.max(1,width),android.text.TextUtils.TruncateAt.END).toString(),x,baseline,text);
    }
    private void drawLyrics(Canvas c,RectF area,List<Lyrics.Line> lines,int position,String status){
        if(area.height()<30*d)return;
        if(lines.isEmpty()){label(c,status,area.left,area.centerY(),15*d,0x99FFFFFF,false,area.width());return;}
        int active=0;for(int i=0;i<lines.size();i++){if(lines.get(i).ms<0)continue;if(lines.get(i).ms>position)break;active=i;}
        int first=Math.max(0,active-3),last=Math.min(lines.size()-1,active+3);List<StaticLayout> layouts=new ArrayList<>();
        for(int i=first;i<=last;i++){
            TextPaint ink=new TextPaint(Paint.ANTI_ALIAS_FLAG);ink.setTypeface(Typeface.DEFAULT_BOLD);ink.setTextSize(Math.min(21*d,area.width()*.063f));
            ink.setColor(i==active?0x66FFFFFF:Math.abs(i-active)==1?0x88FFFFFF:0x50FFFFFF);
            layouts.add(StaticLayout.Builder.obtain(lines.get(i).text,0,lines.get(i).text.length(),ink,Math.max(1,(int)area.width())).setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).setLineSpacing(2*d,1).build());
        }
        StaticLayout selected=layouts.get(active-first);
        long now=android.os.SystemClock.uptimeMillis();
        if(lastLines!=lines){lastLines=lines;lastActive=active;lyricOffset=0;}
        else if(lastActive!=active){lyricOffset=Math.abs(active-lastActive)==1?(active>lastActive?1:-1)*(lastHeight/2f+selected.getHeight()/2f+18*d):0;lyricMotionAt=now;lastActive=active;}
        lastHeight=selected.getHeight();float motion=Math.min(1,(now-lyricMotionAt)/420f);float offset=lyricOffset*(float)Math.pow(1-motion,3);
        if(Math.abs(offset)>.2f)invalidate.run();float y=area.centerY()-selected.getHeight()/2f+offset;
        for(int i=active-first-1;i>=0;i--)y-=layouts.get(i).getHeight()+18*d;
        int save=c.save();c.clipRect(area);
        for(int i=0;i<layouts.size();i++){StaticLayout layout=layouts.get(i);float bottom=y+layout.getHeight();
            if(bottom>area.top&&y<area.bottom){int lineIndex=first+i;int saveLine=c.save();c.translate(area.left,y);layout.draw(c);
                if(lineIndex==active){Lyrics.Line source=lines.get(lineIndex);long next=lineIndex+1<lines.size()?lines.get(lineIndex+1).ms:duration;
                    float chars=LyricSweep.characters(source,next,duration,position);int whole=Math.min(source.text.length(),(int)chars);float amount=chars-whole;
                    layout.getPaint().setColor(Color.WHITE);
                    for(int row=0;row<layout.getLineCount();row++){int start=layout.getLineStart(row),end=layout.getLineEnd(row);if(chars<=start)break;
                        int offset=Math.min(end,whole);float x=layout.getPrimaryHorizontal(offset);if(amount>0&&offset<end)x+=(layout.getPrimaryHorizontal(offset+1)-x)*amount;
                        int inkSave=c.save();c.clipRect(layout.getLineLeft(row),layout.getLineTop(row),chars>=end?layout.getLineRight(row):x,layout.getLineBottom(row));layout.draw(c);c.restoreToCount(inkSave);
                    }
                }c.restoreToCount(saveLine);
                if(lines.get(lineIndex).ms>=0)lyrics.add(new Button(new RectF(area.left,Math.max(y-6*d,area.top),area.right,Math.min(bottom+6*d,area.bottom)),()->actions.seek((int)Math.min(Integer.MAX_VALUE,lines.get(lineIndex).ms))));}
            y=bottom+18*d;
        }
        c.restoreToCount(save);
    }
    private void button(Canvas c,RectF hit,String icon,boolean active,Runnable action){
        float amount=feedbackBounds!=null&&feedbackBounds.equals(hit)?feedbackAmount:0;
        if(amount>0){p.setColor(((int)(64*Math.min(1,amount))<<24)|0xFFFFFF);p.setStyle(Paint.Style.FILL);c.drawRoundRect(hit,9*d,9*d,p);}
        buttons.add(new Button(hit,action));int save=c.save();c.translate(hit.centerX(),hit.centerY());float iconScale=d*(1-.14f*amount);c.scale(iconScale,iconScale);
        p.setColor(active?0xFF4CDBC7:Color.WHITE);p.setStrokeWidth(1.8f);p.setStyle(Paint.Style.STROKE);
        Path path=new Path();
        switch(icon){
            case "previous":case "next":{float direction=icon.equals("next")?1:-1;c.drawLine(direction*7,-7,direction*7,7,p);path.moveTo(direction*4,0);path.lineTo(-direction*6,-7);path.lineTo(-direction*6,7);path.close();c.drawPath(path,p);break;}
            case "play":p.setStyle(Paint.Style.FILL);path.moveTo(-5,-8);path.lineTo(8,0);path.lineTo(-5,8);path.close();c.drawPath(path,p);break;
            case "pause":p.setStyle(Paint.Style.FILL);c.drawRoundRect(-6,-8,-2,8,1,1,p);c.drawRoundRect(2,-8,6,8,1,1,p);break;
            case "heart":case "heartFill":path.moveTo(0,8);path.cubicTo(-17,-2,-6,-14,0,-6);path.cubicTo(6,-14,17,-2,0,8);if(icon.equals("heartFill"))p.setStyle(Paint.Style.FILL);c.drawPath(path,p);break;
            case "expand":case "collapse":{float a=icon.equals("expand")?8:2,b=icon.equals("expand")?2:8;path.moveTo(-a,-b);path.lineTo(-a,-a);path.lineTo(-b,-a);path.moveTo(-a,-a);path.lineTo(-1,-1);path.moveTo(a,b);path.lineTo(a,a);path.lineTo(b,a);path.moveTo(a,a);path.lineTo(1,1);c.drawPath(path,p);break;}
        }
        p.setStyle(Paint.Style.FILL);c.restoreToCount(save);
    }
    boolean down(float x,float y){
        if(track!=null&&track.contains(x,y)){scrubbing=true;move(x);return true;}
        for(Button b:buttons)if(b.bounds.contains(x,y)){pressed=b;feedbackBounds=new RectF(b.bounds);animateFeedback(1);return true;}return false;
    }
    boolean move(float x){if(!scrubbing)return pressed!=null;float fraction=Math.max(0,Math.min(1,(x-track.left)/track.width()));scrub=(int)(duration*fraction);return true;}
    boolean up(float x,float y,boolean cancel){
        if(scrubbing){int target=scrub;scrubbing=false;scrub=-1;if(!cancel)actions.seek(target);return true;}
        Button button=pressed;pressed=null;if(button==null)return false;animateFeedback(0);if(!cancel&&button.bounds.contains(x,y))button.action.run();return true;
    }
    boolean seekLyric(float x,float y){for(Button b:lyrics)if(b.bounds.contains(x,y)){b.action.run();return true;}return false;}
    private static String time(int ms){return String.format(Locale.ROOT,"%02d:%02d",Math.max(0,ms)/60000,Math.max(0,ms)/1000%60);}
}
