package com.xcosmos.minivoice;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.ClipDrawable;
import android.graphics.drawable.LayerDrawable;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.EditText;
import android.widget.TextView;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.io.File;
import java.io.FileOutputStream;

final class HomeScreen {
    interface Actions {
        void section(String name);
        void backGroup();
        void sort(String field,boolean ascending);

        void playlist(String name);
        void playlistMenu(String name);
        void songMenu(Song song);

        void newPlaylist();

        void settings();

        void search(String query);

        void play(Song song);

        void toggle();

        void previous();

        void next();

        void lyrics();

        void locate();

        void queue();

        void seek(int ms);

        int playbackMode();
        void selectPlaybackMode(int mode);

        void favorite(Song song);
        void favoriteSongs(List<Song> songs,boolean value);
        void playlistSongs(List<Song> songs);
        void removePlaylistSongs(List<Song> songs);
        void clearRecent();
    }

    private final Activity activity;
    private final Actions actions;
    private final FrameLayout frame, drawerLayer;
    private final ScrollView drawerScroll;
    private final FrameLayout drawerPanel;
    private GlassBackdrop wallGlass,drawerGlass;
    private final DrawerMaterialState drawerMaterial=new DrawerMaterialState();
    private LinearLayout drawerContent,drawerBrand,simpleDrawerRoot;
    private PlayerStylePage sidebarPage;
    private EditText drawerSearch;
    private TextView simpleLibraryTab,simpleRecentTab;
    private final LinearLayout player;
    private IdlePlaybackDock idleDock;
    private StandardPlaybackBar standardBar;
    private final ImageView wallSettings;
    private ImageView menuButton, drawerClose, drawerSettings;
    private TextView drawerName,drawerSubtitle;
    private String drawerSelected="歌曲";
    private Set<String> drawerPlaylists=Set.of();
    private int styleTransitionEpoch;
    private final PlayerStyleTransition fragmentTransition;
    private boolean fragmentSwitch;
    private final WallSearchControl searchControl;
    private TextView detailBack;
    private boolean immersive,restoreSearch,landscape,chromeHidden,awaitingRotationLayout,keyboardVisible;
    private int keyboardBottom;
    private int safeLeft,safeTop,safeRight,safeBottom,portraitDockWidth;
    private FrameLayout.LayoutParams dockParams,toolsParams;
    private boolean libraryScanning;
    private LibraryLoadingView libraryLoading;
    private String scanMessage="正在扫描音乐库…";
    void scanProgress(String stage,int completed,int total){scanMessage=(stage==null||stage.isEmpty()?"正在扫描音乐库":stage)+"…"+(total>0?"\n"+completed+" / "+total+" · "+ScanStatusText.percent(completed,total)+"%":"");stylePage.scanProgress(scanMessage);if(sidebarPage!=null)sidebarPage.scanProgress(scanMessage);updateLibraryLoading();}
    private void updateLibraryLoading(){if(libraryLoading==null)return;AppAppearance.Palette colors=AppAppearance.palette(activity,activity.getSharedPreferences("library",0));libraryLoading.palette(colors);libraryLoading.setBackgroundColor(colors.background);libraryLoading.state(libraryScanning,scanMessage);libraryLoading.setVisibility(libraryScanning&&visibleSongs.isEmpty()?View.VISIBLE:View.GONE);}
    void setScanning(boolean value){libraryScanning=value;wall.setScanning(value);stylePage.setScanning(value);if(sidebarPage!=null)sidebarPage.setScanning(value);updateLibraryLoading();}
    private final LinearLayout drawerRows;
    private final WallView wall;
    private final PlayerStylePage stylePage;
    private String playerStyle="wall";
    private boolean restoringWallState;
    private final TextView current;
    private final TransportButton playButton;
    private final SeekBar seek;
    private final EditText searchInput;
    private boolean drawerOpen = false;
    private boolean groupedWall;
    private String sortingField="added";private boolean sortingAscending=false;private String browseSection="歌曲",browseGroup,pageKey;
    private TextView browseHeading;
    private final java.util.Map<String,WallView.CameraState> pageCameras=new java.util.HashMap<>();
    private WallView.CameraState pendingCamera;
    private List<Song> visibleSongs=new ArrayList<>();
    private long displayedSongId = Long.MIN_VALUE;
    private final int green = Color.rgb(21, 188, 135);
    private final Handler main = new Handler();

