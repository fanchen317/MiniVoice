package com.xcosmos.minivoice;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.Drawable;
import android.content.res.ColorStateList;
import android.util.Size;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class MainActivity extends Activity {
    private final List<Song> library=new ArrayList<>();
    private final Handler handler=new Handler();
    private PlaybackService service;
    private SharedPreferences prefs;
    private LinearLayout root,rows,toolbar,playerBar,drawer,drawerItems;
    private FrameLayout shell,wallLayer,drawerLayer,listLayer;
    private GridLayout wallGrid;
    private HomeScreen home;
    private SettingsPanel settings;
    private boolean scanning;
    private TextView now,elapsed;
    private SeekBar progress;
    private String section="歌曲",query="";
    private boolean drawerOpen=true;
    private Song pendingLyricSong;
    private final PlaybackService.Listener listener=()->runOnUiThread(this::refreshPlayer);
    private final ServiceConnection connection=new ServiceConnection(){
        @Override public void onServiceConnected(ComponentName name,IBinder binder){service=((PlaybackService.LocalBinder)binder).get();service.addListener(listener);refreshPlayer();}
        @Override public void onServiceDisconnected(ComponentName name){service=null;}
    };
    @Override public void onCreate(Bundle state){super.onCreate(state);prefs=getSharedPreferences("library",MODE_PRIVATE);buildUi();requestLibrary();handler.postDelayed(new Runnable(){@Override public void run(){refreshPlayer();handler.postDelayed(this,500);}},500);}
    @Override public void onStart(){super.onStart();bindService(new Intent(this,PlaybackService.class),connection,BIND_AUTO_CREATE);}
    @Override public void onStop(){if(service!=null){service.removeListener(listener);unbindService(connection);service=null;}super.onStop();}
    private void requestLibrary(){if(!ids("music_folders").isEmpty()){reload();return;}String permission=Build.VERSION.SDK_INT>=33?Manifest.permission.READ_MEDIA_AUDIO:Manifest.permission.READ_EXTERNAL_STORAGE;if(checkSelfPermission(permission)!=PackageManager.PERMISSION_GRANTED)requestPermissions(new String[]{permission},1);else reload();}
    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] results){super.onRequestPermissionsResult(code,permissions,results);if(code==1&&results.length>0&&results[0]==PackageManager.PERMISSION_GRANTED)reload();else new AlertDialog.Builder(this).setMessage("请允许读取本机音频，或在设置中选择音乐文件夹。 ").setPositiveButton("设置",(d,w)->showSettings()).setNegativeButton("稍后",null).show();}
    private void reload(){
        if(scanning)return;scanning=true;if(settings!=null)settings.refresh(library.size(),true);
        new Thread(()->{
            Set<String> folders=ids("music_folders");
            List<Song> found=folders.isEmpty()?Library.load(this):FolderLibrary.scan(this,folders,prefs.getBoolean("scan_recursive",true));
            runOnUiThread(()->{library.clear();library.addAll(found);scanning=false;renderRows();if(home!=null)home.updateWall(library);if(settings!=null)settings.refresh(library.size(),false);});
        }).start();
    }
    private int dp(int value){return Math.round(getResources().getDisplayMetrics().density*value);}
    private TextView label(String text,int size,int color){TextView view=new TextView(this);view.setText(text);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER_VERTICAL);return view;}
    private Button button(String text,Runnable action){Button b=new Button(this);b.setText(text);b.setAllCaps(false);b.setOnClickListener(v->action.run());return b;}
    private void buildUi(){
        shell=new FrameLayout(this);setContentView(shell);
        home=new HomeScreen(this,new HomeScreen.Actions(){
            public void section(String name){selectSection(name);}
            public void playlist(String name){showPlaylist(name);}
            public void newPlaylist(){createPlaylist();}
            public void settings(){showSettings();}
            public void search(){showSearch();}
            public void play(Song song){MainActivity.this.play(song);}
            public void toggle(){if(service!=null)service.toggle();}
            public void previous(){if(service!=null)service.previous();}
            public void next(){if(service!=null)service.next(true);}
            public void lyrics(){showLyrics();}
        });
        shell.addView(home.view(),new FrameLayout.LayoutParams(-1,-1));
        root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(Color.rgb(246,249,247));root.setPadding(dp(12),dp(12),dp(12),dp(8));root.setVisibility(View.GONE);shell.addView(root,new FrameLayout.LayoutParams(-1,-1));
        LinearLayout heading=new LinearLayout(this);heading.setGravity(Gravity.CENTER_VERTICAL);root.addView(heading,new LinearLayout.LayoutParams(-1,dp(52)));
        heading.addView(button("‹ 返回",()->root.setVisibility(View.GONE)));
        TextView title=label("音乐库",22,Color.rgb(24,99,62));heading.addView(title);
        toolbar=new LinearLayout(this);toolbar.setOrientation(LinearLayout.HORIZONTAL);root.addView(toolbar);
        for(String s:new String[]{"歌曲","歌手","专辑","收藏"})toolbar.addView(button(s,()->{section=s;renderRows();}),new LinearLayout.LayoutParams(0,dp(48),1));
        EditText search=new EditText(this);search.setSingleLine(true);search.setHint("搜索歌曲、歌手或专辑");root.addView(search);
        search.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int st,int c,int a){}public void onTextChanged(CharSequence s,int st,int before,int count){query=s.toString().toLowerCase(Locale.ROOT);renderRows();}public void afterTextChanged(android.text.Editable e){}});
        LinearLayout actions=new LinearLayout(this);root.addView(actions);
        actions.addView(button("刷新音乐库",this::reload));actions.addView(button("新建歌单",this::createPlaylist));
        ScrollView scroll=new ScrollView(this);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));rows=new LinearLayout(this);rows.setOrientation(LinearLayout.VERTICAL);scroll.addView(rows);
        playerBar=new LinearLayout(this);playerBar.setOrientation(LinearLayout.VERTICAL);playerBar.setPadding(dp(8),dp(8),dp(8),0);playerBar.setBackgroundColor(Color.rgb(225,241,230));root.addView(playerBar);
        now=label("选择一首歌曲",16,Color.rgb(20,70,42));playerBar.addView(now);now.setOnClickListener(v->showLyrics());
        progress=new SeekBar(this);playerBar.addView(progress);progress.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar s,int p,boolean fromUser){}public void onStartTrackingTouch(SeekBar s){}public void onStopTrackingTouch(SeekBar s){if(service!=null)service.seek(s.getProgress());}});
        LinearLayout controls=new LinearLayout(this);controls.setGravity(Gravity.CENTER);playerBar.addView(controls);
        controls.addView(button("⏮",()->{if(service!=null)service.previous();}));controls.addView(button("播放/暂停",()->{if(service!=null)service.toggle();}));controls.addView(button("⏭",()->{if(service!=null)service.next(true);}));
        controls.addView(button("模式",()->{if(service!=null){service.mode=(service.mode+1)%5;android.widget.Toast.makeText(this,new String[]{"单曲播放","列表播放","随机播放","单曲循环","列表循环"}[service.mode],android.widget.Toast.LENGTH_SHORT).show();}}));
        elapsed=label("0:00",12,Color.DKGRAY);playerBar.addView(elapsed);renderRows();
        settings=new SettingsPanel(this,prefs,new SettingsPanel.Actions(){
            public void addFolder(){Intent picker=new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);picker.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);startActivityForResult(picker,3);}
            public void removeFolder(String uri){Set<String> selected=ids("music_folders");selected.remove(uri);saveIds("music_folders",selected);reload();settings.refresh(library.size(),scanning);}
            public void rescan(){reload();}
            public void viewCache(){showCache();}
            public void clearCache(){clearCacheFiles(getCacheDir());android.widget.Toast.makeText(MainActivity.this,"缓存已清理",android.widget.Toast.LENGTH_SHORT).show();}
        });
        home.updateDrawer(section,ids("playlists"));home.updateWall(library);
    }
    private void selectSection(String name){section=name;home.updateDrawer(section,ids("playlists"));root.setVisibility(View.VISIBLE);renderRows();}
    private void showSettings(){settings.show(library.size(),scanning);}
    private void showSearch(){EditText input=new EditText(this);input.setSingleLine(true);input.setHint("搜索歌曲、歌手或专辑");new AlertDialog.Builder(this).setTitle("搜索音乐库").setView(input).setNegativeButton("取消",null).setPositiveButton("搜索",(dialog,which)->{query=input.getText().toString().toLowerCase(Locale.ROOT);selectSection("歌曲");}).show();}
    private void clearCacheFiles(java.io.File folder){java.io.File[] files=folder.listFiles();if(files==null)return;for(java.io.File file:files){if(file.isDirectory())clearCacheFiles(file);file.delete();}}
    private void showCache(){
        java.io.File folder=new java.io.File(getCacheDir(),"covers");java.io.File[] files=folder.listFiles();
        if(files==null||files.length==0){new AlertDialog.Builder(this).setTitle("本地缓存").setMessage("暂无封面缓存。浏览音乐墙后会生成缩略图。").setPositiveButton("关闭",null).show();return;}
        String[] names=new String[files.length];for(int i=0;i<files.length;i++)names[i]=files[i].getName()+"  ·  "+(files[i].length()/1024)+" KB";
        new AlertDialog.Builder(this).setTitle("封面缓存 · "+files.length+" 个文件").setItems(names,(dialog,index)->{
            android.widget.ImageView preview=new android.widget.ImageView(this);preview.setImageBitmap(android.graphics.BitmapFactory.decodeFile(files[index].getAbsolutePath()));preview.setAdjustViewBounds(true);
            new AlertDialog.Builder(this).setTitle(files[index].getName()).setView(preview).setPositiveButton("关闭",null).show();
        }).setPositiveButton("关闭",null).show();
    }
    @Override public void onBackPressed(){if(root!=null&&root.getVisibility()==View.VISIBLE){root.setVisibility(View.GONE);return;}if(home!=null&&home.isDrawerOpen()){home.showDrawer(false);return;}super.onBackPressed();}
    private boolean matches(Song song){return song.title.toLowerCase(Locale.ROOT).contains(query)||song.artist.toLowerCase(Locale.ROOT).contains(query)||song.album.toLowerCase(Locale.ROOT).contains(query);}
    private Set<String> ids(String key){return new HashSet<>(prefs.getStringSet(key,new HashSet<>()));}
    private void saveIds(String key,Set<String> values){prefs.edit().putStringSet(key,values).apply();}
    private void renderRows(){
        if(rows==null)return;rows.removeAllViews();
        if(section.equals("歌单")){for(String name:ids("playlists"))addCategory(name,()->showPlaylist(name));if(ids("playlists").isEmpty())showEmpty("还没有歌单。点上方“新建歌单”。");return;}
        if(section.equals("歌手")||section.equals("专辑")){
            Set<String> names=new java.util.TreeSet<>();for(Song song:library)if(matches(song))names.add(section.equals("歌手")?song.artist:song.album);
            for(String name:names)addCategory(name,()->{List<Song> filtered=new ArrayList<>();for(Song song:library)if((section.equals("歌手")?song.artist:song.album).equals(name))filtered.add(song);showSongDialog(name,filtered);});
        }else{
            Set<String> favorites=ids("favorites");int count=0;
            Set<String> recent=ids("recent");
            for(Song song:library){if(!matches(song))continue;if(section.equals("收藏")&&!favorites.contains(Long.toString(song.id)))continue;if(section.equals("最近播放")&&!recent.contains(Long.toString(song.id)))continue;addSong(song);count++;}
            if(count==0)showEmpty(library.isEmpty()?"没有找到本机音乐。可将音频文件保存到手机后刷新。":"没有匹配的歌曲。");
        }
    }
    private void showEmpty(String message){TextView text=label(message,16,Color.GRAY);text.setPadding(dp(14),dp(28),dp(14),dp(28));rows.addView(text);}
    private void addCategory(String name,Runnable action){Button b=button(name,action);b.setGravity(Gravity.START|Gravity.CENTER_VERTICAL);rows.addView(b,new LinearLayout.LayoutParams(-1,dp(58)));}
    private void addSong(Song song){
        LinearLayout row=new LinearLayout(this);row.setGravity(Gravity.CENTER_VERTICAL);rows.addView(row,new LinearLayout.LayoutParams(-1,dp(68)));
        TextView text=label(song.title+"\n"+song.artist+" · "+song.album,15,Color.rgb(27,45,33));text.setMaxLines(2);row.addView(text,new LinearLayout.LayoutParams(0,-1,1));
        text.setOnClickListener(v->play(song));
        row.addView(button(ids("favorites").contains(Long.toString(song.id))?"♥":"♡",()->{Set<String> set=ids("favorites");String id=Long.toString(song.id);if(!set.add(id))set.remove(id);saveIds("favorites",set);renderRows();}));
        row.addView(button("⋮",()->songMenu(song)));
    }
    private void play(Song song){if(service==null)return;List<Song> queue=new ArrayList<>();for(Song item:library)if(matches(item)&&(!section.equals("收藏")||ids("favorites").contains(Long.toString(item.id))))queue.add(item);int selected=queue.indexOf(song);if(selected<0){queue.clear();queue.add(song);selected=0;}Set<String> recent=ids("recent");recent.add(Long.toString(song.id));saveIds("recent",recent);startService(new Intent(this,PlaybackService.class));service.setQueue(queue,selected);}
    private void songMenu(Song song){List<String> names=new ArrayList<>(ids("playlists"));names.add(0,"查看歌词");new AlertDialog.Builder(this).setTitle(song.title).setItems(names.toArray(new String[0]),(dialog,index)->{if(index==0){showLyricsFor(song);return;}String key="playlist_"+names.get(index);Set<String> set=ids(key);set.add(Long.toString(song.id));saveIds(key,set);android.widget.Toast.makeText(this,"已加入歌单",android.widget.Toast.LENGTH_SHORT).show();}).show();}
    private void createPlaylist(){EditText input=new EditText(this);new AlertDialog.Builder(this).setTitle("新建歌单").setView(input).setNegativeButton("取消",null).setPositiveButton("创建",(d,w)->{String name=input.getText().toString().trim();if(!name.isEmpty()){Set<String> set=ids("playlists");set.add(name);saveIds("playlists",set);renderRows();home.updateDrawer(section,set);}}).show();}
    private void showPlaylist(String name){List<Song> selected=new ArrayList<>();Set<String> saved=ids("playlist_"+name);for(Song song:library)if(saved.contains(Long.toString(song.id)))selected.add(song);showSongDialog(name,selected);}
    private void showSongDialog(String title,List<Song> songs){String[] names=new String[songs.size()];for(int i=0;i<songs.size();i++)names[i]=songs.get(i).title+" · "+songs.get(i).artist;new AlertDialog.Builder(this).setTitle(title).setItems(names,(d,index)->play(songs.get(index))).setPositiveButton("关闭",null).show();}
    private String time(int ms){return String.format(Locale.ROOT,"%d:%02d",ms/60000,(ms/1000)%60);}
    private void refreshPlayer(){if(service==null||now==null)return;Song song=service.current();if(song==null)return;now.setText((service.isPlaying()?"▶ ":"Ⅱ ")+song.title+" · "+song.artist+"  ♪ 歌词");home.setNow(song.title,service.isPlaying());progress.setMax((int)Math.max(1,song.duration));if(!progress.isPressed())progress.setProgress(service.position());elapsed.setText(time(service.position())+" / "+time((int)song.duration));}
    private void showLyrics(){if(service!=null&&service.current()!=null)showLyricsFor(service.current());}
    private void showLyricsFor(Song song){
        String raw=prefs.getString("lyrics_"+song.id,"");List<Lyrics.Line> lines=Lyrics.parse(raw);
        StringBuilder body=new StringBuilder();for(Lyrics.Line line:lines)body.append(time((int)line.ms)).append("  ").append(line.text).append("\n\n");
        new AlertDialog.Builder(this).setTitle(song.title+" · 歌词")
            .setMessage(body.length()==0?"暂无歌词，可导入 LRC 文件。":body.toString())
            .setNeutralButton("导入 LRC",(d,w)->{pendingLyricSong=song;Intent picker=new Intent(Intent.ACTION_OPEN_DOCUMENT);picker.setType("*/*");picker.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(picker,2);})
            .setPositiveButton("关闭",null).show();
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==3&&result==RESULT_OK&&data!=null&&data.getData()!=null){
            try{getContentResolver().takePersistableUriPermission(data.getData(),Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(Exception ignored){}
            Set<String> folders=ids("music_folders");folders.add(data.getData().toString());saveIds("music_folders",folders);settings.refresh(library.size(),scanning);reload();return;
        }
        if(request!=2||result!=RESULT_OK||data==null||pendingLyricSong==null)return;
        Song song=pendingLyricSong;pendingLyricSong=null;
        try(java.io.InputStream stream=getContentResolver().openInputStream(data.getData())){
            byte[] bytes=new byte[1024*1024];int length=stream.read(bytes);if(length<0)return;
            String raw=new String(bytes,0,length,java.nio.charset.StandardCharsets.UTF_8);
            prefs.edit().putString("lyrics_"+song.id,raw).apply();showLyricsFor(song);
        }catch(Exception e){new AlertDialog.Builder(this).setMessage("无法读取歌词文件："+e.getMessage()).setPositiveButton("确定",null).show();}
    }
}
