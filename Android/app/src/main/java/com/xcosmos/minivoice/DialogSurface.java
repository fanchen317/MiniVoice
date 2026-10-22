package com.xcosmos.minivoice;
import android.app.Activity;
import android.graphics.drawable.GradientDrawable;
/** Shared visual tokens for modal cards and draggable sheets. */
final class DialogSurface {
    static AppAppearance.Palette palette(Activity activity){return AppAppearance.palette(activity,activity.getSharedPreferences("library",0));}
    static int dp(Activity activity,float value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    static int scrim(AppAppearance.Palette colors){return colors.dark?0x99000000:0x550F2018;}
    static GradientDrawable background(Activity activity,AppAppearance.Palette colors,boolean bottom){
        GradientDrawable surface=new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,colors.dark?new int[]{0xFF252F29,0xFF18211C}:new int[]{0xFFFAFDFB,0xFFEDF4EF});float r=dp(activity,24);
        surface.setCornerRadii(bottom?new float[]{r,r,r,r,0,0,0,0}:new float[]{r,r,r,r,r,r,r,r});surface.setStroke(dp(activity,1),colors.dark?0xFF526258:0xFFCBD9D0);return surface;
    }
}