    HomeScreen(Activity activity, Actions actions) {
        this.activity = activity;
        this.actions = actions;
        frame = new FrameLayout(activity);
        fragmentTransition=new PlayerStyleTransition(activity,frame);
        frame.setBackgroundColor(Color.rgb(7, 12, 13));
        wall = new WallView(activity, actions::play, actions::toggle, actions::seek);
        wall.setSongMenu(actions::songMenu);
        frame.addView(wall, new FrameLayout.LayoutParams(-1, -1));
        stylePage=new PlayerStylePage(activity,actions::play,actions::seek,actions::lyrics,this::browseSimpleSongs);stylePage.setPlaybackActions(actions);stylePage.setSongLaunch(this::animateSongLaunch);stylePage.setSidebarLocate(this::focusLibrarySong);stylePage.setSongMenu(actions::songMenu);stylePage.setTools(actions::backGroup,this::showSortingOptions,actions::queue,actions::favorite);stylePage.setSortAction(actions::sort);stylePage.setBatchActions(new PlayerStylePage.BatchActions(){
            public void favorite(List<Song> songs,boolean value){actions.favoriteSongs(songs,value);}
            public void playlist(List<Song> songs){actions.playlistSongs(songs);}
            public void removeFromPlaylist(List<Song> songs){actions.removePlaylistSongs(songs);}
            public void clearRecent(){actions.clearRecent();}
        });frame.addView(stylePage,new FrameLayout.LayoutParams(-1,-1));
        libraryLoading=new LibraryLoadingView(activity);libraryLoading.setVisibility(View.GONE);frame.addView(libraryLoading,new FrameLayout.LayoutParams(-1,-1));
        browseHeading=text("",14,Color.WHITE);browseHeading.setSingleLine(true);browseHeading.setEllipsize(android.text.TextUtils.TruncateAt.END);browseHeading.setGravity(Gravity.CENTER_VERTICAL);browseHeading.setPadding(dp(14),0,dp(14),0);browseHeading.setBackground(round(0xDF232B27,20,0x44FFFFFF,1));browseHeading.setOnClickListener(view->actions.backGroup());browseHeading.setVisibility(View.GONE);
        FrameLayout.LayoutParams headingParams=new FrameLayout.LayoutParams(-2,dp(40),Gravity.TOP|Gravity.LEFT);headingParams.setMargins(dp(16),dp(90),dp(16),0);frame.addView(browseHeading,headingParams);
        ImageView menu = roundImage(R.drawable.icon_wall_sidebar, () -> showDrawer(true));
        FrameLayout.LayoutParams menuParams = new FrameLayout.LayoutParams(dp(WallToolStyle.SIDE), dp(WallToolStyle.SIDE), Gravity.TOP | Gravity.LEFT);
        menuParams.setMargins(dp(14), dp(6), 0, 0);
        frame.addView(menu, menuParams);menuButton=menu;
        searchControl=new WallSearchControl(activity);
        searchControl.setBackground(glass().surface(searchControl,28,false));
        FrameLayout.LayoutParams searchParams=new FrameLayout.LayoutParams(dp(WallToolStyle.SIDE),dp(WallToolStyle.SIDE),Gravity.TOP|Gravity.RIGHT);
        searchParams.setMargins(0,dp(6),dp(14),0);frame.addView(searchControl,searchParams);
        detailBack=text("返回",16,green);detailBack.setGravity(Gravity.CENTER);detailBack.setPadding(dp(10),0,dp(10),0);detailBack.setCompoundDrawablePadding(dp(2));detailBack.setSingleLine(true);detailBack.setContentDescription("返回音乐库");detailBack.setVisibility(View.GONE);
        detailBack.setOnClickListener(v->stylePage.collapse());ButtonFeedback.install(detailBack);
        FrameLayout.LayoutParams backParams=new FrameLayout.LayoutParams(dp(76),dp(44),Gravity.TOP|Gravity.LEFT);frame.addView(detailBack,backParams);
        stylePage.setDetailChanged(()->{updateDetailBack();frame.post(this::updateViewport);});
        searchInput=searchControl.input;
        searchInput.addTextChangedListener(new android.text.TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if(drawerSearch!=null&&!s.toString().contentEquals(drawerSearch.getText()))drawerSearch.setText(s);
                actions.search(s.toString());
                if(playerStyle.equals("simple")&&s.length()>0&&!drawerOpen)stylePage.showCatalog();
            }

            public void afterTextChanged(android.text.Editable e) {
            }
        });
        player = new LinearLayout(activity);
        player.setGravity(Gravity.CENTER_VERTICAL);
        player.setPadding(dp(10), 0, dp(10), 0);
        idleDock=new IdlePlaybackDock(activity,player,this::dockProgress);idleDock.setBackground(glass().surface(idleDock,42,false));
        FrameLayout.LayoutParams playerParams = new FrameLayout.LayoutParams(-1, dp(84), Gravity.BOTTOM);
        playerParams.setMargins(dp(16), 0, dp(16), dp(14));
        frame.addView(idleDock, playerParams);dockParams=playerParams;

        playButton = new TransportButton(activity, TransportButton.Glyph.PLAY_PAUSE, actions::toggle);
        playButton.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x18000000), round(0xFFF3F3F3, 31, 0, 0), round(Color.WHITE, 31, 0, 0)));
        player.addView(playButton, new LinearLayout.LayoutParams(dp(62), dp(62)));
        LinearLayout middle = new LinearLayout(activity);
        middle.setOrientation(LinearLayout.VERTICAL);
        middle.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams middleParams = new LinearLayout.LayoutParams(0, dp(76), 1);
        middleParams.setMargins(dp(8), 0, dp(4), 0);
        player.addView(middle, middleParams);
        LinearLayout middleTop = new LinearLayout(activity);
        middleTop.setGravity(Gravity.CENTER_VERTICAL);
        middle.addView(middleTop, new LinearLayout.LayoutParams(-1, dp(44)));
        TransportButton previous = new TransportButton(activity, TransportButton.Glyph.PREVIOUS, actions::previous);
        middleTop.addView(previous, new LinearLayout.LayoutParams(dp(44), dp(44)));
        current = text("选择歌曲", 15, Color.WHITE);
        current.setGravity(Gravity.CENTER);
        current.setSingleLine(true);
        current.setEllipsize(android.text.TextUtils.TruncateAt.END);
        current.setOnClickListener(v -> actions.locate());
        current.setOnLongClickListener(v -> {actions.lyrics();return true;});
        middleTop.addView(current, new LinearLayout.LayoutParams(0, -1, 1));
        TransportButton next = new TransportButton(activity, TransportButton.Glyph.NEXT, actions::next);
        middleTop.addView(next, new LinearLayout.LayoutParams(dp(44), dp(44)));
        seek = new SeekBar(activity);
        styleSeekBar(seek);
        ((GradientDrawable)((LayerDrawable)seek.getProgressDrawable()).findDrawableByLayerId(android.R.id.background)).setSize(1,dp(3));
        GradientDrawable dockThumb=new GradientDrawable();dockThumb.setShape(GradientDrawable.OVAL);dockThumb.setColor(Color.WHITE);dockThumb.setSize(dp(20),dp(20));seek.setThumb(dockThumb);seek.setThumbOffset(dp(10));seek.setPadding(dp(11),dp(4),dp(11),dp(4));
        ((LayerDrawable)seek.getProgressDrawable()).setLayerHeight(0,dp(3));((LayerDrawable)seek.getProgressDrawable()).setLayerGravity(0,Gravity.CENTER_VERTICAL);
        ((LayerDrawable)seek.getProgressDrawable()).setLayerHeight(1,dp(3));((LayerDrawable)seek.getProgressDrawable()).setLayerGravity(1,Gravity.CENTER_VERTICAL);
        ((LayerDrawable)seek.getProgressDrawable()).findDrawableByLayerId(android.R.id.progress).setTint(0xEFFFFFFF);seek.getThumb().setTint(Color.WHITE);
        seek.setMax(1);
        middle.addView(seek, new LinearLayout.LayoutParams(-1, dp(30)));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar bar, int value, boolean user) {
            }

            public void onStartTrackingTouch(SeekBar bar) {
            }

            public void onStopTrackingTouch(SeekBar bar) {
                actions.seek(bar.getProgress());
            }
        });
        TransportButton queue = new TransportButton(activity, TransportButton.Glyph.QUEUE, actions::queue);
        player.addView(queue, new LinearLayout.LayoutParams(dp(44), dp(44)));
        standardBar=new StandardPlaybackBar(activity,actions,()->stylePage.toggleExpanded());FrameLayout.LayoutParams standardParams=new FrameLayout.LayoutParams(-1,dp(104),Gravity.BOTTOM);standardParams.setMargins(dp(14),0,dp(14),dp(8));frame.addView(standardBar,standardParams);
        wallSettings = roundImage(R.drawable.icon_wall_settings, this::showWallOptions);
        FrameLayout.LayoutParams wallSettingsParams = new FrameLayout.LayoutParams(dp(WallToolStyle.SIDE), dp(WallToolStyle.SIDE), Gravity.RIGHT | Gravity.BOTTOM);
        wallSettingsParams.setMargins(0, 0, dp(16), dp(112));
        frame.addView(wallSettings, wallSettingsParams);toolsParams=wallSettingsParams;
        drawerLayer = new FrameLayout(activity);
        // The standard footer has elevation; the entire modal layer, including
        // its scrim and touch target, must sit above that footer.
        drawerLayer.setElevation(dp(16));
        drawerLayer.setClickable(true);
        frame.addView(drawerLayer, new FrameLayout.LayoutParams(-1, -1));
        drawerLayer.setBackgroundColor(0x99000000);
        View outside = new View(activity);
        drawerLayer.addView(outside, new FrameLayout.LayoutParams(-1, -1));
        outside.setOnClickListener(v -> showDrawer(false));
        drawerScroll = new ScrollView(activity);
        drawerScroll.setFillViewport(true);
        ListScrollStyle.apply(drawerScroll);
        FrameLayout.LayoutParams drawerParams = new FrameLayout.LayoutParams(Math.min(dp(340), Math.round(activity.getResources().getDisplayMetrics().widthPixels * .80f)), -1, Gravity.LEFT);
        drawerPanel = new FrameLayout(activity);
        drawerPanel.setClickable(true);
        drawerPanel.setBackground(glass().surface(drawerPanel,24,true));
        drawerLayer.addView(drawerPanel, drawerParams);
        drawerPanel.addView(drawerScroll, new FrameLayout.LayoutParams(-1,-1));
        LinearLayout drawer = new LinearLayout(activity);drawerContent=drawer;
        drawer.setOrientation(LinearLayout.VERTICAL);
        drawer.setPadding(dp(12), dp(14), dp(12), dp(14));
        drawer.setBackgroundColor(Color.TRANSPARENT);
        drawerScroll.addView(drawer);
        LinearLayout brand = new LinearLayout(activity);drawerBrand=brand;
        brand.setGravity(Gravity.CENTER_VERTICAL);
        brand.setMinimumHeight(dp(64));
        drawer.addView(brand, new LinearLayout.LayoutParams(-1, -2));
        ImageView icon = new ImageView(activity);
        icon.setImageResource(R.drawable.minivoice_icon);
        icon.setScaleType(ImageView.ScaleType.CENTER_CROP);
        icon.setBackground(round(0xFF3ED766, 14, 0, 0));
        icon.setClipToOutline(true);
        brand.addView(icon, new LinearLayout.LayoutParams(dp(48), dp(48)));
        icon.setContentDescription("切换播放器样式：简易、音乐库、音乐墙");
        icon.setOnClickListener(v->{
            if(fragmentTransition.isRunning())return;
            icon.performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);
            Runnable changeStyle=()->{
            fragmentSwitch=true;stylePage.setSnapshotTransition(true);
            try{
            String nextStyle=playerStyle.equals("simple")?"library":playerStyle.equals("library")?"wall":"simple";
            activity.getSharedPreferences("library",Activity.MODE_PRIVATE).edit().putString("player_style",nextStyle).apply();
            searchInput.setText("");actions.section("歌曲");applyAppearance();if(playerStyle.equals("simple"))stylePage.showPlayer();updateViewport();
            icon.announceForAccessibility(nextStyle.equals("simple")?"简易样式":nextStyle.equals("library")?"音乐库样式":"音乐墙样式");
            }finally{fragmentSwitch=false;stylePage.setSnapshotTransition(false);}
        };fragmentTransition.run(icon,changeStyle);});
        LinearLayout title = new LinearLayout(activity);
        title.setOrientation(LinearLayout.VERTICAL);
        title.setPadding(dp(12), 0, 0, 0);
        brand.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        TextView name = text("MiniVoice", 19, Color.WHITE);
        name.setTypeface(null, Typeface.BOLD);
        title.addView(name);drawerName=name;
        TextView sub = text("音乐让生活更美好", 11, 0xFF9DA7A4);
        sub.setSingleLine(false);
        sub.setEllipsize(null);
        sub.setPadding(0, dp(3), 0, 0);
        title.addView(sub);drawerSubtitle=sub;
        ImageView settings=imageButton(R.drawable.icon_settings_gear,Color.WHITE,actions::settings);drawerSettings=settings;settings.setContentDescription("设置");settings.setTooltipText("设置");settings.setPadding(dp(10),dp(10),dp(10),dp(10));
        brand.addView(settings,new LinearLayout.LayoutParams(dp(44),dp(44)));
        ImageView closeDrawer = imageButton(R.drawable.icon_close, Color.WHITE, () -> showDrawer(false));
        drawerClose=closeDrawer;
        closeDrawer.setPadding(dp(8), dp(8), dp(8), dp(8));
        brand.addView(closeDrawer, new LinearLayout.LayoutParams(dp(34), dp(42)));
        drawerRows = new LinearLayout(activity);
        drawerRows.setOrientation(LinearLayout.VERTICAL);
        drawerRows.setPadding(0, dp(12), 0, 0);
        drawer.addView(drawerRows);
        View spacer = new View(activity);
        drawer.addView(spacer, new LinearLayout.LayoutParams(1, 0, 1));
        buildSimpleDrawer();
        View drawerEdge=new View(activity);
        drawerEdge.setContentDescription("向左滑动关闭侧栏");
        drawerPanel.addView(drawerEdge,new FrameLayout.LayoutParams(dp(12),-1,Gravity.RIGHT));
        drawerEdge.setOnTouchListener(new View.OnTouchListener(){
            float start;android.view.VelocityTracker velocity;
            public boolean onTouch(View view,android.view.MotionEvent event){
                int action=event.getActionMasked();
                if(action==android.view.MotionEvent.ACTION_DOWN){drawerPanel.animate().cancel();drawerLayer.animate().cancel();start=event.getRawX()-drawerPanel.getTranslationX();velocity=android.view.VelocityTracker.obtain();}
                if(velocity==null)return true;velocity.addMovement(event);
                if(action==android.view.MotionEvent.ACTION_MOVE){float x=Math.min(0,event.getRawX()-start);drawerPanel.setTranslationX(x);drawerPanel.invalidate();drawerLayer.setAlpha(Math.max(0,1+x/Math.max(1,drawerPanel.getWidth())));}
                if(action==android.view.MotionEvent.ACTION_UP||action==android.view.MotionEvent.ACTION_CANCEL){velocity.computeCurrentVelocity(1000);boolean close=action==android.view.MotionEvent.ACTION_UP&&PanelDismiss.shouldClose(-drawerPanel.getTranslationX(),-velocity.getXVelocity(),drawerPanel.getWidth(),activity.getResources().getDisplayMetrics().density);velocity.recycle();velocity=null;if(close)showDrawer(false);else{animateDrawerPanel(0,220);drawerLayer.animate().alpha(1).setDuration(220).start();}}
                return true;
            }
        });
        drawerLayer.setVisibility(View.GONE);
        frame.setOnApplyWindowInsetsListener((view, insets) -> {
            landscape=activity.getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE;
            int top,bottom,left=0,right=0;
            if(android.os.Build.VERSION.SDK_INT>=30){android.graphics.Insets safe=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.displayCutout());top=safe.top;bottom=safe.bottom;left=safe.left;right=safe.right;}
            else{top=insets.getSystemWindowInsetTop();bottom=insets.getSystemWindowInsetBottom();android.view.DisplayCutout cutout=insets.getDisplayCutout();if(cutout!=null){left=cutout.getSafeInsetLeft();right=cutout.getSafeInsetRight();top=Math.max(top,cutout.getSafeInsetTop());bottom=Math.max(bottom,cutout.getSafeInsetBottom());}}
            if(landscape&&!isWallStyle()){int symmetric=Math.max(left,right);left=symmetric;right=symmetric;}
            safeLeft=left;safeTop=top;safeRight=right;safeBottom=bottom;
            menuParams.topMargin=top+dp(6);menuParams.leftMargin=left+dp(14);menu.setLayoutParams(menuParams);
            searchParams.topMargin=top+dp(6);searchParams.rightMargin=right+dp(14);searchControl.setLayoutParams(searchParams);
            drawerParams.width=Math.min(dp(320),Math.round((activity.getResources().getDisplayMetrics().widthPixels-left-right)*.82f));drawerParams.height=-1;drawerParams.bottomMargin=bottom+dp(8);drawerParams.leftMargin=left+dp(12);drawerParams.topMargin=top+dp(6);drawerParams.gravity=Gravity.TOP|Gravity.LEFT;drawerPanel.setLayoutParams(drawerParams);drawer.setPadding(dp(16),dp(14),dp(16),dp(14));
            keyboardBottom=android.os.Build.VERSION.SDK_INT>=30?insets.getInsets(WindowInsets.Type.ime()).bottom:0;
            boolean keyboard=android.os.Build.VERSION.SDK_INT>=30&&insets.isVisible(WindowInsets.Type.ime())&&keyboardBottom>bottom;keyboardVisible=keyboard;
            updateViewport();updatePlaybackBarVisibility();
            return insets;
        });
        wall.setCardActions(new WallView.CardActions(){
            public void previous(){actions.previous();}
            public void next(){actions.next();}
            public void favorite(Song song){actions.favorite(song);}
            public void immersive(boolean expanded){setImmersive(expanded);}
        });
        frame.addOnLayoutChangeListener((view,left,top,right,bottom,oldLeft,oldTop,oldRight,oldBottom)->{if(right-left!=oldRight-oldLeft||bottom-top!=oldBottom-oldTop)updateViewport();});
        ButtonFeedback.installTree(frame);
        wall.setScaleListener(this::zoomChanged);
        frame.post(frame::requestApplyInsets);
    }

    View view() {
        return frame;
    }

    boolean isDrawerOpen() {
        return drawerOpen;
    }

    private void animateDrawerPanel(float destination,long duration){
        // Translation alone reuses the old display list. The sampled background must be
        // recorded at every new screen position, including the final settled position.
        drawerPanel.animate().translationX(destination).setDuration(duration)
            .setUpdateListener(animation->drawerPanel.invalidate())
            .withEndAction(()->{drawerPanel.invalidate();drawerPanel.postOnAnimation(drawerPanel::invalidate);}).start();
    }

    void showDrawer(boolean open) {
        if (drawerOpen == open) return;
        drawerOpen = open;
        drawerPanel.animate().cancel();
        drawerLayer.animate().cancel();
        if (open) {
            drawerLayer.bringToFront();
            applyDrawerAppearance();
            drawerLayer.setVisibility(View.VISIBLE);
            if(playerStyle.equals("simple"))sidebarPage.refreshVisibleArtwork();
            drawerLayer.setAlpha(0);
            drawerPanel.setTranslationX(-drawerPanel.getLayoutParams().width-dp(20));
            drawerLayer.animate().alpha(1).setDuration(220).start();
            animateDrawerPanel(0,260);
        } else {
            drawerSearch.clearFocus();((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(drawerSearch.getWindowToken(),0);
            animateDrawerPanel(-drawerPanel.getLayoutParams().width-dp(20),230);
            drawerLayer.animate().alpha(0).setDuration(230).withEndAction(() -> {
                if (!drawerOpen) drawerLayer.setVisibility(View.GONE);
            }).start();
        }
    }

    void setPlayback(long id, String title, boolean playing, int position, int duration) {
        boolean changed = displayedSongId != id;
        displayedSongId = id;
        if(!title.contentEquals(current.getText()))current.setText(title);
        playButton.setPlaying(playing);idleDock.setPlaying(playing);standardBar.state(playing,position,duration);
        seek.setMax(Math.max(1, duration));
        if (!seek.isPressed()) seek.setProgress(position);
        wall.setPlayback(id, playing, position);stylePage.setPlayback(position,duration,playing);sidebarPage.setPlayback(position,duration,playing);
        // Playback changes update the visible player without navigating the catalog.
        // Only the wall follows the playing card automatically.
        if (changed && !groupedWall && isWallStyle()) wall.locateSong(id);
    }

    private ImageView flyingArtwork;
    private void animateSongLaunch(ImageView source){
        if(!playerStyle.equals("library")||!android.animation.ValueAnimator.areAnimatorsEnabled()||!standardBar.isShown())return;
        ImageView target=standardBar.artworkTarget();if(target==null||source.getDrawable()==null||source.getWidth()==0||target.getWidth()==0)return;
        if(flyingArtwork!=null){flyingArtwork.animate().cancel();frame.removeView(flyingArtwork);}
        int[] origin=new int[2],destination=new int[2],host=new int[2];source.getLocationInWindow(origin);target.getLocationInWindow(destination);frame.getLocationInWindow(host);
        ImageView flight=new ImageView(activity);flyingArtwork=flight;flight.setImageDrawable(source.getDrawable().getConstantState()==null?source.getDrawable():source.getDrawable().getConstantState().newDrawable().mutate());flight.setScaleType(ImageView.ScaleType.CENTER_CROP);flight.setBackground(round(Color.TRANSPARENT,8,0,0));flight.setClipToOutline(true);flight.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);flight.setElevation(dp(32));
        FrameLayout.LayoutParams bounds=new FrameLayout.LayoutParams(source.getWidth(),source.getHeight());bounds.leftMargin=origin[0]-host[0];bounds.topMargin=origin[1]-host[1];frame.addView(flight,bounds);flight.setPivotX(0);flight.setPivotY(0);
        flight.animate().translationX(destination[0]-origin[0]).translationY(destination[1]-origin[1]).scaleX(target.getWidth()/(float)source.getWidth()).scaleY(target.getHeight()/(float)source.getHeight()).alpha(.3f).setDuration(360).setInterpolator(new android.view.animation.DecelerateInterpolator()).withEndAction(()->{frame.removeView(flight);if(flyingArtwork==flight)flyingArtwork=null;}).start();
    }
    private void browseSimpleSongs(){actions.section("歌曲");stylePage.showCatalog();}
    void songSelected(){if(playerStyle.equals("simple"))stylePage.showPlayer();}
    void navigationChanged(){if(playerStyle.equals("simple"))stylePage.showCatalog();}
    void setNowPlaying(Song song){sidebarPage.setSong(song);stylePage.setSong(song);standardBar.song(song);}
    boolean isWallStyle(){return playerStyle.equals("wall");}
    void applyAppearance(){
        android.content.SharedPreferences prefs=activity.getSharedPreferences("library",Activity.MODE_PRIVATE);
        String nextStyle=AppAppearance.style(prefs);boolean changed=!playerStyle.equals(nextStyle);
        int epoch=++styleTransitionEpoch;
        wall.collapse();playerStyle=nextStyle;wall.animate().cancel();stylePage.animate().cancel();
        stylePage.configure(playerStyle,AppAppearance.palette(activity,prefs));stylePage.setSongs(visibleSongs);
        if(changed&&!fragmentSwitch&&android.animation.ValueAnimator.areAnimatorsEnabled()){
            if(isWallStyle()){
                wall.setVisibility(View.VISIBLE);wall.setAlpha(0);wall.animate().alpha(1).setDuration(300).start();
                stylePage.setVisibility(View.VISIBLE);stylePage.animate().cancel();stylePage.setAlpha(1);stylePage.animate().alpha(0).setDuration(220).withEndAction(()->{if(epoch==styleTransitionEpoch&&isWallStyle()){stylePage.setVisibility(View.GONE);stylePage.setAlpha(1);}}).start();
            }else{
                wall.setVisibility(View.VISIBLE);wall.setAlpha(1);wall.animate().alpha(0).setDuration(220).withEndAction(()->{if(epoch==styleTransitionEpoch&&!isWallStyle()){wall.setVisibility(View.GONE);wall.setAlpha(1);}}).start();
            }
        }else{wall.setVisibility(isWallStyle()?View.VISIBLE:View.GONE);wall.setAlpha(1);stylePage.setAlpha(1);}
        if(changed&&!fragmentSwitch&&!isWallStyle()&&android.animation.ValueAnimator.areAnimatorsEnabled()){standardBar.animate().cancel();standardBar.setAlpha(0);standardBar.setTranslationY(dp(14));standardBar.animate().alpha(1).translationY(0).setDuration(280).start();}
        standardBar.configure(AppAppearance.palette(activity,prefs),frame.getWidth()-safeLeft-safeRight>=dp(620),false);standardBar.setBackground(stylePage.glassSurface(standardBar,20,AppAppearance.dark(activity,prefs)));updatePlaybackBarVisibility();
        updateViewport();applyControlsAppearance();updateLibraryLoading();
        boolean light=!isWallStyle()&&!AppAppearance.dark(activity,prefs);int flags=activity.getWindow().getDecorView().getSystemUiVisibility();int lightFlags=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;activity.getWindow().getDecorView().setSystemUiVisibility(light?flags|lightFlags:flags&~lightFlags);
        browseHeading.setVisibility(isWallStyle()&&browseGroup!=null&&!chromeHidden?View.VISIBLE:View.GONE);
        if(idleDock!=null)idleDock.configure(Math.max(dp(56),Math.round(portraitDockWidth)),idleEligible());
        if(!isWallStyle())wallSettings.setVisibility(View.GONE);else if(!chromeHidden&&!keyboardVisible)wallSettings.setVisibility(View.VISIBLE);
    }
    void setCardState(Set<String> favorites,int mode,int duration){wall.setCardState(favorites,mode,duration);stylePage.setFavorites(favorites);sidebarPage.setFavorites(favorites);standardBar.mode(mode);}
    boolean collapsePlayer(){return isWallStyle()?wall.collapse():stylePage.collapse();}
    private void setImmersive(boolean expanded){
        immersive=expanded;
        idleDock.configure(Math.max(dp(56),Math.round(portraitDockWidth)),idleEligible());
        if(expanded){restoreSearch=searchControl.isOpen();showDrawer(false);searchControl.setOpen(false,false);}
        applyChromeVisibility((landscape&&(isWallStyle()||stylePage.landscapePlayback()||stylePage.landscapeLibrary()))||immersive,true);idleDock.animate().cancel();
        if(expanded){idleDock.animate().alpha(0).translationY(dp(24)).setDuration(180).withEndAction(()->{if(immersive)idleDock.setVisibility(View.INVISIBLE);}).start();}
        else{updatePlaybackBarVisibility();idleDock.animate().alpha(1).translationY(0).setDuration(230).start();}
        if(!expanded&&!landscape&&restoreSearch)searchControl.setOpen(true,false);
    }
    void orientationChanged(){
        fragmentTransition.cancel();
        boolean next=activity.getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE;
        if(next){showDrawer(false);searchControl.setOpen(false,false);}landscape=next;awaitingRotationLayout=true;
        applyChromeVisibility((landscape&&(isWallStyle()||stylePage.landscapePlayback()||stylePage.landscapeLibrary()))||immersive,true);frame.requestApplyInsets();frame.post(this::updateViewport);
    }
    private void applyChromeVisibility(boolean hidden,boolean animate){
        browseHeading.setVisibility(!hidden&&browseGroup!=null&&isWallStyle()?View.VISIBLE:View.GONE);if(chromeHidden==hidden)return;chromeHidden=hidden;
        View[] controls=isWallStyle()?new View[]{menuButton,searchControl,wallSettings}:new View[]{menuButton,searchControl};
        for(int i=0;i<controls.length;i++){View control=controls[i];control.animate().cancel();control.setVisibility(View.VISIBLE);control.setEnabled(!hidden);
            if(control==searchControl)for(int child=0;child<searchControl.getChildCount();child++)searchControl.getChildAt(child).setEnabled(!hidden);
            control.setImportantForAccessibility(hidden?View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:View.IMPORTANT_FOR_ACCESSIBILITY_AUTO);
            float x=hidden?(i==0?-1:1)*(Math.max(control.getWidth(),dp(56))+dp(80)):0,y=hidden?(i==2?1:-1)*dp(80):0;
            if(animate)control.animate().translationX(x).translationY(y).alpha(hidden?0:1).setDuration(280).withEndAction(()->{if(chromeHidden)control.setVisibility(View.INVISIBLE);}).start();
            else{control.setTranslationX(x);control.setTranslationY(y);control.setAlpha(hidden?0:1);control.setVisibility(hidden?View.INVISIBLE:View.VISIBLE);}
        }
    }
    private void updateViewport(){
        if(frame.getWidth()==0||frame.getHeight()==0)return;
        landscape=activity.getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE;
        if(awaitingRotationLayout&&(frame.getWidth()>frame.getHeight())!=landscape)return;
        awaitingRotationLayout=false;
        float density=activity.getResources().getDisplayMetrics().density;
        if(!landscape)portraitDockWidth=Math.max(1,frame.getWidth()-safeLeft-safeRight-dp(32));
        if(portraitDockWidth==0)portraitDockWidth=Math.max(dp(280),Math.min(frame.getWidth(),frame.getHeight())-dp(32));
        WallViewport viewport=new WallViewport(frame.getWidth(),frame.getHeight(),density,safeLeft,safeTop,safeRight,safeBottom,landscape,portraitDockWidth);
        dockParams.width=Math.round(viewport.dockWidth);dockParams.height=dp(84);dockParams.gravity=Gravity.BOTTOM|(landscape?Gravity.RIGHT:Gravity.LEFT);dockParams.leftMargin=landscape?0:safeLeft+dp(14);dockParams.rightMargin=Math.round(viewport.dockRight);dockParams.bottomMargin=Math.round(viewport.dockBottom);idleDock.setLayoutParams(dockParams);
        toolsParams.rightMargin=safeRight+dp(14);wallSettings.setLayoutParams(toolsParams);idleDock.configure(Math.round(viewport.dockWidth),idleEligible());
        wall.setSafeInsets(safeTop,safeBottom);wall.setViewport(viewport);applyChromeVisibility((landscape&&(isWallStyle()||stylePage.landscapePlayback()||stylePage.landscapeLibrary()))||immersive,true);
        updatePlaybackBarVisibility();
        if(!immersive){idleDock.animate().cancel();idleDock.setAlpha(1);idleDock.setTranslationY(0);}
        if(!chromeHidden)wallSettings.setVisibility(keyboardVisible||!isWallStyle()?View.GONE:View.VISIBLE);
        boolean standardWide=frame.getWidth()-safeLeft-safeRight>=dp(620);standardBar.configure(AppAppearance.palette(activity,activity.getSharedPreferences("library",0)),standardWide,false);standardBar.setBackground(stylePage.glassSurface(standardBar,20,AppAppearance.dark(activity,activity.getSharedPreferences("library",0))));
        FrameLayout.LayoutParams standardParams=(FrameLayout.LayoutParams)standardBar.getLayoutParams();standardParams.width=frame.getWidth()-safeLeft-safeRight-dp(28);standardParams.height=dp(standardWide?88:104);standardParams.leftMargin=safeLeft+dp(14);standardParams.rightMargin=safeRight+dp(14);standardParams.bottomMargin=safeBottom+dp(8);standardBar.setLayoutParams(standardParams);
        updateDrawerBounds();
        int resizedBy=Math.max(0,activity.getWindow().getDecorView().getHeight()-frame.getHeight());
        stylePage.setInputInsets(keyboardVisible,Math.max(0,keyboardBottom-resizedBy));
        stylePage.setInsets(safeLeft,safeTop,safeRight,safeBottom);updateDetailBack();
        FrameLayout.LayoutParams heading=(FrameLayout.LayoutParams)browseHeading.getLayoutParams();heading.topMargin=safeTop+dp(20);heading.leftMargin=safeLeft+dp(76);browseHeading.setLayoutParams(heading);browseHeading.setMaxWidth(Math.max(dp(120),frame.getWidth()-safeLeft-safeRight-dp(158)));browseHeading.setVisibility(browseGroup!=null&&isWallStyle()&&!chromeHidden&&!searchControl.isOpen()?View.VISIBLE:View.GONE);
    }

    private void updateDrawerBounds(){
        // Anchor to the controls themselves so style changes and rotation use
        // the same visible top/bottom edges instead of independent margins.
        FrameLayout.LayoutParams drawer=(FrameLayout.LayoutParams)drawerPanel.getLayoutParams();
        FrameLayout.LayoutParams menu=(FrameLayout.LayoutParams)menuButton.getLayoutParams();
        FrameLayout.LayoutParams playback=(FrameLayout.LayoutParams)(isWallStyle()?idleDock:standardBar).getLayoutParams();
        drawer.topMargin=Math.max(safeTop,menu.topMargin);
        drawer.bottomMargin=Math.max(safeBottom,playback.bottomMargin);
        drawerPanel.setLayoutParams(drawer);
    }

    private void updatePlaybackBarVisibility(){
        if(idleDock!=null)idleDock.setVisibility(keyboardVisible||immersive||!isWallStyle()?View.GONE:View.VISIBLE);
        if(standardBar!=null)standardBar.setVisibility(keyboardVisible||isWallStyle()||stylePage.landscapePlayback()?View.GONE:View.VISIBLE);
    }
    private boolean idleEligible(){return isWallStyle()&&!immersive&&!keyboardVisible;}
    private void dockProgress(float amount){if(toolsParams!=null){toolsParams.bottomMargin=safeBottom+dp(14+98*amount);wallSettings.setLayoutParams(toolsParams);}}
    void setLyricsStatus(long id,String message){wall.setLyricsStatus(id,message);if(displayedSongId==id)stylePage.setLyricsStatus(message);}

    void setLyrics(long id, List<Lyrics.Line> lines) {
        wall.setLyrics(id, lines);if(displayedSongId==id)stylePage.setLyrics(lines);
    }

    void updateDrawer(String selected, Set<String> playlists) {
        drawerSelected=selected;drawerPlaylists=new java.util.HashSet<>(playlists);
        stylePage.setSection(selected);
        if(sidebarPage!=null){sidebarPage.preparePage(selected);sidebarPage.setSection(selected);updateSimpleTabs();}
        drawerRows.removeAllViews();
        nav("♫", "音乐库", selected.equals("歌曲"), () -> actions.section("歌曲"));
        nav("◷", "最近播放", selected.equals("最近播放"), () -> actions.section("最近播放"));
        nav("♡", "收藏", selected.equals("收藏"), () -> actions.section("收藏"));
        nav("♙", "歌手", selected.equals("歌手"), () -> actions.section("歌手"));
        nav("◎", "专辑", selected.equals("专辑"), () -> actions.section("专辑"));
        TextView heading = text("我的歌单", 13, chromePalette().secondary);
        heading.setPadding(dp(20), dp(18), 0, dp(8));
        drawerRows.addView(heading);
        for (String name : new java.util.TreeSet<>(playlists)) {
            int count = activity.getSharedPreferences("library", Activity.MODE_PRIVATE).getStringSet("playlist_" + name, Set.of()).size();
            nav("☷", name, selected.equals("歌单:" + name), () -> actions.playlist(name), Integer.toString(count));
            drawerRows.getChildAt(drawerRows.getChildCount()-1).setOnLongClickListener(v->{actions.playlistMenu(name);return true;});
        }
        nav("＋", "新建歌单", false, actions::newPlaylist);

    }

    private void nav(String symbol, String label, boolean selected, Runnable action) {
        nav(symbol, label, selected, action, null);
    }

    private void nav(String symbol, String label, boolean selected, Runnable action, String badge) {
        LinearLayout row = new LinearLayout(activity);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(14), 0, dp(8), 0);
        AppAppearance.Palette palette=chromePalette();
        if (selected) row.setBackground(round(palette.dark?0x55468C74:0x220A8763, 13, 0, 0));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(51));
        lp.setMargins(0, dp(2), 0, dp(2));
        drawerRows.addView(row, lp);
        int resource = iconFor(label);
        if (resource != 0)
            row.addView(imageButton(resource, selected ? palette.accent : palette.text, () -> row.performClick()), new LinearLayout.LayoutParams(dp(30), dp(30)));
        else {
            TextView icon = text(symbol, 22, selected ? palette.accent : palette.text);
            icon.setGravity(Gravity.CENTER);
            row.addView(icon, new LinearLayout.LayoutParams(dp(30), -1));
        }
        TextView title = text(label, 15, selected ? palette.accent : palette.text);
        title.setTypeface(null, Typeface.BOLD);
        title.setPadding(dp(8), 0, 0, 0);
        row.addView(title, new LinearLayout.LayoutParams(0, -1, 1));
        if (badge != null) {
            TextView count = text(badge, 12, palette.secondary);
            row.addView(count);
        }
        ButtonFeedback.install(row);
        row.setOnClickListener(v -> {
            action.run();
            if (!label.equals("新建歌单")) showDrawer(false);
        });
    }

    void setPageKey(String key){if(key.equals(pageKey))return;stylePage.preparePage(key);if(pageKey!=null)pageCameras.put(pageKey,wall.cameraState());pageKey=key;pendingCamera=pageCameras.get(key);restoringWallState=true;wall.resetCamera();wall.zoomTo(WallZoom.scale(activity.getSharedPreferences("library",0).getInt("wall_zoom_"+key,100)));restoringWallState=false;refreshZoomControls();}
    private void zoomChanged(){refreshZoomControls();if(pageKey!=null&&!restoringWallState)activity.getSharedPreferences("library",0).edit().putInt("wall_zoom_"+pageKey,WallZoom.percent(wall.scale())).apply();}
    void setBrowseContext(String group,String section){browseGroup=group;browseSection=section;browseHeading.setText("‹  "+section+" / "+(group==null?"":group));browseHeading.setVisibility(group!=null&&isWallStyle()&&!chromeHidden&&!searchControl.isOpen()?View.VISIBLE:View.GONE);stylePage.setBrowseContext(group,section);}
    void setSorting(String field,boolean ascending){sortingField=field;sortingAscending=ascending;stylePage.setSorting(field,ascending);sidebarPage.setSorting(field,ascending);}
    void updateWall(List<Song> songs) {
        updateWall(songs, false);
    }

    void updateWall(List<Song> songs, boolean grouped) {
        groupedWall = grouped;visibleSongs=new ArrayList<>(songs);updateLibraryLoading();
        wall.setGrouped(grouped);wall.setSongs(songs);stylePage.setSongs(songs);sidebarPage.setSongs(grouped?java.util.Collections.emptyList():songs);if(pendingCamera!=null){wall.restoreCamera(pendingCamera);pendingCamera=null;}
    }

    void ensureSongVisible(Song song){
        if(!groupedWall)for(Song visible:visibleSongs)if(visible.id==song.id)return;
        List<Song> revealed=groupedWall?new ArrayList<>():new ArrayList<>(visibleSongs);revealed.add(song);updateWall(revealed,false);
    }
    void locateSongDirectly(long songId){if(isWallStyle())wall.locateSongDirectly(songId);else stylePage.locate(songId);}
    void locateSong(long songId) {if(playerStyle.equals("wall"))wall.locateSong(songId);else stylePage.locate(songId);}

    void clearSearch() {searchControl.clearQuery();}
    boolean closeSearch(){if(!searchControl.isOpen())return false;searchControl.setOpen(false,true);return true;}

    private TextView zoomLabel;
    private SeekBar zoomSlider;
    private void refreshZoomControls(){
        int percent=WallZoom.percent(wall.scale());if(zoomLabel!=null)zoomLabel.setText("显示比例  ·  "+percent+"%");
        if(zoomSlider!=null&&!zoomSlider.isPressed())zoomSlider.setProgress(WallZoom.sliderProgress(wall.scale()));
    }
    void dismissEmptySearchOutside(float screenX,float screenY){
        if(!searchControl.isOpen()||searchInput.length()!=0)return;
        android.graphics.Rect bounds=new android.graphics.Rect();searchControl.getGlobalVisibleRect(bounds);
        if(WallSearchDismiss.shouldClose(searchControl.isOpen(),searchInput.length(),bounds.contains((int)screenX,(int)screenY)))searchControl.setOpen(false,true);
    }
    private void showWallOptions() {
        final android.app.Dialog[] sheet = {null};
        sheet[0] = BottomSheet.show(activity, (browseGroup==null?browseSection:browseGroup)+" · 页面设置", body -> {
            if(isWallStyle()){
            TextView ratio = text("显示比例  ·  " + Math.round(wall.scale() * 100) + "%", 15, 0xFFE6F3ED);
            ratio.setPadding(dp(14), dp(12), 0, dp(4));
            body.addView(ratio);
            SeekBar zoom = new SeekBar(activity){
                private final android.graphics.Paint ticks=new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
                @Override protected synchronized void onDraw(android.graphics.Canvas canvas){
                    ticks.setColor(0x88FFFFFF);
                    float start=getPaddingLeft(),length=getWidth()-getPaddingLeft()-getPaddingRight();
                    for(int i=0;i<=6;i++)canvas.drawCircle(start+length*i/6f,getHeight()/2f,dp(2),ticks);
                    super.onDraw(canvas);
                }
            };
            styleSeekBar(zoom);
            zoom.setMax(WallZoom.MAX-WallZoom.MIN);
            zoom.setProgress(WallZoom.sliderProgress(wall.scale()));zoomLabel=ratio;zoomSlider=zoom;
            body.addView(zoom, new LinearLayout.LayoutParams(-1, dp(48)));
            LinearLayout stops=new LinearLayout(activity);stops.setPadding(dp(16),0,dp(16),0);body.addView(stops);
            for(int step=0;step<=6;step++){final int target=step;TextView stop=text((60+step*10)+"",12,0xFFCFDCD6);stop.setGravity(Gravity.CENTER);stop.setContentDescription((60+step*10)+"%");stops.addView(stop,new LinearLayout.LayoutParams(0,dp(40),1));stop.setOnClickListener(v->{wall.zoomTo(WallZoom.stepScale(target));refreshZoomControls();});ButtonFeedback.install(stop);}
            zoom.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                public void onProgressChanged(SeekBar bar, int progress, boolean user) {
                    if (user) {wall.zoomTo(WallZoom.sliderScale(progress));refreshZoomControls();}
                }
                public void onStartTrackingTouch(SeekBar bar) {}
                public void onStopTrackingTouch(SeekBar bar) {
                    int value=WallZoom.snapProgress(bar.getProgress());
                    wall.zoomTo(WallZoom.sliderScale(value));bar.setProgress(value);refreshZoomControls();
                }
            });
            BottomSheet.action(activity, body, "恢复 100%", () -> {wall.zoomTo(1f);refreshZoomControls();});
            }
            addSorting(body);
            addPlaybackModes(body);
            if(isWallStyle())BottomSheet.action(activity, body, "回到起始位置", () -> {wall.resetCamera();sheet[0].dismiss();});
            BottomSheet.action(activity, body, "应用设置", () -> {sheet[0].dismiss();actions.settings();});
        });
        sheet[0].setOnDismissListener(dialog->{zoomLabel=null;zoomSlider=null;});refreshZoomControls();
    }

    private void showSortingOptions() {
        BottomSheet.show(activity, "排序方式", body -> {
            if (sortingField == null) {
                TextView note = text("最近播放按播放时间排序", 15, 0xFFB9C8C0);
                note.setPadding(dp(14), dp(18), dp(14), dp(18));
                body.addView(note);
            } else addSorting(body);
        });
    }

    private void addSorting(LinearLayout body){
        if(sortingField==null)return;
        String[] fields=groupedWall?LibraryOrdering.GROUP_FIELDS:LibraryOrdering.TRACK_FIELDS;
        String[] names=groupedWall?new String[]{browseSection.equals("歌手")?"歌手姓名":"专辑名称","歌曲数量"}:LibraryOrdering.TRACK_NAMES;
        List<TextView> rows=new ArrayList<>();List<TextView> directions=new ArrayList<>();
        Runnable refresh=()->{for(int i=0;i<rows.size();i++){boolean selected=fields[i].equals(sortingField);rows.get(i).setText((selected?"✓  ":"    ")+names[i]);rows.get(i).setTextColor(selected?0xFF35D8A6:Color.WHITE);}for(int i=0;i<directions.size();i++){boolean selected=sortingAscending==(i==0);directions.get(i).setText((selected?"✓  ":"    ")+(i==0?"正序":"降序"));directions.get(i).setTextColor(selected?0xFF35D8A6:Color.WHITE);}};
        for(int i=0;i<fields.length;i++){String field=fields[i];rows.add(BottomSheet.action(activity,body,names[i],()->{actions.sort(field,sortingAscending);refresh.run();}));}
        View divider=new View(activity);divider.setBackgroundColor(0x22FFFFFF);body.addView(divider,new LinearLayout.LayoutParams(-1,dp(1)));
        for(int i=0;i<2;i++){boolean ascending=i==0;directions.add(BottomSheet.action(activity,body,i==0?"正序":"降序",()->{actions.sort(sortingField,ascending);refresh.run();}));}refresh.run();
    }

    private void addPlaybackModes(LinearLayout body){
        TextView heading=text("播放模式",15,0xFFB9C8C0);heading.setPadding(dp(14),dp(16),dp(14),dp(8));body.addView(heading);
        List<LinearLayout> choices=new ArrayList<>();List<TextView> checks=new ArrayList<>();
        Runnable refresh=()->{int selected=PlaybackModes.valid(actions.playbackMode());for(int i=0;i<choices.size();i++){choices.get(i).setBackground(round(i==selected?0x3332C89C:0x08FFFFFF,12,0,0));checks.get(i).setText(i==selected?"✓":"○");checks.get(i).setTextColor(i==selected?0xFF35D8A6:0xFF8D9B93);choices.get(i).setSelected(i==selected);}};
        for(int i=0;i<PlaybackModes.NAMES.length;i++){int mode=i;LinearLayout row=new LinearLayout(activity);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(14),dp(8),dp(14),dp(8));
            TextView check=text("",23,Color.WHITE);row.addView(check,new LinearLayout.LayoutParams(dp(36),-1));
            LinearLayout caption=new LinearLayout(activity);caption.setOrientation(LinearLayout.VERTICAL);caption.addView(text(PlaybackModes.NAMES[i],15,Color.WHITE));caption.addView(text(PlaybackModes.DETAILS[i],11,0xFFAEBDB4));row.addView(caption,new LinearLayout.LayoutParams(0,-2,1));
            LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(-1,-2);params.setMargins(0,dp(3),0,dp(3));row.setMinimumHeight(dp(60));body.addView(row,params);choices.add(row);checks.add(check);
            row.setContentDescription(PlaybackModes.NAMES[i]+"，"+PlaybackModes.DETAILS[i]);row.setOnClickListener(view->{actions.selectPlaybackMode(mode);refresh.run();});ButtonFeedback.install(row);
        }refresh.run();
    }

    private void styleSeekBar(SeekBar bar) {
        GradientDrawable track = new GradientDrawable();track.setColor(0x66FFFFFF);track.setCornerRadius(dp(4));track.setSize(1, dp(6));
        GradientDrawable fill = new GradientDrawable();fill.setColor(0xFF18BD91);fill.setCornerRadius(dp(4));fill.setSize(1, dp(6));
        LayerDrawable layers = new LayerDrawable(new android.graphics.drawable.Drawable[]{track, new ClipDrawable(fill, Gravity.LEFT, ClipDrawable.HORIZONTAL)});
        layers.setId(0, android.R.id.background);layers.setId(1, android.R.id.progress);bar.setProgressDrawable(layers);
        GradientDrawable thumb = new GradientDrawable();thumb.setShape(GradientDrawable.OVAL);thumb.setColor(0xFF22C999);thumb.setSize(dp(18), dp(18));
        bar.setThumb(thumb);bar.setThumbOffset(dp(9));bar.setPadding(dp(10), dp(5), dp(10), dp(5));bar.setSplitTrack(false);
    }

    private TextView text(String value, int size, int color) {
        TextView view = new TextView(activity);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER_VERTICAL);
        return view;
    }

    private TextView iconButton(String value, int color, Runnable action) {
        TextView view = text(value, 27, color);
        view.setGravity(Gravity.CENTER);
        view.setOnClickListener(v -> action.run());ButtonFeedback.install(view);
        return view;
    }

    private TextView playerButton(String value, Runnable action) {
        TextView view = iconButton(value, Color.WHITE, action);
        view.setTextSize(30);
        return view;
    }

    private int iconFor(String label) {
        switch (label) {
            case "音乐库":
                return R.drawable.icon_navigation_all;
            case "最近播放":
                return R.drawable.icon_navigation_recent;
            case "收藏":
                return R.drawable.icon_navigation_favorites;
            case "歌手":
                return R.drawable.icon_navigation_artists;
            case "专辑":
                return R.drawable.icon_navigation_albums;
            case "新建歌单":
                return 0;
            default:
                return R.drawable.icon_list;
        }
    }

    private ImageView imageButton(int resource, int tint, Runnable action) {
        ImageView view = new ImageView(activity);
        view.setImageResource(resource);
        view.setColorFilter(tint);
        view.setScaleType(ImageView.ScaleType.FIT_CENTER);
        view.setPadding(dp(4), dp(4), dp(4), dp(4));
        view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x66FFFFFF), null, round(Color.WHITE, 28, 0, 0)));
        view.setOnClickListener(v -> action.run());ButtonFeedback.install(view);
        return view;
    }

    private void focusLibrarySong(){
        if(stylePage.focusCurrentSong())return;
        if(displayedSongId==Long.MIN_VALUE)return;
        searchInput.setText("");actions.section("歌曲");
        stylePage.post(()->stylePage.focusCurrentSong());
    }
    private void focusSidebarSong(){
        if(sidebarPage.focusCurrentSong())return;
        if(displayedSongId==Long.MIN_VALUE)return;
        drawerSearch.setText("");actions.section("歌曲");stylePage.showPlayer();sidebarPage.post(()->sidebarPage.focusCurrentSong());
    }
    private void buildSimpleDrawer(){
        simpleDrawerRoot=new LinearLayout(activity);simpleDrawerRoot.setOrientation(LinearLayout.VERTICAL);simpleDrawerRoot.setPadding(dp(14),dp(14),dp(14),dp(10));simpleDrawerRoot.setVisibility(View.GONE);
        drawerPanel.addView(simpleDrawerRoot,new FrameLayout.LayoutParams(-1,-1));
        drawerSearch=new EditText(activity);drawerSearch.setSingleLine(true);drawerSearch.setTextSize(14);drawerSearch.setHint("搜索歌曲、歌手或专辑");drawerSearch.setPadding(dp(14),0,dp(12),0);drawerSearch.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        LinearLayout.LayoutParams searchParams=new LinearLayout.LayoutParams(-1,dp(48));searchParams.setMargins(0,dp(12),0,dp(12));simpleDrawerRoot.addView(drawerSearch,searchParams);
        drawerSearch.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void onTextChanged(CharSequence s,int start,int before,int count){if(!s.toString().contentEquals(searchInput.getText()))searchInput.setText(s);}public void afterTextChanged(android.text.Editable value){}});
        drawerSearch.setOnEditorActionListener((v,action,event)->{if(action==EditorInfo.IME_ACTION_SEARCH){((InputMethodManager)activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(v.getWindowToken(),0);drawerSearch.clearFocus();return true;}return false;});
        simpleLibraryTab=simpleTab("音乐库",R.drawable.icon_navigation_all,()->actions.section("歌曲"));simpleRecentTab=simpleTab("最近播放",R.drawable.icon_navigation_recent,()->actions.section("最近播放"));
        sidebarPage=new PlayerStylePage(activity,actions::play,actions::seek,actions::lyrics,()->{});sidebarPage.useSidebarCatalog();sidebarPage.glassSource(stylePage);sidebarPage.setSidebarLocate(this::focusSidebarSong);sidebarPage.setScanning(libraryScanning);sidebarPage.setSongMenu(actions::songMenu);sidebarPage.setTools(()->{},this::showSortingOptions,actions::queue,actions::favorite);sidebarPage.setSortAction(actions::sort);
        sidebarPage.setBatchActions(new PlayerStylePage.BatchActions(){public void favorite(List<Song> songs,boolean value){actions.favoriteSongs(songs,value);}public void playlist(List<Song> songs){actions.playlistSongs(songs);}public void removeFromPlaylist(List<Song> songs){actions.removePlaylistSongs(songs);}public void clearRecent(){actions.clearRecent();}});
        simpleDrawerRoot.addView(sidebarPage,new LinearLayout.LayoutParams(-1,0,1));
    }
    private TextView simpleTab(String caption,int resource,Runnable action){TextView tab=text(caption,17,green);android.graphics.drawable.Drawable icon=activity.getDrawable(resource).mutate();icon.setBounds(0,0,dp(24),dp(24));tab.setCompoundDrawables(icon,null,null,null);tab.setCompoundDrawablePadding(dp(16));tab.setGravity(Gravity.CENTER_VERTICAL);tab.setPadding(dp(18),0,dp(12),0);tab.setOnClickListener(v->{drawerSearch.setText("");action.run();stylePage.showPlayer();});ButtonFeedback.install(tab);simpleDrawerRoot.addView(tab,new LinearLayout.LayoutParams(-1,dp(52)));return tab;}
    private void updateSimpleTabs(){if(simpleLibraryTab==null)return;AppAppearance.Palette palette=chromePalette();boolean recent=drawerSelected.equals("最近播放");simpleLibraryTab.setBackground(round(recent?Color.TRANSPARENT:palette.dark?0x334FCDA6:0x220A8763,14,0,0));simpleRecentTab.setBackground(round(recent?(palette.dark?0x334FCDA6:0x220A8763):Color.TRANSPARENT,14,0,0));simpleLibraryTab.setTextColor(recent?palette.text:palette.accent);simpleRecentTab.setTextColor(recent?palette.accent:palette.text);simpleLibraryTab.getCompoundDrawables()[0].setTint(recent?palette.text:palette.accent);simpleRecentTab.getCompoundDrawables()[0].setTint(recent?palette.accent:palette.text);}

    private AppAppearance.Palette chromePalette(){return new AppAppearance.Palette(isWallStyle()||AppAppearance.dark(activity,activity.getSharedPreferences("library",0)));}
    private android.graphics.drawable.Drawable chromeBackground(View view){
        AppAppearance.Palette palette=chromePalette();
        return isWallStyle()?glass().surface(view,28,false):new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(palette.dark?0x22FFFFFF:0x16000000),stylePage.glassSurface(view,28,palette.dark),round(Color.WHITE,28,0,0));
    }
    private void applyDrawerAppearance(){
        AppAppearance.Palette palette=chromePalette();
        boolean simple=playerStyle.equals("simple");
        LinearLayout parent=simple?simpleDrawerRoot:drawerContent;
        if(drawerBrand.getParent()!=parent){((android.view.ViewGroup)drawerBrand.getParent()).removeView(drawerBrand);parent.addView(drawerBrand,0,new LinearLayout.LayoutParams(-1,-2));}
        drawerScroll.setVisibility(simple?View.GONE:View.VISIBLE);simpleDrawerRoot.setVisibility(simple?View.VISIBLE:View.GONE);
        drawerLayer.setBackgroundColor(isWallStyle()?0x99000000:0x44000000);
        sidebarPage.configure("library",palette);
        drawerSearch.setTextColor(palette.text);drawerSearch.setHintTextColor(palette.secondary);drawerSearch.setBackground(round(palette.dark?0x553F4945:0x99FFFFFF,14,0,0));
        simpleLibraryTab.setTextColor(palette.text);simpleRecentTab.setTextColor(palette.text);updateSimpleTabs();
        boolean materialChanged=drawerMaterial.update(playerStyle,palette.dark);
        if(materialChanged||drawerGlass==null)drawerGlass=DrawerMaterialState.liquid(playerStyle)?glass():new GlassBackdrop(stylePage,true,28);
        drawerPanel.setBackground(drawerGlass.surface(drawerPanel,24,!DrawerMaterialState.liquid(playerStyle),!palette.dark));
        drawerName.setTextColor(palette.text);drawerSubtitle.setTextColor(palette.secondary);
        drawerClose.setColorFilter(palette.text);drawerSettings.setColorFilter(palette.text);drawerSettings.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(palette.dark?0x22FFFFFF:0x16000000),null,null));
    }
    private void updateDetailBack(){
        if(detailBack==null)return;
        boolean visible=!isWallStyle()&&(stylePage.libraryDetailOpen()||stylePage.groupCatalogOpen())&&!chromeHidden;
        detailBack.setContentDescription(stylePage.groupCatalogOpen()?"返回"+browseSection:"返回音乐库");
        detailBack.setVisibility(visible?View.VISIBLE:View.GONE);
        AppAppearance.Palette palette=chromePalette();detailBack.setTextColor(palette.accent);android.graphics.drawable.Drawable backIcon=activity.getDrawable(R.drawable.icon_back).mutate();backIcon.setTint(palette.accent);backIcon.setBounds(0,0,dp(18),dp(18));detailBack.setCompoundDrawablesRelative(backIcon,null,null,null);detailBack.setBackground(stylePage.glassSurface(detailBack,22,palette.dark));
        FrameLayout.LayoutParams back=(FrameLayout.LayoutParams)detailBack.getLayoutParams();back.leftMargin=safeLeft+dp(80);back.topMargin=safeTop+dp(12);detailBack.setLayoutParams(back);
        FrameLayout.LayoutParams search=(FrameLayout.LayoutParams)searchControl.getLayoutParams();search.leftMargin=safeLeft+dp(visible?168:82);searchControl.setLayoutParams(search);
    }
    private void applyControlsAppearance(){
        AppAppearance.Palette palette=chromePalette();menuButton.setColorFilter(palette.text);menuButton.setBackground(chromeBackground(menuButton));
        searchControl.simpleStyle(false);searchControl.configure(palette);searchControl.setBackground(chromeBackground(searchControl));
        updateDetailBack();applyDrawerAppearance();updateDrawer(drawerSelected,drawerPlaylists);
    }

    private GlassBackdrop glass(){if(wallGlass==null)wallGlass=new GlassBackdrop(wall,true);return wallGlass;}

    private ImageView roundImage(int resource, Runnable action) {
        ImageView view = imageButton(resource, Color.WHITE, action);
        view.setImageDrawable(new WallToolStyle.Glyph(resource==R.drawable.icon_wall_sidebar?WallToolStyle.Glyph.SIDEBAR:WallToolStyle.Glyph.SETTINGS));
        int inset=dp((WallToolStyle.SIDE-WallToolStyle.ICON)/2f);view.setPadding(inset,inset,inset,inset);
        view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x16FFFFFF),glass().surface(view,28,false),WallToolStyle.glass(activity)));
        return view;
    }

    private TextView roundButton(String value, int size, Runnable action) {
        TextView view = iconButton(value, Color.WHITE, action);
        view.setTextSize(size);
        view.setBackground(round(0x9952574F, 28, 0x88FFFFFF, 1));
        return view;
    }

    private GradientDrawable round(int color, int radius, int stroke, int width) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));
        if (width > 0) drawable.setStroke(dp(width), stroke);
        return drawable;
    }

    private int dp(float number) {
        return Math.round(number * activity.getResources().getDisplayMetrics().density);
    }
}
