package com.xcosmos.minivoice;

/** Distances and velocity are positive in the panel's dismissal direction. */
final class PanelDismiss {
    static boolean shouldClose(float distance,float velocity,float extent,float density){
        if(extent<=0||density<=0)return false;
        if(velocity < -600*density)return false;
        return distance>=Math.min(extent*.25f,120*density)
                || distance>=12*density&&velocity>=800*density;
    }
}
