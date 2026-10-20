package com.xcosmos.minivoice;

import android.graphics.*;
import android.graphics.drawable.Drawable;
import android.view.View;

/** Blurs only the captured background; foreground text and controls stay sharp. */
final class GlassBackdrop {
    private Bitmap bitmap;
    private final View source;
    private final boolean live;
    private long captured;
    private android.graphics.RenderNode node;
    private final boolean hardware=android.os.Build.VERSION.SDK_INT>=31;
    private final int[] origin=new int[2];
    GlassBackdrop(View source,boolean live){this.source=source;this.live=live;if(!live)capture();}
    void capture(){
        if(source.getWidth()==0||source.getHeight()==0)return;
        int width=Math.max(1,source.getWidth()/12),height=Math.max(1,source.getHeight()/12);
        Bitmap image=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);
        Canvas canvas=new Canvas(image);canvas.scale(width/(float)source.getWidth(),height/(float)source.getHeight());source.draw(canvas);
        source.getLocationOnScreen(origin);
        int[] pixels=new int[width*height],temp=new int[pixels.length];image.getPixels(pixels,0,width,0,0,width,height);
        // Separable Gaussian kernel, with clamped edges to avoid black borders.
        int[] kernel={1,4,6,4,1};
        for(int pass=0;pass<3;pass++){
            for(int axis=0;axis<2;axis++){
                for(int y=0;y<height;y++)for(int x=0;x<width;x++){
                    int r=0,g=0,b=0;
                    for(int k=-2;k<=2;k++){int xx=axis==0?Math.max(0,Math.min(width-1,x+k)):x,yy=axis==1?Math.max(0,Math.min(height-1,y+k)):y,c=pixels[yy*width+xx],w=kernel[k+2];r+=Color.red(c)*w;g+=Color.green(c)*w;b+=Color.blue(c)*w;}
                    temp[y*width+x]=Color.rgb(r/16,g/16,b/16);
                }
                int[] swap=pixels;pixels=temp;temp=swap;
            }
        }
        image.setPixels(pixels,0,width,0,0,width,height);bitmap=image;captured=android.os.SystemClock.uptimeMillis();
    }
    Drawable surface(View host,float radius,boolean panel){return new Drawable(){
        final Paint paint=new Paint(3);final int[] location=new int[2];
        public void draw(Canvas canvas){
            if(live&&hardware&&canvas.isHardwareAccelerated()&&source.getWidth()>0){
                long now=android.os.SystemClock.uptimeMillis();
                if(node==null||node.getWidth()!=Math.max(1,source.getWidth()/4)||node.getHeight()!=Math.max(1,source.getHeight()/4)){
                    if(node==null)node=new android.graphics.RenderNode("MiniVoice glass");
                    int w=Math.max(1,source.getWidth()/4),h=Math.max(1,source.getHeight()/4);node.setPosition(0,0,w,h);
                    Canvas recording=node.beginRecording(w,h);recording.scale(w/(float)source.getWidth(),h/(float)source.getHeight());if(source instanceof WallView)((WallView)source).drawBackdrop(recording);node.endRecording();
                    node.setRenderEffect(android.graphics.RenderEffect.createBlurEffect(7,7,Shader.TileMode.CLAMP));source.getLocationOnScreen(origin);captured=now;
                }
            }
            RectF bounds=new RectF(getBounds());Path clip=new Path();float r=radius*host.getResources().getDisplayMetrics().density;
            clip.addRoundRect(bounds,r,r,Path.Direction.CW);int save=canvas.save();canvas.clipPath(clip);
            if(live&&hardware&&node!=null&&canvas.isHardwareAccelerated()){host.getLocationOnScreen(location);int layer=canvas.save();canvas.translate(origin[0]-location[0],origin[1]-location[1]);canvas.scale(source.getWidth()/(float)node.getWidth(),source.getHeight()/(float)node.getHeight());canvas.drawRenderNode(node);canvas.restoreToCount(layer);}
            if(!live&&bitmap!=null){host.getLocationOnScreen(location);float sx=source.getWidth()/(float)bitmap.getWidth(),sy=source.getHeight()/(float)bitmap.getHeight();RectF destination=new RectF(origin[0]-location[0],origin[1]-location[1],origin[0]-location[0]+bitmap.getWidth()*sx,origin[1]-location[1]+bitmap.getHeight()*sy);paint.setShader(null);paint.setColor(Color.WHITE);canvas.drawBitmap(bitmap,null,destination,paint);}
            paint.setShader(new LinearGradient(0,0,0,bounds.height(),panel?new int[]{0xDE25292C,0xEB101317}:new int[]{0x805E6562,0xB51C2220},null,Shader.TileMode.CLAMP));canvas.drawRect(bounds,paint);paint.setShader(null);canvas.restoreToCount(save);
            paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(host.getResources().getDisplayMetrics().density);paint.setShader(new LinearGradient(0,0,0,bounds.height(),0x99FFFFFF,0x22FFFFFF,Shader.TileMode.CLAMP));bounds.inset(.7f,.7f);canvas.drawRoundRect(bounds,r,r,paint);paint.setShader(null);paint.setStyle(Paint.Style.FILL);
            if(live&&hardware&&host.isShown())host.postInvalidateOnAnimation();
        }
        public void setAlpha(int alpha){}public void setColorFilter(ColorFilter filter){}public int getOpacity(){return PixelFormat.TRANSLUCENT;}
    };}
}
