package com.xcosmos.minivoice;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;

final class AppAppearance {
    static String styleValue(String value){return "simple".equals(value)||"library".equals(value)?value:"wall";}
    static String themeValue(String value){return "light".equals(value)||"dark".equals(value)?value:"system";}
    static boolean darkValue(String value,boolean systemDark){String theme=themeValue(value);return theme.equals("dark")||theme.equals("system")&&systemDark;}
    static String style(SharedPreferences prefs){return styleValue(prefs.getString("player_style","wall"));}
    static String theme(SharedPreferences prefs){return themeValue(prefs.getString("appearance","system"));}
    static boolean dark(Context context,SharedPreferences prefs){return darkValue(theme(prefs),(context.getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES);}
    static final class Palette {
        final boolean dark;final int background,surface,text,secondary,line,accent;
        Palette(boolean dark){this.dark=dark;background=dark?0xFF111513:0xFFF5F7F5;surface=dark?0xFF1C2320:0xFFFFFFFF;text=dark?0xFFE9EFEA:0xFF1C2721;secondary=dark?0xFFADB9B1:0xFF68776E;line=dark?0xFF303B35:0xFFE4EAE6;accent=dark?0xFF51D5AA:0xFF0A8763;}
    }
    static Palette palette(Context context,SharedPreferences prefs){return new Palette(dark(context,prefs));}
}
