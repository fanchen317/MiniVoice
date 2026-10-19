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

        void locate();

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
    private final TransportButton playButton;
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
        playButton = new TransportButton(activity, TransportButton.Glyph.PLAY_PAUSE, actions::toggle);
        playButton.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x55000000), round(0xFFF3F3F3, 31, 0, 0), round(Color.WHITE, 31, 0, 0)));
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
        drawerScroll = new ScrollView(activity);
        drawerScroll.setFillViewport(true);
        drawerScroll.setVerticalScrollBarEnabled(false);
        FrameLayout.LayoutParams drawerParams = new FrameLayout.LayoutParams(Math.min(dp(268), Math.round(activity.getResources().getDisplayMetrics().widthPixels * .72f)), -1, Gravity.LEFT);
        drawerParams.setMargins(dp(10), dp(12), 0, dp(10));
        drawerLayer.addView(drawerScroll, drawerParams);
        LinearLayout drawer = new LinearLayout(activity);
        drawer.setOrientation(LinearLayout.VERTICAL);
        drawer.setPadding(dp(12), dp(14), dp(12), dp(14));
        drawer.setBackground(round(0xF21B211F, 22, 0x55FFFFFF, 1));
        drawerScroll.addView(drawer);
        LinearLayout brand = new LinearLayout(activity);
        brand.setGravity(Gravity.CENTER_VERTICAL);
        drawer.addView(brand, new LinearLayout.LayoutParams(-1, dp(64)));
        ImageView icon = new ImageView(activity);
        icon.setImageResource(R.drawable.minivoice_icon);
        icon.setScaleType(ImageView.ScaleType.CENTER_CROP);
        icon.setBackground(round(0xFF3ED766, 14, 0, 0));
        icon.setClipToOutline(true);
        brand.addView(icon, new LinearLayout.LayoutParams(dp(48), dp(48)));
        LinearLayout title = new LinearLayout(activity);
        title.setOrientation(LinearLayout.VERTICAL);
        title.setPadding(dp(12), 0, 0, 0);
        brand.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        TextView name = text("MiniVoice", 19, Color.WHITE);
        name.setTypeface(null, Typeface.BOLD);
        title.addView(name);
        TextView sub = text("音乐让生活更美...", 11, 0xFF9DA7A4);
        sub.setSingleLine(true);
        title.addView(sub);
        ImageView closeDrawer = imageButton(R.drawable.icon_close, Color.WHITE, () -> showDrawer(false));
        closeDrawer.setPadding(dp(8), dp(8), dp(8), dp(8));
        brand.addView(closeDrawer, new LinearLayout.LayoutParams(dp(34), dp(42)));
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
        drawerLayer.setVisibility(View.GONE);
        frame.setOnApplyWindowInsetsListener((view, insets) -> {
            int top = android.os.Build.VERSION.SDK_INT >= 30 ? insets.getInsets(WindowInsets.Type.statusBars()).top : insets.getSystemWindowInsetTop();
            menuParams.topMargin = top + dp(14);
            menu.setLayoutParams(menuParams);
            searchParams.topMargin = top + dp(14);
            search.setLayoutParams(searchParams);
            searchInputParams.topMargin = top + dp(78);
            searchInput.setLayoutParams(searchInputParams);
            drawerParams.topMargin = top + dp(12);
            drawerScroll.setLayoutParams(drawerParams);
            boolean keyboard = android.os.Build.VERSION.SDK_INT >= 30 && insets.isVisible(WindowInsets.Type.ime());
            player.setVisibility(keyboard ? View.GONE : View.VISIBLE);
            wallSettings.setVisibility(keyboard ? View.GONE : View.VISIBLE);
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
        if (drawerOpen == open) return;
        drawerOpen = open;
        drawerScroll.animate().cancel();
        drawerLayer.animate().cancel();
        if (open) {
            drawerLayer.setVisibility(View.VISIBLE);
            drawerLayer.setAlpha(0);
            drawerScroll.setTranslationX(-drawerScroll.getLayoutParams().width - dp(20));
            drawerLayer.animate().alpha(1).setDuration(220).start();
            drawerScroll.animate().translationX(0).setDuration(260).start();
        } else {
            drawerScroll.animate().translationX(-drawerScroll.getLayoutParams().width - dp(20)).setDuration(230).start();
            drawerLayer.animate().alpha(0).setDuration(230).withEndAction(() -> {
                if (!drawerOpen) drawerLayer.setVisibility(View.GONE);
            }).start();
        }
    }

    void setPlayback(long id, String title, boolean playing, int position, int duration) {
        boolean changed = displayedSongId != id;
        displayedSongId = id;
        current.setText(title);
        playButton.setPlaying(playing);
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
        TextView heading = text("我的歌单", 13, 0xFFB8BEBA);
        heading.setPadding(dp(20), dp(18), 0, dp(8));
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
        row.setPadding(dp(14), 0, dp(8), 0);
        if (selected) row.setBackground(round(0x55468C74, 13, 0, 0));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(51));
        lp.setMargins(0, dp(2), 0, dp(2));
        drawerRows.addView(row, lp);
        int resource = iconFor(label);
        if (resource != 0)
            row.addView(imageButton(resource, selected ? green : 0xFFE6EBE8, () -> row.performClick()), new LinearLayout.LayoutParams(dp(30), dp(30)));
        else {
            TextView icon = text(symbol, 22, selected ? green : 0xFFE6EBE8);
            icon.setGravity(Gravity.CENTER);
            row.addView(icon, new LinearLayout.LayoutParams(dp(30), -1));
        }
        TextView title = text(label, 15, selected ? green : Color.WHITE);
        title.setTypeface(null, Typeface.BOLD);
        title.setPadding(dp(8), 0, 0, 0);
        row.addView(title, new LinearLayout.LayoutParams(0, -1, 1));
        if (badge != null) {
            TextView count = text(badge, 12, 0xFFB6BDB8);
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
        ((android.view.inputmethod.InputMethodManager) activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(searchInput.getWindowToken(), 0);
    }

    private void toggleSearch() {
        boolean opening = searchInput.getVisibility() != View.VISIBLE;
        if (opening) {
            searchInput.setAlpha(0);
            searchInput.setTranslationY(-dp(8));
            searchInput.setVisibility(View.VISIBLE);
            searchInput.animate().alpha(1).translationY(0).setDuration(180).start();
            searchInput.requestFocus();
            searchInput.post(() -> ((android.view.inputmethod.InputMethodManager) activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).showSoftInput(searchInput, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT));
        } else {
            searchInput.setText("");
            searchInput.clearFocus();
            ((android.view.inputmethod.InputMethodManager) activity.getSystemService(Activity.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(searchInput.getWindowToken(), 0);
            searchInput.setVisibility(View.GONE);
        }
    }

    private void showWallOptions() {
        final android.app.Dialog[] sheet = {null};
        sheet[0] = BottomSheet.show(activity, "音乐墙", body -> {
            TextView ratio = text("显示比例  ·  " + Math.round(wall.scale() * 100) + "%", 15, 0xFFE6F3ED);
            ratio.setPadding(dp(14), dp(12), 0, dp(4));
            body.addView(ratio);
            SeekBar zoom = new SeekBar(activity);
            styleSeekBar(zoom);
            zoom.setMax(60);
            zoom.setProgress(Math.round(wall.scale() * 100) - 60);
            body.addView(zoom, new LinearLayout.LayoutParams(-1, dp(48)));
            zoom.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                public void onProgressChanged(SeekBar bar, int progress, boolean user) {
                    if (user) {wall.zoom((progress + 60) / 100f / wall.scale());ratio.setText("显示比例  ·  " + Math.round(wall.scale() * 100) + "%");}
                }
                public void onStartTrackingTouch(SeekBar bar) {}
                public void onStopTrackingTouch(SeekBar bar) {}
            });
            BottomSheet.action(activity, body, "恢复 100%", () -> {wall.zoom(1f / wall.scale());zoom.setProgress(40);ratio.setText("显示比例  ·  100%");});
            BottomSheet.action(activity, body, "播放模式", actions::playMode);
            BottomSheet.action(activity, body, "回到起始位置", () -> {wall.resetCamera();sheet[0].dismiss();});
            BottomSheet.action(activity, body, "应用设置", () -> {sheet[0].dismiss();actions.settings();});
        });
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
        view.setPadding(dp(10), dp(10), dp(10), dp(10));
        view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x66FFFFFF), round(0xB5353C38, 28, 0x99FFFFFF, 1), round(Color.WHITE, 28, 0, 0)));
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
