package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.drawable.RippleDrawable;
import android.view.View;

/** Transport glyphs sized for touch rather than the desktop icon canvas. */
final class TransportButton extends View {
    enum Glyph { PREVIOUS, NEXT, QUEUE, PLAY_PAUSE }
    private final Glyph glyph;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float density;
    private boolean playing;
    TransportButton(Context context,Glyph glyph,Runnable action){super(context);this.glyph=glyph;density=getResources().getDisplayMetrics().density;
        setClickable(true);setOnClickListener(view->action.run());setBackground(new RippleDrawable(ColorStateList.valueOf(0x55FFFFFF),null,null));
        ButtonFeedback.install(this);
        setContentDescription(glyph==Glyph.PREVIOUS?"上一首":glyph==Glyph.NEXT?"下一首":glyph==Glyph.QUEUE?"播放队列":"播放");
    }
    void setPlaying(boolean value){if(playing==value)return;playing=value;setContentDescription(value?"暂停":"播放");invalidate();}
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);float cx=getWidth()/2f,cy=getHeight()/2f;
        paint.setColor(glyph==Glyph.PLAY_PAUSE?0xFF202522:Color.WHITE);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);
        if(glyph==Glyph.PLAY_PAUSE){paint.setStyle(Paint.Style.FILL);
            if(playing){canvas.drawRoundRect(cx-10*density,cy-13*density,cx-3*density,cy+13*density,2*density,2*density,paint);
                canvas.drawRoundRect(cx+3*density,cy-13*density,cx+10*density,cy+13*density,2*density,2*density,paint);}
            else {Path play=new Path();play.moveTo(cx-8*density,cy-13*density);play.lineTo(cx+14*density,cy);play.lineTo(cx-8*density,cy+13*density);play.close();canvas.drawPath(play,paint);}return;}
        if(glyph==Glyph.QUEUE){
            paint.setStyle(Paint.Style.FILL);
            for(int i=-1;i<=1;i++){float y=cy+i*8*density;canvas.drawCircle(cx-11*density,y,1.8f*density,paint);
                paint.setStrokeWidth(2.8f*density);canvas.drawRoundRect(cx-5*density,y-1.4f*density,cx+13*density,y+1.4f*density,1.4f*density,1.4f*density,paint);}
            return;
        }
        float direction=glyph==Glyph.PREVIOUS?-1:1;
        paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(2.8f*density);
        Path chevron=new Path();chevron.moveTo(cx-direction*4*density,cy-9*density);chevron.lineTo(cx+direction*5*density,cy);chevron.lineTo(cx-direction*4*density,cy+9*density);canvas.drawPath(chevron,paint);
    }
}
