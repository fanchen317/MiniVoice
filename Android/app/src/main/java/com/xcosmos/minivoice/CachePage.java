package com.xcosmos.minivoice;

import android.app.*;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;

import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.BooleanSupplier;

/**
 * Full-screen cache browser with recycled rows, file details and explicit selection.
 */
final class CachePage extends Dialog {
    private final Activity activity;
    private final BooleanSupplier busy;
    private final Runnable changed;
    private final AppAppearance.Palette colors;
    private final Map<String, File> roots = new LinkedHashMap<>();
    private final List<CacheFiles.Entry> entries = new ArrayList<>();
    private final Set<String> selected = new HashSet<>();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
    private ListView list;
    private TextView summary, selection, all, delete, clear, refresh;
    private boolean selecting, working, closed;
    private final FilesAdapter adapter = new FilesAdapter();
    private final android.util.LruCache<String, Bitmap> thumbs = new android.util.LruCache<String, Bitmap>(4 * 1024 * 1024) {
        @Override
        protected int sizeOf(String key, Bitmap bitmap) {
            return bitmap.getAllocationByteCount();
        }
    };
    private final Set<String> requested = new HashSet<>();

    CachePage(Activity activity, BooleanSupplier busy, Runnable changed) {
        super(activity, android.R.style.Theme_Material_Light_NoActionBar);
        this.activity = activity;
        this.busy = busy;
        this.changed = changed;
        colors = AppAppearance.palette(activity, activity.getSharedPreferences("library", 0));
        roots.put("音乐库缓存", LibraryCache.root(activity));
        roots.put("旧版内部缓存", new File(activity.getFilesDir(), "library-cache"));
        roots.put("内部临时缓存", activity.getCacheDir());
        roots.put("外部临时缓存", AppStorage.temporary(activity));
    }

    void open() {
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        build();
        show();
        PageChrome.apply(this, colors);
        load();
    }

    private int dp(int n) {
        return Math.round(n * activity.getResources().getDisplayMetrics().density);
    }

    private TextView text(String value, int size, int color) {
        TextView v = new TextView(activity);
        v.setText(value);
        v.setTextSize(size);
        v.setTextColor(color);
        return v;
    }

    private TextView button(String label, Runnable click) {
        TextView view = text(label, 14, colors.accent);
        view.setGravity(Gravity.CENTER);
        view.setIncludeFontPadding(false);
        view.setSingleLine(true);
        view.setMinHeight(dp(44));
        view.setPadding(dp(14), 0, dp(14), 0);
        view.setTypeface(android.graphics.Typeface.create("sans-serif-medium", 0));
        view.setOnClickListener(v -> click.run());
        styleButton(view, false, false);
        ButtonFeedback.install(view);
        return view;
    }

