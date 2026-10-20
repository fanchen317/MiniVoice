package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.*;
import android.view.*;
import android.widget.*;

/** Simple/library footer: album and metadata, transport, clock and thin seek. */
final class StandardPlaybackBar extends LinearLayout {
    private final HomeScreen.Actions actions;private final Runnable expand;
    private AppAppearance.Palette colors=new AppAppearance.Palette(false);private boolean wide,playing,simple;
    private SeekBar mediaVolume;private TextView volumePercent;private long sampledAudioAt;
    private Song song;private int position,duration,mode;private ImageView artwork;private TextView title,artist,elapsed,total,modeButton;private SeekBar seek;private TransportButton play;
    StandardPlaybackBar(Context context,HomeScreen.Actions actions,Runnable expand){super(context);this.actions=actions;this.expand=expand;setVisibility(GONE);setElevation(dp(6));}
    private int dp(float n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(getContext());view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setSingleLine(true);view.setEllipsize(android.text.TextUtils.TruncateAt.END);return view;}
    private GradientDrawable shape(int color,int radius){GradientDrawable result=new GradientDrawable();result.setColor(color);result.setCornerRadius(dp(radius));return result;}
    void configure(AppAppearance.Palette value,boolean landscape,boolean simpleStyle){boolean rebuild=play==null||wide!=landscape||colors.dark!=value.dark||simple!=simpleStyle;colors=value;wide=landscape;simple=simpleStyle;if(rebuild)render();}
    void song(Song value){song=value;refreshSong();}
    void state(boolean value,int time,int length){if(simple)refreshAudio();playing=value;position=time;duration=length;if(play==null)return;play.setPlaying(value);if(!seek.isPressed()){seek.setMax(Math.max(1,length));seek.setProgress(Math.min(length,time));elapsed.setText(clock(time));}total.setText(clock(length));seek.setEnabled(song!=null&&length>0);}
    void mode(int value){mode=PlaybackModes.valid(value);if(modeButton!=null){PlaybackModeGlyph.bind(modeButton,mode,colors.accent);modeButton.setContentDescription("播放模式："+PlaybackModes.NAMES[mode]);}}
    private void cycleMode(){int next=(PlaybackModes.valid(actions.playbackMode())+1)%PlaybackModes.NAMES.length;actions.selectPlaybackMode(next);mode(next);announceForAccessibility("播放模式："+PlaybackModes.NAMES[next]);}
    private TransportButton button(TransportButton.Glyph glyph,Runnable action){TransportButton button=new TransportButton(getContext(),glyph,action);button.setColors(colors.text,colors.surface);return button;}
    private void render(){
        if(simple){renderSimple();return;}
        modeButton=null;mediaVolume=null;volumePercent=null;removeAllViews();setOrientation(wide?HORIZONTAL:VERTICAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(12),dp(8),dp(12),dp(8));setBackground(FrostedSurface.background(getContext(),20));
        LinearLayout top=new LinearLayout(getContext());top.setGravity(Gravity.CENTER_VERTICAL);addView(top,wide?new LayoutParams(0,-1,1):new LayoutParams(-1,dp(48)));
        artwork=new ImageView(getContext());artwork.setScaleType(ImageView.ScaleType.CENTER_CROP);artwork.setBackground(shape(colors.line,8));artwork.setClipToOutline(true);artwork.setContentDescription("展开或收起播放页");artwork.setOnClickListener(v->expand.run());ButtonFeedback.install(artwork);top.addView(artwork,new LayoutParams(dp(44),dp(44)));
        LinearLayout info=new LinearLayout(getContext());info.setOrientation(VERTICAL);info.setGravity(Gravity.CENTER_VERTICAL);info.setPadding(dp(10),0,dp(8),0);info.setOnClickListener(v->actions.locate());ButtonFeedback.install(info);top.addView(info,new LayoutParams(0,-1,1));title=text("",14,colors.text);title.setTypeface(null,Typeface.BOLD);artist=text("",11,colors.secondary);artist.setPadding(0,dp(4),0,0);info.addView(title);info.addView(artist);
        LinearLayout controls=new LinearLayout(getContext());controls.setGravity(Gravity.CENTER);TransportButton previous=button(TransportButton.Glyph.PREVIOUS_TRACK,actions::previous);play=button(TransportButton.Glyph.PLAY_PAUSE,actions::toggle);play.setBackground(shape(colors.accent,22));TransportButton next=button(TransportButton.Glyph.NEXT_TRACK,actions::next);controls.addView(previous,new LayoutParams(dp(40),dp(44)));controls.addView(play,new LayoutParams(dp(44),dp(44)));controls.addView(next,new LayoutParams(dp(40),dp(44)));
        LinearLayout center=new LinearLayout(getContext());center.setOrientation(VERTICAL);center.setGravity(Gravity.CENTER);if(wide){addView(center,new LayoutParams(0,-1,1.2f));center.addView(controls,new LayoutParams(-1,dp(44)));}else top.addView(controls,new LayoutParams(-2,dp(48)));
        LinearLayout progress=new LinearLayout(getContext());progress.setGravity(Gravity.CENTER_VERTICAL);if(wide)center.addView(progress,new LayoutParams(-1,dp(24)));else addView(progress,new LayoutParams(-1,dp(40)));
        elapsed=text("0:00",10,colors.secondary);total=text("0:00",10,colors.secondary);elapsed.setGravity(Gravity.CENTER);total.setGravity(Gravity.CENTER);progress.addView(elapsed,new LayoutParams(dp(36),-1));
        seek=new SeekBar(getContext());GradientDrawable track=shape(colors.dark?0x667A9690:0x66708179,2),fill=shape(colors.accent,2);ClipDrawable clip=new ClipDrawable(fill,Gravity.LEFT,ClipDrawable.HORIZONTAL);LayerDrawable layers=new LayerDrawable(new android.graphics.drawable.Drawable[]{track,clip});layers.setId(0,android.R.id.background);layers.setId(1,android.R.id.progress);for(int i=0;i<2;i++){layers.setLayerHeight(i,dp(2));layers.setLayerGravity(i,Gravity.CENTER_VERTICAL);}seek.setProgressDrawable(layers);seek.setSplitTrack(false);GradientDrawable thumb=new GradientDrawable();thumb.setShape(GradientDrawable.OVAL);thumb.setColor(colors.accent);thumb.setSize(dp(12),dp(12));seek.setThumb(thumb);seek.setThumbOffset(dp(6));seek.setPadding(dp(6),0,dp(6),0);progress.addView(seek,new LayoutParams(0,-1,1));progress.addView(total,new LayoutParams(dp(36),-1));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar bar,int value,boolean user){if(user)elapsed.setText(clock(value));}public void onStartTrackingTouch(SeekBar bar){}public void onStopTrackingTouch(SeekBar bar){actions.seek(bar.getProgress());}});
        LinearLayout tools=new LinearLayout(getContext());tools.setGravity(Gravity.CENTER_VERTICAL);if(wide)addView(tools,new LayoutParams(-2,-1));else top.addView(tools,new LayoutParams(-2,dp(48)));
        modeButton=text("",wide?12:19,colors.accent);modeButton.setGravity(Gravity.CENTER);modeButton.setOnClickListener(v->cycleMode());ButtonFeedback.install(modeButton);if(wide)tools.addView(modeButton,new LayoutParams(dp(44),dp(44)));else progress.addView(modeButton,0,new LayoutParams(dp(40),dp(40)));
        TransportButton queue=button(TransportButton.Glyph.QUEUE,actions::queue);tools.addView(queue,new LayoutParams(dp(44),dp(44)));refreshSong();state(playing,position,duration);mode(mode);
    }
    private void renderSimple(){
        removeAllViews();modeButton=null;setOrientation(VERTICAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(14),dp(10),dp(14),dp(10));
        GradientDrawable glass=shape(colors.dark?0xB3263432:0xA8E2EBED,20);glass.setStroke(dp(1),colors.dark?0x557E9690:0xBBFFFFFF);setBackground(glass);setElevation(dp(2));
        LinearLayout top=new LinearLayout(getContext());top.setGravity(Gravity.CENTER_VERTICAL);addView(top,new LayoutParams(-1,dp(wide?44:60)));
        artwork=new ImageView(getContext());artwork.setScaleType(ImageView.ScaleType.CENTER_CROP);artwork.setBackground(shape(colors.line,10));artwork.setClipToOutline(true);artwork.setOnClickListener(v->expand.run());artwork.setContentDescription("展开或收起歌词");ButtonFeedback.install(artwork);top.addView(artwork,new LayoutParams(dp(wide?40:52),dp(wide?40:52)));
        LinearLayout info=new LinearLayout(getContext());info.setOrientation(VERTICAL);info.setGravity(Gravity.CENTER_VERTICAL);info.setPadding(dp(10),0,dp(8),0);info.setOnClickListener(v->actions.locate());ButtonFeedback.install(info);top.addView(info,new LayoutParams(0,-1,1));title=text("",14,colors.text);title.setTypeface(null,Typeface.BOLD);artist=text("",12,colors.secondary);artist.setPadding(0,dp(5),0,0);info.addView(title);info.addView(artist);
        LinearLayout audio=new LinearLayout(getContext());audio.setOrientation(VERTICAL);audio.setGravity(Gravity.CENTER_VERTICAL);top.addView(audio,new LayoutParams(0,-1,1.2f));
        android.media.AudioManager manager=(android.media.AudioManager)getContext().getSystemService(Context.AUDIO_SERVICE);
        LinearLayout volumeRow=new LinearLayout(getContext());volumeRow.setGravity(Gravity.CENTER_VERTICAL);audio.addView(volumeRow,new LayoutParams(-1,0,1));ImageView speaker=new ImageView(getContext());speaker.setImageDrawable(new SimplePlayerGlyph(SimplePlayerGlyph.VOLUME,colors.secondary,getResources().getDisplayMetrics().density));speaker.setContentDescription("媒体音量");speaker.setScaleType(ImageView.ScaleType.CENTER);volumeRow.addView(speaker,new LayoutParams(dp(28),dp(40)));
        TextView percent=text("",11,colors.secondary);volumePercent=percent;SeekBar volume=new SeekBar(getContext());mediaVolume=volume;volume.setContentDescription("媒体音量");int max=Math.max(1,manager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC));volume.setMax(max);volume.setProgress(manager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC));percent.setText(Math.round(volume.getProgress()*100f/max)+"%");volume.setProgressTintList(android.content.res.ColorStateList.valueOf(colors.accent));volume.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(colors.dark?0x447A9690:0x33708179));
        GradientDrawable volumeThumb=shape(0xFFFFFFFF,8);volumeThumb.setSize(dp(16),dp(16));volume.setThumb(volumeThumb);volume.setThumbOffset(dp(8));volume.setPadding(dp(8),0,dp(8),0);volume.setSplitTrack(false);volumeRow.addView(volume,new LayoutParams(0,dp(44),1));volumeRow.addView(percent,new LayoutParams(dp(36),-2));
        volume.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar bar,int value,boolean user){percent.setText(Math.round(value*100f/max)+"%");if(user)manager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC,value,0);}public void onStartTrackingTouch(SeekBar bar){}public void onStopTrackingTouch(SeekBar bar){}});
        LinearLayout progress=new LinearLayout(getContext());progress.setGravity(Gravity.CENTER_VERTICAL);addView(progress,new LayoutParams(-1,dp(wide?32:44)));elapsed=text("0:00",11,colors.secondary);total=text("0:00",11,colors.secondary);elapsed.setGravity(Gravity.CENTER);total.setGravity(Gravity.CENTER);progress.addView(elapsed,new LayoutParams(dp(40),-1));
        seek=new SeekBar(getContext());seek.setContentDescription("播放进度");seek.setProgressTintList(android.content.res.ColorStateList.valueOf(colors.accent));seek.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(colors.dark?0x337A9690:0x66FFFFFF));GradientDrawable thumb=shape(0xFFFFFFFF,14);thumb.setSize(dp(32),dp(22));seek.setThumb(thumb);seek.setThumbOffset(dp(16));seek.setPadding(dp(16),0,dp(16),0);progress.addView(seek,new LayoutParams(0,-1,1));progress.addView(total,new LayoutParams(dp(40),-1));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar bar,int value,boolean user){if(user)elapsed.setText(clock(value));}public void onStartTrackingTouch(SeekBar bar){}public void onStopTrackingTouch(SeekBar bar){actions.seek(bar.getProgress());}});
        LinearLayout controls=new LinearLayout(getContext());controls.setGravity(Gravity.CENTER);addView(controls,new LayoutParams(-1,0,1));
        TransportButton queue=button(TransportButton.Glyph.QUEUE,actions::queue);queue.setContentDescription("播放队列，长按切换播放模式");queue.setOnLongClickListener(v->{cycleMode();return true;});controls.addView(queue,new LayoutParams(0,dp(44),1));
        TransportButton previous=button(TransportButton.Glyph.PREVIOUS_TRACK,actions::previous);controls.addView(previous,new LayoutParams(0,dp(48),1));
        play=button(TransportButton.Glyph.PLAY_PAUSE,actions::toggle);play.setColors(colors.text,0xFFFFFFFF);play.setBackground(shape(colors.accent,40));int playSide=dp(wide?48:64);controls.addView(play,new LayoutParams(playSide,playSide));
        TransportButton next=button(TransportButton.Glyph.NEXT_TRACK,actions::next);controls.addView(next,new LayoutParams(0,dp(48),1));ImageView lyrics=new ImageView(getContext());lyrics.setImageDrawable(new SimplePlayerGlyph(SimplePlayerGlyph.LYRICS,colors.text,getResources().getDisplayMetrics().density));lyrics.setScaleType(ImageView.ScaleType.CENTER);lyrics.setContentDescription("展开或收起歌词");lyrics.setOnClickListener(v->expand.run());lyrics.setOnLongClickListener(v->{actions.lyrics();return true;});ButtonFeedback.install(lyrics);controls.addView(lyrics,new LayoutParams(0,dp(48),1));
        refreshSong();state(playing,position,duration);
    }
    private void refreshAudio(){
        if(mediaVolume==null||android.os.SystemClock.uptimeMillis()-sampledAudioAt<1000)return;sampledAudioAt=android.os.SystemClock.uptimeMillis();
        android.media.AudioManager manager=(android.media.AudioManager)getContext().getSystemService(Context.AUDIO_SERVICE);
        int max=Math.max(1,manager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)),value=manager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC);
        if(!mediaVolume.isPressed()){mediaVolume.setMax(max);mediaVolume.setProgress(value);volumePercent.setText(Math.round(value*100f/max)+"%");}

    }
    private void refreshSong(){if(title==null)return;title.setText(song==null?"选择一首歌曲":song.title);artist.setText(song==null?"MiniVoice":song.artist+(!simple&&wide?" · "+song.album:""));artwork.setEnabled(song!=null);play.setEnabled(song!=null);Bitmap bitmap=song==null?null:ArtworkCache.peek(song,256);artwork.setImageBitmap(bitmap!=null?bitmap:song==null?null:song.artworkPreview);}
    private String clock(int ms){return String.format(java.util.Locale.ROOT,"%d:%02d",Math.max(0,ms)/60000,Math.max(0,ms)/1000%60);}
}
