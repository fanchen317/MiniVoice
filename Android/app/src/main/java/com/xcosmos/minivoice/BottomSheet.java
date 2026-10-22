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
        return show(activity,title,content,false);
    }
    static Dialog queue(Activity activity,String title,Consumer<LinearLayout> content){return show(activity,title,content,true);}
    private static Dialog show(Activity activity,String title,Consumer<LinearLayout> content,boolean queue){
        AppAppearance.Palette colors=DialogSurface.palette(activity);
        SheetDialog dialog=new SheetDialog(activity);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        FrameLayout root=new FrameLayout(activity);
        View outside=new View(activity);outside.setBackgroundColor(DialogSurface.scrim(colors));root.addView(outside,new FrameLayout.LayoutParams(-1,-1));outside.setOnClickListener(v->dialog.dismiss());
        LinearLayout sheet=new LinearLayout(activity);sheet.setOrientation(LinearLayout.VERTICAL);sheet.setPadding(dp(activity,20),0,dp(activity,20),dp(activity,12));GradientDrawable surface=DialogSurface.background(activity,colors,false);sheet.setBackground(surface);
        FrameLayout.LayoutParams panelParams=new FrameLayout.LayoutParams(Math.min(dp(activity,560),activity.getResources().getDisplayMetrics().widthPixels-dp(activity,24)),activity.getResources().getDisplayMetrics().heightPixels,Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);panelParams.bottomMargin=dp(activity,12);root.addView(sheet,panelParams);
        FrameLayout grip=new FrameLayout(activity);grip.setContentDescription("上下拖动调整面板高度，继续下拉关闭");sheet.addView(grip,new LinearLayout.LayoutParams(-1,dp(activity,32)));
        View handle=new View(activity);GradientDrawable handleShape=new GradientDrawable();handleShape.setColor(colors.secondary);handleShape.setCornerRadius(dp(activity,3));handle.setBackground(handleShape);
        grip.addView(handle,new FrameLayout.LayoutParams(dp(activity,36),dp(activity,5),Gravity.CENTER));
        dialog.panel=sheet;dialog.scrim=outside;
        LinearLayout heading=new LinearLayout(activity);heading.setGravity(Gravity.CENTER_VERTICAL);sheet.addView(heading,new LinearLayout.LayoutParams(-1,dp(activity,48)));
        TextView titleView=new TextView(activity);titleView.setText(title);titleView.setTextColor(colors.text);titleView.setTextSize(21);titleView.setTypeface(null,Typeface.BOLD);heading.addView(titleView,new LinearLayout.LayoutParams(0,-2,1));
        TextView close=new TextView(activity);close.setText("×");close.setTextSize(28);close.setTextColor(colors.secondary);close.setGravity(Gravity.CENTER);close.setContentDescription("关闭");close.setBackground(new RippleDrawable(ColorStateList.valueOf(colors.accent&0x00FFFFFF|0x22000000),null,null));close.setOnClickListener(view->dialog.dismiss());ButtonFeedback.install(close);heading.addView(close,new LinearLayout.LayoutParams(dp(activity,42),dp(activity,42)));
        SheetScroll scroll=new SheetScroll(activity);scroll.setFillViewport(false);ListScrollStyle.apply(scroll);FrameLayout scrollArea=new FrameLayout(activity);sheet.addView(scrollArea,new LinearLayout.LayoutParams(-1,0,1));scrollArea.addView(scroll,new FrameLayout.LayoutParams(-1,-1));
        LinearLayout body=new LinearLayout(activity);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(0,dp(activity,10),0,dp(activity,16));scroll.addView(body);content.accept(body);
        if(queue){scroll.setVerticalScrollBarEnabled(false);body.setPadding(0,dp(activity,10),dp(activity,32),dp(activity,16));QueueScrollThumb thumb=new QueueScrollThumb(scroll);scrollArea.addView(thumb,new FrameLayout.LayoutParams(dp(activity,32),-1,Gravity.RIGHT));dialog.queueThumb=thumb;scrollArea.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->thumb.invalidate());}
        Drag drag=new Drag(activity,dialog,sheet,outside,panelParams,root,body);grip.setOnTouchListener(drag);heading.setOnTouchListener(drag);scroll.drag=drag;dialog.drag=drag;
        dialog.setContentView(root);dialog.show();Window window=dialog.getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.setLayout(-1,-1);
            window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.setStatusBarColor(Color.TRANSPARENT);window.setNavigationBarColor(Color.TRANSPARENT);
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
            if(android.os.Build.VERSION.SDK_INT>=29){window.setNavigationBarContrastEnforced(false);window.setStatusBarContrastEnforced(false);}
            if(android.os.Build.VERSION.SDK_INT>=30)window.setDecorFitsSystemWindows(false);
            WindowManager.LayoutParams attributes=window.getAttributes();attributes.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;window.setAttributes(attributes);
        }
        root.setOnApplyWindowInsetsListener((v,insets)->{sheet.setPadding(dp(activity,20)+insets.getSystemWindowInsetLeft(),0,dp(activity,20)+insets.getSystemWindowInsetRight(),dp(activity,12)+insets.getSystemWindowInsetBottom());drag.top=insets.getSystemWindowInsetTop();root.post(drag::layout);return insets;});
        root.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{if(b-t!=ob-ot)drag.layout();});
        sheet.setVisibility(View.INVISIBLE);root.post(()->{root.requestApplyInsets();drag.layout();});
        return dialog;
    }
    private static final class SheetScroll extends ScrollView {
        Drag drag;MotionEvent down;boolean moving;
        SheetScroll(Activity activity){super(activity);}
        @Override public boolean onInterceptTouchEvent(MotionEvent e){
            if(drag!=null&&drag.dialog.closing)return false;
            if(e.getActionMasked()==MotionEvent.ACTION_DOWN){if(down!=null)down.recycle();down=MotionEvent.obtain(e);moving=false;}
            if(startDrag(e))return true;
            return super.onInterceptTouchEvent(e);
        }
        private boolean startDrag(MotionEvent e){
            if(moving||e.getActionMasked()!=MotionEvent.ACTION_MOVE||down==null||drag==null)return false;
            float dy=e.getRawY()-down.getRawY(),dx=e.getRawX()-down.getRawX();
            if(Math.abs(dy)>android.view.ViewConfiguration.get(getContext()).getScaledTouchSlop()&&Math.abs(dy)>Math.abs(dx)&&(!drag.expanded&&dy<0||dy>0&&!canScrollVertically(-1))){moving=true;drag.onTouch(this,down);getParent().requestDisallowInterceptTouchEvent(true);return true;}return false;
        }
        @Override public boolean onTouchEvent(MotionEvent e){
            if(drag!=null&&drag.dialog.closing)return true;
            startDrag(e);
            if(moving&&drag!=null){drag.onTouch(this,e);if(e.getActionMasked()==MotionEvent.ACTION_UP||e.getActionMasked()==MotionEvent.ACTION_CANCEL){moving=false;getParent().requestDisallowInterceptTouchEvent(false);}return true;}
            return super.onTouchEvent(e);
        }
        @Override protected void onDetachedFromWindow(){if(down!=null){down.recycle();down=null;}super.onDetachedFromWindow();}
    }
    /** A single animation owner for opening, settling, interruption and dismissal. */
    private static final class Drag implements View.OnTouchListener {
        final Activity activity;final SheetDialog dialog;final View sheet,scrim,root,content;final FrameLayout.LayoutParams params;
        int top;float start,startPosition,collapsed;boolean expanded,ready;android.view.VelocityTracker velocity;
        android.animation.ValueAnimator motion;
        Drag(Activity a,SheetDialog d,View s,View scrim,FrameLayout.LayoutParams p,View root,View content){this.content=content;activity=a;dialog=d;sheet=s;this.scrim=scrim;params=p;this.root=root;}
        void layout(){
            if(dialog.closing||root.getHeight()<=top)return;
            int available=root.getHeight()-top-params.bottomMargin;int natural=content.getMeasuredHeight()+dp(activity,80)+sheet.getPaddingTop()+sheet.getPaddingBottom();int height=Math.min(available,Math.max(dp(activity,180),natural));boolean first=!ready;
            if(!first&&params.height==height)return;
            stop();params.height=height;sheet.setLayoutParams(params);collapsed=natural<=available*.75f?0:Math.min(SheetPosition.collapsed(root.getHeight()),height);ready=true;
            if(first){sheet.setVisibility(View.VISIBLE);sheet.setTranslationY(height);animate(collapsed,null);}else position(expanded?0:collapsed);
        }
        void stop(){if(motion!=null){motion.removeAllListeners();motion.cancel();motion=null;}sheet.animate().cancel();scrim.animate().cancel();}
        void recycle(){if(velocity!=null){velocity.recycle();velocity=null;}}
        void position(float value){sheet.setTranslationY(value);if(dialog.queueThumb!=null)dialog.queueThumb.invalidate();scrim.setAlpha(value<=collapsed?1:Math.max(0,1-(value-collapsed)/Math.max(1,params.height-collapsed)));}
        void animate(float target,Runnable end){
            stop();android.animation.ValueAnimator animation=android.animation.ValueAnimator.ofFloat(sheet.getTranslationY(),target);motion=animation;animation.setDuration(dialog.closing?220:250);animation.setInterpolator(new android.view.animation.DecelerateInterpolator());
            animation.addUpdateListener(a->position((float)a.getAnimatedValue()));
            animation.addListener(new android.animation.AnimatorListenerAdapter(){@Override public void onAnimationEnd(android.animation.Animator a){if(motion!=a)return;motion=null;if(end!=null)end.run();}});animation.start();
        }
        public boolean onTouch(View v,MotionEvent e){
            if(dialog.closing||!ready)return true;int action=e.getActionMasked();
            if(action==MotionEvent.ACTION_DOWN){stop();recycle();start=e.getRawY();startPosition=sheet.getTranslationY();velocity=android.view.VelocityTracker.obtain();v.getParent().requestDisallowInterceptTouchEvent(true);}
            if(velocity==null)return true;velocity.addMovement(e);
            if(action==MotionEvent.ACTION_MOVE)position(SheetPosition.drag(startPosition,e.getRawY()-start,params.height));
            if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){velocity.computeCurrentVelocity(1000);float speed=velocity.getYVelocity();recycle();v.getParent().requestDisallowInterceptTouchEvent(false);float density=activity.getResources().getDisplayMetrics().density;
                if(action==MotionEvent.ACTION_UP&&PanelDismiss.shouldClose(Math.max(0,sheet.getTranslationY()-collapsed),speed,params.height,density)){dialog.dismiss();return true;}
                expanded=SheetPosition.expand(sheet.getTranslationY(),collapsed,speed,action==MotionEvent.ACTION_CANCEL,expanded,density);animate(expanded?0:collapsed,null);
            }return true;
        }
    }
    private static final class SheetDialog extends Dialog {
        View panel,scrim;QueueScrollThumb queueThumb;Drag drag;boolean closing;
        SheetDialog(Activity activity){super(activity);}
        @Override public void cancel(){dismiss();}
        @Override public void dismiss(){
            if(closing)return;if(panel==null||!isShowing()){super.dismiss();return;}
            closing=true;if(drag!=null){drag.recycle();drag.animate(Math.max(drag.params.height,panel.getHeight()),()->SheetDialog.super.dismiss());}else super.dismiss();
        }
        @Override protected void onStop(){if(drag!=null){drag.stop();drag.recycle();}super.onStop();}
    }
    static TextView action(Activity activity,LinearLayout body,String text,Runnable runnable){
        AppAppearance.Palette colors=DialogSurface.palette(activity);TextView row=new TextView(activity);row.setText(text);row.setTextColor(colors.text);row.setTextSize(16);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(activity,14),0,dp(activity,14),0);
        row.setBackground(new RippleDrawable(ColorStateList.valueOf(colors.accent&0x00FFFFFF|0x22000000),null,null));row.setOnClickListener(view->runnable.run());ButtonFeedback.install(row);body.addView(row,new LinearLayout.LayoutParams(-1,dp(activity,54)));return row;
    }
}
