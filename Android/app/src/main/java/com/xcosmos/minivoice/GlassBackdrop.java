package com.xcosmos.minivoice;

import android.graphics.*;
import android.graphics.drawable.Drawable;
import android.view.View;
import android.view.ViewParent;
import java.util.WeakHashMap;

/** Samples the scene behind a surface, never the surface or its foreground text. */
final class GlassBackdrop {
    private Bitmap bitmap;
    private final Bitmap[] cachedBitmaps=new Bitmap[2];
    private final int[] cachedGenerations={-1,-1},cachedWidths=new int[2],cachedHeights=new int[2];
    private final View source;
    private final boolean live;
    private final float blurDp;
    private final WeakHashMap<View,Boolean> hosts=new WeakHashMap<>();
    private int generation,bitmapWidth,bitmapHeight;
    private final int[] origin=new int[2];
    GlassBackdrop(View source,boolean live){this(source,live,20);}
    GlassBackdrop(View source,boolean live,float blurDp){this.source=source;this.live=live;this.blurDp=blurDp>0?blurDp:20;}
    void invalidateSnapshot(){generation++;bitmap=null;cachedBitmaps[0]=cachedBitmaps[1]=null;for(View host:hosts.keySet())if(host.isShown())host.invalidate();}
    private boolean contains(View host){for(ViewParent parent=host.getParent();parent!=null;parent=parent.getParent())if(parent==source)return true;return host==source;}
    private boolean drawSource(Canvas canvas,boolean scene){
        if(source instanceof PlayerStylePage)return ((PlayerStylePage)source).drawBackdrop(canvas,scene);
        if(source instanceof WallView&&canvas.isHardwareAccelerated())return ((WallView)source).drawBackdrop(canvas);
        source.draw(canvas);return true;
    }
    private void capture(boolean scene){
        if(source.getWidth()<=0||source.getHeight()<=0)return;
        float density=source.getResources().getDisplayMetrics().density;
        // Keep detail in the sampling texture; a Gaussian kernel supplies the blur.
        int sample=Math.max(2,Math.round(blurDp*density/4));
        int width=Math.max(1,(source.getWidth()+sample-1)/sample),height=Math.max(1,(source.getHeight()+sample-1)/sample);
        Bitmap image=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);
        Canvas canvas=new Canvas(image);canvas.scale(width/(float)source.getWidth(),height/(float)source.getHeight());
        drawSource(canvas,scene);
        int[] pixels=new int[width*height];image.getPixels(pixels,0,width,0,0,width,height);
        pixels=GlassGaussian.blur(pixels,width,height);
        image.setPixels(pixels,0,width,0,0,width,height);bitmap=image;bitmapWidth=source.getWidth();bitmapHeight=source.getHeight();int key=scene?1:0;cachedBitmaps[key]=image;cachedGenerations[key]=generation;cachedWidths[key]=bitmapWidth;cachedHeights[key]=bitmapHeight;
    }
    Drawable surface(View host,float radius,boolean panel){return surface(host,radius,panel,false);}
    Drawable surface(View host,float radius,boolean panel,boolean light){
        hosts.put(host,Boolean.TRUE);
        return new Drawable(){
            final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
            final int[] location=new int[2];
            android.graphics.RenderNode tile;
            int previousX=Integer.MIN_VALUE,previousY,previousWidth,previousHeight,previousGeneration=-1,previousSourceWidth,previousSourceHeight;
            boolean previousScene;
            int sourceRetries;
            @Override public void draw(Canvas canvas){
                RectF bounds=new RectF(getBounds());if(bounds.isEmpty())return;
                float density=host.getResources().getDisplayMetrics().density,r=radius*density;
                boolean scene=!contains(host),gpu=live&&android.os.Build.VERSION.SDK_INT>=31&&canvas.isHardwareAccelerated();
                host.getLocationOnScreen(location);source.getLocationOnScreen(origin);
                int x=location[0]-origin[0],y=location[1]-origin[1],width=getBounds().width(),height=getBounds().height();
                int pad=Math.max(1,Math.round(blurDp*density*2));
                if(gpu&&source.getWidth()>0&&source.getHeight()>0){
                    if(tile==null||x!=previousX||y!=previousY||width!=previousWidth||height!=previousHeight||generation!=previousGeneration||source.getWidth()!=previousSourceWidth||source.getHeight()!=previousSourceHeight||scene!=previousScene){
                        if(tile==null)tile=new android.graphics.RenderNode("MiniVoice glass tile");
                        int w=Math.max(1,(width+2*pad)/2),h=Math.max(1,(height+2*pad)/2);tile.setPosition(0,0,w,h);tile.setClipToBounds(true);
                        Canvas recording=tile.beginRecording(w,h);boolean ready;
                        try{recording.scale(.5f,.5f);recording.translate(pad-x,pad-y);ready=drawSource(recording,scene);}finally{tile.endRecording();}
                        tile.setRenderEffect(android.graphics.RenderEffect.createBlurEffect(blurDp*density/2,blurDp*density/2,Shader.TileMode.CLAMP));
                        if(ready){previousX=x;previousY=y;previousWidth=width;previousHeight=height;previousGeneration=generation;previousScene=scene;previousSourceWidth=source.getWidth();previousSourceHeight=source.getHeight();sourceRetries=0;}else{
                            tile=null;
                            // A scene may not be recorded on the first frame. Retry without
                            // requiring a tap, but never start an unbounded redraw loop.
                            if(sourceRetries++<3){source.postInvalidateOnAnimation();host.postInvalidateOnAnimation();}
                        }
                    }
                }else{
                    int key=scene?1:0;bitmap=cachedBitmaps[key];
                    if(bitmap==null||cachedWidths[key]!=source.getWidth()||cachedHeights[key]!=source.getHeight()||(live&&cachedGenerations[key]!=generation))capture(scene);
                }
                Path clip=new Path();clip.addRoundRect(bounds,r,r,Path.Direction.CW);int save=canvas.save();canvas.clipPath(clip);
                // An opaque base only fills unavailable source pixels; the sampled scene is drawn above it.
                paint.setColor(light?0xFFE5EDE9:0xFF202925);canvas.drawRect(bounds,paint);
                if(gpu&&tile!=null){int layer=canvas.save();canvas.translate(bounds.left-pad,bounds.top-pad);canvas.scale(2,2);canvas.drawRenderNode(tile);canvas.restoreToCount(layer);}
                else if(bitmap!=null){float sx=bitmapWidth/(float)bitmap.getWidth(),sy=bitmapHeight/(float)bitmap.getHeight();RectF destination=new RectF(bounds.left-x,bounds.top-y,bounds.left-x+bitmap.getWidth()*sx,bounds.top-y+bitmap.getHeight()*sy);paint.setColor(Color.WHITE);canvas.drawBitmap(bitmap,null,destination,paint);}
                int top=light?0x5CF5FAF8:panel?0x88202A27:0x66202A27,bottom=light?0x80E5EFEB:panel?0xA6101916:0x88202A27;
                paint.setShader(new LinearGradient(0,bounds.top,0,bounds.bottom,top,bottom,Shader.TileMode.CLAMP));canvas.drawRect(bounds,paint);paint.setShader(null);canvas.restoreToCount(save);
                paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(density);
                paint.setShader(new LinearGradient(0,bounds.top,0,bounds.bottom,light?0x8071847D:0x99D3E3DC,light?0x59647770:0x668CA69A,Shader.TileMode.CLAMP));
                bounds.inset(density/2,density/2);canvas.drawRoundRect(bounds,Math.max(0,r-density/2),Math.max(0,r-density/2),paint);paint.setShader(null);paint.setStyle(Paint.Style.FILL);
            }
            @Override public void getOutline(Outline outline){outline.setRoundRect(getBounds(),radius*host.getResources().getDisplayMetrics().density);}
            @Override public void setAlpha(int alpha){}@Override public void setColorFilter(ColorFilter filter){}@Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}
        };
    }
}
