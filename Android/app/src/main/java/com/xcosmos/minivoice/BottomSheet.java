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
        GlassBackdrop backdrop=new GlassBackdrop(activity.getWindow().getDecorView(),false);
        FrameLayout root=new FrameLayout(activity);
        View outside=new View(activity);outside.setBackgroundColor(0x99000000);root.addView(outside,new FrameLayout.LayoutParams(-1,-1));outside.setOnClickListener(v->dialog.dismiss());
        LinearLayout sheet=new LinearLayout(activity);sheet.setOrientation(LinearLayout.VERTICAL);sheet.setPadding(dp(activity,20),0,dp(activity,20),dp(activity,12));sheet.setBackground(backdrop.surface(sheet,24,true));
        FrameLayout.LayoutParams panelParams=new FrameLayout.LayoutParams(-1,Math.round(activity.getResources().getDisplayMetrics().heightPixels*.75f),Gravity.BOTTOM);root.addView(sheet,panelParams);
        FrameLayout grip=new FrameLayout(activity);grip.setContentDescription("上下拖动调整面板高度，继续下拉关闭");sheet.addView(grip,new LinearLayout.LayoutParams(-1,dp(activity,32)));
        View handle=new View(activity);GradientDrawable handleShape=new GradientDrawable();handleShape.setColor(0xFF48484D);handleShape.setCornerRadius(dp(activity,3));handle.setBackground(handleShape);
        grip.addView(handle,new FrameLayout.LayoutParams(dp(activity,36),dp(activity,5),Gravity.CENTER));
        dialog.panel=sheet;dialog.scrim=outside;
        LinearLayout heading=new LinearLayout(activity);heading.setGravity(Gravity.CENTER_VERTICAL);sheet.addView(heading,new LinearLayout.LayoutParams(-1,dp(activity,48)));
        TextView titleView=new TextView(activity);titleView.setText(title);titleView.setTextColor(Color.WHITE);titleView.setTextSize(21);titleView.setTypeface(null,Typeface.BOLD);heading.addView(titleView,new LinearLayout.LayoutParams(0,-2,1));
        TextView close=new TextView(activity);close.setText("×");close.setTextSize(28);close.setTextColor(0xCCFFFFFF);close.setGravity(Gravity.CENTER);close.setContentDescription("关闭");close.setBackground(new RippleDrawable(ColorStateList.valueOf(0x44FFFFFF),null,null));close.setOnClickListener(view->dialog.dismiss());ButtonFeedback.install(close);heading.addView(close,new LinearLayout.LayoutParams(dp(activity,42),dp(activity,42)));
        SheetScroll scroll=new SheetScroll(activity);scroll.setFillViewport(false);scroll.setVerticalScrollBarEnabled(false);sheet.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout body=new LinearLayout(activity);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(0,dp(activity,10),0,dp(activity,16));scroll.addView(body);content.accept(body);
        Drag drag=new Drag(activity,dialog,sheet,outside,panelParams,root);grip.setOnTouchListener(drag);heading.setOnTouchListener(drag);scroll.drag=drag;
        dialog.setContentView(root);dialog.show();Window window=dialog.getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.setLayout(-1,-1);
            window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.setStatusBarColor(Color.TRANSPARENT);window.setNavigationBarColor(Color.TRANSPARENT);
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
            if(android.os.Build.VERSION.SDK_INT>=29){window.setNavigationBarContrastEnforced(false);window.setStatusBarContrastEnforced(false);}
            if(android.os.Build.VERSION.SDK_INT>=30)window.setDecorFitsSystemWindows(false);
            WindowManager.LayoutParams attributes=window.getAttributes();attributes.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;window.setAttributes(attributes);
        }
        root.setOnApplyWindowInsetsListener((v,insets)->{int bottom=insets.getSystemWindowInsetBottom(),left=insets.getSystemWindowInsetLeft(),right=insets.getSystemWindowInsetRight();sheet.setPadding(dp(activity,20)+left,0,dp(activity,20)+right,dp(activity,12)+bottom);drag.top=insets.getSystemWindowInsetTop();drag.initial=Math.min(Math.round(root.getHeight()*.75f),Math.max(dp(activity,100),root.getHeight()-drag.top));if(!drag.expanded){panelParams.height=drag.initial;sheet.setLayoutParams(panelParams);}return insets;});
        root.post(root::requestApplyInsets);
        sheet.setTranslationY(activity.getResources().getDisplayMetrics().heightPixels);sheet.animate().translationY(0).setDuration(280).start();
        return dialog;
    }
    private static final class SheetScroll extends ScrollView {
        Drag drag;MotionEvent down;boolean moving;
        SheetScroll(Activity activity){super(activity);}
        @Override public boolean onInterceptTouchEvent(MotionEvent e){
            if(e.getActionMasked()==MotionEvent.ACTION_DOWN){if(down!=null)down.recycle();down=MotionEvent.obtain(e);moving=false;}
            if(e.getActionMasked()==MotionEvent.ACTION_MOVE&&down!=null&&drag!=null){float delta=e.getRawY()-down.getRawY();
                if(Math.abs(delta)>android.view.ViewConfiguration.get(getContext()).getScaledTouchSlop()&&(!drag.expanded||delta>0&&getScrollY()==0)){moving=true;drag.onTouch(this,down);return true;}}
            return super.onInterceptTouchEvent(e);
        }
        @Override public boolean onTouchEvent(MotionEvent e){if(moving&&drag!=null){drag.onTouch(this,e);if(e.getActionMasked()==MotionEvent.ACTION_UP||e.getActionMasked()==MotionEvent.ACTION_CANCEL)moving=false;return true;}return super.onTouchEvent(e);}
        @Override protected void onDetachedFromWindow(){if(down!=null){down.recycle();down=null;}super.onDetachedFromWindow();}
    }
    /** Two resting heights, with downward overscroll reserved for dismissal. */
    private static final class Drag implements View.OnTouchListener {
        final Activity activity;final SheetDialog dialog;final View sheet,scrim,root;final FrameLayout.LayoutParams params;
        int initial,top,startHeight;boolean expanded;float start;android.view.VelocityTracker velocity;
        Drag(Activity a,SheetDialog d,View s,View scrim,FrameLayout.LayoutParams p,View root){activity=a;dialog=d;sheet=s;this.scrim=scrim;params=p;this.root=root;initial=p.height;}
        public boolean onTouch(View v,MotionEvent e){int action=e.getActionMasked();
            if(action==MotionEvent.ACTION_DOWN){sheet.animate().cancel();start=e.getRawY();startHeight=params.height;velocity=android.view.VelocityTracker.obtain();}
            if(velocity==null)return true;velocity.addMovement(e);
            float dy=e.getRawY()-start;int max=Math.max(initial,root.getHeight()-top);
            if(action==MotionEvent.ACTION_MOVE){int wanted=Math.round(startHeight-dy);params.height=Math.max(initial,Math.min(max,wanted));sheet.setLayoutParams(params);sheet.setTranslationY(Math.max(0,initial-wanted));scrim.setAlpha(Math.max(0,1-sheet.getTranslationY()/initial));}
            if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){velocity.computeCurrentVelocity(1000);float speed=velocity.getYVelocity();velocity.recycle();velocity=null;
                if(action==MotionEvent.ACTION_UP&&PanelDismiss.shouldClose(sheet.getTranslationY(),speed,initial,activity.getResources().getDisplayMetrics().density)){dialog.dismiss();return true;}
                boolean up=action!=MotionEvent.ACTION_CANCEL&&(speed< -600||speed<600&&params.height>(initial+max)/2);expanded=up;
                int from=params.height,to=up?max:initial;android.animation.ValueAnimator animator=android.animation.ValueAnimator.ofInt(from,to);animator.setDuration(220);animator.addUpdateListener(a->{params.height=(int)a.getAnimatedValue();sheet.setLayoutParams(params);});animator.start();sheet.animate().translationY(0).setDuration(220).start();scrim.animate().alpha(1).setDuration(220).start();
            }return true;
        }
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
