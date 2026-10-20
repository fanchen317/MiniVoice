package com.xcosmos.minivoice;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;

final class AppAppearance {
    static String style(SharedPreferences prefs){String value=prefs.getString("player_style","wall");return value.equals("simple")||value.equals("library")?value:"wall";}
    static String theme(SharedPreferences prefs){String value=prefs.getString("appearance","system");return value.equals("light")||value.equals("dark")?value:"system";}
    static boolean dark(Context context,SharedPreferences prefs){String value=theme(prefs);return value.equals("dark")||value.equals("system")&&(context.getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES;}
    static final class Palette {
        final boolean dark;final int background,surface,text,secondary,line,accent;
        Palette(boolean dark){this.dark=dark;background=dark?0xFF111513:0xFFF5F7F5;surface=dark?0xFF1C2320:0xFFFFFFFF;text=dark?0xFFE9EFEA:0xFF1C2721;secondary=dark?0xFFADB9B1:0xFF68776E;line=dark?0xFF303B35:0xFFE4EAE6;accent=dark?0xFF51D5AA:0xFF0A8763;}
    }
    static Palette palette(Context context,SharedPreferences prefs){return new Palette(dark(context,prefs));}
}
