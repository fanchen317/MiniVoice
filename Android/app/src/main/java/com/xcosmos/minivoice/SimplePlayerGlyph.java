package com.xcosmos.minivoice;

import android.graphics.*;
import android.graphics.drawable.Drawable;

/** Small native vector glyphs for the frosted player controls. */
final class SimplePlayerGlyph extends Drawable {
    static final int VOLUME=0,OUTPUT=1,LYRICS=2;
    private final int kind,side;private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    SimplePlayerGlyph(int kind,int color,float density){this.kind=kind;side=Math.round(24*density);paint.setColor(color);paint.setStrokeWidth(1.7f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);}
    @Override public void draw(Canvas canvas){Rect b=getBounds();int saved=canvas.save();canvas.translate(b.exactCenterX(),b.exactCenterY());canvas.scale(b.width()/24f,b.height()/24f);paint.setStyle(Paint.Style.STROKE);
        if(kind==VOLUME){Path speaker=new Path();speaker.moveTo(-9,-3);speaker.lineTo(-5,-3);speaker.lineTo(0,-7);speaker.lineTo(0,7);speaker.lineTo(-5,3);speaker.lineTo(-9,3);speaker.close();paint.setStyle(Paint.Style.FILL);canvas.drawPath(speaker,paint);paint.setStyle(Paint.Style.STROKE);canvas.drawArc(-4,-7,10,7,-55,110,false,paint);canvas.drawArc(-7,-10,15,10,-55,110,false,paint);}
        else if(kind==OUTPUT){canvas.drawArc(-9,-10,9,8,35,290,false,paint);canvas.drawArc(-5,-6,5,4,35,290,false,paint);Path triangle=new Path();triangle.moveTo(0,2);triangle.lineTo(-5,10);triangle.lineTo(5,10);triangle.close();canvas.drawPath(triangle,paint);}
        else{Path bubble=new Path();bubble.moveTo(-7,-9);bubble.lineTo(7,-9);bubble.quadTo(10,-9,10,-6);bubble.lineTo(10,4);bubble.quadTo(10,7,7,7);bubble.lineTo(-1,7);bubble.lineTo(-6,11);bubble.lineTo(-6,7);bubble.lineTo(-7,7);bubble.quadTo(-10,7,-10,4);bubble.lineTo(-10,-6);bubble.quadTo(-10,-9,-7,-9);canvas.drawPath(bubble,paint);canvas.drawLine(-5,-3,5,-3,paint);canvas.drawLine(-5,2,2,2,paint);}
        canvas.restoreToCount(saved);
    }
    @Override public int getIntrinsicWidth(){return side;}@Override public int getIntrinsicHeight(){return side;}
    @Override public void setAlpha(int alpha){paint.setAlpha(alpha);invalidateSelf();}@Override public void setColorFilter(ColorFilter filter){paint.setColorFilter(filter);invalidateSelf();}@Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}
}
