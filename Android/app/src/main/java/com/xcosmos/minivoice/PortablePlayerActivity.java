package com.xcosmos.minivoice;

import android.app.Activity;
import android.content.*;
import android.os.*;
import android.webkit.*;
import android.net.Uri;
import org.json.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

/** Thin local-content host. Rendering and page behavior live in Shared/UI. */
public final class PortablePlayerActivity extends Activity {
    private static final String ORIGIN="https://minivoice.local";
    private WebView web;
    private PlaybackService playback;
    private boolean bound,wallChrome,immersiveChrome;
    private JSONObject lastWorkspace;
    private String appliedChrome;
    private String navigationAction="",nativeNotice="";private long navigationToken,noticeToken;
    private volatile boolean closed;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    // Raster encoding must not block workspace writes, lyrics or playback requests.
    private final ExecutorService rasterWorker=Executors.newSingleThreadExecutor();
    private volatile List<Song> songs=Collections.emptyList();
    private volatile JSONArray rows=new JSONArray();
    private volatile long catalogRevision;
    private volatile boolean scanning;
    private volatile String scanDetail="";
    private long scanRevision=Long.MIN_VALUE;
    private final LibraryScanService.Listener scanObserver=state->{scanning=state.running;scanDetail=state.detail;if(!state.running&&state.revision!=scanRevision){scanRevision=state.revision;if(!closed)try{worker.execute(()->{try{readLibrary();}catch(Exception ignored){}});}catch(RejectedExecutionException ignored){}}};
    private final ServiceConnection connection=new ServiceConnection(){
        public void onServiceConnected(ComponentName name,IBinder binder){playback=((PlaybackService.LocalBinder)binder).get();}
        public void onServiceDisconnected(ComponentName name){playback=null;}
    };
    @Override public void onCreate(Bundle state){super.onCreate(state);
        web=new WebView(this);setContentView(web);applyChrome(null);
        web.setOnApplyWindowInsetsListener((view,insets)->{publishInsets(insets);return insets;});
        WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        web.setWebViewClient(new WebViewClient(){
            @Override public void onPageFinished(WebView view,String url){view.requestApplyInsets();publishInsets(view.getRootWindowInsets());}
            @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){return true;}
            @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){
                Uri uri=request.getUrl();String path=uri.getPath();
                if("https".equals(uri.getScheme())&&"minivoice.local".equals(uri.getHost())&&path!=null&&path.matches("/art/-?[0-9]+")&&"GET".equals(request.getMethod())){for(Song song:songs)if(Long.toString(song.id).equals(path.substring(5)))try{if("original".equals(uri.getQueryParameter("quality"))){byte[] original=Artwork.original(PortablePlayerActivity.this,song);if(original==null)return denied();android.graphics.BitmapFactory.Options info=new android.graphics.BitmapFactory.Options();info.inJustDecodeBounds=true;android.graphics.BitmapFactory.decodeByteArray(original,0,original.length,info);return new WebResourceResponse(info.outMimeType==null?"image/jpeg":info.outMimeType,null,new ByteArrayInputStream(original));}android.graphics.Bitmap bitmap=ArtworkCache.load(PortablePlayerActivity.this,song,512);if(bitmap==null)return denied();ByteArrayOutputStream bytes=new ByteArrayOutputStream();bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,88,bytes);return new WebResourceResponse("image/jpeg",null,new ByteArrayInputStream(bytes.toByteArray()));}catch(Exception ignored){return denied();}return denied();}
                if(!"https".equals(uri.getScheme())||!"minivoice.local".equals(uri.getHost())||path==null||!"GET".equals(request.getMethod())||path.contains("..")||!(path.equals("/index.html")||path.startsWith("/assets/")))return denied();
                try{String mime=path.endsWith(".js")?"application/javascript":path.endsWith(".css")?"text/css":path.endsWith(".png")?"image/png":"text/html";
                    return new WebResourceResponse(mime,"UTF-8",200,"OK",Collections.singletonMap("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-src 'none'"),getAssets().open(path.substring(1)));
                }catch(IOException ignored){return denied();}
            }
        });
        web.addJavascriptInterface(new Host(),"MiniVoiceHost");
        bound=bindService(new Intent(this,PlaybackService.class),connection,BIND_AUTO_CREATE);
        worker.execute(()->{try{readLibrary();main.post(()->{if(!closed)web.loadUrl(ORIGIN+"/index.html");});}catch(Exception failure){main.post(()->{if(!closed)finish();});}});
        LibraryScanService.observe(scanObserver);acceptNavigation(getIntent());if(!getIntent().getBooleanExtra("minivoice.uiRegression",false))LibraryScanService.request(this,false,true,false);
    }
    private void acceptNavigation(Intent intent){String action=intent.getAction();if(MainActivity.ACTION_LOCATE_PLAYING.equals(action)||MainActivity.ACTION_SHOW_SCAN.equals(action)){navigationAction=action;navigationToken++;}}
    @Override protected void onNewIntent(Intent intent){super.onNewIntent(intent);setIntent(intent);acceptNavigation(intent);}
    private void notice(String message){nativeNotice=message;noticeToken++;}
    private void readLibrary()throws Exception{
        SharedPreferences prefs=getSharedPreferences("library",MODE_PRIVATE);List<Song> cached=LibrarySnapshot.read(this,"folders\n"+LibrarySnapshot.source(prefs.getStringSet("music_folders",Collections.emptySet()),prefs.getBoolean("scan_recursive",true)));
        List<Song> next=cached;if(next==null){next=new ArrayList<>();Set<String> selected=prefs.getStringSet("music_folders",Collections.emptySet());for(Song song:songs)if(authorized(song,selected))next.add(song);}Map<String,String> aliases=PortableSettingsTools.aliases(getSharedPreferences("library",0));Map<String,String> canonical=new HashMap<>();JSONArray nextRows=new JSONArray();for(Song song:next)nextRows.put(new JSONObject().put("id",Long.toString(song.id)).put("title",song.title).put("artist",canonical.computeIfAbsent(song.artist,value->ArtistNames.canonical(value,aliases))).put("album",song.album).put("duration",song.duration).put("sourceAdded",song.sourceAdded).put("added",song.updated).put("path",song.path).put("size",song.fileSize).put("artwork",ORIGIN+"/art/"+song.id+"?v="+Uri.encode(song.artworkVersion)).put("artworkDetail",ORIGIN+"/art/"+song.id+"?quality=original&v="+Uri.encode(song.artworkVersion)));songs=next;if(!nextRows.toString().equals(rows.toString())){rows=nextRows;catalogRevision++;List<Song> allowed=new ArrayList<>(next);main.post(()->{if(!closed&&playback!=null)playback.retainLibrary(allowed);});}
    }
    private static boolean authorized(Song song,Set<String> folders){for(String value:folders)try{Uri tree=Uri.parse(value);if(!Objects.equals(tree.getAuthority(),song.uri.getAuthority()))continue;String parent=android.provider.DocumentsContract.getTreeDocumentId(tree),child=android.provider.DocumentsContract.getDocumentId(song.uri);if(android.provider.DocumentsContract.isTreeUri(song.uri)&&parent.equals(android.provider.DocumentsContract.getTreeDocumentId(song.uri)))return true;if(child.equals(parent)||child.startsWith(parent+"/"))return true;}catch(Exception ignored){}return false;}
    @Override protected void onResume(){super.onResume();if(!closed)try{worker.execute(()->{try{readLibrary();}catch(Exception ignored){}});}catch(RejectedExecutionException ignored){}}
    private static WebResourceResponse denied(){return new WebResourceResponse("text/plain","UTF-8",403,"Forbidden",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
    private long lastHaptic;
    private final class Host {
        @JavascriptInterface public void haptic(){main.post(()->{
            if(closed||web==null||!web.hasWindowFocus())return;
            long now=SystemClock.uptimeMillis();if(now-lastHaptic<45)return;lastHaptic=now;
            // View feedback respects the user's system touch-feedback setting.
            web.performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK);
        });}

        @JavascriptInterface public void request(String id,String raw){
            if(closed||id==null||!id.matches("[0-9]{1,12}")||raw==null||raw.length()>4*1024*1024)return;
            try{worker.execute(()->{try{JSONObject request=new JSONObject(raw);if(request.optInt("version")!=1)throw new IllegalArgumentException("不支持的协议版本");String kind=request.getString("kind");
                switch(kind){
                    case "captureStyle":main.post(()->captureStyle(id));return;
                    case "core":JSONObject result=new JSONObject(SharedCore.execute(request.getJSONObject("request").toString()));if(!result.optBoolean("ok"))throw new IllegalArgumentException(result.optString("error"));reply(id,result.opt("value"),null);return;
                    case "readState":JSONObject saved=new JSONObject(getSharedPreferences("portable",0).getString("workspace","{\"version\":1,\"pages\":{}}"));main.post(()->applyChrome(saved));reply(id,saved,null);return;
                    case "writeState":JSONObject value=request.getJSONObject("state");if(value.optInt("version")!=1)throw new IllegalArgumentException("无效的页面状态");if(!getSharedPreferences("portable",0).edit().putString("workspace",value.toString()).commit())throw new IOException("页面状态保存失败");main.post(()->applyChrome(value));reply(id,true,null);return;
                    case "action":String action=request.getString("name");if(PortableMetadataActions.handles(action)){reply(id,metadataAction(action,request.getJSONObject("payload")),null);return;}if(PortableLibraryActions.handles(action)){Object actionResult=PortableLibraryActions.execute(PortablePlayerActivity.this,songs,action,request.optJSONObject("payload")==null?new JSONObject():request.getJSONObject("payload"));if(action.equals("removeFolder")||action.equals("recursive")||action.equals("artistAlias")||action.equals("clearArtistAliases")){readLibrary();List<Song> allowed=new ArrayList<>(songs);main.post(()->{if(!closed&&playback!=null)playback.retainLibrary(allowed);});}reply(id,actionResult,null);}else main.post(()->playbackRequest(id,kind,request));return;
                    case "snapshot":case "play":case "toggle":case "seek":case "skip":case "exit":main.post(()->playbackRequest(id,kind,request));return;
                    default:throw new IllegalArgumentException("不支持的系统操作");
                }
            }catch(Exception failure){reply(id,null,failure.getMessage());}});}catch(RejectedExecutionException ignored){}
        }
    }
    // Copies only this Activity's WebView surface; no display capture permission.
    private void captureStyle(String id){
        if(closed||web==null||web.getWidth()<1||web.getHeight()<1){reply(id,null,"页面尚未就绪");return;}
        final android.graphics.Bitmap bitmap;
        try{
            int width=web.getWidth(),height=web.getHeight();float scale=Math.min(1f,Math.min(2560f/Math.max(width,height),(float)Math.sqrt(3000000d/(width*(double)height))));
            bitmap=android.graphics.Bitmap.createBitmap(Math.max(1,Math.round(width*scale)),Math.max(1,Math.round(height*scale)),android.graphics.Bitmap.Config.ARGB_8888);
            int[] location=new int[2];web.getLocationInWindow(location);
            android.graphics.Rect rect=new android.graphics.Rect(location[0],location[1],location[0]+width,location[1]+height);
            android.view.PixelCopy.request(getWindow(),rect,bitmap,result->{
                if(result!=android.view.PixelCopy.SUCCESS||closed){bitmap.recycle();reply(id,null,"页面画面暂不可用");return;}
                try{rasterWorker.execute(()->{try{ByteArrayOutputStream bytes=new ByteArrayOutputStream();bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,95,bytes);reply(id,"data:image/jpeg;base64,"+android.util.Base64.encodeToString(bytes.toByteArray(),android.util.Base64.NO_WRAP),null);}catch(Exception error){reply(id,null,error.getMessage());}finally{bitmap.recycle();}});}catch(RejectedExecutionException ignored){bitmap.recycle();}
            },main);
        }catch(Exception error){reply(id,null,error.getMessage());}
    }
    private Object metadataAction(String action,JSONObject payload)throws Exception{
        if(action.equals("metadataDetail"))return PortableMetadataActions.execute(this,songs,action,payload);
        long id=PortableMetadataActions.editingSong(this,songs,action,payload).id;FutureTask<PlaybackService> task=new FutureTask<>(()->{if(playback==null)throw new IllegalStateException("播放器尚未连接");playback.beginFileEdit(id);return playback;});main.post(task);PlaybackService editing=task.get();
        boolean success=false;try{Object value=PortableMetadataActions.execute(this,songs,action,payload);success=true;return value;}finally{boolean scan=success;main.post(()->{editing.endFileEdit();if(scan)LibraryScanService.request(this,false,false,true);});}
    }
    private void playbackRequest(String id,String kind,JSONObject request){if(closed)return;try{
        if(kind.equals("exit")){reply(id,true,null);finish();return;}
        if(playback==null){if(kind.equals("snapshot")){reply(id,new JSONObject().put("songs",rows).put("position",0).put("playing",false),null);return;}throw new IllegalStateException("播放器尚未准备好");}
        switch(kind){
            case "action":hostAction(request);reply(id,true,null);return;
            case "snapshot":Song current=playback.current();SharedPreferences lyricPrefs=getSharedPreferences("library",0);String raw=current==null?"":lyricPrefs.getBoolean("lyrics_override_"+current.id,false)?lyricPrefs.getString("lyrics_"+current.id,""):LyricsRepository.select(current,lyricPrefs.getString("lyrics_"+current.id,""));SharedPreferences prefs=getSharedPreferences("library",0);JSONArray recent=new JSONArray(),queue=new JSONArray(),playlists=new JSONArray();List<String> recentIds=new ArrayList<>(prefs.getStringSet("recent",Collections.emptySet()));recentIds.sort((a,b)->Long.compare(prefs.getLong("recent_time_"+b,0),prefs.getLong("recent_time_"+a,0)));for(String value:recentIds)recent.put(value);for(Song song:playback.queue)queue.put(Long.toString(song.id));for(String name:new TreeSet<>(prefs.getStringSet("playlists",Collections.emptySet())))playlists.put(new JSONObject().put("id",name).put("name",name).put("ids",new JSONArray(prefs.getStringSet("playlist_"+name,Collections.emptySet()))));reply(id,new JSONObject().put("songs",Long.toString(catalogRevision).equals(request.optString("catalogRevision"))?JSONObject.NULL:rows).put("catalogRevision",Long.toString(catalogRevision)).put("scanning",scanning).put("scanDetail",scanDetail).put("style",AppAppearance.style(prefs)).put("theme",AppAppearance.theme(prefs)).put("favorites",new JSONArray(prefs.getStringSet("favorites",Collections.emptySet()))).put("recent",recent).put("playlists",playlists).put("queue",queue).put("mode",playback.mode).put("current",current==null?JSONObject.NULL:Long.toString(current.id)).put("position",playback.position()).put("playing",playback.isPlaying()).put("rawLyrics",raw).put("navigationAction",navigationAction).put("navigationToken",navigationToken).put("playbackError",playback.playbackError).put("playbackErrorToken",playback.playbackErrorToken).put("nativeNotice",nativeNotice).put("noticeToken",noticeToken).put("capabilities",new JSONArray(Arrays.asList("favorite","mode","queueSelect","createPlaylist","addToPlaylist","settings"))),null);return;
            case "play":int index=-1;String selected=request.getString("id");for(int i=0;i<songs.size();i++)if(Long.toString(songs.get(i).id).equals(selected)){index=i;break;}if(index<0)throw new IllegalArgumentException("歌曲不在已授权音乐库中");List<Song> selectedQueue=songs;JSONArray ids=request.optJSONArray("ids");if(ids!=null){Map<String,Song> allowed=new HashMap<>();for(Song song:songs)allowed.put(Long.toString(song.id),song);List<Song> ordered=new ArrayList<>();Set<String> added=new HashSet<>();for(int i=0;i<ids.length();i++){String value=ids.getString(i);Song song=allowed.get(value);if(song==null)throw new IllegalArgumentException("播放列表包含未授权歌曲");if(added.add(value))ordered.add(song);}index=-1;for(int i=0;i<ordered.size();i++)if(Long.toString(ordered.get(i).id).equals(selected)){index=i;break;}if(index<0)throw new IllegalArgumentException("歌曲不在当前列表中");selectedQueue=ordered;}startService(new Intent(this,PlaybackService.class));playback.setQueue(selectedQueue,index);SharedPreferences recentPrefs=getSharedPreferences("library",0);Set<String> recentSongs=new HashSet<>(recentPrefs.getStringSet("recent",Collections.emptySet()));recentSongs.add(selected);recentPrefs.edit().putStringSet("recent",recentSongs).putLong("recent_time_"+selected,System.currentTimeMillis()).apply();break;
            case "toggle":playback.toggle();break;
            case "seek":playback.seek((int)Math.min(Integer.MAX_VALUE,Math.max(0,request.getLong("position"))));break;
            case "skip":if(request.getInt("delta")<0)playback.previous();else playback.next(true);break;
        }reply(id,true,null);
    }catch(Exception failure){reply(id,null,failure.getMessage());}}
    private void applyChrome(JSONObject workspace){
        if(workspace!=null)lastWorkspace=workspace;
        SharedPreferences prefs=getSharedPreferences("library",0);JSONObject pages=lastWorkspace==null?null:lastWorkspace.optJSONObject("pages"),appearance=pages==null?null:pages.optJSONObject("appearance");String theme=appearance==null?AppAppearance.theme(prefs):appearance.optString("theme",AppAppearance.theme(prefs));String style=appearance==null?AppAppearance.style(prefs):appearance.optString("style",AppAppearance.style(prefs));boolean dark=AppAppearance.darkValue(theme,(getResources().getConfiguration().uiMode&android.content.res.Configuration.UI_MODE_NIGHT_MASK)==android.content.res.Configuration.UI_MODE_NIGHT_YES);wallChrome=style.equals("wall");if(!wallChrome)immersiveChrome=false;
        String chromeKey=style+":"+dark+":"+immersiveChrome+":"+getResources().getConfiguration().orientation;if(chromeKey.equals(appliedChrome))return;appliedChrome=chromeKey;
        int color=wallChrome?(dark?0xFF10241A:0xFFDCEADE):(dark?0xFF182720:0xFFEAF0EE);android.view.Window window=getWindow();window.addFlags(android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.setStatusBarColor(android.graphics.Color.TRANSPARENT);window.setNavigationBarColor(android.graphics.Color.TRANSPARENT);if(Build.VERSION.SDK_INT>=29)window.setNavigationBarContrastEnforced(!wallChrome);

        int flags=android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE|android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
        if(!dark)flags|=android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        if(wallChrome&&immersiveChrome)flags|=android.view.View.SYSTEM_UI_FLAG_FULLSCREEN|android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
        window.getDecorView().setSystemUiVisibility(flags);if(Build.VERSION.SDK_INT>=30&&window.getInsetsController()!=null){android.view.WindowInsetsController control=window.getInsetsController();control.setSystemBarsBehavior(android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);if(wallChrome&&immersiveChrome)control.hide(android.view.WindowInsets.Type.systemBars());else control.show(android.view.WindowInsets.Type.systemBars());}
        android.view.WindowManager.LayoutParams attributes=window.getAttributes();attributes.layoutInDisplayCutoutMode=wallChrome?android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES:android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;window.setAttributes(attributes);
        if(Build.VERSION.SDK_INT>=30)window.setDecorFitsSystemWindows(false);
        android.view.View content=window.findViewById(android.R.id.content);if(content!=null){content.setFitsSystemWindows(false);content.setPadding(0,0,0,0);content.requestLayout();}web.setFitsSystemWindows(false);
        web.setBackgroundColor(color);web.requestApplyInsets();web.postInvalidateOnAnimation();publishInsets(web.getRootWindowInsets());
    }
    private void publishInsets(android.view.WindowInsets insets){
        if(web==null||closed)return;int left=0,top=0,right=0,bottom=0;if(insets!=null){if(Build.VERSION.SDK_INT>=30){android.graphics.Insets safe=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.displayCutout());left=safe.left;top=safe.top;right=safe.right;bottom=safe.bottom;}else{left=insets.getSystemWindowInsetLeft();top=insets.getSystemWindowInsetTop();right=insets.getSystemWindowInsetRight();bottom=Math.min(insets.getSystemWindowInsetBottom(),insets.getStableInsetBottom());}}
        float d=getResources().getDisplayMetrics().density;String script="(()=>{const s=document.documentElement.style;s.setProperty('--mv-safe-left','"+(left/d)+"px');s.setProperty('--mv-safe-top','"+(top/d)+"px');s.setProperty('--mv-safe-right','"+(right/d)+"px');s.setProperty('--mv-safe-bottom','"+(bottom/d)+"px');window.dispatchEvent(new Event('minivoice-insets'));})()";web.evaluateJavascript(script,null);
    }
    @Override public void onConfigurationChanged(android.content.res.Configuration value){super.onConfigurationChanged(value);applyChrome(lastWorkspace);}
    private void hostAction(JSONObject request)throws Exception{
        String name=request.getString("name");JSONObject payload=request.optJSONObject("payload");if(payload==null)payload=new JSONObject();SharedPreferences prefs=getSharedPreferences("library",0);
        switch(name){
            case "immersive":immersiveChrome=payload.optBoolean("value")&&wallChrome;applyChrome(lastWorkspace);return;
            case "chooseFolder":startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION),81);return;
            case "exportDiagnostics":startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/zip").addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,"MiniVoice-diagnostics.zip"),82);return;
            case "settings":navigationAction=MainActivity.ACTION_SHOW_SCAN;navigationToken++;return;
            case "ackNavigation":if(payload.optLong("token")==navigationToken)navigationAction="";return;
            case "mode":playback.setMode(payload.getInt("value"));return;
            case "queueSelect":String id=payload.getString("id");for(int i=0;i<playback.queue.size();i++)if(Long.toString(playback.queue.get(i).id).equals(id)){playback.select(i);return;}throw new IllegalArgumentException("歌曲不在播放队列中");
            default:throw new IllegalArgumentException("此平台暂不支持该操作");
        }
    }
    private void reply(String id,Object value,String error){try{JSONObject envelope=new JSONObject().put("ok",error==null);if(error==null)envelope.put("value",value==null?JSONObject.NULL:value);else envelope.put("error",error);String script="globalThis.MiniVoiceTransport?.receive("+JSONObject.quote(id)+","+envelope+")";main.post(()->{if(!closed)web.evaluateJavascript(script,null);});}catch(JSONException ignored){}}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;Uri uri=data.getData();if(request==81){try{getContentResolver().takePersistableUriPermission(uri,data.getFlags()&(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION));SharedPreferences prefs=getSharedPreferences("library",0);Set<String> folders=new HashSet<>(prefs.getStringSet("music_folders",Collections.emptySet()));folders.add(uri.toString());prefs.edit().putStringSet("music_folders",folders).putBoolean("folder_library",true).commit();LibraryScanService.request(this,false,false,true);}catch(Exception failure){notice("无法授权文件夹，请重新选择并允许读写权限");}}else if(request==82)worker.execute(()->{String message="诊断报告已导出";try(java.io.OutputStream out=getContentResolver().openOutputStream(uri,"wt")){if(out==null)throw new IOException();Diagnostics.export(this,out);}catch(Exception failure){message="导出失败，请重试";}String status=message;main.post(()->{if(!closed)notice(status);});});}
    @Override public void onBackPressed(){if(web!=null&&web.getProgress()==100)web.evaluateJavascript("globalThis.dispatchEvent(new Event('minivoice-back'))",null);else super.onBackPressed();}
    @Override public void onDestroy(){closed=true;LibraryScanService.remove(scanObserver);if(bound)unbindService(connection);worker.shutdownNow();rasterWorker.shutdownNow();if(web!=null){web.removeJavascriptInterface("MiniVoiceHost");web.destroy();}super.onDestroy();}
}
