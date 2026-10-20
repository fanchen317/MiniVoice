package com.xcosmos.minivoice;

import java.util.*;

/** Full-bleed artwork crop scored to keep detected faces complete. Coordinates are normalized. */
final class ArtworkFraming {
    static final class Face {
        final float left,top,right,bottom,confidence;
        Face(float left,float top,float right,float bottom,float confidence){this.left=clamp(left,0,1);this.top=clamp(top,0,1);this.right=clamp(right,this.left,1);this.bottom=clamp(bottom,this.top,1);this.confidence=clamp(confidence,0,1);}
    }
    static final class Plan {
        final float sourceX,sourceY,sourceWidth,sourceHeight,x,y,width,height;
        Plan(float sx,float sy,float sw,float sh,float x,float y,float width,float height){sourceX=sx;sourceY=sy;sourceWidth=sw;sourceHeight=sh;this.x=x;this.y=y;this.width=width;this.height=height;}
    }
    static Plan plan(float iw,float ih,float x,float y,float width,float height,Face[] faces){
        iw=Math.max(1,iw);ih=Math.max(1,ih);width=Math.max(1,width);height=Math.max(1,height);
        float scale=Math.max(width/iw,height/ih),sw=width/scale/iw,sh=height/scale/ih;
        float baseX=(1-sw)/2,baseY=(1-sh)*.38f;
        if(faces==null||faces.length==0)return new Plan(baseX*iw,baseY*ih,sw*iw,sh*ih,x,y,width,height);
        List<Float> xs=new ArrayList<>(),ys=new ArrayList<>();xs.add(baseX);ys.add(baseY);
        float left=1,top=1,right=0,bottom=0;
        for(Face face:faces){if(face.confidence<.35f)continue;left=Math.min(left,face.left);top=Math.min(top,face.top);right=Math.max(right,face.right);bottom=Math.max(bottom,face.bottom);candidates(xs,face.left,face.right,sw);candidates(ys,face.top,face.bottom,sh);}
        if(right>=left&&bottom>=top){candidates(xs,left,right,sw);candidates(ys,top,bottom,sh);}
        // Sample intermediate positions too: a group may not fit, but neither edge
        // should be sacrificed merely to earn the whole-face bonus for one person.
        int count=0;for(Face face:faces)if(face.confidence>=.35f)count++;
        if(count>1)for(int i=0;i<=16;i++){xs.add((1-sw)*i/16);ys.add((1-sh)*i/16);}
        float bestX=baseX,bestY=baseY;double best=-Double.MAX_VALUE;
        for(float cx:xs)for(float cy:ys){float leastVisible=1;double score=-.06*(Math.abs(cx-baseX)+Math.abs(cy-baseY));
            for(Face face:faces){if(face.confidence<.35f)continue;float area=(face.right-face.left)*(face.bottom-face.top);if(area<=0)continue;float visible=Math.max(0,Math.min(cx+sw,face.right)-Math.max(cx,face.left))*Math.max(0,Math.min(cy+sh,face.bottom)-Math.max(cy,face.top))/area;leastVisible=Math.min(leastVisible,visible);double weight=face.confidence*(.5+Math.sqrt(area));score+=weight*(visible*3+(visible>.995f?1:0));}
            if(count>1)score+=12*leastVisible;
            if(score>best){best=score;bestX=cx;bestY=cy;}
        }
        return new Plan(bestX*iw,bestY*ih,sw*iw,sh*ih,x,y,width,height);
    }
    private static void candidates(List<Float> out,float low,float high,float size){out.add(clamp((low+high-size)/2,0,1-size));out.add(clamp(low,0,1-size));out.add(clamp(high-size,0,1-size));}
    private static float clamp(float value,float min,float max){return Float.isFinite(value)?Math.max(min,Math.min(max,value)):min;}
}