    private void styleButton(TextView view, boolean filled, boolean danger) {
        int tint = danger ? (colors.dark ? 0xFFFFA59C : 0xFFB3261E) : colors.accent;
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(dp(22));
        shape.setColor(filled ? tint : colors.dark ? 0xFF27352F : 0xFFE8F1EC);
        if (!filled) shape.setStroke(dp(1), colors.line);
        GradientDrawable mask = new GradientDrawable();
        mask.setColor(Color.WHITE);
        mask.setCornerRadius(dp(22));
        view.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(filled ? 0x22FFFFFF : 0x180A8763), shape, mask));
        view.setTextColor(filled ? Color.WHITE : tint);
    }

    private void build() {
        FrameLayout page = new FrameLayout(activity);
        page.setBackgroundColor(colors.background);
        setContentView(page);
        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(1);
        page.addView(root, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout toolbar = new LinearLayout(activity);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setPadding(dp(12), dp(4), dp(12), dp(4));
        root.addView(toolbar, new LinearLayout.LayoutParams(-1, dp(56)));
        View back = new PageBackButton(activity,colors.text,this::back);
        toolbar.addView(back,new LinearLayout.LayoutParams(dp(48),dp(48)));
        TextView title = text("本地缓存", 20, colors.text);
        title.setPadding(dp(8), 0, 0, 0);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        toolbar.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        refresh = button("刷新", this::load);
        toolbar.addView(refresh, new LinearLayout.LayoutParams(-2, dp(44)));
        summary = text("读取缓存文件…", 12, colors.secondary);
        summary.setPadding(dp(20), dp(10), dp(20), dp(10));
        root.addView(summary);
        LinearLayout actions = new LinearLayout(activity);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        actions.setPadding(dp(16), dp(4), dp(16), dp(10));
        root.addView(actions);
        selection = text("", 13, colors.secondary);
        actions.addView(selection, new LinearLayout.LayoutParams(0, -2, 1));
        all = button("全选", () -> {
            selecting = true;
            if (selected.size() == entries.size()) selected.clear();
            else for (CacheFiles.Entry e : entries) selected.add(e.file.getAbsolutePath());
            update();
        });
        actions.addView(all, new LinearLayout.LayoutParams(-2, dp(44)));
        delete = button("删除", () -> confirm(false));
        styleButton(delete, false, true);
        LinearLayout.LayoutParams deleteParams = new LinearLayout.LayoutParams(-2, dp(44));
        deleteParams.leftMargin = dp(8);
        actions.addView(delete, deleteParams);
        list = new ListView(activity);
        list.setBackgroundColor(colors.background);
        list.setDivider(new android.graphics.drawable.ColorDrawable(colors.line));
        list.setDividerHeight(dp(1));
        list.setClipToPadding(false);
        list.setAdapter(adapter);
        root.addView(list, new LinearLayout.LayoutParams(-1, 0, 1));
        list.setOnItemClickListener((p, v, index, id) -> {
            CacheFiles.Entry entry = entries.get(index);
            if (selecting) toggle(entry);
            else detail(entry);
        });
        list.setOnItemLongClickListener((p, v, index, id) -> {
            selecting = true;
            toggle(entries.get(index));
            v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
            return true;
        });
        clear = button("清理全部缓存", () -> confirm(true));
        styleButton(clear, true, false);
        clear.setElevation(dp(6));
        FrameLayout.LayoutParams footer = new FrameLayout.LayoutParams(-1, dp(48), Gravity.BOTTOM);
        footer.setMargins(dp(20), 0, dp(20), dp(12));
        page.addView(clear, footer);
        page.setOnApplyWindowInsetsListener((v, i) -> {
            int left = i.getSystemWindowInsetLeft(), right = i.getSystemWindowInsetRight(), bottom = i.getSystemWindowInsetBottom();
            root.setPadding(left, i.getSystemWindowInsetTop(), right, 0);
            list.setPadding(0, 0, 0, bottom + dp(84));
            footer.setMargins(left + dp(20), 0, right + dp(20), bottom + dp(12));
            clear.setLayoutParams(footer);
            return i;
        });
        page.post(page::requestApplyInsets);
        update();
    }

    private void toggle(CacheFiles.Entry entry) {
        String path = entry.file.getAbsolutePath();
        if (!selected.add(path)) selected.remove(path);
        update();
    }

    private void update() {
        selection.setText(selecting ? "已选 " + selected.size() + " / " + entries.size() : "长按文件多选");
        all.setText(!entries.isEmpty() && selected.size() == entries.size() ? "取消全选" : "全选");
        all.setEnabled(!working && !entries.isEmpty());
        delete.setEnabled(!working && !selected.isEmpty());
        delete.setText("删除" + (selected.isEmpty() ? "" : " (" + selected.size() + ")"));
        clear.setEnabled(!working && !entries.isEmpty());
        refresh.setEnabled(!working);
        for (TextView control : new TextView[]{all, delete, clear, refresh})
            control.setAlpha(control.isEnabled() ? 1f : .4f);
        adapter.notifyDataSetChanged();
    }

    private void load() {
        if (working || closed) return;
        working = true;
        summary.setText("正在读取缓存文件…");
        update();
        worker.execute(() -> {
            List<CacheFiles.Entry> found = null;
            String error = null;
            try {
                found = CacheFiles.list(roots);
            } catch (Exception e) {
                error = e.getMessage();
            }
            final List<CacheFiles.Entry> result = found;
            final String failure = error;
            handler.post(() -> {
                if (closed) return;
                working = false;
                entries.clear();
                if (result != null) entries.addAll(result);
                Set<String> existing = new HashSet<>();
                long total = 0;
                for (CacheFiles.Entry e : entries) {
                    existing.add(e.file.getAbsolutePath());
                    total += e.bytes;
                }
                selected.retainAll(existing);
                summary.setText(failure != null ? "读取失败：" + failure : entries.size() + " 个文件 · " + size(total) + "\n" + LibraryCache.root(activity).getAbsolutePath() + "\n包含旧目录残留；配置、收藏、歌单和原始音乐不参与清理。");
                update();
            });
        });
    }

    private void confirm(boolean everything) {
        if (working) return;
        if (busy.getAsBoolean()) {
            Toast.makeText(activity, "正在扫描音乐库，请扫描结束后清理", Toast.LENGTH_SHORT).show();
            return;
        }
        List<CacheFiles.Entry> targets = new ArrayList<>();
        for (CacheFiles.Entry e : entries)
            if (everything || selected.contains(e.file.getAbsolutePath())) targets.add(e);
        if (targets.isEmpty()) return;
        long total = 0;
        for (CacheFiles.Entry e : targets) total += e.bytes;
        new AlertDialog.Builder(activity).setTitle(everything ? "清理全部缓存？" : "删除选中文件？").setMessage(targets.size() + " 个文件 · " + size(total) + "\n仅删除派生缓存，音乐、设置、收藏和歌单保留。后续使用时可能按需重新生成。").setNegativeButton("取消", null).setPositiveButton("删除", (d, w) -> erase(targets)).show();
    }

    private void erase(List<CacheFiles.Entry> targets) {
        if (busy.getAsBoolean()) {
            Toast.makeText(activity, "扫描尚未结束，暂时无法清理", Toast.LENGTH_SHORT).show();
            return;
        }
        working = true;
        update();
        worker.execute(() -> {
            String error = null;
            long bytes = 0;
            try {
                bytes = CacheFiles.delete(targets, roots.values());
            } catch (Exception e) {
                error = e.getMessage();
            }
            String failure = error;
            long removed = bytes;
            handler.post(() -> {
                changed.run();
                if (closed) return;
                working = false;
                selected.clear();
                selecting = false;
                thumbs.evictAll();
                Toast.makeText(activity, failure == null ? "已清理 " + size(removed) : "部分文件未删除：" + failure, Toast.LENGTH_LONG).show();
                load();
            });
        });
    }

    private void detail(CacheFiles.Entry e) {
        new AlertDialog.Builder(activity).setTitle(e.file.getName()).setMessage(e.name + "\n\n大小：" + size(e.bytes) + "\n修改时间：" + android.text.format.DateFormat.format("yyyy-MM-dd HH:mm", e.modified) + "\n\n" + e.file.getAbsolutePath()).setNegativeButton("关闭", null).setPositiveButton("删除", (d, w) -> {
            selected.clear();
            selected.add(e.file.getAbsolutePath());
            selecting = true;
            update();
            confirm(false);
        }).show();
    }

    private static String size(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format(java.util.Locale.ROOT, "%.1f KB", bytes / 1024d);
        return String.format(java.util.Locale.ROOT, "%.1f MB", bytes / (1024d * 1024));
    }

    private void thumbnail(TextView view, CacheFiles.Entry entry) {
        String key = entry.file.getAbsolutePath();
        view.setTag(key);
        view.setCompoundDrawables(null, null, null, null);
        if (selecting || !entry.file.getName().endsWith(".jpg")) return;
        Bitmap cached = thumbs.get(key);
        if (cached != null) {
            showThumb(view, cached);
            return;
        }
        if (!requested.add(key)) return;
        worker.execute(() -> {
            Bitmap image = null;
            try {
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                BitmapFactory.decodeFile(key, options);
                options.inSampleSize = 1;
                while (options.outWidth / options.inSampleSize > 128 && options.outHeight / options.inSampleSize > 128)
                    options.inSampleSize *= 2;
                options.inJustDecodeBounds = false;
                image = BitmapFactory.decodeFile(key, options);
            } catch (Exception ignored) {
            }
            Bitmap result = image;
            handler.post(() -> {
                requested.remove(key);
                if (closed) return;
                if (result != null) {
                    thumbs.put(key, result);
                    if (key.equals(view.getTag()) && !selecting) showThumb(view, result);
                }
            });
        });
    }

    private void showThumb(TextView view, Bitmap bitmap) {
        view.setText("");
        android.graphics.drawable.BitmapDrawable image = new android.graphics.drawable.BitmapDrawable(activity.getResources(), bitmap);
        image.setBounds(0, 0, dp(40), dp(40));
        view.setCompoundDrawables(null, image, null, null);
    }

    private void back() {
        if (selecting) {
            selected.clear();
            selecting = false;
            update();
        } else dismiss();
    }

    @Override
    public void onBackPressed() {
        back();
    }

    @Override
    public void dismiss() {
        closed = true;
        worker.shutdown();
        handler.removeCallbacksAndMessages(null);
        super.dismiss();
    }

    private static final class CheckGlyph extends android.graphics.drawable.Drawable {
        final boolean checked;
        final int accent, outline;
        final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

        CheckGlyph(boolean checked, int accent, int outline) {
            this.checked = checked;
            this.accent = accent;
            this.outline = outline;
        }

        @Override
        public void draw(Canvas canvas) {
            int save = canvas.save();
            canvas.translate(getBounds().left, getBounds().top);
            canvas.scale(getBounds().width() / 24f, getBounds().height() / 24f);
            paint.setStrokeWidth(1.8f);
            paint.setColor(checked ? accent : outline);
            paint.setStyle(checked ? Paint.Style.FILL : Paint.Style.STROKE);
            canvas.drawRoundRect(2, 2, 22, 22, 6, 6, paint);
            if (checked) {
                paint.setColor(Color.WHITE);
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(2.2f);
                paint.setStrokeCap(Paint.Cap.ROUND);
                paint.setStrokeJoin(Paint.Join.ROUND);
                Path tick = new Path();
                tick.moveTo(7, 12);
                tick.lineTo(10.5f, 15.5f);
                tick.lineTo(17, 9);
                canvas.drawPath(tick, paint);
            }
            canvas.restoreToCount(save);
        }

        @Override
        public void setAlpha(int value) {
            paint.setAlpha(value);
        }

        @Override
        public void setColorFilter(ColorFilter filter) {
            paint.setColorFilter(filter);
        }

        @Override
        public int getOpacity() {
            return PixelFormat.TRANSLUCENT;
        }
    }

    private final class FilesAdapter extends BaseAdapter {
        public int getCount() {
            return entries.size();
        }

        public Object getItem(int p) {
            return entries.get(p);
        }

        public long getItemId(int p) {
            return p;
        }

        public View getView(int position, View recycled, android.view.ViewGroup parent) {
            LinearLayout row;
            TextView icon, name, meta;
            LinearLayout labels;
            if (recycled == null) {
                row = new LinearLayout(activity);
                row.setGravity(Gravity.CENTER_VERTICAL);
                row.setPadding(dp(12), dp(12), dp(12), dp(12));
                icon = text("", 14, colors.accent);
                icon.setGravity(Gravity.CENTER);
                row.addView(icon, new LinearLayout.LayoutParams(dp(48), dp(48)));
                labels = new LinearLayout(activity);
                labels.setOrientation(1);
                name = text("", 14, colors.text);
                name.setMaxLines(2);
                name.setEllipsize(android.text.TextUtils.TruncateAt.MIDDLE);
                labels.addView(name);
                meta = text("", 11, colors.secondary);
                meta.setPadding(0, dp(5), 0, 0);
                labels.addView(meta);
                row.addView(labels, new LinearLayout.LayoutParams(0, -2, 1));
                row.setTag(new TextView[]{icon, name, meta});
            } else row = (LinearLayout) recycled;
            TextView[] views = (TextView[]) row.getTag();
            CacheFiles.Entry e = entries.get(position);
            boolean checked = selected.contains(e.file.getAbsolutePath());
            views[0].setText(selecting ? "" : e.file.getName().endsWith(".jpg") ? "封面" : e.file.getName().endsWith(".txt") ? "歌词" : e.file.getName().endsWith(".json") ? "索引" : "文件");
            views[1].setText(e.name);
            views[2].setText(size(e.bytes) + " · " + android.text.format.DateFormat.format("MM-dd HH:mm", e.modified));
            row.setBackgroundColor(checked ? (colors.dark ? 0xFF214238 : 0xFFE0F3EA) : colors.surface);
            views[0].setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
            row.setAccessibilityDelegate(new View.AccessibilityDelegate() {
                @Override
                public void onInitializeAccessibilityNodeInfo(View host, android.view.accessibility.AccessibilityNodeInfo info) {
                    super.onInitializeAccessibilityNodeInfo(host, info);
                    info.setCheckable(selecting);
                    info.setChecked(checked);
                }
            });
            thumbnail(views[0], e);
            if (selecting) {
                CheckGlyph check = new CheckGlyph(checked, colors.accent, colors.secondary);
                check.setBounds(0, 0, dp(24), dp(24));
                views[0].setCompoundDrawables(null, check, null, null);
            }
            row.setContentDescription(e.name + "，" + size(e.bytes) + (checked ? "，已选中" : ""));
            return row;
        }
    }
}
