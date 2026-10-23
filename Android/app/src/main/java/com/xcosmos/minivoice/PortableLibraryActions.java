package com.xcosmos.minivoice;

import android.app.Activity;
import android.content.*;
import android.net.Uri;
import android.provider.DocumentsContract;
import org.json.*;
import java.io.IOException;
import java.util.*;

/** Storage and directory adapters for the shared phone presentation; no UI decisions here. */
final class PortableLibraryActions {
    private static final Set<String> ACTIONS=new HashSet<>(Arrays.asList("favorite","addToPlaylist","getSettings","renamePlaylist","deletePlaylist","createPlaylist","favoriteMany","addManyToPlaylist","removeManyFromPlaylist","clearRecent","recursive","rescan","removeFolder","readLyrics"));
    static boolean handles(String name){return ACTIONS.contains(name)||PortableSettingsTools.handles(name);}
    static Set<String> selectedSongs(List<Song> songs,JSONArray ids)throws JSONException{
        if(ids==null||ids.length()==0)throw new IllegalArgumentException("请先选择歌曲");Set<String> allowed=new HashSet<>(),result=new LinkedHashSet<>();for(Song song:songs)allowed.add(Long.toString(song.id));
        for(int i=0;i<ids.length();i++){String id=ids.getString(i);if(!allowed.contains(id))throw new IllegalArgumentException("歌曲已不在当前音乐库中");result.add(id);}return result;
    }
    static String playlistName(String value){String title=value.trim();if(title.isEmpty()||title.length()>100)throw new IllegalArgumentException("歌单名称需为 1—100 字");return title;}
    private static void save(SharedPreferences.Editor editor)throws IOException{if(!editor.commit())throw new IOException("保存失败，请重试");}
    static Object execute(Activity activity,List<Song> songs,String action,JSONObject payload)throws Exception{
        if(PortableSettingsTools.handles(action))return PortableSettingsTools.execute(activity,songs,action,payload);
        SharedPreferences prefs=activity.getSharedPreferences("library",0);Set<String> names=new HashSet<>(prefs.getStringSet("playlists",Collections.emptySet()));
        switch(action){
            case "getSettings":JSONArray folders=new JSONArray();for(String source:new TreeSet<>(prefs.getStringSet("music_folders",Collections.emptySet()))){String label;try{label=DocumentsContract.getTreeDocumentId(Uri.parse(source));}catch(Exception ignored){label=source;}folders.put(new JSONObject().put("id",source).put("name",label).put("path",source));}return PortableSettingsTools.settings(activity,songs,new JSONObject().put("folders",folders).put("recursive",prefs.getBoolean("scan_recursive",true)).put("crashCount",Diagnostics.crashCount()).put("actions",new JSONArray(Arrays.asList("chooseFolder","removeFolder","recursive","rescan","exportDiagnostics","clearRecent","cacheInfo","clearCache","inspectLibrary","artistAlias","clearArtistAliases","saveLyrics"))));
            case "readLyrics":String songId=payload.getString("id");for(Song song:songs)if(Long.toString(song.id).equals(songId)){LyricsRepository.prepareSong(activity,song);return new JSONObject().put("title",song.title).put("raw",prefs.getBoolean("lyrics_override_"+song.id,false)?prefs.getString("lyrics_"+song.id,""):LyricsRepository.select(song,prefs.getString("lyrics_"+song.id,"")));}throw new IllegalArgumentException("歌曲已不在当前音乐库中");
            case "createPlaylist":String name=playlistName(payload.getString("name"));if(!names.add(name))throw new IllegalArgumentException("已有同名歌单");Set<String> initial=payload.optJSONArray("ids")==null||payload.getJSONArray("ids").length()==0?new HashSet<>():selectedSongs(songs,payload.getJSONArray("ids"));save(prefs.edit().putStringSet("playlists",names).putStringSet("playlist_"+name,initial));return new JSONObject().put("id",name);
            case "renamePlaylist":case "deletePlaylist":String id=payload.getString("playlist");if(!names.contains(id))throw new IllegalArgumentException("歌单不存在");String next=action.equals("deletePlaylist")?null:playlistName(payload.getString("name"));if(next!=null&&!next.equals(id)&&names.contains(next))throw new IllegalArgumentException("已有同名歌单");if(id.equals(next))return new JSONObject().put("id",id);Set<String> contents=new HashSet<>(prefs.getStringSet("playlist_"+id,Collections.emptySet()));names.remove(id);SharedPreferences.Editor edit=prefs.edit().remove("playlist_"+id);if(next!=null){names.add(next);edit.putStringSet("playlist_"+next,contents);}save(edit.putStringSet("playlists",names));BrowseStateStore browse=new BrowseStateStore(activity);if(browse.section().equals("歌单:"+id)){browse.navigation(next==null?"歌曲":"歌单:"+next,null);browse.flush();}return new JSONObject().put("id",next==null?JSONObject.NULL:next);
            case "favorite":Set<String> one=selectedSongs(songs,new JSONArray().put(payload.getString("id"))),savedFavorites=new HashSet<>(prefs.getStringSet("favorites",Collections.emptySet()));String only=one.iterator().next();if(!savedFavorites.add(only))savedFavorites.remove(only);save(prefs.edit().putStringSet("favorites",savedFavorites));return true;
            case "addToPlaylist":return execute(activity,songs,"addManyToPlaylist",new JSONObject().put("playlist",payload.getString("playlist")).put("ids",new JSONArray().put(payload.getString("id"))));
            case "favoriteMany":Set<String> selected=selectedSongs(songs,payload.getJSONArray("ids")),favorites=new HashSet<>(prefs.getStringSet("favorites",Collections.emptySet()));if(payload.getBoolean("value"))favorites.addAll(selected);else favorites.removeAll(selected);save(prefs.edit().putStringSet("favorites",favorites));return true;
            case "addManyToPlaylist":case "removeManyFromPlaylist":String destination=payload.getString("playlist");if(!names.contains(destination))throw new IllegalArgumentException("歌单不存在");Set<String> ids=selectedSongs(songs,payload.getJSONArray("ids")),saved=new HashSet<>(prefs.getStringSet("playlist_"+destination,Collections.emptySet()));if(action.equals("addManyToPlaylist"))saved.addAll(ids);else saved.removeAll(ids);save(prefs.edit().putStringSet("playlist_"+destination,saved));return true;
            case "clearRecent":SharedPreferences.Editor clear=prefs.edit().remove("recent");for(String recent:prefs.getStringSet("recent",Collections.emptySet()))clear.remove("recent_time_"+recent);save(clear);return true;
            case "rescan":LibraryScanService.request(activity,false,false,false);return true;
            case "recursive":save(prefs.edit().putBoolean("scan_recursive",payload.getBoolean("value")));LibraryScanService.request(activity,false,false,true);return true;
            case "removeFolder":String folder=payload.getString("folder");Set<String> sources=new HashSet<>(prefs.getStringSet("music_folders",Collections.emptySet()));if(!sources.remove(folder))throw new IllegalArgumentException("文件夹已移除");save(prefs.edit().putStringSet("music_folders",sources));try{activity.getContentResolver().releasePersistableUriPermission(Uri.parse(folder),Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(SecurityException ignored){}LibraryScanService.request(activity,false,false,true);return true;
            default:throw new IllegalArgumentException("不支持的音乐库操作");
        }
    }
}
