package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.Drawable;

/** Five playback modes drawn on the same 24 dp grid with a shared stroke. */
final class PlaybackModeGlyph extends Drawable {
    private final Paint paint=new Paint(3);private final int mode,size;
    PlaybackModeGlyph(Context context,int mode,int color){this.mode=PlaybackModes.valid(mode);size=Math.round(24*context.getResources().getDisplayMetrics().density);paint.setColor(color);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(1.8f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);setBounds(0,0,size,size);}
    private void line(Canvas c,float... points){Path p=new Path();p.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)p.lineTo(points[i],points[i+1]);c.drawPath(p,paint);}
    @Override public void draw(Canvas c){int save=c.save();c.translate(getBounds().left,getBounds().top);c.scale(getBounds().width()/24f,getBounds().height()/24f);
        if(mode==2){line(c,3,6,7,6,17,18,21,18);line(c,17,14,21,18,17,21);line(c,3,18,7,18,10,14);line(c,14,10,17,6,21,6);line(c,17,3,21,6,17,10);}
        else if(mode>=3){line(c,5,10,5,6,20,6,17,3);line(c,20,6,17,9);line(c,19,14,19,18,4,18,7,21);line(c,4,18,7,15);if(mode==3){line(c,10,11,12,10,12,15);}}
        else if(mode==1){for(int y=6;y<=18;y+=6){c.drawCircle(4,y,.6f,paint);line(c,9,y,20,y);}}
        else{c.drawRoundRect(3,3,21,21,5,5,paint);line(c,10,10,12,8,12,16);}
        c.restoreToCount(save);
    }
    @Override public int getIntrinsicWidth(){return size;}@Override public int getIntrinsicHeight(){return size;}
    @Override public void setAlpha(int alpha){paint.setAlpha(alpha);}@Override public void setColorFilter(ColorFilter filter){paint.setColorFilter(filter);}@Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}
    private static void center(android.widget.TextView view){if("edge".equals(view.getTag())){view.setPadding(0,0,0,0);return;}int icon=Math.round(24*view.getResources().getDisplayMetrics().density);view.setPadding(Math.max(0,(view.getWidth()-icon)/2),0,0,0);}
    static void bind(android.widget.TextView view,int mode,int color){
        view.setText("");view.setCompoundDrawables(new PlaybackModeGlyph(view.getContext(),mode,color),null,null,null);
        if(view.getTag()==null){view.setTag(Boolean.TRUE);view.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->center(view));}center(view);
    }
}
