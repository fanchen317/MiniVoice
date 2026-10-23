package com.xcosmos.minivoice;
import android.app.Activity;
import android.content.*;
import android.os.ParcelFileDescriptor;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
/** Authorized document adapter; content and confirmation live in Shared/UI. */
final class PortableMetadataActions {
 static boolean handles(String name){return name.equals("metadataDetail")||name.equals("writeMetadata")||name.equals("restoreMetadata");}
 static Song song(List<Song> songs,String id){for(Song song:songs)if(Long.toString(song.id).equals(id))return song;throw new IllegalArgumentException("歌曲已不在音乐库中");}
 static String format(Song song){String name=song.path.toLowerCase(Locale.ROOT);return name.endsWith(".mp3")?"mp3":name.endsWith(".flac")?"flac":name.endsWith(".m4a")?"m4a":"";}
 static File journal(Activity activity,String id)throws IOException{if(!id.matches("original-[0-9]+\\.audio\\.json"))throw new IOException("无效的恢复记录");File file=new File(new File(activity.getFilesDir(),"edit-recovery"),id);if(!file.isFile()||file.length()>16384)throw new IOException("恢复记录已失效");return file;}
 static JSONObject record(File file)throws Exception{return new JSONObject(new String(java.nio.file.Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));}
 static Song editingSong(Activity activity,List<Song> songs,String action,JSONObject payload)throws Exception{if(!action.equals("restoreMetadata"))return song(songs,payload.getString("id"));String uri=record(journal(activity,payload.getString("id"))).getString("uri");for(Song song:songs)if(song.uri.toString().equals(uri))return song;throw new IOException("请先重新授权原歌曲所在的文件夹，再恢复备份");}
 static JSONArray recoveries(Activity activity){JSONArray result=new JSONArray();File root=new File(activity.getFilesDir(),"edit-recovery");File[] files=root.listFiles((dir,name)->name.endsWith(".audio.json"));if(files!=null)for(File file:files)try{JSONObject value=record(journal(activity,file.getName()));File backup=new File(root,file.getName().substring(0,file.getName().length()-5));if(backup.isFile())result.put(new JSONObject().put("id",file.getName()).put("title",value.optString("name","音乐文件")));}catch(Exception ignored){}return result;}
 static Object execute(Activity activity,List<Song> songs,String action,JSONObject payload)throws Exception{
  Song song=editingSong(activity,songs,action,payload);String format=format(song);
  if(action.equals("restoreMetadata")){if(LibraryScanService.isRunning())throw new IOException("请等待扫描完成后再恢复");File journal=journal(activity,payload.getString("id")),backup=new File(journal.getParentFile(),journal.getName().substring(0,journal.getName().length()-5));if(!backup.isFile())throw new IOException("原文件备份不存在");copyTo(activity,backup,song);try(InputStream in=activity.getContentResolver().openInputStream(song.uri)){if(in==null||!Arrays.equals(digest(in),digest(new FileInputStream(backup))))throw new IOException("恢复校验失败，备份已保留");}backup.delete();journal.delete();LibrarySnapshot.invalidate(activity);return true;}

  if(action.equals("metadataDetail")){AudioTags tags=AudioTags.read(activity,song.uri,false);return new JSONObject().put("id",Long.toString(song.id)).put("title",tags.title==null?song.title:tags.title).put("artist",tags.artist==null?song.artist:tags.artist).put("album",tags.album==null?song.album:tags.album).put("lyrics",activity.getSharedPreferences("library",0).getBoolean("lyrics_override_"+song.id,false)?activity.getSharedPreferences("library",0).getString("lyrics_"+song.id,""):tags.lyrics==null?"":tags.lyrics).put("writable",!format.isEmpty()).put("format",format).put("path",song.path);}
  if(recoveries(activity).length()>0)throw new IOException("存在待恢复的文件备份，请先在设置中处理");
  if(format.isEmpty())throw new IOException("此格式暂不支持原文件标签写入");if(LibraryScanService.isRunning())throw new IOException("请等待扫描完成后再保存");
  String title=field(payload,"title",500),artist=field(payload,"artist",500),album=field(payload,"album",500),lyrics=field(payload,"lyrics",1024*1024);if(title.trim().isEmpty())throw new IOException("歌曲名称不能为空");
  // Check write access without truncating anything. Existing read-only tree grants need reauthorization.
  try(ParcelFileDescriptor descriptor=activity.getContentResolver().openFileDescriptor(song.uri,"rw")){if(descriptor==null)throw new IOException("无法打开文件");}catch(SecurityException denied){throw new IOException("缺少文件写入权限，请在设置中重新授权此音乐文件夹",denied);}
  File root=new File(activity.getFilesDir(),"edit-recovery");if(!root.isDirectory()&&!root.mkdirs())throw new IOException("无法创建写入备份");File backup=File.createTempFile("original-",".audio",root),output=new File(backup.getPath()+".new"),journal=new File(backup.getPath()+".json");boolean keep=false,mutated=false;
  try{
   try(InputStream in=activity.getContentResolver().openInputStream(song.uri);OutputStream out=new FileOutputStream(backup)){if(in==null)throw new IOException("无法读取原文件");byte[] bytes=new byte[65536];long total=0;for(int n;(n=in.read(bytes))!=-1;){total+=n;if(total>512L*1024*1024||root.getUsableSpace()<total+32L*1024*1024)throw new IOException("文件过大或可用空间不足");out.write(bytes,0,n);}out.flush();((FileOutputStream)out).getFD().sync();}
   PortableTagCodec.rewrite(backup,output,format,title,artist,album,lyrics);
   AudioTags checked;try(InputStream in=new FileInputStream(output)){checked=AudioTags.read(in,false);}if(!title.equals(checked.title)||!artist.equals(checked.artist==null?"":checked.artist)||!album.equals(checked.album==null?"":checked.album)||!lyrics.equals(checked.lyrics==null?"":checked.lyrics))throw new IOException("标签回读校验失败，原文件未修改");
   try(InputStream in=activity.getContentResolver().openInputStream(song.uri)){if(in==null||!Arrays.equals(digest(in),digest(new FileInputStream(backup))))throw new IOException("文件已在其他位置更改，请重新打开编辑器");}
   try(FileOutputStream record=new FileOutputStream(journal)){record.write(new JSONObject().put("uri",song.uri.toString()).put("name",song.title).put("backup",backup.getName()).toString().getBytes(StandardCharsets.UTF_8));record.getFD().sync();}
   mutated=true;copyTo(activity,output,song);try(InputStream in=activity.getContentResolver().openInputStream(song.uri)){if(in==null||!Arrays.equals(digest(in),digest(new FileInputStream(output))))throw new IOException("文件写入校验失败");}
   SharedPreferences prefs=activity.getSharedPreferences("library",0);prefs.edit().remove("lyrics_"+song.id).remove("lyrics_override_"+song.id).commit();LibrarySnapshot.invalidate(activity);return true;
  }catch(Exception failure){if(mutated)try{copyTo(activity,backup,song);try(InputStream in=activity.getContentResolver().openInputStream(song.uri)){if(in==null||!Arrays.equals(digest(in),digest(new FileInputStream(backup))))throw new IOException("恢复校验失败");}}catch(Exception rollback){keep=true;Diagnostics.failure("metadata recovery required",rollback);throw new IOException("写入和恢复均失败，原文件备份已保留，请勿清除应用数据。请导出诊断报告并联系支持。",failure);}throw failure;}
  finally{output.delete();if(!keep){backup.delete();journal.delete();}}
 }
 static String field(JSONObject payload,String key,int limit)throws Exception{String value=payload.getString(key);if(value.length()>limit||value.indexOf('\0')>=0)throw new IOException("字段过长或包含无效字符");return key.equals("lyrics")?value:value.trim();}
 static byte[] digest(InputStream input)throws Exception{try(InputStream in=input){MessageDigest hash=MessageDigest.getInstance("SHA-256");byte[] bytes=new byte[65536];for(int n;(n=in.read(bytes))!=-1;)hash.update(bytes,0,n);return hash.digest();}}
 static void copyTo(Activity activity,File file,Song song)throws Exception{try(OutputStream out=activity.getContentResolver().openOutputStream(song.uri,"rwt");InputStream in=new FileInputStream(file)){if(out==null)throw new IOException("无法写入文档");in.transferTo(out);out.flush();}}
}
