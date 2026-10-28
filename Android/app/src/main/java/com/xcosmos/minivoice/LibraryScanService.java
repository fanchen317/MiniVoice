package com.xcosmos.minivoice;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.os.*;
import java.io.File;
import java.util.*;
import java.util.concurrent.*;

/** Owns the entire scan pipeline independently of any Activity or playback session. */
public final class LibraryScanService extends Service {
    interface Listener {void changed(State state);}
    static final class State {
        final boolean running;final int completed,total;final String stage,detail,error;
        final List<Song> songs;final long revision;
        State(boolean running,int completed,int total,String stage,String detail,String error,List<Song> songs,long revision){this.running=running;this.completed=completed;this.total=total;this.stage=stage;this.detail=detail;this.error=error;this.songs=songs;this.revision=revision;}
    }
    private static final String CHANNEL="library_scan";
    private static final int ONGOING=2,RESULT=3;
    private static final Handler MAIN=new Handler(Looper.getMainLooper());
    private static final List<Listener> LISTENERS=new CopyOnWriteArrayList<>();
    private static final Object SOURCE_LOCK=new Object();
    private static volatile int generation;
    private static volatile State state=new State(false,0,0,"音乐库","",null,null,0);
    private final ScanRequestQueue requests=new ScanRequestQueue();
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private NotificationManager notifications;
    private PowerManager.WakeLock wakeLock;
    private volatile boolean destroyed;
    private volatile long wakeRenewedAt;
    private long lastNotification;
    static boolean isRunning(){return state.running;}
    static void observe(Listener listener){LISTENERS.add(listener);listener.changed(state);}
    static void remove(Listener listener){LISTENERS.remove(listener);}
    static void request(Context context,boolean rebuild,boolean restore,boolean sourcesChanged){
        if(sourcesChanged)synchronized(SOURCE_LOCK){generation++;LibrarySnapshot.forgetResident();}
        Intent intent=new Intent(context,LibraryScanService.class).putExtra("rebuild",rebuild).putExtra("restore",restore).putExtra("sources_changed",sourcesChanged);
        context.startForegroundService(intent);
    }
    private static void publish(State value){state=value;for(Listener listener:LISTENERS)listener.changed(value);}
    @Override public void onCreate(){
        super.onCreate();AppStorage.mirrorPreferences(this);notifications=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        NotificationChannel channel=new NotificationChannel(CHANNEL,"音乐库扫描",NotificationManager.IMPORTANCE_LOW);channel.setDescription("扫描歌曲、匹配歌词和缓存封面的进度与结果");notifications.createNotificationChannel(channel);
        wakeLock=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"MiniVoice:libraryScan");wakeLock.setReferenceCounted(false);
    }
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        Notification initial=notification(state.running?state:new State(true,0,0,"准备音乐库","正在准备扫描…",null,state.songs,state.revision),true);
        startForeground(ONGOING,initial,ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        boolean rebuild=intent!=null&&intent.getBooleanExtra("rebuild",false),restore=intent!=null&&intent.getBooleanExtra("restore",false),sources=intent!=null&&intent.getBooleanExtra("sources_changed",false);
        android.content.SharedPreferences prefs=getSharedPreferences("library",MODE_PRIVATE);
        if((flags&START_FLAG_REDELIVERY)!=0||(!state.running&&prefs.getBoolean("scan_in_progress",false))){rebuild|=prefs.getBoolean("scan_requested_rebuild",false);restore=false;}
        ScanRequestQueue.Request next=requests.offer(rebuild,restore,sources);
        if(next!=null)start(next);
        else if(rebuild)prefs.edit().putBoolean("scan_requested_rebuild",true).apply();
        return START_REDELIVER_INTENT;
    }
    private boolean inFolders(Song song,Set<String> folders){for(String value:folders)try{android.net.Uri tree=android.net.Uri.parse(value);if(!java.util.Objects.equals(tree.getAuthority(),song.uri.getAuthority()))continue;String parent=android.provider.DocumentsContract.getTreeDocumentId(tree),child=android.provider.DocumentsContract.getDocumentId(song.uri);if(android.provider.DocumentsContract.isTreeUri(song.uri)&&parent.equals(android.provider.DocumentsContract.getTreeDocumentId(song.uri)))return true;if(child.equals(parent)||child.startsWith(parent+"/"))return true;}catch(Exception ignored){}return false;}
    private String source(Set<String> folders,boolean recursive){return "folders\n"+LibrarySnapshot.source(folders,recursive);}
    private String currentSource(){android.content.SharedPreferences prefs=getSharedPreferences("library",MODE_PRIVATE);return source(prefs.getStringSet("music_folders",Collections.emptySet()),prefs.getBoolean("scan_recursive",true));}
    private void start(ScanRequestQueue.Request request){
        final int token=generation;final android.content.SharedPreferences prefs=getSharedPreferences("library",MODE_PRIVATE);
        final Set<String> folders=new HashSet<>(prefs.getStringSet("music_folders",Collections.emptySet()));final boolean recursive=prefs.getBoolean("scan_recursive",true);final String source=source(folders,recursive);
        String initial=request.restore?"正在恢复音乐库缓存":"正在查找音乐文件";
        publish(new State(true,0,0,request.restore?"恢复音乐库":"查找音乐文件",initial,null,state.songs,state.revision));updateNotification(true);
        prefs.edit().putBoolean("scan_in_progress",true).putBoolean("scan_requested_rebuild",request.rebuild).apply();
        wakeLock.acquire(10*60*1000L);wakeRenewedAt=SystemClock.elapsedRealtime();
        worker.execute(()->{
            final long[] lastProgress={0};
            ScanProgress progress=(completed,total,detail)->{
                if(destroyed||Thread.currentThread().isInterrupted()||token!=generation)throw new CancellationException();
                if(SystemClock.elapsedRealtime()-wakeRenewedAt>5*60*1000L){wakeLock.acquire(10*60*1000L);wakeRenewedAt=SystemClock.elapsedRealtime();}
                long now=SystemClock.uptimeMillis();if(!(total>0&&completed==total)&&now-lastProgress[0]<100)return;lastProgress[0]=now;
                MAIN.post(()->{if(destroyed||token!=generation)return;State previous=state;publish(new State(true,completed,total,ScanStatusText.stage(previous.stage,detail),detail,null,previous.songs,previous.revision));updateNotification(total>0&&completed==total);});
            };
            List<Song> found=null;String error=null;boolean cancelled=false,cached=false;
            try{
                LibraryCache.migrateLegacy(this);
                if(request.rebuild){progress.update(0,0,"清理旧缓存…");synchronized(SOURCE_LOCK){LibrarySnapshot.invalidate(this);}ArtworkCache.clear();LibraryCache.clear(this);clearFiles(getCacheDir());clearFiles(AppStorage.temporary(this));}
                found=request.restore&&!request.rebuild?LibrarySnapshot.read(this,source):null;cached=found!=null;
                if(found==null){List<Song> previous=request.rebuild?null:LibrarySnapshot.read(this,source);boolean sameScope=previous!=null;if(previous==null&&!request.rebuild)previous=LibrarySnapshot.readAny(this);if(previous!=null)previous.removeIf(song->!inFolders(song,folders));found=folders.isEmpty()?new ArrayList<>():FolderLibrary.scan(this,folders,recursive,progress,previous==null?Collections.emptyList():previous,sameScope);}
                stampDates(found,prefs);LyricsRepository.prepare(this,found,progress);ArtworkCache.prepare(this,found,progress);
                synchronized(SOURCE_LOCK){
                    if(token!=generation||!source.equals(currentSource())||destroyed)throw new CancellationException();
                    // Persist even restored indexes, so repaired metadata/lyrics survive process death.
                    LibrarySnapshot.write(this,source,found);ArtworkCache.prune(this,found);LyricsRepository.prune(this,found);
                }
            }catch(CancellationException failure){cancelled=true;}
            catch(Exception|OutOfMemoryError failure){error="扫描失败，请检查音乐目录权限和可用空间后重试";android.util.Log.w("MiniVoice","音乐库扫描失败",failure);Diagnostics.failure("scan failed",failure);}
            final List<Song> result=found;final String failure=error;final boolean stale=cancelled,restored=cached;
            MAIN.post(()->finish(token,request,result,failure,stale,restored));
        });
    }
    private void finish(int token,ScanRequestQueue.Request request,List<Song> found,String error,boolean cancelled,boolean restored){
        if(destroyed)return;if(wakeLock.isHeld())wakeLock.release();
        ScanRequestQueue.Request next=requests.complete();
        boolean stale=cancelled||token!=generation;
        if(!stale){
            List<Song> songs=error==null&&found!=null?Collections.unmodifiableList(new ArrayList<>(found)):state.songs;
            String detail=error==null?"已完成，共 "+(songs==null?0:songs.size())+" 首歌曲":error;
            publish(new State(next!=null,0,0,error==null?"音乐库扫描完成":"音乐库扫描失败",detail,error,songs,state.revision+1));
        }
        if(next!=null){start(next);return;}
        if(stale)publish(new State(false,0,0,"扫描已更新","",null,state.songs,state.revision));
        if(!stale)clearJournal();
        stopForeground(STOP_FOREGROUND_REMOVE);
        if(!stale&&(!request.restore||!restored||error!=null))notifications.notify(RESULT,notification(state,false));
        stopSelf();
    }
    private PendingIntent openIntent(){return PendingIntent.getActivity(this,2,getPackageManager().getLaunchIntentForPackage(getPackageName()).setAction(MainActivity.ACTION_SHOW_SCAN).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
    private Notification notification(State value,boolean ongoing){
        String title=value.stage+(ongoing&&value.total>0?" · "+ScanStatusText.percent(value.completed,value.total)+"%":"");
        String detail=value.detail+(ongoing&&value.total>0?"\n已处理 "+value.completed+" / "+value.total+" 首":"");
        Notification.Builder builder=new Notification.Builder(this,CHANNEL).setSmallIcon(R.drawable.ic_scan_notification).setContentTitle(title).setContentText(detail).setStyle(new Notification.BigTextStyle().bigText(detail)).setContentIntent(openIntent()).setOnlyAlertOnce(true).setOngoing(ongoing).setAutoCancel(!ongoing).setCategory(ongoing?Notification.CATEGORY_PROGRESS:Notification.CATEGORY_STATUS);
        if(ongoing){builder.setSubText(value.total>0?value.completed+" / "+value.total+" 首":"音乐库扫描");builder.setProgress(Math.max(0,value.total),Math.max(0,value.completed),value.total<=0);}
        else builder.setTimeoutAfter(60*60*1000L);
        return builder.build();
    }
    private void updateNotification(boolean force){long now=SystemClock.uptimeMillis();if(force||now-lastNotification>=500){lastNotification=now;notifications.notify(ONGOING,notification(state,true));}}
    private void stampDates(List<Song> songs,android.content.SharedPreferences prefs){android.content.SharedPreferences.Editor edit=prefs.edit();long now=System.currentTimeMillis();for(Song song:songs){String key="first_seen_"+LibraryCache.key(song.uri.toString());if(song.sourceAdded<=0)song.sourceAdded=prefs.getLong(key,now);edit.putLong(key,song.sourceAdded);if(song.updated<=0)try{long time=Long.parseLong(song.artworkVersion.split(":")[0]);song.updated=time>0&&time<100000000000L?time*1000:time;}catch(Exception ignored){}}edit.apply();}
    private void clearFiles(File folder){File[] files=folder.listFiles();if(files==null)return;for(File file:files){if(file.isDirectory())clearFiles(file);file.delete();}}
    private void clearJournal(){getSharedPreferences("library",MODE_PRIVATE).edit().putBoolean("scan_in_progress",false).putBoolean("scan_requested_rebuild",false).apply();}
    @Override public void onTimeout(int startId,int type){destroyed=true;worker.shutdownNow();clearJournal();publish(new State(false,0,0,"扫描已中断","系统暂停了长时间扫描，请重新扫描以继续", "系统暂停了长时间扫描，请重新扫描以继续",state.songs,state.revision+1));stopForeground(STOP_FOREGROUND_REMOVE);notifications.notify(RESULT,notification(state,false));stopSelf();}
    @Override public void onDestroy(){destroyed=true;worker.shutdownNow();if(wakeLock!=null&&wakeLock.isHeld())wakeLock.release();if(state.running)publish(new State(false,0,0,"扫描已中断","重新打开应用后将继续扫描",null,state.songs,state.revision));super.onDestroy();}
}
