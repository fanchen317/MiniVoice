package com.xcosmos.minivoice;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.io.File;
import java.io.FileOutputStream;

final class HomeScreen {
    interface Actions { void section(String name); void playlist(String name); void newPlaylist(); void settings(); void search(); void play(Song song); void toggle(); void previous(); void next(); void lyrics(); }
    private final Activity activity;
    private final Actions actions;
    private final FrameLayout frame,drawerLayer;
    private final LinearLayout wall,drawerRows;
    private final TextView current;
    private boolean drawerOpen=true;
    private final int green=Color.rgb(21,188,135);
    private final Handler main=new Handler();
    HomeScreen(Activity activity,Actions actions){
        this.activity=activity;this.actions=actions;
        frame=new FrameLayout(activity);frame.setBackgroundColor(Color.rgb(7,12,13));
        ScrollView wallScroll=new ScrollView(activity);wallScroll.setFillViewport(true);wallScroll.setVerticalScrollBarEnabled(false);frame.addView(wallScroll);
        wall=new LinearLayout(activity);wall.setOrientation(LinearLayout.VERTICAL);wallScroll.addView(wall);
        ImageView menu=roundImage(R.drawable.icon_sidebar,()->showDrawer(true));FrameLayout.LayoutParams menuParams=new FrameLayout.LayoutParams(dp(54),dp(54),Gravity.TOP|Gravity.LEFT);menuParams.setMargins(dp(14),dp(16),0,0);frame.addView(menu,menuParams);
        ImageView search=roundImage(R.drawable.icon_search,actions::search);FrameLayout.LayoutParams searchParams=new FrameLayout.LayoutParams(dp(56),dp(56),Gravity.TOP|Gravity.RIGHT);searchParams.setMargins(0,dp(16),dp(14),0);frame.addView(search,searchParams);
        LinearLayout player=new LinearLayout(activity);player.setGravity(Gravity.CENTER_VERTICAL);player.setPadding(dp(12),0,dp(10),0);player.setBackground(round(0xDA171A19,34,0x66FFFFFF,1));
        FrameLayout.LayoutParams playerParams=new FrameLayout.LayoutParams(-1,dp(76),Gravity.BOTTOM);playerParams.setMargins(dp(18),0,dp(18),dp(18));frame.addView(player,playerParams);
        player.addView(playerButton("▶",actions::toggle),new LinearLayout.LayoutParams(dp(52),dp(52)));
        player.addView(playerButton("‹",actions::previous),new LinearLayout.LayoutParams(dp(38),dp(52)));
        current=text("选择歌曲",17,Color.WHITE);current.setGravity(Gravity.CENTER);current.setSingleLine(true);current.setOnClickListener(v->actions.lyrics());player.addView(current,new LinearLayout.LayoutParams(0,-1,1));
        player.addView(playerButton("›",actions::next),new LinearLayout.LayoutParams(dp(38),dp(52)));
        player.addView(playerButton("☷",()->showDrawer(true)),new LinearLayout.LayoutParams(dp(38),dp(52)));
        drawerLayer=new FrameLayout(activity);frame.addView(drawerLayer,new FrameLayout.LayoutParams(-1,-1));drawerLayer.setBackgroundColor(0x99000000);
        View outside=new View(activity);drawerLayer.addView(outside,new FrameLayout.LayoutParams(-1,-1));outside.setOnClickListener(v->showDrawer(false));
        ScrollView drawerScroll=new ScrollView(activity);drawerScroll.setFillViewport(true);drawerScroll.setVerticalScrollBarEnabled(false);
        FrameLayout.LayoutParams drawerParams=new FrameLayout.LayoutParams(Math.min(dp(310),activity.getResources().getDisplayMetrics().widthPixels-dp(58)),-1,Gravity.LEFT);drawerParams.setMargins(dp(15),dp(20),0,dp(16));drawerLayer.addView(drawerScroll,drawerParams);
        LinearLayout drawer=new LinearLayout(activity);drawer.setOrientation(LinearLayout.VERTICAL);drawer.setPadding(dp(16),dp(18),dp(16),dp(18));drawer.setBackground(round(0xE9171C1B,24,0x77FFFFFF,1));drawerScroll.addView(drawer);
        LinearLayout brand=new LinearLayout(activity);brand.setGravity(Gravity.CENTER_VERTICAL);drawer.addView(brand,new LinearLayout.LayoutParams(-1,dp(72)));
        ImageView icon=new ImageView(activity);icon.setImageResource(R.drawable.minivoice_icon);icon.setScaleType(ImageView.ScaleType.CENTER_CROP);icon.setBackground(round(0xFF3ED766,15,0,0));icon.setClipToOutline(true);brand.addView(icon,new LinearLayout.LayoutParams(dp(56),dp(56)));
        LinearLayout title=new LinearLayout(activity);title.setOrientation(LinearLayout.VERTICAL);title.setPadding(dp(12),0,0,0);brand.addView(title,new LinearLayout.LayoutParams(0,-2,1));
        TextView name=text("MiniVoice",22,Color.WHITE);name.setTypeface(null,Typeface.BOLD);title.addView(name);
        TextView sub=text("音乐让生活更美...",13,0xFF9DA7A4);title.addView(sub);
        brand.addView(iconButton("ⓘ",green,()->actions.settings()),new LinearLayout.LayoutParams(dp(38),dp(46)));
        brand.addView(imageButton(R.drawable.icon_close,Color.WHITE,()->showDrawer(false)),new LinearLayout.LayoutParams(dp(38),dp(46)));
        drawerRows=new LinearLayout(activity);drawerRows.setOrientation(LinearLayout.VERTICAL);drawerRows.setPadding(0,dp(12),0,0);drawer.addView(drawerRows);
        View spacer=new View(activity);drawer.addView(spacer,new LinearLayout.LayoutParams(1,0,1));
        ImageView settings=imageButton(R.drawable.icon_settings_gear,Color.WHITE,actions::settings);settings.setContentDescription("设置");settings.setPadding(dp(12),dp(12),dp(12),dp(12));settings.setBackground(round(0x55373F3D,14,0x44FFFFFF,1));
        LinearLayout.LayoutParams settingsParams=new LinearLayout.LayoutParams(dp(48),dp(48));settingsParams.setMargins(dp(4),dp(4),0,0);drawer.addView(settings,settingsParams);
    }
    View view(){return frame;}
    boolean isDrawerOpen(){return drawerOpen;}
    void showDrawer(boolean open){drawerOpen=open;drawerLayer.setVisibility(open?View.VISIBLE:View.GONE);}
    void setNow(String title,boolean playing){current.setText((playing?"♫ ":"♪ ")+title);}
    void updateDrawer(String selected,Set<String> playlists){
        drawerRows.removeAllViews();
        nav("♫","音乐库",selected.equals("歌曲"),()->actions.section("歌曲"));
        nav("◷","最近播放",selected.equals("最近播放"),()->actions.section("最近播放"));
        nav("♡","收藏",selected.equals("收藏"),()->actions.section("收藏"));
        nav("♙","歌手",selected.equals("歌手"),()->actions.section("歌手"));
        nav("◎","专辑",selected.equals("专辑"),()->actions.section("专辑"));
        TextView heading=text("我的歌单",15,0xFFB8BEBA);heading.setPadding(dp(28),dp(22),0,dp(10));drawerRows.addView(heading);
        for(String name:new java.util.TreeSet<>(playlists))nav("☷",name,false,()->actions.playlist(name));
        nav("＋","新建歌单",false,actions::newPlaylist);
    }
    private void nav(String symbol,String label,boolean selected,Runnable action){
        LinearLayout row=new LinearLayout(activity);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(18),0,dp(10),0);if(selected)row.setBackground(round(0x55468C74,15,0,0));
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(60));lp.setMargins(0,dp(3),0,dp(3));drawerRows.addView(row,lp);
        int resource=iconFor(label);
        if(resource!=0)row.addView(imageButton(resource,selected?green:0xFFE6EBE8,()->row.performClick()),new LinearLayout.LayoutParams(dp(35),dp(35)));
        else {TextView icon=text(symbol,27,selected?green:0xFFE6EBE8);icon.setGravity(Gravity.CENTER);row.addView(icon,new LinearLayout.LayoutParams(dp(35),-1));}
        TextView title=text(label,18,selected?green:Color.WHITE);title.setTypeface(null,Typeface.BOLD);title.setPadding(dp(8),0,0,0);row.addView(title,new LinearLayout.LayoutParams(0,-1,1));
        row.setOnClickListener(v->{action.run();if(!label.equals("新建歌单"))showDrawer(false);});
    }
    void updateWall(List<Song> songs){
        wall.removeAllViews();
        List<Song> source=songs.size()>18?songs.subList(0,18):songs;
        int rows=Math.max(6,(source.size()+2)/3);
        for(int rowIndex=0;rowIndex<rows;rowIndex++){
            LinearLayout row=new LinearLayout(activity);wall.addView(row);
            int height=rowIndex%3==0?280:rowIndex%3==1?160:260;
            for(int column=0;column<3;column++){
                int index=rowIndex*3+column;
                Song song=source.isEmpty()?null:source.get(index%source.size());
                FrameLayout tile=tile(song,index);
                LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(0,dp(height),column==1?0.76f:0.12f);
                params.setMargins(dp(2),dp(2),dp(2),dp(2));row.addView(tile,params);
            }
        }
    }
    private FrameLayout tile(Song song,int index){
        FrameLayout tile=new FrameLayout(activity);
        int[] palette={0xFF403F30,0xFF292B3D,0xFF3C2A24,0xFF243A33,0xFF39302E,0xFF262F42};tile.setBackgroundColor(palette[index%palette.length]);
        if(song!=null){
            ImageView art=new ImageView(activity);art.setScaleType(ImageView.ScaleType.CENTER_CROP);tile.addView(art,new FrameLayout.LayoutParams(-1,-1));
            new Thread(()->{
                File folder=new File(activity.getCacheDir(),"covers");File file=new File(folder,song.id+".jpg");
                Bitmap bitmap=file.isFile()?BitmapFactory.decodeFile(file.getAbsolutePath()):null;
                if(bitmap==null){MediaMetadataRetriever retriever=new MediaMetadataRetriever();try{
                    retriever.setDataSource(activity,song.uri);byte[] bytes=retriever.getEmbeddedPicture();
                    if(bytes!=null){Bitmap raw=BitmapFactory.decodeByteArray(bytes,0,bytes.length);if(raw!=null){
                        int side=Math.min(640,Math.max(raw.getWidth(),raw.getHeight()));
                        float scale=(float)side/Math.max(raw.getWidth(),raw.getHeight());
                        bitmap=Bitmap.createScaledBitmap(raw,Math.max(1,Math.round(raw.getWidth()*scale)),Math.max(1,Math.round(raw.getHeight()*scale)),true);
                        folder.mkdirs();try(FileOutputStream out=new FileOutputStream(file)){bitmap.compress(Bitmap.CompressFormat.JPEG,85,out);}catch(Exception ignored){}
                    }}
                }catch(Exception ignored){}finally{try{retriever.release();}catch(Exception ignored){}}}
                Bitmap result=bitmap;if(result!=null)main.post(()->art.setImageBitmap(result));
            }).start();
        }
        View shade=new View(activity);shade.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{0x00000000,0x10000000,0xCC000000}));tile.addView(shade,new FrameLayout.LayoutParams(-1,-1));
        TextView caption=text(song==null?"MiniVoice":song.title,21,Color.WHITE);caption.setTypeface(null,Typeface.BOLD);caption.setPadding(dp(14),0,dp(8),dp(8));caption.setMaxLines(2);FrameLayout.LayoutParams cap=new FrameLayout.LayoutParams(-1,-2,Gravity.BOTTOM);tile.addView(caption,cap);
        if(song!=null)tile.setOnClickListener(v->actions.play(song));
        return tile;
    }
    private TextView text(String value,int size,int color){TextView view=new TextView(activity);view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER_VERTICAL);return view;}
    private TextView iconButton(String value,int color,Runnable action){TextView view=text(value,27,color);view.setGravity(Gravity.CENTER);view.setOnClickListener(v->action.run());return view;}
    private TextView playerButton(String value,Runnable action){TextView view=iconButton(value,Color.WHITE,action);view.setTextSize(30);return view;}
    private int iconFor(String label){switch(label){case "音乐库":return R.drawable.icon_list;case "最近播放":return R.drawable.icon_queue;case "收藏":return R.drawable.icon_favorites;case "专辑":return R.drawable.icon_albums;case "新建歌单":return 0;default:return label.equals("歌手")?0:R.drawable.icon_list;}}
    private ImageView imageButton(int resource,int tint,Runnable action){ImageView view=new ImageView(activity);view.setImageResource(resource);view.setColorFilter(tint);view.setScaleType(ImageView.ScaleType.FIT_CENTER);view.setPadding(dp(4),dp(4),dp(4),dp(4));view.setOnClickListener(v->action.run());return view;}
    private ImageView roundImage(int resource,Runnable action){ImageView view=imageButton(resource,Color.WHITE,action);view.setPadding(dp(13),dp(13),dp(13),dp(13));view.setBackground(round(0x9952574F,28,0x88FFFFFF,1));return view;}
    private TextView roundButton(String value,int size,Runnable action){TextView view=iconButton(value,Color.WHITE,action);view.setTextSize(size);view.setBackground(round(0x9952574F,28,0x88FFFFFF,1));return view;}
    private GradientDrawable round(int color,int radius,int stroke,int width){GradientDrawable drawable=new GradientDrawable();drawable.setColor(color);drawable.setCornerRadius(dp(radius));if(width>0)drawable.setStroke(dp(width),stroke);return drawable;}
    private int dp(int number){return Math.round(number*activity.getResources().getDisplayMetrics().density);}
}
