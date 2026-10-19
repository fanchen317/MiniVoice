package com.xcosmos.minivoice;

import android.app.Activity;
import android.app.Dialog;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.function.Consumer;

/** Shared half-height panel for wall tools and the playback queue. */
final class BottomSheet {
    private static int dp(Activity activity,float value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    private static GradientDrawable background(Activity activity,int color,int radius){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadii(new float[]{dp(activity,radius),dp(activity,radius),dp(activity,radius),dp(activity,radius),0,0,0,0});return shape;}
    static Dialog show(Activity activity,String title,Consumer<LinearLayout> content){
        Dialog dialog=new Dialog(activity);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout sheet=new LinearLayout(activity);sheet.setOrientation(LinearLayout.VERTICAL);sheet.setPadding(dp(activity,20),dp(activity,10),dp(activity,20),dp(activity,12));sheet.setBackground(background(activity,0xF51B211F,26));
        View handle=new View(activity);GradientDrawable handleShape=new GradientDrawable();handleShape.setColor(0x80FFFFFF);handleShape.setCornerRadius(dp(activity,3));handle.setBackground(handleShape);
        LinearLayout.LayoutParams handleParams=new LinearLayout.LayoutParams(dp(activity,36),dp(activity,4));handleParams.gravity=Gravity.CENTER_HORIZONTAL;handleParams.bottomMargin=dp(activity,16);sheet.addView(handle,handleParams);
        final float[] touchY={0};handle.setOnTouchListener((view,event)->{if(event.getActionMasked()==MotionEvent.ACTION_DOWN){touchY[0]=event.getRawY();return true;}if(event.getActionMasked()==MotionEvent.ACTION_UP){if(event.getRawY()-touchY[0]>dp(activity,45))dialog.dismiss();return true;}return true;});
        LinearLayout heading=new LinearLayout(activity);heading.setGravity(Gravity.CENTER_VERTICAL);sheet.addView(heading,new LinearLayout.LayoutParams(-1,dp(activity,44)));
        TextView titleView=new TextView(activity);titleView.setText(title);titleView.setTextColor(Color.WHITE);titleView.setTextSize(21);titleView.setTypeface(null,Typeface.BOLD);heading.addView(titleView,new LinearLayout.LayoutParams(0,-2,1));
        TextView close=new TextView(activity);close.setText("×");close.setTextSize(28);close.setTextColor(0xCCFFFFFF);close.setGravity(Gravity.CENTER);close.setContentDescription("关闭");close.setBackground(new RippleDrawable(ColorStateList.valueOf(0x44FFFFFF),null,null));close.setOnClickListener(view->dialog.dismiss());heading.addView(close,new LinearLayout.LayoutParams(dp(activity,42),dp(activity,42)));
        ScrollView scroll=new ScrollView(activity);scroll.setFillViewport(false);scroll.setVerticalScrollBarEnabled(false);sheet.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout body=new LinearLayout(activity);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(0,dp(activity,10),0,dp(activity,16));scroll.addView(body);content.accept(body);
        dialog.setContentView(sheet);dialog.show();Window window=dialog.getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.setGravity(Gravity.BOTTOM);window.setLayout(-1,Math.min(dp(activity,600),Math.round(activity.getResources().getDisplayMetrics().heightPixels*.62f)));
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND|WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);WindowManager.LayoutParams attributes=window.getAttributes();attributes.dimAmount=.55f;window.setAttributes(attributes);window.setNavigationBarColor(0xFF1B211F);}
        sheet.setTranslationY(activity.getResources().getDisplayMetrics().heightPixels);sheet.animate().translationY(0).setDuration(260).start();
        return dialog;
    }
    static TextView action(Activity activity,LinearLayout body,String text,Runnable runnable){
        TextView row=new TextView(activity);row.setText(text);row.setTextColor(Color.WHITE);row.setTextSize(16);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(activity,14),0,dp(activity,14),0);
        row.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33FFFFFF),null,null));row.setOnClickListener(view->runnable.run());body.addView(row,new LinearLayout.LayoutParams(-1,dp(activity,54)));return row;
    }
}
