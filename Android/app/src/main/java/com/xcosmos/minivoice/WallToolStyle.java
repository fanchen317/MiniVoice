package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.*;
import android.graphics.drawable.*;

final class WallToolStyle {
    static final int SIDE=56,ICON=24;
    static GradientDrawable glass(Context context){float d=context.getResources().getDisplayMetrics().density;GradientDrawable shape=new GradientDrawable();shape.setColor(0xCC292D2B);shape.setCornerRadius(SIDE*d/2);shape.setStroke(Math.max(1,Math.round(d)),0x66FFFFFF);return shape;}
    static RippleDrawable background(Context context){GradientDrawable mask=new GradientDrawable();mask.setShape(GradientDrawable.OVAL);mask.setColor(Color.WHITE);return new RippleDrawable(ColorStateList.valueOf(0x44FFFFFF),glass(context),mask);}
    static final class Glyph extends Drawable {
        static final int SIDEBAR=0,SEARCH=1,SETTINGS=2;
        private final int kind;private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
        Glyph(int kind){this.kind=kind;paint.setColor(Color.WHITE);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(1.8f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);}
        @Override public void draw(Canvas canvas){Rect bounds=getBounds();int save=canvas.save();canvas.translate(bounds.exactCenterX(),bounds.exactCenterY());canvas.scale(bounds.width()/24f,bounds.height()/24f);
            if(kind==SEARCH){canvas.drawCircle(-2,-2,7,paint);canvas.drawLine(3.2f,3.2f,10,10,paint);}
            else if(kind==SIDEBAR){canvas.drawRoundRect(-10,-9,10,9,2,2,paint);canvas.drawLine(-4,-8,-4,8,paint);for(int i=-1;i<=1;i++)canvas.drawLine(-8,i*4,-6,i*4,paint);}
            else for(int i=-1;i<=1;i++){float y=i*7,x=i==0?-5:i<0?5:3;canvas.drawLine(-10,y,x-3,y,paint);canvas.drawLine(x+3,y,10,y,paint);canvas.drawCircle(x,y,2.6f,paint);}
            canvas.restoreToCount(save);
        }
        @Override public void setAlpha(int alpha){paint.setAlpha(alpha);invalidateSelf();}
        @Override public void setColorFilter(ColorFilter filter){paint.setColorFilter(filter);invalidateSelf();}
        @Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}
    }
}
