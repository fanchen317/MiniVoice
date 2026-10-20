package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.*;
import android.graphics.drawable.RippleDrawable;
import android.view.View;

/** Density-independent sidebar controls with full 44 dp touch targets. */
final class SidebarToolButton extends View {
    static final int LOCATE=0,RELOAD=1,SORT=2,SELECT=3;
    private final int kind;private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private boolean busy,selected;
    SidebarToolButton(Context context,int kind,int color,String label,Runnable action){super(context);this.kind=kind;paint.setColor(color);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(1.65f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);setContentDescription(label);setOnClickListener(v->action.run());setBackground(new RippleDrawable(ColorStateList.valueOf(0x220A8763),null,null));ButtonFeedback.install(this);}
    void busy(boolean value){busy=value;setEnabled(!value);setContentDescription(value?"正在重新扫描音乐库":"重新扫描音乐库");invalidate();}
    void selecting(boolean value){selected=value;setContentDescription(value?"完成多选":"多选歌曲");invalidate();}
    @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);int save=canvas.save();float density=getResources().getDisplayMetrics().density;canvas.translate(getWidth()/2f,getHeight()/2f);canvas.scale(density,density);
        if(kind==LOCATE){canvas.drawCircle(0,0,8,paint);canvas.drawLine(-11,0,-4,0,paint);canvas.drawLine(4,0,11,0,paint);canvas.drawLine(0,-11,0,-4,paint);canvas.drawLine(0,4,0,11,paint);}
        else if(kind==RELOAD){if(busy)canvas.rotate((android.os.SystemClock.uptimeMillis()%900)*360f/900);canvas.drawArc(-8,-8,8,8,-70,300,false,paint);canvas.drawLine(2,-11,6,-7,paint);canvas.drawLine(2,-3,6,-7,paint);}
        else if(kind==SORT){canvas.drawLine(-4,-9,-4,9,paint);canvas.drawLine(-8,-5,-4,-9,paint);canvas.drawLine(0,-5,-4,-9,paint);canvas.drawLine(5,-9,5,9,paint);canvas.drawLine(1,5,5,9,paint);canvas.drawLine(9,5,5,9,paint);}
        else{for(int row=-1;row<=1;row++){float y=row*7;canvas.drawCircle(-7,y,2.5f,paint);canvas.drawLine(0,y,10,y,paint);}if(selected){paint.setStyle(Paint.Style.FILL);canvas.drawCircle(-7,0,1.2f,paint);paint.setStyle(Paint.Style.STROKE);}}
        canvas.restoreToCount(save);if(busy&&isShown()&&hasWindowFocus())postInvalidateDelayed(50);
    }
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused)invalidate();}
}
