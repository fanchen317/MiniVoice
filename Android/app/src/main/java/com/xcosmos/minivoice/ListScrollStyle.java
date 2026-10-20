package com.xcosmos.minivoice;

import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.InsetDrawable;
import android.view.View;
import android.widget.AbsListView;

/** Larger list scroll handles, with a generous touch strip for fast scrolling. */
final class ListScrollStyle {
    private static int dp(View view,int value){return Math.round(value*view.getResources().getDisplayMetrics().density);}
    private static GradientDrawable pill(View view,int color,int width,int height){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadius(dp(view,8));shape.setSize(dp(view,width),dp(view,height));return shape;}
    static void apply(View view){
        view.setVerticalScrollBarEnabled(true);view.setScrollBarSize(dp(view,8));view.setScrollBarDefaultDelayBeforeFade(1800);view.setScrollBarFadeDuration(350);
        view.setVerticalScrollbarThumbDrawable(pill(view,0xCC51BFA0,8,48));view.setVerticalScrollbarTrackDrawable(pill(view,0x18708078,8,48));
    }
    static void fast(AbsListView list){
        apply(list);list.setFastScrollEnabled(true);list.setFastScrollAlwaysVisible(true);
        // The visible 10 dp pill sits inside a 32 dp-wide drawable used for hit testing.
        list.setFastScrollThumbDrawable(new InsetDrawable(pill(list,0xEE51BFA0,10,56),dp(list,11),0,dp(list,11),0));
        list.setFastScrollTrackDrawable(new InsetDrawable(pill(list,0x22708078,4,56),dp(list,14),0,dp(list,14),0));
    }
}
