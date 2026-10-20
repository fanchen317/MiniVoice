package com.xcosmos.minivoice;

import android.animation.ValueAnimator;
import android.graphics.*;
import android.graphics.drawable.Drawable;
import android.view.View;

/** Cover-driven colour and Gaussian atmosphere, with a small reusable texture. */
final class CoverAtmosphere extends Drawable {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
    private Bitmap source,image,previous;
    private int average=0xFFADCAC0,previousAverage=average;
    private boolean dark;
    private float progress=1;
    private ValueAnimator animation;
    void theme(boolean value){dark=value;invalidateSelf();}
    void artwork(Bitmap value){
        if(source==value)return;source=value;stop();previous=image;previousAverage=average;
        image=value==null?null:blur(value);average=image==null?0xFFADCAC0:average(image);
        if(getCallback() instanceof View&&((View)getCallback()).isShown()&&ValueAnimator.areAnimatorsEnabled()){
            progress=0;animation=ValueAnimator.ofFloat(0,1);animation.setDuration(420);animation.addUpdateListener(a->{progress=(float)a.getAnimatedValue();invalidateSelf();});animation.start();
        }else progress=1;
        invalidateSelf();
    }
    void stop(){if(animation!=null){animation.removeAllUpdateListeners();animation.cancel();animation=null;}previous=null;progress=1;}
    private Bitmap blur(Bitmap artwork){
        Bitmap small=Bitmap.createBitmap(48,48,Bitmap.Config.ARGB_8888);Canvas canvas=new Canvas(small);
        canvas.drawBitmap(artwork,null,new Rect(0,0,48,48),paint);
        int[] pixels=new int[48*48],temp=new int[pixels.length],kernel={1,4,6,4,1};small.getPixels(pixels,0,48,0,0,48,48);
        for(int pass=0;pass<4;pass++)for(int axis=0;axis<2;axis++){
            for(int y=0;y<48;y++)for(int x=0;x<48;x++){int r=0,g=0,b=0;for(int k=-2;k<=2;k++){int xx=axis==0?Math.max(0,Math.min(47,x+k)):x,yy=axis==1?Math.max(0,Math.min(47,y+k)):y,c=pixels[yy*48+xx],w=kernel[k+2];r+=Color.red(c)*w;g+=Color.green(c)*w;b+=Color.blue(c)*w;}temp[y*48+x]=Color.rgb(r/16,g/16,b/16);}int[] swap=pixels;pixels=temp;temp=swap;
        }
        small.setPixels(pixels,0,48,0,0,48,48);return small;
    }
    private int average(Bitmap bitmap){long r=0,g=0,b=0;int[] pixels=new int[48*48];bitmap.getPixels(pixels,0,48,0,0,48,48);for(int pixel:pixels){r+=Color.red(pixel);g+=Color.green(pixel);b+=Color.blue(pixel);}return Color.rgb((int)(r/pixels.length),(int)(g/pixels.length),(int)(b/pixels.length));}
    @Override public void draw(Canvas canvas){
        drawLayer(canvas,previous,previousAverage);
        if(progress>0){int saved=canvas.saveLayerAlpha(new RectF(getBounds()),Math.round(255*progress));drawLayer(canvas,image,average);canvas.restoreToCount(saved);}
    }
    private void drawLayer(Canvas canvas,Bitmap bitmap,int rgb){
        Rect bounds=getBounds();paint.setAlpha(255);paint.setShader(null);paint.setColor(dark?0xFF18211F:0xFFE8EEEE);canvas.drawRect(bounds,paint);
        paint.setShader(new LinearGradient(bounds.left,bounds.top,bounds.right,bounds.bottom,CoverAtmosphereColors.bright(rgb),CoverAtmosphereColors.soft(rgb),Shader.TileMode.CLAMP));paint.setAlpha(dark?107:168);canvas.drawRect(bounds,paint);paint.setShader(null);
        if(bitmap!=null){float extent=Math.max(bounds.width(),bounds.height())*1.24f;RectF target=new RectF(bounds.exactCenterX()-extent/2,bounds.exactCenterY()-extent/2,bounds.exactCenterX()+extent/2,bounds.exactCenterY()+extent/2);paint.setAlpha(dark?102:97);canvas.drawBitmap(bitmap,null,target,paint);}
        paint.setAlpha(255);paint.setColor(dark?0x33000000:0x10FFFFFF);canvas.drawRect(bounds,paint);
    }
    @Override public void setAlpha(int alpha){}@Override public void setColorFilter(ColorFilter filter){}@Override public int getOpacity(){return PixelFormat.OPAQUE;}
}
