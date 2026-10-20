package com.xcosmos.minivoice;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.*;
import java.util.Set;
import java.util.TreeSet;

/** Phone-first Android preferences. Values are persisted and applied immediately. */
final class SettingsPanel {
    interface Actions {void addFolder();void removeFolder(String uri);void rescan();void viewCache();void clearCache();void appearanceChanged();}
    private final Activity activity;private final SharedPreferences prefs;private final Actions actions;
    private Dialog dialog;private LinearLayout body;private ScrollView scroll;private AppAppearance.Palette colors;
    private int songCount,scanCompleted,scanTotal;private boolean scanning;private String scanMessage="正在查找音乐文件";
    private TextView scanDetail,statusText;private ProgressBar scanBar;
    SettingsPanel(Activity activity,SharedPreferences prefs,Actions actions){this.activity=activity;this.prefs=prefs;this.actions=actions;}
    void show(int count,boolean busy){songCount=count;scanning=busy;if(dialog!=null&&dialog.isShowing())return;dialog=new Dialog(activity);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);build();dialog.show();styleWindow();}
    void refresh(int count,boolean busy){songCount=count;scanning=busy;if(dialog!=null&&dialog.isShowing())build();}
    void appearanceChanged(){if(dialog!=null&&dialog.isShowing())build();}
    void progress(int completed,int total,String message){scanCompleted=completed;scanTotal=total;scanMessage=message;updateProgress();}
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(activity);view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER_VERTICAL);view.setIncludeFontPadding(false);return view;}
    private GradientDrawable shape(int color,int radius){GradientDrawable result=new GradientDrawable();result.setColor(color);result.setCornerRadius(dp(radius));return result;}
    private void styleWindow(){Window window=dialog.getWindow();if(window==null)return;window.setLayout(-1,-1);window.setBackgroundDrawableResource(android.R.color.transparent);window.setStatusBarColor(colors.background);window.setNavigationBarColor(colors.background);window.getDecorView().setSystemUiVisibility(colors.dark?0:View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);if(android.os.Build.VERSION.SDK_INT>=29){window.setStatusBarContrastEnforced(false);window.setNavigationBarContrastEnforced(false);}}
    private void build(){
        int position=scroll==null?0:scroll.getScrollY();colors=AppAppearance.palette(activity,prefs);scanDetail=null;scanBar=null;statusText=null;
        LinearLayout root=new LinearLayout(activity);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(colors.background);dialog.setContentView(root);
        LinearLayout toolbar=new LinearLayout(activity);toolbar.setGravity(Gravity.CENTER_VERTICAL);toolbar.setPadding(dp(8),0,dp(16),0);root.addView(toolbar,new LinearLayout.LayoutParams(-1,dp(56)));
        TextView back=text("‹",32,colors.text);back.setGravity(Gravity.CENTER);back.setContentDescription("返回");back.setOnClickListener(view->dialog.dismiss());toolbar.addView(back,new LinearLayout.LayoutParams(dp(48),dp(48)));
        TextView title=text("设置",20,colors.text);title.setTypeface(null,Typeface.BOLD);title.setPadding(dp(8),0,0,0);toolbar.addView(title);
        scroll=new ScrollView(activity);scroll.setFillViewport(false);scroll.setClipToPadding(false);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        FrameLayout centered=new FrameLayout(activity);scroll.addView(centered);body=new LinearLayout(activity);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(dp(16),dp(4),dp(16),dp(28));
        int max=dp(680),width=activity.getResources().getDisplayMetrics().widthPixels;FrameLayout.LayoutParams bp=new FrameLayout.LayoutParams(width>max?max:-1,-2,Gravity.CENTER_HORIZONTAL);centered.addView(body,bp);
        section("外观");LinearLayout appearance=group();
        String style=AppAppearance.style(prefs);String styleName=style.equals("simple")?"简易样式":style.equals("library")?"音乐库样式":"音乐墙样式";
        preference(appearance,"播放器样式",styleName+" · 切换后立即生效",()->choose("播放器样式",new String[]{"简易样式","音乐库样式","音乐墙样式"},new String[]{"simple","library","wall"},"player_style",style));
        divider(appearance);String theme=AppAppearance.theme(prefs);String themeName=theme.equals("light")?"浅色模式":theme.equals("dark")?"深色模式":"跟随系统";
        preference(appearance,"界面外观",themeName,()->choose("界面外观",new String[]{"跟随系统","浅色模式","深色模式"},new String[]{"system","light","dark"},"appearance",theme));
        section("音乐文件夹");LinearLayout folders=group();Set<String> selected=new TreeSet<>(prefs.getStringSet("music_folders",Set.of()));
        if(selected.isEmpty())preference(folders,"系统音乐库","尚未选择文件夹，读取手机音频媒体库",null);
        for(String value:selected){String path=folderPath(value);String name=path.substring(path.lastIndexOf('/')+1);preference(folders,name,path,()->new AlertDialog.Builder(activity,colors.dark?android.app.AlertDialog.THEME_DEVICE_DEFAULT_DARK:android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT).setTitle(name).setMessage(path+"\n\n移除后不会删除目录中的音乐文件。").setNegativeButton("取消",null).setPositiveButton("移除文件夹",(dialog,which)->actions.removeFolder(value)).show());divider(folders);}
        preference(folders,"添加音乐文件夹","通过系统文件选择器授权读取",actions::addFolder);
        section("音乐库");LinearLayout library=group();
        LinearLayout recursive=row(library);LinearLayout recursiveLabels=labels(recursive,"包含子文件夹","扫描所选目录中的下级文件夹");
        Switch toggle=new Switch(activity);toggle.setChecked(prefs.getBoolean("scan_recursive",true));toggle.setThumbTintList(new ColorStateList(new int[][]{new int[]{android.R.attr.state_checked},new int[]{}},new int[]{colors.accent,colors.secondary}));recursive.addView(toggle);toggle.setOnCheckedChangeListener((button,value)->{prefs.edit().putBoolean("scan_recursive",value).apply();actions.rescan();});
        divider(library);statusText=preference(library,"重新扫描",scanning?"正在扫描…":songCount+" 首歌曲 · 更新新增或修改的文件",()->{if(!scanning)actions.rescan();});
        scanDetail=text("",12,colors.secondary);scanDetail.setPadding(dp(16),0,dp(16),dp(8));scanDetail.setMaxLines(2);library.addView(scanDetail);
        scanBar=new ProgressBar(activity,null,android.R.attr.progressBarStyleHorizontal);scanBar.setProgressTintList(ColorStateList.valueOf(colors.accent));LinearLayout.LayoutParams progress=new LinearLayout.LayoutParams(-1,dp(4));progress.setMargins(dp(16),0,dp(16),dp(12));library.addView(scanBar,progress);updateProgress();
        section("缓存与存储");LinearLayout cache=group();preference(cache,"查看本地缓存","歌曲索引、封面与歌词保存在应用私有目录",actions::viewCache);divider(cache);
        preference(cache,"重建缓存","清理缓存后重新读取音乐，不删除原始文件",()->new AlertDialog.Builder(activity,colors.dark?android.app.AlertDialog.THEME_DEVICE_DEFAULT_DARK:android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT).setTitle("重建音乐库缓存？").setMessage("将重新读取歌曲、封面和歌词。音乐文件、收藏和歌单会保留。").setNegativeButton("取消",null).setPositiveButton("重建",(dialog,which)->{if(!scanning)actions.clearCache();}).show());
        section("歌词");LinearLayout lyrics=group();preference(lyrics,"歌词读取","优先读取歌曲内嵌歌词，其次匹配音乐目录的 lrc 文件夹；支持手动导入。",null);divider(lyrics);preference(lyrics,"歌词显示","增强 LRC 按逐字时间高亮；逐行 LRC 使用行间时间估算高亮。",null);
        TextView footer=text("MiniVoice · 本地音乐播放器",12,colors.secondary);footer.setGravity(Gravity.CENTER);footer.setPadding(0,dp(24),0,dp(8));body.addView(footer);
        scroll.post(()->scroll.scrollTo(0,position));styleWindow();
    }
    private void choose(String title,String[] names,String[] values,String key,String value){int checked=0;for(int i=0;i<values.length;i++)if(values[i].equals(value))checked=i;
        new AlertDialog.Builder(activity,colors.dark?android.app.AlertDialog.THEME_DEVICE_DEFAULT_DARK:android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT).setTitle(title).setSingleChoiceItems(names,checked,(dialog,which)->{prefs.edit().putString(key,values[which]).apply();dialog.dismiss();actions.appearanceChanged();build();}).setNegativeButton("取消",null).show();}
    private void section(String title){TextView label=text(title,13,colors.accent);label.setTypeface(null,Typeface.BOLD);label.setPadding(dp(16),dp(22),0,dp(10));body.addView(label);}
    private LinearLayout group(){LinearLayout result=new LinearLayout(activity);result.setOrientation(LinearLayout.VERTICAL);result.setBackground(shape(colors.surface,18));body.addView(result,new LinearLayout.LayoutParams(-1,-2));return result;}
    private LinearLayout row(LinearLayout parent){LinearLayout result=new LinearLayout(activity);result.setGravity(Gravity.CENTER_VERTICAL);result.setPadding(dp(16),dp(15),dp(16),dp(15));result.setMinimumHeight(dp(72));parent.addView(result,new LinearLayout.LayoutParams(-1,-2));return result;}
    private LinearLayout labels(LinearLayout row,String title,String subtitle){LinearLayout result=new LinearLayout(activity);result.setOrientation(LinearLayout.VERTICAL);TextView name=text(title,16,colors.text);result.addView(name);TextView detail=text(subtitle,13,colors.secondary);detail.setPadding(0,dp(6),dp(8),0);detail.setLineSpacing(dp(2),1);result.addView(detail);row.addView(result,new LinearLayout.LayoutParams(0,-2,1));return result;}
    private TextView preference(LinearLayout parent,String title,String subtitle,Runnable action){LinearLayout row=row(parent);LinearLayout box=labels(row,title,subtitle);if(action!=null){TextView arrow=text("›",24,colors.secondary);arrow.setGravity(Gravity.CENTER);row.addView(arrow,new LinearLayout.LayoutParams(dp(24),dp(32)));row.setBackground(new RippleDrawable(ColorStateList.valueOf(colors.dark?0x22FFFFFF:0x16008763),null,shape(0xFFFFFFFF,14)));row.setOnClickListener(view->action.run());}return (TextView)box.getChildAt(1);}
    private void divider(LinearLayout parent){View line=new View(activity);line.setBackgroundColor(colors.line);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(1));lp.setMargins(dp(16),0,dp(16),0);parent.addView(line,lp);}
    private String folderPath(String value){try{String path=DocumentsContract.getTreeDocumentId(Uri.parse(value));int colon=path.indexOf(':');if(colon>=0)return (path.startsWith("primary:")?"内部存储/":"存储设备/")+path.substring(colon+1);return path;}catch(Exception ignored){return "已授权音乐文件夹";}}
    private void updateProgress(){if(statusText!=null)statusText.setText(scanning?"正在扫描…":songCount+" 首歌曲 · 更新新增或修改的文件");if(scanDetail!=null){scanDetail.setVisibility(scanning?View.VISIBLE:View.GONE);scanDetail.setText(scanMessage+(scanTotal>0?"  "+scanCompleted+" / "+scanTotal: ""));}if(scanBar!=null){scanBar.setVisibility(scanning?View.VISIBLE:View.GONE);scanBar.setIndeterminate(scanTotal<=0);scanBar.setMax(Math.max(1,scanTotal));scanBar.setProgress(scanCompleted);}}
}
