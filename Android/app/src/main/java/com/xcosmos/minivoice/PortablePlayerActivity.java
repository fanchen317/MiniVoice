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
    private boolean bound;
    private volatile boolean closed;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
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
        WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){return true;}
            @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){
                Uri uri=request.getUrl();String path=uri.getPath();
                if("https".equals(uri.getScheme())&&"minivoice.local".equals(uri.getHost())&&path!=null&&path.matches("/art/-?[0-9]+")&&"GET".equals(request.getMethod())){for(Song song:songs)if(Long.toString(song.id).equals(path.substring(5)))try{android.graphics.Bitmap bitmap=ArtworkCache.load(PortablePlayerActivity.this,song,512);if(bitmap==null)return denied();ByteArrayOutputStream bytes=new ByteArrayOutputStream();bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,88,bytes);return new WebResourceResponse("image/jpeg",null,new ByteArrayInputStream(bytes.toByteArray()));}catch(Exception ignored){return denied();}return denied();}
                if(!"https".equals(uri.getScheme())||!"minivoice.local".equals(uri.getHost())||path==null||!"GET".equals(request.getMethod())||path.contains("..")||!(path.equals("/index.html")||path.startsWith("/assets/")))return denied();
                try{String mime=path.endsWith(".js")?"application/javascript":path.endsWith(".css")?"text/css":path.endsWith(".png")?"image/png":"text/html";
                    return new WebResourceResponse(mime,"UTF-8",200,"OK",Collections.singletonMap("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-src 'none'"),getAssets().open(path.substring(1)));
                }catch(IOException ignored){return denied();}
            }
        });
        web.addJavascriptInterface(new Host(),"MiniVoiceHost");
        bound=bindService(new Intent(this,PlaybackService.class),connection,BIND_AUTO_CREATE);
        worker.execute(()->{try{readLibrary();main.post(()->{if(!closed)web.loadUrl(ORIGIN+"/index.html");});}catch(Exception failure){main.post(()->{if(!closed)finish();});}});
        LibraryScanService.observe(scanObserver);
    }
    private void readLibrary()throws Exception{
        SharedPreferences prefs=getSharedPreferences("library",MODE_PRIVATE);List<Song> cached=LibrarySnapshot.read(this,"folders\n"+LibrarySnapshot.source(prefs.getStringSet("music_folders",Collections.emptySet()),prefs.getBoolean("scan_recursive",true)));
        List<Song> next=cached;if(next==null){next=new ArrayList<>();Set<String> selected=prefs.getStringSet("music_folders",Collections.emptySet());for(Song song:songs)if(authorized(song,selected))next.add(song);}JSONArray nextRows=new JSONArray();for(Song song:next)nextRows.put(new JSONObject().put("id",Long.toString(song.id)).put("title",song.title).put("artist",song.artist).put("album",song.album).put("duration",song.duration).put("path",song.path).put("size",song.fileSize).put("artwork",ORIGIN+"/art/"+song.id+"?v="+Uri.encode(song.artworkVersion)));songs=next;if(!nextRows.toString().equals(rows.toString())){rows=nextRows;catalogRevision++;}
    }
    private static boolean authorized(Song song,Set<String> folders){for(String value:folders)try{Uri tree=Uri.parse(value);if(!Objects.equals(tree.getAuthority(),song.uri.getAuthority()))continue;String parent=android.provider.DocumentsContract.getTreeDocumentId(tree),child=android.provider.DocumentsContract.getDocumentId(song.uri);if(android.provider.DocumentsContract.isTreeUri(song.uri)&&parent.equals(android.provider.DocumentsContract.getTreeDocumentId(song.uri)))return true;if(child.equals(parent)||child.startsWith(parent+"/"))return true;}catch(Exception ignored){}return false;}
    @Override protected void onResume(){super.onResume();if(!closed)try{worker.execute(()->{try{readLibrary();}catch(Exception ignored){}});}catch(RejectedExecutionException ignored){}}
    private static WebResourceResponse denied(){return new WebResourceResponse("text/plain","UTF-8",403,"Forbidden",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
    private final class Host {
        @JavascriptInterface public void request(String id,String raw){
            if(closed||id==null||!id.matches("[0-9]{1,12}")||raw==null||raw.length()>4*1024*1024)return;
            try{worker.execute(()->{try{JSONObject request=new JSONObject(raw);if(request.optInt("version")!=1)throw new IllegalArgumentException("不支持的协议版本");String kind=request.getString("kind");
                switch(kind){
                    case "core":JSONObject result=new JSONObject(SharedCore.execute(request.getJSONObject("request").toString()));if(!result.optBoolean("ok"))throw new IllegalArgumentException(result.optString("error"));reply(id,result.opt("value"),null);return;
                    case "readState":JSONObject saved=new JSONObject(getSharedPreferences("portable",0).getString("workspace","{\"version\":1,\"pages\":{}}"));main.post(()->applyChrome(saved));reply(id,saved,null);return;
                    case "writeState":JSONObject value=request.getJSONObject("state");if(value.optInt("version")!=1)throw new IllegalArgumentException("无效的页面状态");if(!getSharedPreferences("portable",0).edit().putString("workspace",value.toString()).commit())throw new IOException("页面状态保存失败");main.post(()->applyChrome(value));reply(id,true,null);return;
                    case "action":String action=request.getString("name");if(PortableLibraryActions.handles(action)){Object actionResult=PortableLibraryActions.execute(PortablePlayerActivity.this,songs,action,request.optJSONObject("payload")==null?new JSONObject():request.getJSONObject("payload"));if(action.equals("removeFolder")||action.equals("recursive")){readLibrary();List<Song> allowed=new ArrayList<>(songs);main.post(()->{if(!closed&&playback!=null)playback.retainLibrary(allowed);});}reply(id,actionResult,null);}else main.post(()->playbackRequest(id,kind,request));return;
                    case "snapshot":case "play":case "toggle":case "seek":case "skip":case "exit":main.post(()->playbackRequest(id,kind,request));return;
                    default:throw new IllegalArgumentException("不支持的系统操作");
                }
            }catch(Exception failure){reply(id,null,failure.getMessage());}});}catch(RejectedExecutionException ignored){}
        }
    }
    private void playbackRequest(String id,String kind,JSONObject request){if(closed)return;try{
        if(kind.equals("exit")){reply(id,true,null);finish();return;}
        if(playback==null){if(kind.equals("snapshot")){reply(id,new JSONObject().put("songs",rows).put("position",0).put("playing",false),null);return;}throw new IllegalStateException("播放器尚未准备好");}
        switch(kind){
            case "action":hostAction(request);reply(id,true,null);return;
            case "snapshot":Song current=playback.current();String raw=current==null?"":LyricsRepository.select(current,getSharedPreferences("library",0).getString("lyrics_"+current.id,""));SharedPreferences prefs=getSharedPreferences("library",0);JSONArray recent=new JSONArray(),queue=new JSONArray(),playlists=new JSONArray();List<String> recentIds=new ArrayList<>(prefs.getStringSet("recent",Collections.emptySet()));recentIds.sort((a,b)->Long.compare(prefs.getLong("recent_time_"+b,0),prefs.getLong("recent_time_"+a,0)));for(String value:recentIds)recent.put(value);for(Song song:playback.queue)queue.put(Long.toString(song.id));for(String name:new TreeSet<>(prefs.getStringSet("playlists",Collections.emptySet())))playlists.put(new JSONObject().put("id",name).put("name",name).put("ids",new JSONArray(prefs.getStringSet("playlist_"+name,Collections.emptySet()))));reply(id,new JSONObject().put("songs",Long.toString(catalogRevision).equals(request.optString("catalogRevision"))?JSONObject.NULL:rows).put("catalogRevision",Long.toString(catalogRevision)).put("scanning",scanning).put("scanDetail",scanDetail).put("style",AppAppearance.style(prefs)).put("theme",AppAppearance.theme(prefs)).put("favorites",new JSONArray(prefs.getStringSet("favorites",Collections.emptySet()))).put("recent",recent).put("playlists",playlists).put("queue",queue).put("mode",playback.mode).put("current",current==null?JSONObject.NULL:Long.toString(current.id)).put("position",playback.position()).put("playing",playback.isPlaying()).put("rawLyrics",raw).put("capabilities",new JSONArray(Arrays.asList("favorite","mode","queueSelect","createPlaylist","addToPlaylist","settings"))),null);return;
            case "play":int index=-1;String selected=request.getString("id");for(int i=0;i<songs.size();i++)if(Long.toString(songs.get(i).id).equals(selected)){index=i;break;}if(index<0)throw new IllegalArgumentException("歌曲不在已授权音乐库中");List<Song> selectedQueue=songs;JSONArray ids=request.optJSONArray("ids");if(ids!=null){Map<String,Song> allowed=new HashMap<>();for(Song song:songs)allowed.put(Long.toString(song.id),song);List<Song> ordered=new ArrayList<>();Set<String> added=new HashSet<>();for(int i=0;i<ids.length();i++){String value=ids.getString(i);Song song=allowed.get(value);if(song==null)throw new IllegalArgumentException("播放列表包含未授权歌曲");if(added.add(value))ordered.add(song);}index=-1;for(int i=0;i<ordered.size();i++)if(Long.toString(ordered.get(i).id).equals(selected)){index=i;break;}if(index<0)throw new IllegalArgumentException("歌曲不在当前列表中");selectedQueue=ordered;}startService(new Intent(this,PlaybackService.class));playback.setQueue(selectedQueue,index);SharedPreferences recentPrefs=getSharedPreferences("library",0);Set<String> recentSongs=new HashSet<>(recentPrefs.getStringSet("recent",Collections.emptySet()));recentSongs.add(selected);recentPrefs.edit().putStringSet("recent",recentSongs).putLong("recent_time_"+selected,System.currentTimeMillis()).apply();break;
            case "toggle":playback.toggle();break;
            case "seek":playback.seek((int)Math.min(Integer.MAX_VALUE,Math.max(0,request.getLong("position"))));break;
            case "skip":if(request.getInt("delta")<0)playback.previous();else playback.next(true);break;
        }reply(id,true,null);
    }catch(Exception failure){reply(id,null,failure.getMessage());}}
    private void applyChrome(JSONObject workspace){
        SharedPreferences prefs=getSharedPreferences("library",0);JSONObject pages=workspace==null?null:workspace.optJSONObject("pages"),appearance=pages==null?null:pages.optJSONObject("appearance");String theme=appearance==null?AppAppearance.theme(prefs):appearance.optString("theme",AppAppearance.theme(prefs));String style=appearance==null?AppAppearance.style(prefs):appearance.optString("style",AppAppearance.style(prefs));boolean dark=AppAppearance.darkValue(theme,(getResources().getConfiguration().uiMode&android.content.res.Configuration.UI_MODE_NIGHT_MASK)==android.content.res.Configuration.UI_MODE_NIGHT_YES);int color=style.equals("wall")?(dark?0xFF10241A:0xFFDCEADE):(dark?0xFF182720:0xFFEAF0EE);android.view.Window window=getWindow();window.addFlags(android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);window.setStatusBarColor(color);window.setNavigationBarColor(color);window.getDecorView().setSystemUiVisibility(dark?0:android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);web.setBackgroundColor(color);
    }
    private void hostAction(JSONObject request)throws Exception{
        String name=request.getString("name");JSONObject payload=request.optJSONObject("payload");if(payload==null)payload=new JSONObject();SharedPreferences prefs=getSharedPreferences("library",0);
        switch(name){
            case "chooseFolder":startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION),81);return;
            case "exportDiagnostics":startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/zip").addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,"MiniVoice-diagnostics.zip"),82);return;
            case "settings":startActivity(new Intent(this,MainActivity.class).setAction(MainActivity.ACTION_SHOW_SCAN).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT));return;
            case "mode":playback.setMode(payload.getInt("value"));return;
            case "queueSelect":String id=payload.getString("id");for(int i=0;i<playback.queue.size();i++)if(Long.toString(playback.queue.get(i).id).equals(id)){playback.select(i);return;}throw new IllegalArgumentException("歌曲不在播放队列中");
            default:throw new IllegalArgumentException("此平台暂不支持该操作");
        }
    }
    private void reply(String id,Object value,String error){try{JSONObject envelope=new JSONObject().put("ok",error==null);if(error==null)envelope.put("value",value==null?JSONObject.NULL:value);else envelope.put("error",error);String script="globalThis.MiniVoiceTransport?.receive("+JSONObject.quote(id)+","+envelope+")";main.post(()->{if(!closed)web.evaluateJavascript(script,null);});}catch(JSONException ignored){}}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;Uri uri=data.getData();if(request==81){try{getContentResolver().takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION);SharedPreferences prefs=getSharedPreferences("library",0);Set<String> folders=new HashSet<>(prefs.getStringSet("music_folders",Collections.emptySet()));folders.add(uri.toString());prefs.edit().putStringSet("music_folders",folders).putBoolean("folder_library",true).commit();LibraryScanService.request(this,false,false,true);}catch(Exception failure){android.widget.Toast.makeText(this,"无法授权文件夹，请重新选择",android.widget.Toast.LENGTH_LONG).show();}}else if(request==82)worker.execute(()->{String message="诊断报告已导出";try(java.io.OutputStream out=getContentResolver().openOutputStream(uri,"wt")){if(out==null)throw new IOException();Diagnostics.export(this,out);}catch(Exception failure){message="导出失败，请重试";}String status=message;main.post(()->{if(!closed)android.widget.Toast.makeText(this,status,android.widget.Toast.LENGTH_LONG).show();});});}
    @Override public void onBackPressed(){if(web!=null&&web.getProgress()==100)web.evaluateJavascript("globalThis.dispatchEvent(new Event('minivoice-back'))",null);else super.onBackPressed();}
    @Override public void onDestroy(){closed=true;LibraryScanService.remove(scanObserver);if(bound)unbindService(connection);worker.shutdownNow();if(web!=null){web.removeJavascriptInterface("MiniVoiceHost");web.destroy();}super.onDestroy();}
}
