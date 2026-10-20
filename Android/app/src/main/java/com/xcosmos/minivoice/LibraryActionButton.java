package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.*;
import android.graphics.drawable.*;
import android.view.View;

/** Font-independent library row actions, with bounded press feedback. */
final class LibraryActionButton extends View {
    private final boolean favorite;private boolean checked;private int color;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);private final Path path=new Path();
    LibraryActionButton(Context context,boolean favorite,int color){
        super(context);this.favorite=favorite;this.color=color;setFocusable(true);setClickable(true);
        GradientDrawable mask=new GradientDrawable();mask.setColor(Color.WHITE);mask.setShape(GradientDrawable.OVAL);setBackground(new RippleDrawable(ColorStateList.valueOf(0x180A8763),null,mask));ButtonFeedback.install(this);
    }
    void state(boolean checked,int color){this.checked=checked;this.color=color;setSelected(checked);invalidate();}
    @Override protected void onDraw(Canvas canvas){
        super.onDraw(canvas);float d=getResources().getDisplayMetrics().density;int saved=canvas.save();canvas.translate(getWidth()/2f,getHeight()/2f);canvas.scale(d,d);paint.setColor(color);paint.setStrokeWidth(1.7f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);paint.setStyle(Paint.Style.STROKE);path.reset();
        if(favorite){path.moveTo(0,8);path.cubicTo(-17,-2,-6,-14,0,-6);path.cubicTo(6,-14,17,-2,0,8);if(checked)paint.setStyle(Paint.Style.FILL);canvas.drawPath(path,paint);}
        else{path.moveTo(-8,8);path.lineTo(-7,3);path.lineTo(4,-8);path.cubicTo(6,-10,10,-6,8,-4);path.lineTo(-3,7);path.close();canvas.drawPath(path,paint);canvas.drawLine(2,-6,6,-2,paint);canvas.drawLine(-8,11,9,11,paint);}
        canvas.restoreToCount(saved);
    }
}
