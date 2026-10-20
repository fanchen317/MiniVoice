package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.View;

/** Fixed-size toolbar arrow; independent of font metrics and text padding. */
final class PageBackButton extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path arrow=new Path();
    private final float density;
    PageBackButton(Context context,int color,Runnable action){
        super(context);density=getResources().getDisplayMetrics().density;
        paint.setColor(color);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(2*density);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);
        GradientDrawable mask=new GradientDrawable();mask.setShape(GradientDrawable.OVAL);mask.setColor(Color.WHITE);
        setBackground(new RippleDrawable(ColorStateList.valueOf(0x180A8763),null,mask));
        setContentDescription("返回");setFocusable(true);setOnClickListener(v->action.run());ButtonFeedback.install(this);
    }
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);int save=canvas.save();canvas.translate(getWidth()/2f,getHeight()/2f);if(getLayoutDirection()==LAYOUT_DIRECTION_RTL)canvas.scale(-1,1);
        arrow.reset();arrow.moveTo(0,-7*density);arrow.lineTo(-7*density,0);arrow.lineTo(0,7*density);canvas.drawPath(arrow,paint);canvas.drawLine(-7*density,0,8*density,0,paint);canvas.restoreToCount(save);
    }
}
