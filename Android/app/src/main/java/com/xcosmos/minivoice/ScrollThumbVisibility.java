package com.xcosmos.minivoice;

import android.animation.ValueAnimator;
import android.view.View;

/** Hidden at rest, held visible while scrolling/dragging, then faded after a short pause. */
final class ScrollThumbVisibility {
    private final View host;
    private boolean held;
    private final Runnable hide;
    ScrollThumbVisibility(View host){
        this.host=host;host.setAlpha(0);
        hide=()->{if(!held){if(ValueAnimator.areAnimatorsEnabled())host.animate().alpha(0).setDuration(200).start();else host.setAlpha(0);}};
    }
    void pulse(){host.removeCallbacks(hide);host.animate().cancel();host.setAlpha(1);if(!held)host.postDelayed(hide,800);}
    void hold(boolean value){held=value;pulse();}
    boolean visible(){return host.getAlpha()>.05f;}
    void clear(){held=false;host.removeCallbacks(hide);host.animate().cancel();host.setAlpha(0);}
}
