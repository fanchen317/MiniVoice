package com.xcosmos.minivoice;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** The weighted wall partition used by Desktop/src/wallGeometry.js, in Android pixels. */
final class WallLayout {
    static final class Tile {
        final int index; final float x,y,width,height;
        Tile(int index,float x,float y,float width,float height){this.index=index;this.x=x;this.y=y;this.width=width;this.height=height;}
    }
    static final class Instance {
        final Tile tile;final int column,row;final float x,y;
        Instance(Tile tile,int column,int row,float x,float y){this.tile=tile;this.column=column;this.row=row;this.x=x;this.y=y;}
    }
    final List<Tile> tiles=new ArrayList<>();
    final Map<Long,List<Tile>> buckets=new HashMap<>();
    final float width,height,bucket;
    WallLayout(int count,float density){
        bucket=640*density;
        if(count==0){width=height=1;return;}
        int[] pattern={2,1,1,3,1,2,1,1,2,4,1,2};
        float[] sums=new float[count+1];for(int i=0;i<count;i++)sums[i+1]=sums[i]+pattern[i%pattern.length];
        float area=sums[count]*180*density*180*density;
        width=(float)Math.sqrt(area*1.6);height=(float)Math.sqrt(area/1.6);
        divide(0,count,0,0,width,height,sums,5*density);
        for(Tile tile:tiles){
            int left=(int)Math.floor(tile.x/bucket),right=(int)Math.floor((tile.x+tile.width)/bucket);
            int top=(int)Math.floor(tile.y/bucket),bottom=(int)Math.floor((tile.y+tile.height)/bucket);
            for(int by=top;by<=bottom;by++)for(int bx=left;bx<=right;bx++)buckets.computeIfAbsent(key(bx,by),unused->new ArrayList<>()).add(tile);
        }
    }
    private void divide(int first,int end,float x,float y,float w,float h,float[] sums,float gap){
        if(end-first==1){tiles.add(new Tile(first,x,y,w-gap,h-gap));return;}
        int middle=first+(end-first)/2;float fraction=(sums[middle]-sums[first])/(sums[end]-sums[first]);
        if(w>=h){divide(first,middle,x,y,w*fraction,h,sums,gap);divide(middle,end,x+w*fraction,y,w*(1-fraction),h,sums,gap);}
        else{divide(first,middle,x,y,w,h*fraction,sums,gap);divide(middle,end,x,y+h*fraction,w,h*(1-fraction),sums,gap);}
    }
    List<Instance> visible(float cameraX,float cameraY,float scale,float viewWidth,float viewHeight,float overscan){
        List<Instance> result=new ArrayList<>();if(tiles.isEmpty())return result;
        float left=(-cameraX-overscan)/scale,right=(viewWidth-cameraX+overscan)/scale;
        float top=(-cameraY-overscan)/scale,bottom=(viewHeight-cameraY+overscan)/scale;
        for(int cy=(int)Math.floor(top/height);cy<=(int)Math.floor(bottom/height);cy++)
            for(int cx=(int)Math.floor(left/width);cx<=(int)Math.floor(right/width);cx++){
                float l=Math.max(0,left-cx*width),r=Math.min(width,right-cx*width);
                float t=Math.max(0,top-cy*height),b=Math.min(height,bottom-cy*height);
                if(r<l||b<t)continue;
                Set<Tile> nearby=new HashSet<>();
                for(int by=(int)Math.floor(t/bucket);by<=(int)Math.floor(b/bucket);by++)
                    for(int bx=(int)Math.floor(l/bucket);bx<=(int)Math.floor(r/bucket);bx++){
                        List<Tile> part=buckets.get(key(bx,by));if(part!=null)nearby.addAll(part);
                    }
                for(Tile tile:nearby)if(tile.x<r&&tile.x+tile.width>l&&tile.y<b&&tile.y+tile.height>t)
                    result.add(new Instance(tile,cx,cy,tile.x+cx*width,tile.y+cy*height));
            }
        return result;
    }
    Instance nearest(int index,float cameraX,float cameraY,float scale,float viewWidth,float viewHeight){
        if(index<0||index>=tiles.size())return null;
        Tile tile=tiles.get(index);
        int cx=Math.round(((viewWidth/2-cameraX)/scale-tile.x-tile.width/2)/width);
        int cy=Math.round(((viewHeight/2-cameraY)/scale-tile.y-tile.height/2)/height);
        return new Instance(tile,cx,cy,tile.x+cx*width,tile.y+cy*height);
    }
    private static long key(int x,int y){return ((long)x<<32)^(y&0xffffffffL);}
}
