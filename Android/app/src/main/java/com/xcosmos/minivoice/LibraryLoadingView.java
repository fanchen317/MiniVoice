package com.xcosmos.minivoice;

import android.content.Context;
import android.content.res.ColorStateList;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

/** Native indeterminate animation automatically stops when this empty state is hidden. */
final class LibraryLoadingView extends LinearLayout {
    private final ProgressBar spinner;
    private final TextView caption;
    LibraryLoadingView(Context context){
        super(context);setOrientation(VERTICAL);setGravity(Gravity.CENTER);setPadding(dp(24),dp(24),dp(24),dp(24));
        spinner=new ProgressBar(context);spinner.setIndeterminate(true);addView(spinner,new LayoutParams(dp(36),dp(36)));
        caption=new TextView(context);caption.setTextSize(15);caption.setGravity(Gravity.CENTER);caption.setMaxLines(3);
        LayoutParams text=new LayoutParams(-1,-2);text.topMargin=dp(16);addView(caption,text);
    }
    void palette(AppAppearance.Palette colors){spinner.setIndeterminateTintList(ColorStateList.valueOf(colors.accent));caption.setTextColor(colors.secondary);}
    void state(boolean loading,String message){spinner.setVisibility(loading?View.VISIBLE:View.GONE);caption.setText(message);}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
}
