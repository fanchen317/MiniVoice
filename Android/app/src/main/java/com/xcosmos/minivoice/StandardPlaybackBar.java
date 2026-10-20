package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Typeface;
import android.graphics.drawable.*;
import android.view.*;
import android.widget.*;

/** Simple/library footer: album and metadata, transport, clock and thin seek. */
final class StandardPlaybackBar extends LinearLayout {
    private final HomeScreen.Actions actions;private final Runnable expand;
    private AppAppearance.Palette colors=new AppAppearance.Palette(false);private boolean wide,playing;
    private Song song;private int position,duration,mode;private ImageView artwork;private TextView title,artist,elapsed,total,modeButton;private SeekBar seek;private TransportButton play;
    StandardPlaybackBar(Context context,HomeScreen.Actions actions,Runnable expand){super(context);this.actions=actions;this.expand=expand;setVisibility(GONE);setElevation(dp(6));}
    private int dp(float n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(getContext());view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setSingleLine(true);view.setEllipsize(android.text.TextUtils.TruncateAt.END);return view;}
    private GradientDrawable shape(int color,int radius){GradientDrawable result=new GradientDrawable();result.setColor(color);result.setCornerRadius(dp(radius));return result;}
    void configure(AppAppearance.Palette value,boolean landscape){boolean rebuild=play==null||wide!=landscape||colors.dark!=value.dark;colors=value;wide=landscape;if(rebuild)render();}
    void song(Song value){song=value;refreshSong();}
    void state(boolean value,int time,int length){playing=value;position=time;duration=length;if(play==null)return;play.setPlaying(value);if(!seek.isPressed()){seek.setMax(Math.max(1,length));seek.setProgress(Math.min(length,time));elapsed.setText(clock(time));}total.setText(clock(length));seek.setEnabled(song!=null&&length>0);}
    void mode(int value){mode=PlaybackModes.valid(value);if(modeButton!=null){modeButton.setText(wide?PlaybackModes.NAMES[mode]:new String[]{"①","≡","⤨","↻¹","↻"}[mode]);modeButton.setContentDescription("播放模式："+PlaybackModes.NAMES[mode]);}}
    private TransportButton button(TransportButton.Glyph glyph,Runnable action){TransportButton button=new TransportButton(getContext(),glyph,action);button.setColors(colors.text,colors.surface);return button;}
    private void render(){
        removeAllViews();setOrientation(wide?HORIZONTAL:VERTICAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(12),dp(8),dp(12),dp(8));GradientDrawable background=shape(colors.surface,18);background.setStroke(dp(1),colors.line);setBackground(background);
        LinearLayout top=new LinearLayout(getContext());top.setGravity(Gravity.CENTER_VERTICAL);addView(top,wide?new LayoutParams(0,-1,1):new LayoutParams(-1,dp(48)));
        artwork=new ImageView(getContext());artwork.setScaleType(ImageView.ScaleType.CENTER_CROP);artwork.setBackground(shape(colors.line,8));artwork.setClipToOutline(true);artwork.setContentDescription("展开或收起播放页");artwork.setOnClickListener(v->expand.run());ButtonFeedback.install(artwork);top.addView(artwork,new LayoutParams(dp(44),dp(44)));
        LinearLayout info=new LinearLayout(getContext());info.setOrientation(VERTICAL);info.setGravity(Gravity.CENTER_VERTICAL);info.setPadding(dp(10),0,dp(8),0);info.setOnClickListener(v->actions.locate());ButtonFeedback.install(info);top.addView(info,new LayoutParams(0,-1,1));title=text("",14,colors.text);title.setTypeface(null,Typeface.BOLD);artist=text("",11,colors.secondary);artist.setPadding(0,dp(4),0,0);info.addView(title);info.addView(artist);
        LinearLayout controls=new LinearLayout(getContext());controls.setGravity(Gravity.CENTER);TransportButton previous=button(TransportButton.Glyph.PREVIOUS_TRACK,actions::previous);play=button(TransportButton.Glyph.PLAY_PAUSE,actions::toggle);play.setBackground(shape(colors.accent,22));TransportButton next=button(TransportButton.Glyph.NEXT_TRACK,actions::next);controls.addView(previous,new LayoutParams(dp(40),dp(44)));controls.addView(play,new LayoutParams(dp(44),dp(44)));controls.addView(next,new LayoutParams(dp(40),dp(44)));
        LinearLayout center=new LinearLayout(getContext());center.setOrientation(VERTICAL);center.setGravity(Gravity.CENTER);if(wide){addView(center,new LayoutParams(0,-1,1.2f));center.addView(controls,new LayoutParams(-1,dp(44)));}else top.addView(controls,new LayoutParams(-2,dp(48)));
        LinearLayout progress=new LinearLayout(getContext());progress.setGravity(Gravity.CENTER_VERTICAL);if(wide)center.addView(progress,new LayoutParams(-1,dp(24)));else addView(progress,new LayoutParams(-1,dp(40)));
        elapsed=text("0:00",10,colors.secondary);total=text("0:00",10,colors.secondary);elapsed.setGravity(Gravity.CENTER);total.setGravity(Gravity.CENTER);progress.addView(elapsed,new LayoutParams(dp(36),-1));
        seek=new SeekBar(getContext());GradientDrawable track=shape(colors.line,2),fill=shape(colors.accent,2);ClipDrawable clip=new ClipDrawable(fill,Gravity.LEFT,ClipDrawable.HORIZONTAL);LayerDrawable layers=new LayerDrawable(new android.graphics.drawable.Drawable[]{track,clip});layers.setId(0,android.R.id.background);layers.setId(1,android.R.id.progress);for(int i=0;i<2;i++){layers.setLayerHeight(i,dp(2));layers.setLayerGravity(i,Gravity.CENTER_VERTICAL);}seek.setProgressDrawable(layers);GradientDrawable thumb=new GradientDrawable();thumb.setShape(GradientDrawable.OVAL);thumb.setColor(colors.accent);thumb.setSize(dp(12),dp(12));seek.setThumb(thumb);seek.setThumbOffset(dp(6));seek.setPadding(dp(6),0,dp(6),0);progress.addView(seek,new LayoutParams(0,-1,1));progress.addView(total,new LayoutParams(dp(36),-1));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar bar,int value,boolean user){if(user)elapsed.setText(clock(value));}public void onStartTrackingTouch(SeekBar bar){}public void onStopTrackingTouch(SeekBar bar){actions.seek(bar.getProgress());}});
        LinearLayout tools=new LinearLayout(getContext());tools.setGravity(Gravity.CENTER_VERTICAL);if(wide)addView(tools,new LayoutParams(-2,-1));else top.addView(tools,new LayoutParams(-2,dp(48)));
        modeButton=text("",wide?12:19,colors.accent);modeButton.setGravity(Gravity.CENTER);modeButton.setOnClickListener(v->new android.app.AlertDialog.Builder(getContext()).setTitle("播放模式").setSingleChoiceItems(PlaybackModes.NAMES,mode,(dialog,index)->{actions.selectPlaybackMode(index);mode(index);dialog.dismiss();}).setNegativeButton("取消",null).show());ButtonFeedback.install(modeButton);if(wide)tools.addView(modeButton,new LayoutParams(dp(78),dp(44)));else progress.addView(modeButton,0,new LayoutParams(dp(40),dp(40)));
        TransportButton queue=button(TransportButton.Glyph.QUEUE,actions::queue);tools.addView(queue,new LayoutParams(dp(44),dp(44)));refreshSong();state(playing,position,duration);mode(mode);
    }
    private void refreshSong(){if(title==null)return;title.setText(song==null?"选择一首歌曲":song.title);artist.setText(song==null?"MiniVoice":song.artist+(wide?" · "+song.album:""));artwork.setEnabled(song!=null);play.setEnabled(song!=null);Bitmap bitmap=song==null?null:ArtworkCache.peek(song,256);artwork.setImageBitmap(bitmap!=null?bitmap:song==null?null:song.artworkPreview);}
    private String clock(int ms){return String.format(java.util.Locale.ROOT,"%d:%02d",Math.max(0,ms)/60000,Math.max(0,ms)/1000%60);}
}
