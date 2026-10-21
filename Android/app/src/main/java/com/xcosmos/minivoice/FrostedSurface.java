package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;

/** Shared translucent material over the blurred cover background. */
final class FrostedSurface {
    static GradientDrawable background(Context context,float radius,boolean dark){
        float density=context.getResources().getDisplayMetrics().density;
        GradientDrawable surface=new GradientDrawable();surface.setColor(dark?0xB3263432:0xE6EDF3F2);
        surface.setCornerRadius(radius*density);surface.setStroke(Math.max(1,Math.round(density)),dark?0x557E9690:0xBBFFFFFF);return surface;
    }
}
