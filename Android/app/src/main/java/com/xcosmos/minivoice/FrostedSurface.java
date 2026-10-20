package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;

/** Shared translucent material over the blurred cover background. */
final class FrostedSurface {
    static GradientDrawable background(Context context,float radius){
        float density=context.getResources().getDisplayMetrics().density;
        GradientDrawable surface=new GradientDrawable();surface.setColor(0xB3263432);
        surface.setCornerRadius(radius*density);surface.setStroke(Math.max(1,Math.round(density)),0x557E9690);return surface;
    }
}
