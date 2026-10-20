package com.xcosmos.minivoice;

final class FocusCardPresentation {
    static boolean compact(float wallScale,boolean expanded){return !expanded&&wallScale<.7f;}
    static float contentScale(float width,float density){return Math.max(.1f,Math.min(2,width/(352*density)));}
}
