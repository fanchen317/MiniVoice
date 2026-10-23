package com.xcosmos.minivoice;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.session.MediaSession;
import android.media.MediaMetadata;
import android.media.session.PlaybackState;
import android.graphics.Bitmap;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class PlaybackService extends Service {
    interface Listener { void changed(); }
    static final String CHANNEL="playback", ACTION_TOGGLE="toggle", ACTION_NEXT="next", ACTION_PREVIOUS="previous";
    final Binder binder=new LocalBinder();
    final List<Song> queue=new ArrayList<>();
    final List<Listener> listeners=new ArrayList<>();
    MediaPlayer player; MediaSession session; AudioFocusRequest focusRequest;
    private final ExecutorService artworkLoader=Executors.newSingleThreadExecutor();
    private Bitmap artwork;
    private long artworkSongId=Long.MIN_VALUE;
    private int artworkGeneration;
    int index=-1, mode=1; // 0 single, 1 list, 2 shuffle, 3 repeat one, 4 repeat list
    String playbackError="";long playbackErrorToken;
    private boolean fileEditing;private long editingID;private int editingPosition;private boolean editingPlaying;
    boolean active=false;
    final Random random=new Random();
    private final BroadcastReceiver noisyReceiver=new BroadcastReceiver(){@Override public void onReceive(Context context,Intent intent){if(player!=null&&player.isPlaying()){player.pause();publish();}}};
    public class LocalBinder extends Binder { PlaybackService get(){return PlaybackService.this;} }
    @Override public IBinder onBind(Intent intent){return binder;}
    @Override public void onCreate(){
        super.onCreate();AppStorage.mirrorPreferences(this);mode=PlaybackModes.valid(getSharedPreferences("library",MODE_PRIVATE).getInt("playback_mode",1));
        ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(new NotificationChannel(CHANNEL,"音乐播放",NotificationManager.IMPORTANCE_LOW));
        session=new MediaSession(this,"MiniVoice");session.setCallback(new MediaSession.Callback(){
            @Override public void onPlay(){if(!isPlaying())toggle();}
            @Override public void onPause(){if(isPlaying())toggle();}
            @Override public void onSkipToNext(){next(true);}
            @Override public void onSkipToPrevious(){previous();}
            @Override public void onSeekTo(long position){seek((int)position);}
        });session.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS | MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);session.setActive(true);
        registerReceiver(noisyReceiver,new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    }
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null && intent.getAction()!=null) switch(intent.getAction()) {
            case ACTION_TOGGLE: toggle(); break; case ACTION_NEXT: next(true); break; case ACTION_PREVIOUS: previous(); break;
        }
        return START_NOT_STICKY;
    }
    void setMode(int value){mode=PlaybackModes.valid(value);getSharedPreferences("library",MODE_PRIVATE).edit().putInt("playback_mode",mode).apply();publish();}
    void setQueue(List<Song> songs,int selected){
        if(fileEditing)return;
        queue.clear(); queue.addAll(songs); index=selected; playCurrent();
    }
    void retainLibrary(List<Song> songs){
        Song previous=current();java.util.Set<String> keep=new java.util.HashSet<>();for(Song song:songs)keep.add(song.uri.toString());
        queue.removeIf(song->!keep.contains(song.uri.toString()));index=-1;
        if(previous!=null)for(int i=0;i<queue.size();i++)if(queue.get(i).uri.equals(previous.uri)){index=i;break;}
        if(index<0){if(player!=null){player.release();player=null;}active=false;artwork=null;artworkSongId=Long.MIN_VALUE;artworkGeneration++;session.setMetadata(null);session.setPlaybackState(new PlaybackState.Builder().setState(PlaybackState.STATE_STOPPED,0,0).build());stopForeground(STOP_FOREGROUND_REMOVE);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).cancel(1);notifyListeners();}
        else refreshLibrary(songs);
    }
    void refreshLibrary(List<Song> songs){
        java.util.Map<String,Song> updated=new java.util.HashMap<>();for(Song song:songs)updated.put(song.uri.toString(),song);
        for(int i=0;i<queue.size();i++){Song song=updated.get(queue.get(i).uri.toString());if(song!=null)queue.set(i,song);}
        Song song=current();if(song!=null){artworkSongId=song.id;loadArtwork(song,++artworkGeneration);publish();}
    }
    void select(int selected){if(selected>=0&&selected<queue.size()){index=selected;playCurrent();}}
    Song current(){return index>=0 && index<queue.size()?queue.get(index):null;}
    boolean isPlaying(){return player!=null && player.isPlaying();}
    int position(){try{return player==null?0:player.getCurrentPosition();}catch(Exception e){return 0;}}
    void seek(int ms){if(player!=null){player.seekTo(Math.max(0,Math.min(ms,player.getDuration())));publish();}}
    void toggle(){
        if(fileEditing)return;
        if(player==null){playCurrent();return;}
        if(player.isPlaying()) player.pause(); else {requestFocus();player.start();}
        publish();
    }
    void next(boolean manual){
        if(fileEditing)return;
        if(queue.isEmpty())return;
        if(!manual && mode==0){stopPlayback();return;}
        if(!manual && mode==3){seek(0);player.start();publish();return;}
        if(mode==2 && queue.size()>1){int previous=index;do{index=random.nextInt(queue.size());}while(index==previous);}
        else if(index+1<queue.size())index++;
        else if(manual || mode==4)index=0;
        else {stopPlayback();return;}
        playCurrent();
    }
    void previous(){if(fileEditing)return;if(position()>3000){seek(0);return;}if(queue.isEmpty())return;index=index>0?index-1:queue.size()-1;playCurrent();}
    void beginFileEdit(long id){
        if(fileEditing)throw new IllegalStateException("正在保存其他歌曲");fileEditing=true;editingID=id;editingPosition=position();editingPlaying=isPlaying();
        if(current()!=null&&current().id==id&&player!=null){player.release();player=null;publish();}
    }
    void endFileEdit(){if(!fileEditing)return;fileEditing=false;if(current()!=null&&current().id==editingID&&player==null)playCurrent(editingPosition,editingPlaying);}
    private void playCurrent(){playCurrent(0,true);}
    private void playCurrent(int start,boolean autoplay){
        Song song=current(); if(song==null)return;
        artwork=null;artworkSongId=song.id;int generation=++artworkGeneration;
        if(player!=null){player.release();player=null;}
        try {
            player=new MediaPlayer(); player.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
            player.setDataSource(this,song.uri); player.setOnCompletionListener(mp->next(false)); player.prepare();
            if(start>0)player.seekTo(Math.min(start,player.getDuration()));if(autoplay){requestFocus();player.start();}active=true;publish();loadArtwork(song,generation);
        } catch(Exception e){Diagnostics.failure("playback failed",e);playbackError="无法播放：文件可能已失效或格式不支持";playbackErrorToken++;if(player!=null){player.release();player=null;}active=false;publish();}
    }
    private void loadArtwork(Song song,int generation){
        artworkLoader.execute(()->{
            Bitmap result=ArtworkCache.load(this,song);
            new android.os.Handler(getMainLooper()).post(()->{if(artworkGeneration==generation && artworkSongId==song.id && current()==song){artwork=result;publish();}});
        });
    }
    private void requestFocus(){
        AudioManager manager=(AudioManager)getSystemService(AUDIO_SERVICE);
        if(Build.VERSION.SDK_INT>=26){focusRequest=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setOnAudioFocusChangeListener(change->{if(change<=0 && player!=null && player.isPlaying()){player.pause();publish();}}).build();manager.requestAudioFocus(focusRequest);}
    }
    private void stopPlayback(){if(player!=null){try{if(player.isPlaying())player.pause();player.seekTo(0);}catch(IllegalStateException ignored){}}active=false;publish();}
    void addListener(Listener listener){listeners.add(listener);listener.changed();}
    void removeListener(Listener listener){listeners.remove(listener);}
    private void notifyListeners(){for(Listener listener:new ArrayList<>(listeners))listener.changed();}
    private PendingIntent action(String action,int requestCode){Intent intent=new Intent(this,PlaybackService.class).setAction(action);return PendingIntent.getService(this,requestCode,intent,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);}
    private void publish(){
        Song song=current(); notifyListeners(); if(song==null)return;
        MediaMetadata.Builder metadata=new MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE,song.title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST,song.artist).putString(MediaMetadata.METADATA_KEY_ALBUM,song.album)
            .putLong(MediaMetadata.METADATA_KEY_DURATION,player!=null?player.getDuration():song.duration);
        if(artwork!=null)metadata.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART,artwork).putBitmap(MediaMetadata.METADATA_KEY_ART,artwork);
        session.setMetadata(metadata.build());
        session.setPlaybackState(new PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_PLAY_PAUSE|PlaybackState.ACTION_SKIP_TO_NEXT|PlaybackState.ACTION_SKIP_TO_PREVIOUS|PlaybackState.ACTION_SEEK_TO)
            .setState(isPlaying()?PlaybackState.STATE_PLAYING:active?PlaybackState.STATE_PAUSED:PlaybackState.STATE_STOPPED,position(),isPlaying()?1f:0f,android.os.SystemClock.elapsedRealtime()).build());
        Intent open=new Intent(this,PortablePlayerActivity.class).setAction(MainActivity.ACTION_LOCATE_PLAYING)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_CLEAR_TOP);
        Notification notification=new Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(song.title).setContentText(song.artist).setContentIntent(PendingIntent.getActivity(this,0,open,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT))
            .setLargeIcon(artwork).setVisibility(Notification.VISIBILITY_PUBLIC).setCategory(Notification.CATEGORY_TRANSPORT).setOngoing(isPlaying())
            .addAction(android.R.drawable.ic_media_previous,"上一首",action(ACTION_PREVIOUS,1))
            .addAction(isPlaying()?android.R.drawable.ic_media_pause:android.R.drawable.ic_media_play,isPlaying()?"暂停":"播放",action(ACTION_TOGGLE,2))
            .addAction(android.R.drawable.ic_media_next,"下一首",action(ACTION_NEXT,3))
            .setStyle(new Notification.MediaStyle().setMediaSession(session.getSessionToken()).setShowActionsInCompactView(0,1,2)).build();
        if(active)startForeground(1,notification);else {stopForeground(STOP_FOREGROUND_REMOVE);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(1,notification);}
    }
    @Override public void onDestroy(){unregisterReceiver(noisyReceiver);artworkLoader.shutdownNow();if(player!=null)player.release();if(session!=null)session.release();super.onDestroy();}
}
