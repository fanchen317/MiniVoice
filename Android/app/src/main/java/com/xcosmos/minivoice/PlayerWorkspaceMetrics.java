package com.xcosmos.minivoice;

/** Geometry after safe-area, toolbar and dock insets have been removed. */
final class PlayerWorkspaceMetrics {
    final boolean wide;final int artwork,hero;
    PlayerWorkspaceMetrics(int width,int height,float density){
        float w=Math.max(1,width),h=Math.max(1,height);wide=w>=620*density;
        if(wide){hero=Math.round(Math.min(320*density,w*.4f));artwork=Math.round(Math.max(1,Math.min(260*density,Math.min(hero-40*density,h*.6f))));}
        else{hero=Math.round(Math.min(h*.55f,330*density));artwork=Math.round(Math.max(1,Math.min(220*density,Math.min(w-48*density,hero-100*density))));}
    }
}
