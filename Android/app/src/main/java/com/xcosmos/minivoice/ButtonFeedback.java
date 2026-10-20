package com.xcosmos.minivoice;

import android.animation.*;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import java.util.WeakHashMap;

/** Uses pressed state, preserving each button's click, ripple, and gesture handling. */
final class ButtonFeedback {
    private static final WeakHashMap<View,Boolean> installed=new WeakHashMap<>();
    static void install(View view){
        if(installed.containsKey(view))return;installed.put(view,true);
        if(view.getBackground() instanceof android.graphics.drawable.RippleDrawable){
            android.graphics.drawable.RippleDrawable old=(android.graphics.drawable.RippleDrawable)view.getBackground();
            android.graphics.drawable.Drawable mask=old.findDrawableByLayerId(android.R.id.mask),content=old.getNumberOfLayers()>0?old.getDrawable(0):null;if(content==mask)content=null;
            android.graphics.drawable.GradientDrawable bounded=new android.graphics.drawable.GradientDrawable();bounded.setColor(android.graphics.Color.WHITE);bounded.setCornerRadius(28*view.getResources().getDisplayMetrics().density);
            view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x16FFFFFF),content,bounded));
        }
        view.setOnTouchListener((v,event)->{if(event.getActionMasked()==android.view.MotionEvent.ACTION_UP&&v.isPressed()&&v.isEnabled())v.performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);return false;});
        float down=view instanceof ViewGroup ? .98f : .94f;
        StateListAnimator states=new StateListAnimator();
        AnimatorSet press=new AnimatorSet();press.playTogether(ObjectAnimator.ofFloat(view,"scaleX",down),ObjectAnimator.ofFloat(view,"scaleY",down));press.setDuration(90);press.setInterpolator(new DecelerateInterpolator());
        AnimatorSet release=new AnimatorSet();release.playTogether(ObjectAnimator.ofFloat(view,"scaleX",1),ObjectAnimator.ofFloat(view,"scaleY",1));release.setDuration(150);release.setInterpolator(new OvershootInterpolator(1.2f));
        states.addState(new int[]{android.R.attr.state_pressed,android.R.attr.state_enabled},press);states.addState(new int[]{},release);view.setStateListAnimator(states);
    }
    static void installTree(View root){
        if(root.isClickable()&&root.getClass()!=View.class&&!(root instanceof android.widget.EditText)&&!(root instanceof android.widget.SeekBar)&&!(root instanceof WallSearchControl))install(root);
        if(root instanceof ViewGroup){ViewGroup group=(ViewGroup)root;for(int i=0;i<group.getChildCount();i++)installTree(group.getChildAt(i));}
    }
}
