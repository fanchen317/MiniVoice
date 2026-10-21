package com.xcosmos.minivoice;

/** Four separable Gaussian passes on a downsampled opaque scene, with clamped edges. */
final class GlassGaussian {
    static int[] blur(int[] input,int width,int height){
        if(width<=0||height<=0||input.length!=(long)width*height)throw new IllegalArgumentException("Invalid blur dimensions");
        int[] pixels=input.clone(),temp=new int[pixels.length],kernel={1,4,6,4,1};
        for(int pass=0;pass<4;pass++)for(int axis=0;axis<2;axis++){
            for(int y=0;y<height;y++)for(int x=0;x<width;x++){
                int r=0,g=0,b=0;
                for(int k=-2;k<=2;k++){
                    int xx=axis==0?Math.max(0,Math.min(width-1,x+k)):x;
                    int yy=axis==1?Math.max(0,Math.min(height-1,y+k)):y,c=pixels[yy*width+xx],w=kernel[k+2];
                    r+=((c>>>16)&255)*w;g+=((c>>>8)&255)*w;b+=(c&255)*w;
                }
                temp[y*width+x]=0xFF000000|(r/16)<<16|(g/16)<<8|b/16;
            }
            int[] swap=pixels;pixels=temp;temp=swap;
        }
        return pixels;
    }
}
