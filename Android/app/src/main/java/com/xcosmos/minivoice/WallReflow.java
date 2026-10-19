package com.xcosmos.minivoice;

/** Immutable world-space transforms allow an interrupted focus to resume from its visible shape. */
final class WallReflow {
    static final class Frame {
        final float x,y,width,height;
        Frame(float x,float y,float width,float height){this.x=x;this.y=y;this.width=width;this.height=height;}
        float centerX(){return x+width/2;}
        float centerY(){return y+height/2;}
    }
    interface Transform { Frame apply(Frame frame); }
    static final Transform IDENTITY=frame->frame;
    static Transform focused(Frame focus,float side,float gap){
        return frame->{
            float x=coordinate(frame.x,focus.x,focus.x+focus.width+gap,side+gap);
            float right=coordinate(frame.x+frame.width+gap,focus.x,focus.x+focus.width+gap,side+gap);
            float y=coordinate(frame.y,focus.y,focus.y+focus.height+gap,side+gap);
            float bottom=coordinate(frame.y+frame.height+gap,focus.y,focus.y+focus.height+gap,side+gap);
            return new Frame(x,y,right-x-gap,bottom-y-gap);
        };
    }
    static Transform between(Transform from,Transform to,float progress){
        if(progress<=0)return from;if(progress>=1)return to;
        return frame->{Frame a=from.apply(frame),b=to.apply(frame);return new Frame(lerp(a.x,b.x,progress),lerp(a.y,b.y,progress),lerp(a.width,b.width,progress),lerp(a.height,b.height,progress));};
    }
    private static float coordinate(float value,float lower,float upper,float length){
        float delta=(Math.max(1,length)-(upper-lower))/2;
        if(value<=lower)return value-delta;if(value>=upper)return value+delta;
        return lower-delta+(value-lower)*Math.max(1,length)/(upper-lower);
    }
    private static float lerp(float from,float to,float progress){return from+(to-from)*progress;}
}
