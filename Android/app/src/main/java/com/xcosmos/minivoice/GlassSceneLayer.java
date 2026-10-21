package com.xcosmos.minivoice;

import android.graphics.Canvas;
import android.graphics.RenderNode;
import java.util.function.Consumer;

/** Records children once during their normal draw; glass reads the independent display list. */
final class GlassSceneLayer {
    private final RenderNode node=new RenderNode("MiniVoice workspace scene");
    private boolean ready;
    void draw(Canvas output,int width,int height,Consumer<Canvas> children){
        if(!output.isHardwareAccelerated()){children.accept(output);return;}
        node.setPosition(0,0,width,height);node.setClipToBounds(true);
        Canvas recording=node.beginRecording(width,height);
        try{children.accept(recording);}finally{node.endRecording();}
        ready=true;output.drawRenderNode(node);
    }
    boolean backdrop(Canvas canvas){if(!ready||!canvas.isHardwareAccelerated())return false;canvas.drawRenderNode(node);return true;}
    void clear(){ready=false;node.discardDisplayList();}
}
