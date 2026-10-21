package com.xcosmos.minivoice;

import android.graphics.drawable.GradientDrawable;
import android.view.View;
import android.widget.AbsListView;

/** Slim, edge-aligned scroll indicators with a generous fast-scroll touch strip. */
final class ListScrollStyle {
    private static int dp(View view,int value){return Math.round(value*view.getResources().getDisplayMetrics().density);}
    private static GradientDrawable pill(View view,int color,int width,int height){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadius(dp(view,8));shape.setSize(dp(view,width),dp(view,height));return shape;}
    static void apply(View view){
        view.setVerticalScrollBarEnabled(true);view.setScrollBarSize(dp(view,4));view.setScrollbarFadingEnabled(true);view.setScrollBarDefaultDelayBeforeFade(700);view.setScrollBarFadeDuration(250);view.setScrollBarStyle(View.SCROLLBARS_OUTSIDE_OVERLAY);view.setVerticalScrollbarPosition(View.SCROLLBAR_POSITION_RIGHT);
        view.setVerticalScrollbarThumbDrawable(pill(view,0xB351BFA0,4,36));view.setVerticalScrollbarTrackDrawable(pill(view,0x00708078,4,36));
    }
    static android.content.Context context(android.content.Context base){return new android.view.ContextThemeWrapper(base,R.style.LargeFastScroll);}
    static void fast(AbsListView list){
        apply(list);list.setFastScrollEnabled(true);list.setFastScrollAlwaysVisible(false);
        list.setVerticalScrollBarEnabled(false);
    }
}
