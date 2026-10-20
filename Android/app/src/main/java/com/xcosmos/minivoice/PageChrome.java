package com.xcosmos.minivoice;

import android.app.Dialog;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.view.*;

/** Opaque, non-floating settings pages with edge-to-edge system navigation. */
final class PageChrome {
    static void apply(Dialog page,AppAppearance.Palette colors){
        Window window=page.getWindow();if(window==null)return;
        window.setLayout(-1,-1);window.setBackgroundDrawable(new ColorDrawable(colors.background));
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND|WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS|WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(colors.background);window.setNavigationBarColor(Color.TRANSPARENT);window.setNavigationBarDividerColor(Color.TRANSPARENT);
        window.setStatusBarContrastEnforced(false);window.setNavigationBarContrastEnforced(false);
        int flags=View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
        if(!colors.dark)flags|=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        window.getDecorView().setSystemUiVisibility(flags);
        WindowManager.LayoutParams attributes=window.getAttributes();attributes.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;window.setAttributes(attributes);
        if(Build.VERSION.SDK_INT>=30){window.setDecorFitsSystemWindows(false);WindowInsetsController controller=window.getInsetsController();if(controller!=null){int appearance=WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS|WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;controller.setSystemBarsAppearance(colors.dark?0:appearance,appearance);controller.show(WindowInsets.Type.systemBars());}}
    }
}
