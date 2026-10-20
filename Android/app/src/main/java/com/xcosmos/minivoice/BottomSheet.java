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

/** Shared draggable bottom panel for wall tools and the playback queue. */
final class BottomSheet {
    private static int dp(Activity activity,float value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    private static GradientDrawable background(Activity activity,int color,int radius){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadii(new float[]{dp(activity,radius),dp(activity,radius),dp(activity,radius),dp(activity,radius),0,0,0,0});return shape;}
    static Dialog show(Activity activity,String title,Consumer<LinearLayout> content){
        SheetDialog dialog=new SheetDialog(activity);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        FrameLayout root=new FrameLayout(activity);
        View outside=new View(activity);outside.setBackgroundColor(0x99000000);root.addView(outside,new FrameLayout.LayoutParams(-1,-1));outside.setOnClickListener(v->dialog.dismiss());
        LinearLayout sheet=new LinearLayout(activity);sheet.setOrientation(LinearLayout.VERTICAL);sheet.setPadding(dp(activity,20),0,dp(activity,20),dp(activity,12));sheet.setBackground(background(activity,0xFF101014,24));
        FrameLayout.LayoutParams panelParams=new FrameLayout.LayoutParams(-1,Math.round(activity.getResources().getDisplayMetrics().heightPixels*.75f),Gravity.BOTTOM);root.addView(sheet,panelParams);
        FrameLayout grip=new FrameLayout(activity);grip.setContentDescription("向下滑动关闭");sheet.addView(grip,new LinearLayout.LayoutParams(-1,dp(activity,32)));
        View handle=new View(activity);GradientDrawable handleShape=new GradientDrawable();handleShape.setColor(0xFF48484D);handleShape.setCornerRadius(dp(activity,3));handle.setBackground(handleShape);
        grip.addView(handle,new FrameLayout.LayoutParams(dp(activity,36),dp(activity,5),Gravity.CENTER));
        dialog.panel=sheet;dialog.scrim=outside;
        grip.setOnTouchListener(new View.OnTouchListener(){
            float start;android.view.VelocityTracker velocity;
            public boolean onTouch(View view,MotionEvent event){
                int action=event.getActionMasked();
                if(action==MotionEvent.ACTION_DOWN){sheet.animate().cancel();start=event.getRawY()-sheet.getTranslationY();velocity=android.view.VelocityTracker.obtain();}
                if(velocity==null)return true;velocity.addMovement(event);
                if(action==MotionEvent.ACTION_MOVE){float y=Math.max(0,event.getRawY()-start);sheet.setTranslationY(y);outside.setAlpha(Math.max(0,1-y/Math.max(1,sheet.getHeight())));}
                if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){velocity.computeCurrentVelocity(1000);boolean close=action==MotionEvent.ACTION_UP&&PanelDismiss.shouldClose(sheet.getTranslationY(),velocity.getYVelocity(),sheet.getHeight(),activity.getResources().getDisplayMetrics().density);velocity.recycle();velocity=null;if(close)dialog.dismiss();else{sheet.animate().translationY(0).setDuration(220).start();outside.animate().alpha(1).setDuration(220).start();}}
                return true;
            }
        });
        LinearLayout heading=new LinearLayout(activity);heading.setGravity(Gravity.CENTER_VERTICAL);sheet.addView(heading,new LinearLayout.LayoutParams(-1,dp(activity,48)));
        TextView titleView=new TextView(activity);titleView.setText(title);titleView.setTextColor(Color.WHITE);titleView.setTextSize(21);titleView.setTypeface(null,Typeface.BOLD);heading.addView(titleView,new LinearLayout.LayoutParams(0,-2,1));
        TextView close=new TextView(activity);close.setText("×");close.setTextSize(28);close.setTextColor(0xCCFFFFFF);close.setGravity(Gravity.CENTER);close.setContentDescription("关闭");close.setBackground(new RippleDrawable(ColorStateList.valueOf(0x44FFFFFF),null,null));close.setOnClickListener(view->dialog.dismiss());ButtonFeedback.install(close);heading.addView(close,new LinearLayout.LayoutParams(dp(activity,42),dp(activity,42)));
        ScrollView scroll=new ScrollView(activity);scroll.setFillViewport(false);scroll.setVerticalScrollBarEnabled(false);sheet.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout body=new LinearLayout(activity);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(0,dp(activity,10),0,dp(activity,16));scroll.addView(body);content.accept(body);
        dialog.setContentView(root);dialog.show();Window window=dialog.getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.setLayout(-1,-1);
            window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.setStatusBarColor(Color.TRANSPARENT);window.setNavigationBarColor(Color.TRANSPARENT);
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
            if(android.os.Build.VERSION.SDK_INT>=29)window.setNavigationBarContrastEnforced(false);
        }
        root.setOnApplyWindowInsetsListener((v,insets)->{int bottom=insets.getSystemWindowInsetBottom(),left=insets.getSystemWindowInsetLeft(),right=insets.getSystemWindowInsetRight();sheet.setPadding(dp(activity,20)+left,0,dp(activity,20)+right,dp(activity,12)+bottom);panelParams.height=Math.min(Math.round(root.getHeight()*.75f),Math.max(dp(activity,100),root.getHeight()-insets.getSystemWindowInsetTop()));sheet.setLayoutParams(panelParams);return insets;});
        root.post(root::requestApplyInsets);
        sheet.setTranslationY(activity.getResources().getDisplayMetrics().heightPixels);sheet.animate().translationY(0).setDuration(280).start();
        return dialog;
    }
    private static final class SheetDialog extends Dialog {
        View panel,scrim;boolean closing;
        SheetDialog(Activity activity){super(activity);}
        @Override public void cancel(){dismiss();}
        @Override public void dismiss(){
            if(closing)return;
            if(panel==null||!isShowing()){super.dismiss();return;}
            closing=true;panel.animate().cancel();scrim.animate().cancel();
            scrim.animate().alpha(0).setDuration(220).start();
            panel.animate().translationY(panel.getHeight()).setDuration(240).withEndAction(()->SheetDialog.super.dismiss()).start();
        }
    }
    static TextView action(Activity activity,LinearLayout body,String text,Runnable runnable){
        TextView row=new TextView(activity);row.setText(text);row.setTextColor(Color.WHITE);row.setTextSize(16);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(activity,14),0,dp(activity,14),0);
        row.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33FFFFFF),null,null));row.setOnClickListener(view->runnable.run());ButtonFeedback.install(row);body.addView(row,new LinearLayout.LayoutParams(-1,dp(activity,54)));return row;
    }
}
