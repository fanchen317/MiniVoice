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
import android.view.Window;
import android.view.WindowManager;
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
    static final String ACTION_SHOW_SCAN="com.xcosmos.minivoice.SHOW_SCAN";
    static final String ACTION_LOCATE_PLAYING="com.xcosmos.minivoice.LOCATE_PLAYING";
    private final List<Song> library=new ArrayList<>();
    private final Handler handler=new Handler();
    private PlaybackService service;
    private boolean bound;
    private SharedPreferences prefs;
    private LinearLayout root,rows,toolbar,playerBar,drawer,drawerItems;
    private FrameLayout shell,wallLayer,drawerLayer,listLayer;
    private GridLayout wallGrid;
    private HomeScreen home;
    private SettingsPanel settings;
    private boolean scanning;
    private long appliedScanRevision=-1,errorScanRevision=-1;
    private final LibraryScanService.Listener scanListener=this::scanChanged;
    private TextView now,elapsed;
    private SeekBar progress;
    private String section="歌曲",query="",groupName;
    private final List<Song> currentTracks=new ArrayList<>();
    private boolean drawerOpen=true;
    private Song pendingLyricSong;
    private Song pendingPlay;
    private boolean pendingLocatePlaying;
    private final LyricsLoadState lyricsLoad=new LyricsLoadState();
    private long lastRecentId=Long.MIN_VALUE;
    private final PlaybackService.Listener listener=()->runOnUiThread(this::refreshPlayer);
    private final ServiceConnection connection=new ServiceConnection(){
        @Override public void onServiceConnected(ComponentName name,IBinder binder){service=((PlaybackService.LocalBinder)binder).get();service.addListener(listener);if(appliedScanRevision>=0)service.retainLibrary(library);refreshPlayer();if(pendingPlay!=null){Song song=pendingPlay;pendingPlay=null;play(song);}locatePlayingIfReady();}
        @Override public void onServiceDisconnected(ComponentName name){service=null;invalidateLyricsLoad();}
    };
    private final Runnable playerTicker=new Runnable(){@Override public void run(){if(!isFinishing()&&!isDestroyed()&&hasWindowFocus()){refreshPlayer();handler.postDelayed(this,500);}}};
    @Override public void onCreate(Bundle state){super.onCreate(state);configureSystemBars();pendingLocatePlaying=ACTION_LOCATE_PLAYING.equals(getIntent().getAction());prefs=getSharedPreferences("library",MODE_PRIVATE);AppStorage.mirrorPreferences(this);buildUi();requestLibrary();if(ACTION_SHOW_SCAN.equals(getIntent().getAction()))showSettings();}
    @Override protected void onNewIntent(Intent intent){super.onNewIntent(intent);setIntent(intent);if(ACTION_SHOW_SCAN.equals(intent.getAction()))showSettings();if(ACTION_LOCATE_PLAYING.equals(intent.getAction())){pendingLocatePlaying=true;locatePlayingIfReady();}}
    @Override public boolean dispatchTouchEvent(android.view.MotionEvent event){
        if(event.getActionMasked()==android.view.MotionEvent.ACTION_DOWN&&home!=null)home.dismissEmptySearchOutside(event.getRawX(),event.getRawY());
        return super.dispatchTouchEvent(event);
    }
    @Override public void onConfigurationChanged(android.content.res.Configuration configuration){
        super.onConfigurationChanged(configuration);configureSystemBars();if(home!=null){home.orientationChanged();home.applyAppearance();}if(settings!=null)settings.appearanceChanged();
    }
    @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused){configureSystemBars();handler.removeCallbacks(playerTicker);handler.post(playerTicker);}else handler.removeCallbacks(playerTicker);}
    private void configureSystemBars(){
        Window window=getWindow();window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        window.setStatusBarColor(Color.TRANSPARENT);window.setNavigationBarColor(Color.TRANSPARENT);
        window.setNavigationBarDividerColor(Color.TRANSPARENT);
        if(Build.VERSION.SDK_INT>=30)window.setDecorFitsSystemWindows(false);
        if(Build.VERSION.SDK_INT>=29){window.setStatusBarContrastEnforced(false);window.setNavigationBarContrastEnforced(false);}
        View decor=window.getDecorView();boolean landscape=getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE;
        int flags=View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
        SharedPreferences appearancePrefs=getSharedPreferences("library",MODE_PRIVATE);if(!AppAppearance.style(appearancePrefs).equals("wall")&&!AppAppearance.dark(this,appearancePrefs))flags|=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        if(landscape)flags|=View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
        decor.setSystemUiVisibility(flags);
        if(Build.VERSION.SDK_INT>=30){android.view.WindowInsetsController controller=window.getInsetsController();if(controller!=null){controller.setSystemBarsBehavior(android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);if(landscape)controller.hide(android.view.WindowInsets.Type.systemBars());else controller.show(android.view.WindowInsets.Type.systemBars());}}
        if(Build.VERSION.SDK_INT>=28){WindowManager.LayoutParams attributes=window.getAttributes();attributes.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;window.setAttributes(attributes);}
    }
    @Override public void onStart(){super.onStart();LibraryScanService.observe(scanListener);bound=bindService(new Intent(this,PlaybackService.class),connection,BIND_AUTO_CREATE);}
    @Override public void onDestroy(){handler.removeCallbacksAndMessages(null);super.onDestroy();}
    @Override public void onStop(){LibraryScanService.remove(scanListener);handler.removeCallbacks(playerTicker);invalidateLyricsLoad();if(service!=null)service.removeListener(listener);if(bound){unbindService(connection);bound=false;}service=null;super.onStop();}
    private void requestLibrary(){reload(false,true);}
    private void reload(){reload(false);}
    private void rebuildLibrary(){reload(true);}
    private void reload(boolean rebuild){reload(rebuild,false);}
    private void reload(boolean rebuild,boolean restore){
        requestScanNotifications();LibraryScanService.request(this,rebuild,restore,false);
    }
    private void requestScanNotifications(){
        if(Build.VERSION.SDK_INT>=33&&!ids("music_folders").isEmpty()&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED&&!prefs.getBoolean("scan_notification_permission_asked",false)){
            prefs.edit().putBoolean("scan_notification_permission_asked",true).apply();requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},42);
        }
    }
    private void scanChanged(LibraryScanService.State state){
        if(isDestroyed())return;boolean wasScanning=scanning;scanning=state.running;home.setScanning(scanning);home.scanProgress(state.stage,state.completed,state.total);
        boolean changed=state.songs!=null&&appliedScanRevision!=state.revision;
        if(changed){appliedScanRevision=state.revision;library.clear();Set<String> folders=ids("music_folders");for(Song song:state.songs)if(belongsToSelectedFolder(song,folders))library.add(song);if(service!=null)service.retainLibrary(library);invalidateLyricsLoad();renderRows();refreshWall();refreshPlayer();if(service!=null&&service.current()!=null&&!groupRoot())home.locateSong(service.current().id);locatePlayingIfReady();}
        if(settings!=null){if(wasScanning!=scanning||changed)settings.refresh(library.size(),scanning);settings.progress(state.completed,state.total,state.detail);}
        if(state.error!=null&&errorScanRevision!=state.revision){errorScanRevision=state.revision;android.widget.Toast.makeText(this,state.error,android.widget.Toast.LENGTH_LONG).show();}
    }
    private boolean belongsToSelectedFolder(Song song,Set<String> folders){
        for(String value:folders)try{android.net.Uri tree=android.net.Uri.parse(value);if(!java.util.Objects.equals(tree.getAuthority(),song.uri.getAuthority()))continue;String parent=android.provider.DocumentsContract.getTreeDocumentId(tree),child=android.provider.DocumentsContract.getDocumentId(song.uri);if(child.equals(parent)||child.startsWith(parent+"/"))return true;}catch(Exception ignored){}
        return false;
    }
    private void sourcesChanged(){
        prefs.edit().putBoolean("folder_library",true).apply();
        Set<String> folders=ids("music_folders");library.removeIf(song->!belongsToSelectedFolder(song,folders));
        if(service!=null)service.retainLibrary(library);invalidateLyricsLoad();refreshWall();refreshPlayer();
        requestScanNotifications();LibraryScanService.request(this,false,false,true);
    }
    private int dp(int value){return Math.round(getResources().getDisplayMetrics().density*value);}
    private TextView label(String text,int size,int color){TextView view=new TextView(this);view.setText(text);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER_VERTICAL);return view;}
    private Button button(String text,Runnable action){Button b=new Button(this);b.setText(text);b.setAllCaps(false);b.setOnClickListener(v->action.run());ButtonFeedback.install(b);return b;}
    private void buildUi(){
        shell=new FrameLayout(this);setContentView(shell);
        home=new HomeScreen(this,new HomeScreen.Actions(){
            public void backGroup(){MainActivity.this.backGroup();}
            public void sort(String field,boolean ascending){String category=sortCategory();prefs.edit().putString("sort_"+category,LibraryOrdering.field(category,field)).putBoolean("ascending_"+category,ascending).apply();refreshWall();}
            public void section(String name){selectSection(name);}
            public void songMenu(Song song){MainActivity.this.songMenu(song);}
            public void playlistMenu(String name){MainActivity.this.playlistMenu(name);}
            public void playlist(String name){selectSection("歌单:"+name);}
            public void newPlaylist(){createPlaylist();}
            public void settings(){showSettings();}
            public void refreshLibrary(){rebuildLibrary();}
            public void search(String value){query=value.toLowerCase(Locale.ROOT);refreshWall();}
            public void play(Song song){MainActivity.this.playFromWall(song);}
            public void toggle(){if(service!=null)service.toggle();}
            public void previous(){if(service!=null)service.previous();}
            public void next(){if(service!=null)service.next(true);}
            public void favorite(Song song){favoriteSongs(java.util.Collections.singletonList(song),!ids("favorites").contains(Long.toString(song.id)));}
            public void favoriteSongs(List<Song> songs,boolean value){MainActivity.this.favoriteSongs(songs,value);}
            public void playlistSongs(List<Song> songs){addToPlaylist(songs);}
            public void removePlaylistSongs(List<Song> songs){MainActivity.this.removePlaylistSongs(songs);}
            public void clearRecent(){MainActivity.this.clearRecent();}
            public void lyrics(){showLyrics();}
            public void locate(){pendingLocatePlaying=true;locatePlayingIfReady();}
            public void queue(){showQueue();}
            public void seek(int ms){if(service!=null)service.seek(ms);}
            public int playbackMode(){return service==null?prefs.getInt("playback_mode",1):service.mode;}
            public void selectPlaybackMode(int mode){int selected=PlaybackModes.valid(mode);prefs.edit().putInt("playback_mode",selected).apply();if(service!=null)service.setMode(selected);refreshPlayer();}

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
        actions.addView(button("刷新音乐库",this::rebuildLibrary));actions.addView(button("新建歌单",this::createPlaylist));
        ScrollView scroll=new ScrollView(this);ListScrollStyle.apply(scroll);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));rows=new LinearLayout(this);rows.setOrientation(LinearLayout.VERTICAL);scroll.addView(rows);
        playerBar=new LinearLayout(this);playerBar.setOrientation(LinearLayout.VERTICAL);playerBar.setPadding(dp(8),dp(8),dp(8),0);playerBar.setBackgroundColor(Color.rgb(225,241,230));root.addView(playerBar);
        now=label("选择一首歌曲",16,Color.rgb(20,70,42));playerBar.addView(now);now.setOnClickListener(v->showLyrics());
        progress=new SeekBar(this);playerBar.addView(progress);progress.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar s,int p,boolean fromUser){}public void onStartTrackingTouch(SeekBar s){}public void onStopTrackingTouch(SeekBar s){if(service!=null)service.seek(s.getProgress());}});
        LinearLayout controls=new LinearLayout(this);controls.setGravity(Gravity.CENTER);playerBar.addView(controls);
        controls.addView(button("⏮",()->{if(service!=null)service.previous();}));controls.addView(button("播放/暂停",()->{if(service!=null)service.toggle();}));controls.addView(button("⏭",()->{if(service!=null)service.next(true);}));
        controls.addView(button("模式",this::showPlaybackModeDialog));
        elapsed=label("0:00",12,Color.DKGRAY);playerBar.addView(elapsed);renderRows();
        settings=new SettingsPanel(this,prefs,new SettingsPanel.Actions(){
            public void addFolder(){Intent picker=new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);picker.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);startActivityForResult(picker,3);}
            public void removeFolder(String uri){try{getContentResolver().releasePersistableUriPermission(android.net.Uri.parse(uri),Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(Exception ignored){}Set<String> selected=ids("music_folders");selected.remove(uri);saveIds("music_folders",selected);sourcesChanged();settings.refresh(library.size(),scanning);}
            public void rescan(){reload();}
            public void appearanceChanged(){home.applyAppearance();configureSystemBars();}
            public void viewCache(){showCache();}
            public void clearCache(){rebuildLibrary();}
        });
        home.updateDrawer(section,ids("playlists"));refreshWall();home.applyAppearance();
    }
    private String sortCategory(){return LibraryOrdering.category(section,groupName!=null);}
    private String sortField(){String category=sortCategory();return LibraryOrdering.field(category,prefs.getString("sort_"+category,null));}
    private boolean sortAscending(){return prefs.getBoolean("ascending_"+sortCategory(),!sortCategory().equals("tracks"));}
    private boolean groupRoot(){return groupName==null&&(section.equals("歌手")||section.equals("专辑"));}
    private void selectSection(String name){section=name;groupName=null;home.updateDrawer(section,ids("playlists"));root.setVisibility(View.GONE);refreshWall();if(service!=null&&service.current()!=null&&!groupRoot())home.locateSongDirectly(service.current().id);home.navigationChanged();}
    private void openGroup(String name){groupName=name;query="";home.clearSearch();refreshWall();}
    private boolean backGroup(){if(groupName==null)return false;groupName=null;query="";home.clearSearch();refreshWall();return true;}
    private void locatePlayingIfReady(){
        if(!pendingLocatePlaying||service==null||home==null)return;
        Song song=service.current();if(song==null){pendingLocatePlaying=false;return;}
        if(scanning)return;
        home.showDrawer(false);root.setVisibility(View.GONE);
        if(section.equals("歌手")||section.equals("专辑")){groupName=section.equals("歌手")?song.artist:song.album;refreshWall();}
        // A locate action reveals the player in the current section; it must not change navigation.
        home.ensureSongVisible(song);
        pendingLocatePlaying=false;home.locateSongDirectly(song.id);
    }
    private void refreshWall(){if(home==null)return;
        home.setPageKey(section+"\n"+(groupName==null?"":groupName));
        home.setCardState(ids("favorites"),service==null?1:service.mode,service==null||service.current()==null?0:(int)service.current().duration);
        List<Song> visible=new ArrayList<>();Set<String> favorites=ids("favorites"),recent=ids("recent");
        for(Song song:library){if(!groupRoot()&&!matches(song))continue;
            if(groupName!=null&&!(section.equals("歌手")?song.artist:song.album).equals(groupName))continue;
            if(section.equals("收藏")&&!favorites.contains(Long.toString(song.id)))continue;
            if(section.equals("最近播放")&&!recent.contains(Long.toString(song.id)))continue;
            if(section.startsWith("歌单:")&&!ids("playlist_"+section.substring(3)).contains(Long.toString(song.id)))continue;visible.add(song);
        }
        currentTracks.clear();
        if(groupRoot()){
            java.util.Map<String,Song> groups=new java.util.LinkedHashMap<>();
            for(Song sample:visible){String name=section.equals("歌手")?sample.artist:sample.album;Song group=groups.get(name);
                if(group==null){group=new Song(sample.id,0,sample.albumId,name,"",sample.album,sample.path,sample.uri);group.artworkUri=sample.artworkUri;group.artworkVersion=sample.artworkVersion;group.artworkPreview=sample.artworkPreview;group.artworkFile=sample.artworkFile;group.artworkCacheKey=sample.artworkCacheKey;group.artworkPrepared=sample.artworkPrepared;groups.put(name,group);}group.groupCount++;
            }
            List<Song> cards=new ArrayList<>();for(Song group:groups.values())if(group.title.toLowerCase(Locale.ROOT).contains(query))cards.add(group);
            cards.sort(LibraryOrdering.comparator(sortField(),sortAscending(),true));home.updateWall(cards,true);
        }else{
            if(section.equals("最近播放"))visible.sort((a,b)->Long.compare(prefs.getLong("recent_time_"+b.id,0),prefs.getLong("recent_time_"+a.id,0)));
            else visible.sort(LibraryOrdering.comparator(sortField(),sortAscending(),false));currentTracks.addAll(visible);home.updateWall(visible,false);
        }
        home.setBrowseContext(groupName,section);home.setSorting(section.equals("最近播放")?null:sortField(),sortAscending());
    }
    private void playFromWall(Song song){if(groupRoot()){openGroup(song.title);return;}play(song);home.songSelected();}
    private void showSettings(){settings.show(library.size(),scanning);}
    private void showPlaybackModeDialog(){int current=service==null?prefs.getInt("playback_mode",1):service.mode;int next=(PlaybackModes.valid(current)+1)%PlaybackModes.NAMES.length;prefs.edit().putInt("playback_mode",next).apply();if(service!=null)service.setMode(next);refreshPlayer();}
    private void showQueue(){if(service==null)return;
        List<Song> queue=new ArrayList<>(service.queue);int selected=service.index;
        final android.app.Dialog[] sheet={null};sheet[0]=BottomSheet.queue(this,"播放队列 · "+queue.size()+" 首",body->{
            if(queue.isEmpty()){BottomSheet.action(this,body,"暂无播放队列",()->{});return;}
            for(int i=0;i<queue.size();i++){Song song=queue.get(i);int index=i;
                TextView row=BottomSheet.action(this,body,(i==selected?"▸  ":"    ")+song.title+"  ·  "+song.artist,()->{if(service!=null)service.select(index);if(sheet[0]!=null)sheet[0].dismiss();});
                row.setSingleLine(true);row.setEllipsize(android.text.TextUtils.TruncateAt.END);
                if(i==selected)row.setTextColor(0xFF20C796);
            }
        });
    }
    private void showSearch(){EditText input=new EditText(this);input.setSingleLine(true);input.setHint("搜索歌曲、歌手或专辑");new AlertDialog.Builder(this).setTitle("搜索音乐库").setView(input).setNegativeButton("取消",null).setPositiveButton("搜索",(dialog,which)->{query=input.getText().toString().toLowerCase(Locale.ROOT);selectSection("歌曲");}).show();}
    private void showCache(){new CachePage(this,()->scanning,()->{ArtworkCache.clear();LibrarySnapshot.forgetResident();}).open();}
    @Override public void onBackPressed(){if(home!=null&&home.isDrawerOpen()){home.showDrawer(false);return;}if(home!=null&&home.collapsePlayer())return;if(home!=null&&home.closeSearch())return;if(root!=null&&root.getVisibility()==View.VISIBLE){root.setVisibility(View.GONE);return;}if(home!=null&&home.isDrawerOpen()){home.showDrawer(false);return;}if(backGroup())return;super.onBackPressed();}
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
    private void play(Song song){if(service==null){pendingPlay=song;startService(new Intent(this,PlaybackService.class));return;}
        List<Song> queue=new ArrayList<>(currentTracks);int selected=-1;for(int i=0;i<queue.size();i++)if(queue.get(i).id==song.id){selected=i;break;}
        if(selected<0){queue.clear();queue.add(song);selected=0;}Set<String> recent=ids("recent");recent.add(Long.toString(song.id));saveIds("recent",recent);prefs.edit().putLong("recent_time_"+song.id,System.currentTimeMillis()).apply();
        startService(new Intent(this,PlaybackService.class));service.setQueue(queue,selected);
        if(service.player==null)new AlertDialog.Builder(this).setTitle("无法播放").setMessage("无法读取这首歌曲，请检查文件是否仍在手机中。").setPositiveButton("确定",null).show();
    }
    private void songMenu(Song song){
        boolean favorite=ids("favorites").contains(Long.toString(song.id));
        List<String> options=new ArrayList<>(java.util.Arrays.asList("播放","查看歌词",favorite?"取消收藏":"收藏歌曲","加入歌单…"));
        if(section.startsWith("歌单:"))options.add("从此歌单移除");
        final android.app.Dialog[] sheet={null};
        sheet[0]=BottomSheet.show(this,"歌曲操作",body->{
            LinearLayout info=new LinearLayout(this);info.setGravity(Gravity.CENTER_VERTICAL);info.setPadding(dp(14),dp(4),dp(14),dp(18));
            android.widget.ImageView cover=new android.widget.ImageView(this);cover.setScaleType(android.widget.ImageView.ScaleType.CENTER_CROP);
            android.graphics.Bitmap artwork=ArtworkCache.peek(song,256);cover.setImageBitmap(artwork!=null?artwork:song.artworkPreview);
            android.graphics.drawable.GradientDrawable background=new android.graphics.drawable.GradientDrawable();background.setColor(0xFF30433C);background.setCornerRadius(dp(12));cover.setBackground(background);cover.setClipToOutline(true);
            info.addView(cover,new LinearLayout.LayoutParams(dp(64),dp(64)));
            LinearLayout metadata=new LinearLayout(this);metadata.setOrientation(LinearLayout.VERTICAL);metadata.setPadding(dp(14),0,0,0);
            TextView title=label(song.title,18,Color.WHITE);title.setTypeface(null,android.graphics.Typeface.BOLD);title.setMaxLines(2);title.setEllipsize(android.text.TextUtils.TruncateAt.END);metadata.addView(title);
            TextView subtitle=label(song.artist+" · "+song.album,13,0xFFB9C8C0);subtitle.setMaxLines(2);subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);metadata.addView(subtitle);
            info.addView(metadata,new LinearLayout.LayoutParams(0,-2,1));body.addView(info);
            for(int i=0;i<options.size();i++){final int index=i;
                TextView row=BottomSheet.action(this,body,options.get(i),()->{
                    sheet[0].dismiss();
                    if(index==0)play(song);
                    else if(index==1)showLyricsFor(song);
                    else if(index==2){Set<String> saved=ids("favorites");String id=Long.toString(song.id);if(!saved.add(id))saved.remove(id);saveIds("favorites",saved);refreshWall();home.setCardState(saved,service==null?prefs.getInt("playback_mode",1):service.mode,service==null||service.current()==null?0:(int)service.current().duration);}
                    else if(index==3)addToPlaylist(song);
                    else{String key="playlist_"+section.substring(3);Set<String> saved=ids(key);saved.remove(Long.toString(song.id));saveIds(key,saved);refreshWall();home.updateDrawer(section,ids("playlists"));}
                });
                if(index==4)row.setTextColor(0xFFFF9292);
            }
        });
    }

    private void favoriteSongs(List<Song> songs,boolean value){
        if(songs.isEmpty())return;Set<String> saved=ids("favorites");for(Song song:songs){String id=Long.toString(song.id);if(value)saved.add(id);else saved.remove(id);}saveIds("favorites",saved);refreshWall();
    }
    private void clearRecent(){
        new AlertDialog.Builder(this).setTitle("清空最近播放记录？").setMessage("清空记录后，歌曲和当前播放队列会保留。").setNegativeButton("取消",null).setPositiveButton("清空",(dialog,which)->{SharedPreferences.Editor edit=prefs.edit();for(String id:ids("recent"))edit.remove("recent_time_"+id);edit.remove("recent").apply();refreshWall();}).show();
    }
    private void removePlaylistSongs(List<Song> songs){
        if(songs.isEmpty()||!section.startsWith("歌单:"))return;String name=section.substring(3);List<Song> snapshot=new ArrayList<>(songs);
        new AlertDialog.Builder(this).setTitle("从歌单移除 "+snapshot.size()+" 首歌曲？").setMessage("只修改“"+name+"”的内容，保留歌曲文件。").setNegativeButton("取消",null).setPositiveButton("移除",(dialog,which)->{if(!ids("playlists").contains(name))return;Set<String> saved=ids("playlist_"+name);for(Song song:snapshot)saved.remove(Long.toString(song.id));saveIds("playlist_"+name,saved);refreshWall();home.updateDrawer(section,ids("playlists"));}).show();
    }
    private void addToPlaylist(Song song){addToPlaylist(java.util.Collections.singletonList(song));}
    private void addToPlaylist(List<Song> songs){
        if(songs.isEmpty())return;List<Song> snapshot=new ArrayList<>(songs);List<String> names=new ArrayList<>(new java.util.TreeSet<>(ids("playlists")));names.add("＋ 新建歌单");
        new AlertDialog.Builder(this).setTitle("将 "+snapshot.size()+" 首歌曲加入歌单").setItems(names.toArray(new String[0]),(dialog,index)->{
            if(index==names.size()-1){createPlaylist(snapshot);return;}String name=names.get(index);if(!ids("playlists").contains(name))return;Set<String> saved=ids("playlist_"+name);for(Song song:snapshot)saved.add(Long.toString(song.id));saveIds("playlist_"+name,saved);refreshWall();home.updateDrawer(section,ids("playlists"));android.widget.Toast.makeText(this,"已加入歌单",android.widget.Toast.LENGTH_SHORT).show();
        }).show();
    }
    private void playlistMenu(String name){
        new AlertDialog.Builder(this).setTitle(name).setItems(new String[]{"重命名歌单","删除歌单"},(dialog,index)->{
            if(index==0){EditText input=new EditText(this);input.setSingleLine(true);input.setText(name);input.setSelection(name.length());
                AlertDialog editor=new AlertDialog.Builder(this).setTitle("重命名歌单").setView(input).setNegativeButton("取消",null).setPositiveButton("保存",null).create();editor.setOnShowListener(v->editor.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(button->{String next=input.getText().toString().trim();Set<String> names=ids("playlists");if(next.isEmpty()){input.setError("请输入歌单名称");return;}if(!next.equals(name)&&names.contains(next)){input.setError("已有同名歌单");return;}if(!next.equals(name)){Set<String> tracks=ids("playlist_"+name);names.remove(name);names.add(next);prefs.edit().putStringSet("playlists",names).remove("playlist_"+name).putStringSet("playlist_"+next,tracks).apply();if(section.equals("歌单:"+name))selectSection("歌单:"+next);}home.updateDrawer(section,ids("playlists"));editor.dismiss();}));editor.show();
            }else new AlertDialog.Builder(this).setTitle("删除歌单？").setMessage("将删除“"+name+"”，保留歌曲文件。").setNegativeButton("取消",null).setPositiveButton("删除",(d,w)->{Set<String> names=ids("playlists");names.remove(name);prefs.edit().putStringSet("playlists",names).remove("playlist_"+name).apply();if(section.equals("歌单:"+name))selectSection("歌曲");home.updateDrawer(section,names);}).show();
        }).show();
    }
    private void createPlaylist(){createPlaylist(java.util.Collections.emptyList());}
    private void createPlaylist(List<Song> initial){
        List<Song> snapshot=new ArrayList<>(initial);EditText input=new EditText(this);input.setSingleLine(true);input.setHint("歌单名称");input.setPadding(dp(20),dp(12),dp(20),dp(12));
        AlertDialog editor=new AlertDialog.Builder(this).setTitle("新建歌单").setView(input).setNegativeButton("取消",null).setPositiveButton("创建",null).create();
        editor.setOnShowListener(v->editor.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(button->{String name=input.getText().toString().trim();Set<String> names=ids("playlists");if(name.isEmpty()){input.setError("请输入歌单名称");return;}if(names.contains(name)){input.setError("已有同名歌单");return;}names.add(name);Set<String> tracks=new HashSet<>();for(Song song:snapshot)tracks.add(Long.toString(song.id));prefs.edit().putStringSet("playlists",names).putStringSet("playlist_"+name,tracks).apply();refreshWall();home.updateDrawer(section,names);editor.dismiss();}));editor.show();
    }
    private void showPlaylist(String name){List<Song> selected=new ArrayList<>();Set<String> saved=ids("playlist_"+name);for(Song song:library)if(saved.contains(Long.toString(song.id)))selected.add(song);showSongDialog(name,selected);}
    private void showSongDialog(String title,List<Song> songs){String[] names=new String[songs.size()];for(int i=0;i<songs.size();i++)names[i]=songs.get(i).title+" · "+songs.get(i).artist;new AlertDialog.Builder(this).setTitle(title).setItems(names,(d,index)->play(songs.get(index))).setPositiveButton("关闭",null).show();}
    private String time(int ms){return String.format(Locale.ROOT,"%d:%02d",ms/60000,(ms/1000)%60);}
    private void refreshPlayer(){if(service==null||now==null)return;Song song=service.current();if(song==null)return;
        if(song.id!=lastRecentId){lastRecentId=song.id;if(service.isPlaying())prefs.edit().putLong("recent_time_"+song.id,System.currentTimeMillis()).apply();Set<String> recent=ids("recent");recent.add(Long.toString(song.id));saveIds("recent",recent);}
        home.setNowPlaying(song);home.setCardState(ids("favorites"),service.mode,(int)song.duration);
        home.setPlayback(song.id,song.title,service.isPlaying(),service.position(),(int)song.duration);loadPlayingLyrics(song);
        if(root.getVisibility()==View.VISIBLE){now.setText((service.isPlaying()?"▶ ":"Ⅱ ")+song.title+" · "+song.artist+"  ♪ 歌词");progress.setMax((int)Math.max(1,song.duration));if(!progress.isPressed())progress.setProgress(service.position());elapsed.setText(time(service.position())+" / "+time((int)song.duration));}}
    private void invalidateLyricsLoad(){lyricsLoad.reset();}
    private Song lyricSong(Song song){for(Song item:library)if(item.id==song.id||item.uri.equals(song.uri))return item;return song;}
    private void loadPlayingLyrics(Song song){
        Song resolved=lyricSong(song);String manual=prefs.getString("lyrics_"+song.id,"");
        String sourceKey=resolved.artworkVersion+":"+resolved.lyricUri+":"+resolved.lyricsRaw.hashCode()+":"+manual;
        int generation=lyricsLoad.begin(song.id,sourceKey,android.os.SystemClock.uptimeMillis());if(generation==0)return;
        if(resolved.lyricsPrepared){displayPlayingLyrics(song.id,resolved,manual,generation);return;}
        home.setLyricsStatus(song.id,"正在加载歌词…");
        new Thread(()->{LyricsRepository.prepareSong(getApplicationContext(),resolved);runOnUiThread(()->{if(lyricsLoad.current(generation)&&!isDestroyed())displayPlayingLyrics(song.id,resolved,manual,generation);});},"load-lyrics").start();
    }
    private void displayPlayingLyrics(long id,Song resolved,String manual,int generation){
        String raw=LyricsRepository.select(resolved,manual);List<Lyrics.Line> lines=Lyrics.parse(raw);home.setLyrics(id,lines);
        if(!lines.isEmpty())return;
        String error=resolved.lyricsError;
        home.setLyricsStatus(id,scanning?"正在加载歌词…":error!=null?error:resolved.lyricReadFailed?"歌词暂时无法加载":"暂无歌词");
        if(error!=null){resolved.lyricsPrepared=false;lyricsLoad.fail(generation,android.os.SystemClock.uptimeMillis());}
    }
    private void showLyrics(){if(service!=null&&service.current()!=null)showLyricsFor(service.current());}
    private void showLyricsFor(Song song){
        Song resolved=lyricSong(song);String manual=prefs.getString("lyrics_"+song.id,"");
        new Thread(()->{LyricsRepository.prepareSong(getApplicationContext(),resolved);String raw=LyricsRepository.select(resolved,manual);runOnUiThread(()->{if(!isFinishing())displayLyrics(song,raw);});},"show-lyrics").start();
    }
    private void displayLyrics(Song song,String raw){
        List<Lyrics.Line> lines=Lyrics.parse(raw);
        StringBuilder body=new StringBuilder();for(Lyrics.Line line:lines)body.append(time((int)line.ms)).append("  ").append(line.text).append("\n\n");
        new AlertDialog.Builder(this).setTitle(song.title+" · 歌词")
            .setMessage(body.length()==0?"暂无歌词。可在歌曲目录的 lrc 文件夹放入同名 .lrc，或手动导入。":body.toString())
            .setNeutralButton("导入 LRC",(d,w)->{pendingLyricSong=song;Intent picker=new Intent(Intent.ACTION_OPEN_DOCUMENT);picker.setType("*/*");picker.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(picker,2);})
            .setPositiveButton("关闭",null).show();
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==3&&result==RESULT_OK&&data!=null&&data.getData()!=null){
            try{getContentResolver().takePersistableUriPermission(data.getData(),Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(Exception ignored){}
            Set<String> folders=ids("music_folders");folders.add(data.getData().toString());saveIds("music_folders",folders);prefs.edit().putBoolean("folder_library",true).apply();sourcesChanged();settings.refresh(library.size(),scanning);return;
        }
        if(request!=2||result!=RESULT_OK||data==null||pendingLyricSong==null)return;
        Song song=pendingLyricSong;pendingLyricSong=null;
        new Thread(()->{try{String raw=Lyrics.read(this,data.getData());prefs.edit().putString("lyrics_"+song.id,raw).apply();runOnUiThread(()->{invalidateLyricsLoad();refreshPlayer();if(!isFinishing())showLyricsFor(song);});}
            catch(Exception e){runOnUiThread(()->{if(!isFinishing())new AlertDialog.Builder(this).setMessage("无法读取歌词文件："+e.getMessage()).setPositiveButton("确定",null).show();});}}).start();
    }
}
