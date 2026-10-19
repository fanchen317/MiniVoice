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

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.io.File;
import java.io.FileOutputStream;

final class HomeScreen {
    interface Actions {
        void section(String name);

        void playlist(String name);

        void newPlaylist();

        void settings();

        void search(String query);

        void play(Song song);

        void toggle();

        void previous();

        void next();

        void lyrics();

        void queue();

        void seek(int ms);

        void playMode();
    }

    private final Activity activity;
    private final Actions actions;
    private final FrameLayout frame, drawerLayer;
    private final ScrollView drawerScroll;
    private final LinearLayout player;
    private final ImageView wallSettings;
    private final LinearLayout drawerRows;
    private final WallView wall;
    private final TextView current;
    private final ImageView playButton;
    private final SeekBar seek;
    private final EditText searchInput;
    private boolean drawerOpen = false;
    private boolean groupedWall;
    private long displayedSongId = Long.MIN_VALUE;
    private final int green = Color.rgb(21, 188, 135);
    private final Handler main = new Handler();

    HomeScreen(Activity activity, Actions actions) {
        this.activity = activity;
        this.actions = actions;
        frame = new FrameLayout(activity);
        frame.setBackgroundColor(Color.rgb(7, 12, 13));
        wall = new WallView(activity, actions::play, actions::toggle, actions::seek);
        frame.addView(wall, new FrameLayout.LayoutParams(-1, -1));
        ImageView menu = roundImage(R.drawable.icon_wall_sidebar, () -> showDrawer(true));
        FrameLayout.LayoutParams menuParams = new FrameLayout.LayoutParams(dp(52), dp(52), Gravity.TOP | Gravity.LEFT);
        menuParams.setMargins(dp(14), dp(14), 0, 0);
        frame.addView(menu, menuParams);
        ImageView search = roundImage(R.drawable.icon_wall_search, this::toggleSearch);
        FrameLayout.LayoutParams searchParams = new FrameLayout.LayoutParams(dp(52), dp(52), Gravity.TOP | Gravity.RIGHT);
        searchParams.setMargins(0, dp(14), dp(14), 0);
        frame.addView(search, searchParams);
        searchInput = new EditText(activity);
        searchInput.setSingleLine(true);
        searchInput.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        searchInput.setTextColor(Color.WHITE);
        searchInput.setHintTextColor(0xFFB9C5BE);
        searchInput.setHint("搜索歌曲、歌手或专辑");
        searchInput.setTextSize(14);
        searchInput.setPadding(dp(16), 0, dp(16), 0);
        searchInput.setBackground(round(0xF0222826, 16, 0x66FFFFFF, 1));
        searchInput.setVisibility(View.GONE);
        FrameLayout.LayoutParams searchInputParams = new FrameLayout.LayoutParams(-1, dp(48), Gravity.TOP);
        searchInputParams.setMargins(dp(16), dp(78), dp(16), 0);
        frame.addView(searchInput, searchInputParams);
        searchInput.addTextChangedListener(new android.text.TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            public void onTextChanged(CharSequence s, int start, int before, int count) {
                actions.search(s.toString());
            }

            public void afterTextChanged(android.text.Editable e) {
            }
        });
        player = new LinearLayout(activity);
        player.setGravity(Gravity.CENTER_VERTICAL);
        player.setPadding(dp(10), 0, dp(10), 0);
        player.setBackground(round(0xE5222725, 32, 0x66FFFFFF, 1));
        FrameLayout.LayoutParams playerParams = new FrameLayout.LayoutParams(-1, dp(84), Gravity.BOTTOM);
        playerParams.setMargins(dp(16), 0, dp(16), dp(14));
        frame.addView(player, playerParams);
        playButton = imageButton(R.drawable.icon_transport_play, 0xFF222222, actions::toggle);
        playButton.setPadding(dp(7), dp(7), dp(7), dp(7));
        playButton.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x55000000), round(0xFFF3F3F3, 31, 0, 0), round(Color.WHITE, 31, 0, 0)));
        player.addView(playButton, new LinearLayout.LayoutParams(dp(62), dp(62)));
        LinearLayout middle = new LinearLayout(activity);
        middle.setOrientation(LinearLayout.VERTICAL);
        middle.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams middleParams = new LinearLayout.LayoutParams(0, dp(72), 1);
        middleParams.setMargins(dp(8), 0, dp(4), 0);
        player.addView(middle, middleParams);
        LinearLayout middleTop = new LinearLayout(activity);
        middleTop.setGravity(Gravity.CENTER_VERTICAL);
        middle.addView(middleTop, new LinearLayout.LayoutParams(-1, dp(40)));
        ImageView previous = imageButton(R.drawable.icon_transport_previous_track, Color.WHITE, actions::previous);
        previous.setPadding(dp(5), dp(5), dp(5), dp(5));
        middleTop.addView(previous, new LinearLayout.LayoutParams(dp(38), dp(38)));
        current = text("选择歌曲", 15, Color.WHITE);
        current.setGravity(Gravity.CENTER);
        current.setSingleLine(true);
        current.setEllipsize(android.text.TextUtils.TruncateAt.END);
        current.setOnClickListener(v -> actions.lyrics());
        middleTop.addView(current, new LinearLayout.LayoutParams(0, -1, 1));
        ImageView next = imageButton(R.drawable.icon_transport_next_track, Color.WHITE, actions::next);
        next.setPadding(dp(5), dp(5), dp(5), dp(5));
        middleTop.addView(next, new LinearLayout.LayoutParams(dp(38), dp(38)));
        seek = new SeekBar(activity);
        styleSeekBar(seek);
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
        ImageView queue = imageButton(R.drawable.icon_transport_list, Color.WHITE, actions::queue);
        queue.setPadding(dp(5), dp(5), dp(5), dp(5));
        player.addView(queue, new LinearLayout.LayoutParams(dp(40), dp(40)));
        wallSettings = roundImage(R.drawable.icon_wall_settings, this::showWallOptions);
        FrameLayout.LayoutParams wallSettingsParams = new FrameLayout.LayoutParams(dp(52), dp(52), Gravity.RIGHT | Gravity.BOTTOM);
        wallSettingsParams.setMargins(0, 0, dp(16), dp(112));
        frame.addView(wallSettings, wallSettingsParams);
        drawerLayer = new FrameLayout(activity);
        frame.addView(drawerLayer, new FrameLayout.LayoutParams(-1, -1));
        drawerLayer.setBackgroundColor(0x99000000);
        View outside = new View(activity);
        drawerLayer.addView(outside, new FrameLayout.LayoutParams(-1, -1));
        outside.setOnClickListener(v -> showDrawer(false));
        ScrollView drawerScroll = new ScrollView(activity);
        drawerScroll.setFillViewport(true);
        drawerScroll.setVerticalScrollBarEnabled(false);
        FrameLayout.LayoutParams drawerParams = new FrameLayout.LayoutParams(Math.min(dp(310), activity.getResources().getDisplayMetrics().widthPixels - dp(58)), -1, Gravity.LEFT);
        drawerParams.setMargins(dp(15), dp(20), 0, dp(16));
        drawerLayer.addView(drawerScroll, drawerParams);
        LinearLayout drawer = new LinearLayout(activity);
        drawer.setOrientation(LinearLayout.VERTICAL);
        drawer.setPadding(dp(16), dp(18), dp(16), dp(18));
        drawer.setBackground(round(0xE9171C1B, 24, 0x77FFFFFF, 1));
        drawerScroll.addView(drawer);
        LinearLayout brand = new LinearLayout(activity);
        brand.setGravity(Gravity.CENTER_VERTICAL);
        drawer.addView(brand, new LinearLayout.LayoutParams(-1, dp(72)));
        ImageView icon = new ImageView(activity);
        icon.setImageResource(R.drawable.minivoice_icon);
        icon.setScaleType(ImageView.ScaleType.CENTER_CROP);
        icon.setBackground(round(0xFF3ED766, 15, 0, 0));
        icon.setClipToOutline(true);
        brand.addView(icon, new LinearLayout.LayoutParams(dp(56), dp(56)));
        LinearLayout title = new LinearLayout(activity);
        title.setOrientation(LinearLayout.VERTICAL);
        title.setPadding(dp(12), 0, 0, 0);
        brand.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        TextView name = text("MiniVoice", 22, Color.WHITE);
        name.setTypeface(null, Typeface.BOLD);
        title.addView(name);
        TextView sub = text("音乐让生活更美...", 13, 0xFF9DA7A4);
        title.addView(sub);
        brand.addView(imageButton(R.drawable.icon_info, green, actions::settings), new LinearLayout.LayoutParams(dp(38), dp(46)));
        brand.addView(imageButton(R.drawable.icon_close, Color.WHITE, () -> showDrawer(false)), new LinearLayout.LayoutParams(dp(38), dp(46)));
        drawerRows = new LinearLayout(activity);
        drawerRows.setOrientation(LinearLayout.VERTICAL);
        drawerRows.setPadding(0, dp(12), 0, 0);
        drawer.addView(drawerRows);
        View spacer = new View(activity);
        drawer.addView(spacer, new LinearLayout.LayoutParams(1, 0, 1));
        ImageView settings = imageButton(R.drawable.icon_settings_gear, Color.WHITE, actions::settings);
        settings.setContentDescription("设置");
        settings.setPadding(dp(12), dp(12), dp(12), dp(12));
        settings.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x66FFFFFF), round(0x55373F3D, 14, 0x44FFFFFF, 1), round(Color.WHITE, 14, 0, 0)));
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(dp(48), dp(48));
        settingsParams.setMargins(dp(4), dp(4), 0, 0);
        drawer.addView(settings, settingsParams);
        frame.setOnApplyWindowInsetsListener((view, insets) -> {
            int top = android.os.Build.VERSION.SDK_INT >= 30 ? insets.getInsets(WindowInsets.Type.statusBars()).top : insets.getSystemWindowInsetTop();
            menuParams.topMargin = top + dp(16);
            menu.setLayoutParams(menuParams);
            searchParams.topMargin = top + dp(16);
            search.setLayoutParams(searchParams);
            searchInputParams.topMargin = top + dp(19);
            searchInput.setLayoutParams(searchInputParams);
            drawerParams.topMargin = top + dp(20);
            drawerScroll.setLayoutParams(drawerParams);
            return insets;
        });
        frame.post(frame::requestApplyInsets);
    }

    View view() {
        return frame;
    }

    boolean isDrawerOpen() {
        return drawerOpen;
    }

    void showDrawer(boolean open) {
        drawerOpen = open;
        drawerLayer.setVisibility(open ? View.VISIBLE : View.GONE);
    }

    void setPlayback(long id, String title, boolean playing, int position, int duration) {
        boolean changed = displayedSongId != id;
        displayedSongId = id;
        current.setText(title);
        playButton.setImageResource(playing ? R.drawable.icon_transport_pause : R.drawable.icon_transport_play);
        seek.setMax(Math.max(1, duration));
        if (!seek.isPressed()) seek.setProgress(position);
        wall.setPlayback(id, playing, position);
        if (changed && !groupedWall) locateSong(id);
    }

    void setLyrics(long id, List<Lyrics.Line> lines) {
        wall.setLyrics(id, lines);
    }

    void updateDrawer(String selected, Set<String> playlists) {
        drawerRows.removeAllViews();
        nav("♫", "音乐库", selected.equals("歌曲"), () -> actions.section("歌曲"));
        nav("◷", "最近播放", selected.equals("最近播放"), () -> actions.section("最近播放"));
        nav("♡", "收藏", selected.equals("收藏"), () -> actions.section("收藏"));
        nav("♙", "歌手", selected.equals("歌手"), () -> actions.section("歌手"));
        nav("◎", "专辑", selected.equals("专辑"), () -> actions.section("专辑"));
        TextView heading = text("我的歌单", 15, 0xFFB8BEBA);
        heading.setPadding(dp(28), dp(22), 0, dp(10));
        drawerRows.addView(heading);
        for (String name : new java.util.TreeSet<>(playlists)) {
            int count = activity.getSharedPreferences("library", Activity.MODE_PRIVATE).getStringSet("playlist_" + name, Set.of()).size();
            nav("☷", name, selected.equals("歌单:" + name), () -> actions.playlist(name), Integer.toString(count));
        }
        nav("＋", "新建歌单", false, actions::newPlaylist);
    }

    private void nav(String symbol, String label, boolean selected, Runnable action) {
        nav(symbol, label, selected, action, null);
    }

    private void nav(String symbol, String label, boolean selected, Runnable action, String badge) {
        LinearLayout row = new LinearLayout(activity);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(18), 0, dp(10), 0);
        if (selected) row.setBackground(round(0x55468C74, 15, 0, 0));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(60));
        lp.setMargins(0, dp(3), 0, dp(3));
        drawerRows.addView(row, lp);
        int resource = iconFor(label);
        if (resource != 0)
            row.addView(imageButton(resource, selected ? green : 0xFFE6EBE8, () -> row.performClick()), new LinearLayout.LayoutParams(dp(35), dp(35)));
        else {
            TextView icon = text(symbol, 27, selected ? green : 0xFFE6EBE8);
            icon.setGravity(Gravity.CENTER);
            row.addView(icon, new LinearLayout.LayoutParams(dp(35), -1));
        }
        TextView title = text(label, 18, selected ? green : Color.WHITE);
        title.setTypeface(null, Typeface.BOLD);
        title.setPadding(dp(8), 0, 0, 0);
        row.addView(title, new LinearLayout.LayoutParams(0, -1, 1));
        if (badge != null) {
            TextView count = text(badge, 13, 0xFFB6BDB8);
            row.addView(count);
        }
        row.setOnClickListener(v -> {
            action.run();
            if (!label.equals("新建歌单")) showDrawer(false);
        });
    }

    void updateWall(List<Song> songs) {
        updateWall(songs, false);
    }

    void updateWall(List<Song> songs, boolean grouped) {
        groupedWall = grouped;
        wall.setSongs(songs);
    }

    void locateSong(long songId) {
        wall.post(() -> wall.locateSong(songId));
    }

    void clearSearch() {
        if (searchInput.length() > 0) searchInput.setText("");
        searchInput.setVisibility(View.GONE);
        searchInput.clearFocus();
    }

    private void toggleSearch() {
        boolean opening = searchInput.getVisibility() != View.VISIBLE;
        searchInput.setVisibility(opening ? View.VISIBLE : View.GONE);
        if (opening) {
            searchInput.requestFocus();
            ((android.view.inputmethod.InputMethodManager) activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).showSoftInput(searchInput, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT);
        } else {
            searchInput.setText("");
            searchInput.clearFocus();
            ((android.view.inputmethod.InputMethodManager) activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(searchInput.getWindowToken(), 0);
        }
    }

    private void showWallOptions() {
        String[] choices = {"播放模式", "放大音乐墙", "缩小音乐墙", "回到起始位置", "设置"};
        new AlertDialog.Builder(activity).setTitle("音乐墙").setItems(choices, (dialog, index) -> {
            switch (index) {
                case 0:
                    actions.playMode();
                    break;
                case 1:
                    wall.zoom(1.2f);
                    break;
                case 2:
                    wall.zoom(1 / 1.2f);
                    break;
                case 3:
                    wall.resetCamera();
                    break;
                default:
                    actions.settings();
            }
        }).show();
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
        view.setOnClickListener(v -> action.run());
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
        view.setOnClickListener(v -> action.run());
        return view;
    }

    private ImageView roundImage(int resource, Runnable action) {
        ImageView view = imageButton(resource, Color.WHITE, action);
        view.setPadding(dp(13), dp(13), dp(13), dp(13));
        view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x66FFFFFF), round(0x9952574F, 28, 0x88FFFFFF, 1), round(Color.WHITE, 28, 0, 0)));
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

    private int dp(int number) {
        return Math.round(number * activity.getResources().getDisplayMetrics().density);
    }
}
