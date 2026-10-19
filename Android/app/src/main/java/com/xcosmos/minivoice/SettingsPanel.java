package com.xcosmos.minivoice;

import android.app.Activity;
import android.app.Dialog;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ImageView;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import java.util.Set;
import java.util.TreeSet;

final class SettingsPanel {
    interface Actions { void addFolder(); void removeFolder(String uri); void rescan(); void viewCache(); void clearCache(); }
    private final Activity activity;private final SharedPreferences prefs;private final Actions actions;
    private Dialog dialog;private LinearLayout body;private int songCount;private boolean scanning;
    private final int green=0xFF118D69;
    SettingsPanel(Activity activity,SharedPreferences prefs,Actions actions){this.activity=activity;this.prefs=prefs;this.actions=actions;}
    void show(int count,boolean busy){songCount=count;scanning=busy;dialog=new Dialog(activity);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);build();dialog.show();Window window=dialog.getWindow();if(window!=null){window.setLayout(-1,-1);window.setBackgroundDrawableResource(android.R.color.transparent);window.setStatusBarColor(0xFFF0F0F0);window.setNavigationBarColor(Color.BLACK);window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);if(android.os.Build.VERSION.SDK_INT>=29)window.setStatusBarContrastEnforced(false);}}
    void refresh(int count,boolean busy){songCount=count;scanning=busy;if(dialog!=null&&dialog.isShowing())build();}
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(activity);view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER_VERTICAL);return view;}
    private GradientDrawable rounded(int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));return d;}
    private Button button(String value,Runnable action){Button b=new Button(activity);b.setText(value);b.setAllCaps(false);b.setTextColor(Color.WHITE);b.setBackground(rounded(green,11));b.setOnClickListener(v->action.run());return b;}
    private Button outlined(String value,Runnable action){Button b=new Button(activity);b.setText(value);b.setAllCaps(false);b.setTextColor(0xFF2B2B2B);GradientDrawable background=rounded(Color.WHITE,10);background.setStroke(dp(1),0xFFD5D5D5);b.setBackground(background);b.setOnClickListener(v->action.run());return b;}
    private void build(){
        LinearLayout root=new LinearLayout(activity);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(0xFFF0F0F0);dialog.setContentView(root);
        LinearLayout top=new LinearLayout(activity);top.setGravity(Gravity.CENTER_VERTICAL);top.setPadding(dp(18),dp(10),dp(18),dp(10));root.addView(top,new LinearLayout.LayoutParams(-1,dp(62)));
        TextView back=text("‹",34,0xFF333333);top.addView(back,new LinearLayout.LayoutParams(dp(42),-1));back.setOnClickListener(v->dialog.dismiss());
        TextView title=text("设置",21,0xFF252525);title.setTypeface(null,Typeface.BOLD);top.addView(title);
        boolean wide=activity.getResources().getConfiguration().screenWidthDp>=600;
        LinearLayout content=new LinearLayout(activity);content.setOrientation(LinearLayout.HORIZONTAL);root.addView(content,new LinearLayout.LayoutParams(-1,0,1));
        if(wide){LinearLayout sidebar=new LinearLayout(activity);sidebar.setOrientation(LinearLayout.VERTICAL);sidebar.setPadding(dp(18),dp(30),dp(18),0);sidebar.setBackgroundColor(0xFFE9E8E8);content.addView(sidebar,new LinearLayout.LayoutParams(dp(230),-1));
            LinearLayout identity=new LinearLayout(activity);identity.setGravity(Gravity.CENTER_VERTICAL);sidebar.addView(identity,new LinearLayout.LayoutParams(-1,dp(72)));
            ImageView logo=new ImageView(activity);logo.setImageResource(R.drawable.minivoice_icon);identity.addView(logo,new LinearLayout.LayoutParams(dp(38),dp(38)));
            TextView brand=text("MiniVoice\n设置",19,0xFF333333);brand.setTypeface(null,Typeface.BOLD);brand.setPadding(dp(12),0,0,0);identity.addView(brand);
            sidebar.addView(navItem("⚙", "通用",false));sidebar.addView(navItem("♫", "音乐库",true));sidebar.addView(navItem("☷", "歌词匹配",false));sidebar.addView(navItem("▦", "快捷键",false));
        }
        ScrollView scroll=new ScrollView(activity);content.addView(scroll,new LinearLayout.LayoutParams(0,-1,1));body=new LinearLayout(activity);body.setPadding(dp(wide?36:20),dp(18),dp(wide?36:20),dp(30));body.setOrientation(LinearLayout.VERTICAL);scroll.addView(body);
        if(!wide){LinearLayout branding=new LinearLayout(activity);branding.setGravity(Gravity.CENTER_VERTICAL);body.addView(branding,new LinearLayout.LayoutParams(-1,dp(46)));
            ImageView logo=new ImageView(activity);logo.setImageResource(R.drawable.minivoice_icon);logo.setScaleType(ImageView.ScaleType.CENTER_CROP);branding.addView(logo,new LinearLayout.LayoutParams(dp(38),dp(38)));
            TextView brand=text("MiniVoice  ·  设置",21,green);brand.setTypeface(null,Typeface.BOLD);brand.setPadding(dp(10),0,0,0);branding.addView(brand);
            TextView nav=text("通用     音乐库     歌词匹配     快捷键",14,0xFF555555);nav.setPadding(0,dp(22),0,dp(12));body.addView(nav);
        }
        TextView heading=text("音乐库",32,0xFF222222);heading.setTypeface(null,Typeface.BOLD);body.addView(heading);
        TextView subtitle=text("管理音乐所在的位置与扫描方式。",16,0xFF888888);body.addView(subtitle);
        section("音乐文件夹");LinearLayout folderCard=card();
        Set<String> folders=new TreeSet<>(prefs.getStringSet("music_folders",Set.of()));
        if(folders.isEmpty())folderCard.addView(padded("尚未添加文件夹。可选一个音乐目录。",15,0xFF777777));
        for(String value:folders){Uri uri=Uri.parse(value);String label=uri.getLastPathSegment();if(label==null)label="音乐文件夹";if(label.contains(":"))label=label.substring(label.lastIndexOf(':')+1);
            LinearLayout line=new LinearLayout(activity);line.setGravity(Gravity.CENTER_VERTICAL);line.setPadding(dp(12),dp(6),dp(12),dp(6));folderCard.addView(line);
            ImageView folderIcon=new ImageView(activity);folderIcon.setImageResource(R.drawable.icon_folder);folderIcon.setColorFilter(green);line.addView(folderIcon,new LinearLayout.LayoutParams(dp(30),dp(30)));
            LinearLayout labelBox=new LinearLayout(activity);labelBox.setOrientation(LinearLayout.VERTICAL);labelBox.setPadding(dp(12),0,dp(4),0);line.addView(labelBox,new LinearLayout.LayoutParams(0,dp(74),1));
            TextView name=text(label,16,0xFF242424);name.setTypeface(null,Typeface.BOLD);labelBox.addView(name,new LinearLayout.LayoutParams(-1,0,1));
            TextView path=text(value,12,0xFF888888);path.setSingleLine(true);path.setEllipsize(android.text.TextUtils.TruncateAt.MIDDLE);labelBox.addView(path,new LinearLayout.LayoutParams(-1,0,1));
            String folder=value;Button remove=outlined("移除",()->actions.removeFolder(folder));line.addView(remove,new LinearLayout.LayoutParams(dp(74),dp(40)));
        }
        TextView count=padded(folders.size()+" 个文件夹",13,0xFF888888);folderCard.addView(count);
        Button add=button("＋ 添加文件夹…",actions::addFolder);LinearLayout.LayoutParams addParams=new LinearLayout.LayoutParams(-1,dp(48));addParams.setMargins(dp(12),dp(4),dp(12),dp(12));folderCard.addView(add,addParams);
        section("扫描");LinearLayout scanCard=card();
        LinearLayout recursive=new LinearLayout(activity);recursive.setGravity(Gravity.CENTER_VERTICAL);recursive.setPadding(dp(14),0,dp(14),0);scanCard.addView(recursive,new LinearLayout.LayoutParams(-1,dp(75)));
        TextView recursiveLabel=text("包含子文件夹\n同时读取所选文件夹内的音乐",15,0xFF242424);recursive.addView(recursiveLabel,new LinearLayout.LayoutParams(0,-1,1));
        Switch toggle=new Switch(activity);toggle.setChecked(prefs.getBoolean("scan_recursive",true));toggle.setOnCheckedChangeListener((button,checked)->prefs.edit().putBoolean("scan_recursive",checked).apply());recursive.addView(toggle);
        View divider=new View(activity);divider.setBackgroundColor(0xFFE5E5E5);scanCard.addView(divider,new LinearLayout.LayoutParams(-1,dp(1)));
        LinearLayout status=new LinearLayout(activity);status.setGravity(Gravity.CENTER_VERTICAL);status.setPadding(dp(14),0,dp(14),0);scanCard.addView(status,new LinearLayout.LayoutParams(-1,dp(78)));
        TextView statusText=text("音乐库状态\n"+(scanning?"正在扫描…":"歌单已载入："+songCount+" 首歌曲"),15,0xFF242424);status.addView(statusText,new LinearLayout.LayoutParams(0,-1,1));
        Button refresh=outlined("重新扫描",actions::rescan);refresh.setEnabled(!scanning);status.addView(refresh,new LinearLayout.LayoutParams(dp(102),dp(42)));
        section("缓存");LinearLayout cacheCard=card();
        cacheCard.addView(padded("本地缓存文件夹",16,0xFF242424));cacheCard.addView(padded(activity.getCacheDir().getAbsolutePath(),12,0xFF888888));
        LinearLayout cacheActions=new LinearLayout(activity);cacheActions.setPadding(dp(12),dp(8),dp(12),dp(12));cacheCard.addView(cacheActions);
        Button open=outlined("查看缓存",actions::viewCache);cacheActions.addView(open,new LinearLayout.LayoutParams(0,dp(44),1));
        Button clear=outlined("清理缓存",actions::clearCache);LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(0,dp(44),1);cp.setMargins(dp(8),0,0,0);cacheActions.addView(clear,cp);
        body.addView(padded("安卓系统将缓存放在应用私有目录，清理不会删除音乐文件。",12,0xFF888888));
    }
    private TextView padded(String value,int size,int color){TextView v=text(value,size,color);v.setPadding(dp(14),dp(10),dp(14),dp(10));return v;}
    private void section(String name){TextView v=text(name,16,0xFF888888);v.setTypeface(null,Typeface.BOLD);v.setPadding(0,dp(28),0,dp(10));body.addView(v);}
    private LinearLayout card(){LinearLayout card=new LinearLayout(activity);card.setOrientation(LinearLayout.VERTICAL);card.setBackground(rounded(Color.WHITE,18));body.addView(card,new LinearLayout.LayoutParams(-1,-2));return card;}
    private TextView navItem(String icon,String name,boolean active){TextView view=text(icon+"    "+name,17,active?green:0xFF444444);view.setTypeface(null,Typeface.BOLD);view.setPadding(dp(14),0,0,0);if(active)view.setBackground(rounded(0xFFD7E5E0,13));LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(-1,dp(54));params.setMargins(0,dp(8),0,0);view.setLayoutParams(params);return view;}
}
