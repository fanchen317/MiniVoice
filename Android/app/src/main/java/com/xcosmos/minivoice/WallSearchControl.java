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

/** Right-anchored search lens: grow first, then open horizontally, like the Mac wall. */
final class WallSearchControl extends FrameLayout {
    final EditText input;
    private final Activity activity;
    private final ImageView lens;
    private final TextView clear;
    private ValueAnimator animator;
    private boolean open;
    private float amount;
    WallSearchControl(Activity activity){
        super(activity);this.activity=activity;setClipChildren(true);setClipToPadding(true);
        GradientDrawable glass=new GradientDrawable();glass.setColor(0xED252A28);glass.setCornerRadius(dp(26));glass.setStroke(dp(1),0x66FFFFFF);setBackground(glass);
        lens=new ImageView(activity);lens.setImageResource(R.drawable.icon_wall_search);lens.setScaleType(ImageView.ScaleType.FIT_CENTER);lens.setPadding(dp(12),dp(12),dp(12),dp(12));lens.setContentDescription("搜索音乐");addView(lens,new LayoutParams(dp(52),dp(52),Gravity.LEFT));
        input=new EditText(activity);input.setSingleLine(true);input.setImeOptions(EditorInfo.IME_ACTION_SEARCH);input.setTextColor(Color.WHITE);input.setHintTextColor(0xFFB9C5BE);input.setHint("搜索音乐");input.setTextSize(14);input.setBackgroundColor(Color.TRANSPARENT);input.setPadding(0,0,0,0);input.setVisibility(INVISIBLE);
        LayoutParams field=new LayoutParams(-1,-1);field.leftMargin=dp(54);field.rightMargin=dp(38);addView(input,field);
        clear=new TextView(activity);clear.setText("×");clear.setTextSize(24);clear.setTextColor(0xFFBAC5BF);clear.setGravity(Gravity.CENTER);clear.setContentDescription("清除搜索");addView(clear,new LayoutParams(dp(38),-1,Gravity.RIGHT));clear.setVisibility(INVISIBLE);clear.setOnClickListener(v->input.setText(""));
        lens.setOnClickListener(v->{if(open){input.requestFocus();keyboard();}else setOpen(true,true);});
        input.setOnEditorActionListener((v,action,event)->{if(action==EditorInfo.IME_ACTION_SEARCH){hideKeyboard();input.clearFocus();if(input.length()==0)setOpen(false,true);return true;}return false;});
        input.setOnFocusChangeListener((v,focused)->{if(!focused&&open&&input.length()==0)setOpen(false,true);});
        input.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void onTextChanged(CharSequence s,int start,int before,int count){clear.setVisibility(open&&s.length()>0?VISIBLE:INVISIBLE);}public void afterTextChanged(android.text.Editable e){}});
        addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{if(getParent() instanceof View&&((View)getParent()).getWidth()>0&&r-l!=Math.round(targetWidth()))apply(amount);});
    }
    private int dp(float value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private float targetWidth(){int parent=getParent() instanceof View?((View)getParent()).getWidth():getResources().getDisplayMetrics().widthPixels;return dp(52)+(Math.min(dp(320),Math.max(dp(52),parent-dp(100)))-dp(52))*amount;}
    private void apply(float value){amount=value;FrameLayout.LayoutParams params=(FrameLayout.LayoutParams)getLayoutParams();if(params!=null){int width=Math.round(targetWidth());if(params.width!=width){params.width=width;setLayoutParams(params);}}
        input.setAlpha(Math.max(0,(value-.25f)/.75f));lens.setColorFilter(value>0?0xFF2DD3A8:Color.WHITE);clear.setAlpha(value);
    }
    boolean isOpen(){return open;}
    void setOpen(boolean value,boolean animate){
        open=value;if(animator!=null){animator.removeAllListeners();animator.cancel();}
        if(!value){hideKeyboard();input.clearFocus();}
        else input.setVisibility(VISIBLE);
        clear.setVisibility(value&&input.length()>0?VISIBLE:INVISIBLE);
        if(!animate){apply(value?1:0);setScaleX(1);setScaleY(1);input.setVisibility(value?VISIBLE:INVISIBLE);return;}
        float start=amount;boolean grow=value&&start==0;
        animator=ValueAnimator.ofFloat(0,1);animator.setDuration(value?600:360);
        animator.addUpdateListener(a->{float t=(float)a.getAnimatedValue();float expansion=grow?Math.max(0,(t-.4f)/.6f):t;float eased=1-(float)Math.pow(1-expansion,3);apply(start+((value?1:0)-start)*eased);
            setPivotX(getWidth()-dp(26));setPivotY(getHeight()/2f);float pulse=grow?(t<.4f?t/.4f:1-(t-.4f)/.6f):0;setScaleX(1+.10f*pulse);setScaleY(1+.10f*pulse);
        });
        animator.addListener(new android.animation.AnimatorListenerAdapter(){@Override public void onAnimationEnd(android.animation.Animator animation){setScaleX(1);setScaleY(1);input.setVisibility(open?VISIBLE:INVISIBLE);if(open){input.requestFocus();keyboard();}}});animator.start();
    }
    void clearQuery(){input.setText("");setOpen(false,false);}
    private void keyboard(){input.post(()->{if(open&&getVisibility()==VISIBLE&&input.hasFocus())((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).showSoftInput(input,InputMethodManager.SHOW_IMPLICIT);});}
    private void hideKeyboard(){((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(input.getWindowToken(),0);}
    @Override protected void onDetachedFromWindow(){if(animator!=null){animator.removeAllListeners();animator.cancel();}super.onDetachedFromWindow();}
}
