package com.xcosmos.minivoice;

/** Rotation changes placement, not the size of the transport controls or the library. */
final class WallViewport {
    final float safeLeft,safeRight;
    final float width,height,focusX,focusY,focusSide,dockWidth,dockRight,dockBottom;
    final boolean landscape;
    WallViewport(float width,float height,float density,float left,float top,float right,float bottom,boolean landscape,float portraitDockWidth){
        this.width=width;this.height=height;this.landscape=landscape;safeLeft=left;safeRight=right;
        float margin=16*density,availableWidth=width-left-right,availableHeight=height-top-bottom;
        dockRight=right+margin;dockBottom=bottom+14*density;
        dockWidth=landscape?Math.min(portraitDockWidth,availableWidth-2*margin):availableWidth-2*margin;
        if(landscape){
            float leftWidth=Math.max(1,availableWidth-dockWidth-3*margin);
            focusX=left+margin+leftWidth/2;focusY=top+availableHeight/2;
            focusSide=Math.min(leftWidth,Math.max(1,availableHeight-2*margin));
        }else{
            focusX=left+availableWidth/2;focusY=(top+80*density+height-bottom-112*density)/2;
            focusSide=Math.max(180*density,Math.min(520*density,Math.min(availableWidth-24*density,availableHeight-180*density)));
        }
    }
}
