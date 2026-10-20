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
        float down=view instanceof ViewGroup ? .98f : .90f;
        StateListAnimator states=new StateListAnimator();
        AnimatorSet press=new AnimatorSet();press.playTogether(ObjectAnimator.ofFloat(view,"scaleX",down),ObjectAnimator.ofFloat(view,"scaleY",down));press.setDuration(90);press.setInterpolator(new DecelerateInterpolator());
        AnimatorSet release=new AnimatorSet();release.playTogether(ObjectAnimator.ofFloat(view,"scaleX",1),ObjectAnimator.ofFloat(view,"scaleY",1));release.setDuration(230);release.setInterpolator(new OvershootInterpolator(1.2f));
        states.addState(new int[]{android.R.attr.state_pressed,android.R.attr.state_enabled},press);states.addState(new int[]{},release);view.setStateListAnimator(states);
    }
    static void installTree(View root){
        if(root.isClickable()&&root.getClass()!=View.class&&!(root instanceof android.widget.EditText)&&!(root instanceof android.widget.SeekBar)&&!(root instanceof WallSearchControl))install(root);
        if(root instanceof ViewGroup){ViewGroup group=(ViewGroup)root;for(int i=0;i<group.getChildCount();i++)installTree(group.getChildAt(i));}
    }
}
