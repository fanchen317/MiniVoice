package com.xcosmos.minivoice;
import android.app.Activity;
import android.content.*;
import org.json.*;
import java.io.*;
import java.util.*;
/** Domain adapters for custom settings. No native dialogs or content widgets. */
final class PortableSettingsTools {
    private static final Set<String> ACTIONS=new HashSet<>(Arrays.asList("cacheInfo","clearCache","inspectLibrary","artistAlias","clearArtistAliases","saveLyrics"));
    private static volatile JSONObject inspection=new JSONObject();
    private static volatile boolean checking;
    static boolean handles(String name){return ACTIONS.contains(name);}
    static Map<String,String> aliases(SharedPreferences prefs){Map<String,String> result=new HashMap<>();try{JSONObject values=new JSONObject(prefs.getString("artist_aliases","{}"));Iterator<String> keys=values.keys();while(keys.hasNext()){String key=keys.next();result.put(key,values.getString(key));}}catch(Exception ignored){}return result;}
    static JSONObject settings(Activity activity,List<Song> songs,JSONObject settings)throws Exception{
        Set<String> names=new TreeSet<>();for(Song song:songs)names.add(song.artist);
        return settings.put("recoveries",PortableMetadataActions.recoveries(activity)).put("artists",new JSONArray(names)).put("aliases",new JSONObject(aliases(activity.getSharedPreferences("library",0))));
    }
    private static Map<String,File> roots(Activity activity){Map<String,File> roots=new LinkedHashMap<>();roots.put("封面",LibraryCache.directory(activity,"covers"));roots.put("歌词读取缓存",LibraryCache.directory(activity,"lyrics"));roots.put("内部临时文件",activity.getCacheDir());roots.put("外部临时文件",AppStorage.temporary(activity));return roots;}
    static Object execute(Activity activity,List<Song> songs,String action,JSONObject payload)throws Exception{
        SharedPreferences prefs=activity.getSharedPreferences("library",0);
        switch(action){
            case "cacheInfo":{List<CacheFiles.Entry> entries=CacheFiles.list(roots(activity));JSONArray rows=new JSONArray();long total=0;for(CacheFiles.Entry entry:entries){total+=entry.bytes;if(rows.length()<2000)rows.put(new JSONObject().put("id",LibraryCache.key(entry.name)).put("name",entry.name).put("bytes",entry.bytes));}return new JSONObject().put("bytes",total).put("count",entries.size()).put("entries",rows).put("truncated",entries.size()>2000);}
            case "clearCache":{if(LibraryScanService.isRunning())throw new IllegalStateException("扫描期间不能清理缓存");Map<String,File> roots=roots(activity);List<CacheFiles.Entry> entries=CacheFiles.list(roots);JSONArray ids=payload.optJSONArray("ids");if(ids!=null){if(ids.length()==0)throw new IllegalArgumentException("请选择缓存文件");Map<String,CacheFiles.Entry> allowed=new HashMap<>();for(CacheFiles.Entry entry:entries)allowed.put(LibraryCache.key(entry.name),entry);List<CacheFiles.Entry> selected=new ArrayList<>();Set<String> added=new HashSet<>();for(int i=0;i<ids.length();i++){String id=ids.getString(i);if(!allowed.containsKey(id))throw new IllegalArgumentException("缓存列表已变化，请刷新后重试");if(added.add(id))selected.add(allowed.get(id));}entries=selected;}long removed=CacheFiles.delete(entries,roots.values());ArtworkCache.clear();return new JSONObject().put("removed",removed);}
            case "inspectLibrary":{if(payload.optBoolean("start"))startInspection(activity.getApplicationContext(),new ArrayList<>(songs),prefs.getString("scan_missing","[]"));return new JSONObject(inspection.toString()).put("running",checking);}
            case "artistAlias":{String source=payload.getString("source"),target=payload.getString("target");Set<String> known=new HashSet<>();for(Song song:songs)known.add(song.artist);Map<String,String> values=aliases(prefs);if(!known.contains(source)||!known.contains(target)||ArtistNames.key(source).equals(ArtistNames.key(target)))throw new IllegalArgumentException("请选择两个不同的现有歌手名称");values.remove(ArtistNames.key(target));values.put(ArtistNames.key(source),target);if(!prefs.edit().putString("artist_aliases",new JSONObject(values).toString()).commit())throw new IOException("保存失败");return true;}
            case "clearArtistAliases":if(!prefs.edit().remove("artist_aliases").commit())throw new IOException("保存失败");return true;
            case "saveLyrics":{String id=payload.getString("id");PortableLibraryActions.selectedSongs(songs,new JSONArray().put(id));String raw=payload.getString("raw");if(raw.getBytes(java.nio.charset.StandardCharsets.UTF_8).length>1024*1024)throw new IllegalArgumentException("歌词不能超过 1MB");if(!prefs.edit().putString("lyrics_"+id,raw).putBoolean("lyrics_override_"+id,true).commit())throw new IOException("歌词保存失败");return true;}
            default:throw new IllegalArgumentException("不支持的设置操作");
        }
    }
    private static synchronized void startInspection(Context context,List<Song> songs,String missing)throws Exception{
        if(checking)return;checking=true;inspection=new JSONObject().put("checked",0).put("total",songs.size()).put("unavailable",new JSONArray()).put("missing",new JSONArray(missing));
        new Thread(()->{JSONArray unavailable=new JSONArray();try{for(int i=0;i<songs.size();i++){Song song=songs.get(i);try(android.content.res.AssetFileDescriptor descriptor=context.getContentResolver().openAssetFileDescriptor(song.uri,"r")){if(descriptor==null)throw new FileNotFoundException();}catch(Exception failure){unavailable.put(new JSONObject().put("id",Long.toString(song.id)).put("title",song.title).put("path",song.path).put("reason","文件不存在、无读取权限或提供方暂不可用"));}if((i+1)%25==0||i+1==songs.size())inspection=new JSONObject().put("checked",i+1).put("total",songs.size()).put("unavailable",new JSONArray(unavailable.toString())).put("missing",new JSONArray(missing));}}catch(Exception error){try{inspection=new JSONObject(inspection.toString()).put("error",error.getMessage());}catch(Exception ignored){}}finally{checking=false;}},"portable-library-inspection").start();
    }
}
