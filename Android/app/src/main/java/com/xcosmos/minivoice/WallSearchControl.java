package com.xcosmos.minivoice;

import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

/** Right-anchored search field with an immediate, reversible horizontal transition. */
final class WallSearchControl extends FrameLayout {
    final EditText input;
    private final Activity activity;
    private final ImageView lens;
    private final TextView clear;
    private ValueAnimator animator;
    private boolean open;
    private float amount;
    private final android.animation.ArgbEvaluator tint=new android.animation.ArgbEvaluator();
    private boolean simpleStyle;
    private final android.graphics.Paint surfacePaint=new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
    private AppAppearance.Palette colors=new AppAppearance.Palette(true);
    WallSearchControl(Activity activity){
        super(activity);this.activity=activity;setWillNotDraw(false);setClipChildren(true);setClipToPadding(true);
        setBackground(WallToolStyle.glass(activity));
        lens=new ImageView(activity);lens.setImageDrawable(new WallToolStyle.Glyph(WallToolStyle.Glyph.SEARCH));lens.setScaleType(ImageView.ScaleType.FIT_CENTER);int inset=dp((WallToolStyle.SIDE-WallToolStyle.ICON)/2f);lens.setPadding(inset,inset,inset,inset);lens.setContentDescription("搜索音乐");
        lens.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x44FFFFFF),null,null));addView(lens,new LayoutParams(dp(WallToolStyle.SIDE),dp(WallToolStyle.SIDE),Gravity.LEFT));
        input=new EditText(activity);input.setSingleLine(true);input.setImeOptions(EditorInfo.IME_ACTION_SEARCH);input.setTextColor(Color.WHITE);input.setHintTextColor(0xFFB9C5BE);input.setHint("搜索音乐");input.setTextSize(14);input.setBackgroundColor(Color.TRANSPARENT);input.setPadding(0,0,0,0);input.setVisibility(INVISIBLE);
        LayoutParams field=new LayoutParams(-1,-1);field.leftMargin=dp(WallToolStyle.SIDE);field.rightMargin=dp(38);addView(input,field);
        clear=new TextView(activity);clear.setText("×");clear.setTextSize(24);clear.setTextColor(0xFFBAC5BF);clear.setGravity(Gravity.CENTER);clear.setContentDescription("清除搜索");addView(clear,new LayoutParams(dp(38),-1,Gravity.RIGHT));clear.setVisibility(INVISIBLE);clear.setOnClickListener(v->input.setText(""));
        lens.setOnClickListener(v->{if(open){if(animator!=null&&animator.isRunning())return;input.requestFocus();keyboard();}else setOpen(true,true);});
        input.setOnEditorActionListener((v,action,event)->{if(action==EditorInfo.IME_ACTION_SEARCH){hideKeyboard();input.clearFocus();if(input.length()==0)setOpen(false,true);return true;}return false;});
        input.setOnFocusChangeListener((v,focused)->{if(!focused&&open&&input.length()==0)setOpen(false,true);});
        input.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void onTextChanged(CharSequence s,int start,int before,int count){clear.setVisibility(open&&s.length()>0?VISIBLE:INVISIBLE);}public void afterTextChanged(android.text.Editable e){}});
        ButtonFeedback.install(lens);lens.setStateListAnimator(null);ButtonFeedback.install(clear);
        addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{if(getParent() instanceof View&&((View)getParent()).getWidth()>0&&r-l!=Math.round(targetWidth()))apply(amount);});
    }
    private int dp(float value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private float targetWidth(){int parent=getParent() instanceof View?((View)getParent()).getWidth():getResources().getDisplayMetrics().widthPixels;return dp(WallToolStyle.SIDE)+(Math.min(dp(320),Math.max(dp(WallToolStyle.SIDE),availableWidth(parent)))-dp(WallToolStyle.SIDE))*amount;}
    private int availableWidth(int parent){FrameLayout.LayoutParams params=(FrameLayout.LayoutParams)getLayoutParams();return params==null?parent-dp(100):parent-params.leftMargin-params.rightMargin;}
    private void apply(float value){amount=value;FrameLayout.LayoutParams params=(FrameLayout.LayoutParams)getLayoutParams();if(params!=null){int width=Math.round(targetWidth());if(params.width!=width){params.width=width;setLayoutParams(params);}}
        input.setAlpha(Math.max(0,(value-.25f)/.75f));lens.setColorFilter((Integer)tint.evaluate(value,colors.text,colors.accent));clear.setAlpha(value);invalidate();
    }
    void configure(AppAppearance.Palette palette){colors=palette;input.setTextColor(colors.text);input.setHintTextColor(colors.secondary);clear.setTextColor(colors.secondary);GradientDrawable mask=new GradientDrawable();mask.setColor(Color.WHITE);mask.setShape(GradientDrawable.OVAL);lens.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(colors.dark?0x20FFFFFF:0x140A8763),null,mask));apply(amount);}
    void simpleStyle(boolean value){simpleStyle=value;invalidate();}
    @Override protected void onDraw(android.graphics.Canvas canvas){
        super.onDraw(canvas);
        if(simpleStyle&&amount>0){
            surfacePaint.setStyle(android.graphics.Paint.Style.FILL);
            surfacePaint.setColor(colors.line);
            surfacePaint.setAlpha(Math.round(android.graphics.Color.alpha(colors.line)*amount));
            canvas.drawRoundRect(0,0,getWidth(),getHeight(),dp(28),dp(28),surfacePaint);
            surfacePaint.setStyle(android.graphics.Paint.Style.STROKE);surfacePaint.setStrokeWidth(dp(1));surfacePaint.setColor(colors.line);surfacePaint.setAlpha(Math.round(android.graphics.Color.alpha(colors.line)*amount));
            canvas.drawRoundRect(dp(.5f),dp(.5f),getWidth()-dp(.5f),getHeight()-dp(.5f),dp(28),dp(28),surfacePaint);
        }
    }
    boolean isOpen(){return open;}
    void setOpen(boolean value,boolean animate){
        open=value;if(animator!=null){animator.removeAllListeners();animator.cancel();}
        if(!value){hideKeyboard();input.clearFocus();}
        else input.setVisibility(VISIBLE);
        clear.setVisibility(value&&input.length()>0?VISIBLE:INVISIBLE);
        if(!animate||!ValueAnimator.areAnimatorsEnabled()){apply(value?1:0);setScaleX(1);setScaleY(1);input.setVisibility(value?VISIBLE:INVISIBLE);if(value&&animate){input.requestFocus();keyboard();}return;}
        float start=amount,target=value?1:0;
        setScaleX(1);setScaleY(1);
        animator=ValueAnimator.ofFloat(start,target);animator.setDuration(Math.max(100,Math.round((value?280:220)*Math.abs(target-start))));
        animator.setInterpolator(new android.view.animation.DecelerateInterpolator(1.5f));
        animator.addUpdateListener(a->apply((float)a.getAnimatedValue()));
        animator.addListener(new android.animation.AnimatorListenerAdapter(){@Override public void onAnimationEnd(android.animation.Animator animation){setScaleX(1);setScaleY(1);input.setVisibility(open?VISIBLE:INVISIBLE);if(open){input.requestFocus();keyboard();}}});animator.start();
    }
    void clearQuery(){input.setText("");setOpen(false,false);}
    private void keyboard(){input.post(()->{if(open&&getVisibility()==VISIBLE&&input.hasFocus())((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).showSoftInput(input,InputMethodManager.SHOW_IMPLICIT);});}
    private void hideKeyboard(){((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(input.getWindowToken(),0);}
    @Override protected void onDetachedFromWindow(){if(animator!=null){animator.removeAllListeners();animator.cancel();}super.onDetachedFromWindow();}
}
