package com.xcosmos.minivoice;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.AtomicFile;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import org.json.*;

/** System-owned app directories: removed on uninstall, retained on package update. */
final class AppStorage {
    private static File files;
    private static SharedPreferences preferences;
    private static SharedPreferences.OnSharedPreferenceChangeListener listener;
    private static final ScheduledExecutorService writer=Executors.newSingleThreadScheduledExecutor();
    private static ScheduledFuture<?> pending;
    static synchronized File files(Context context){
        if(files==null){File external=context.getExternalFilesDir(null);if(external!=null&&(external.isDirectory()||external.mkdirs())&&external.canWrite())files=external;else files=new File(context.getFilesDir(),"storage");files.mkdirs();}
        return files;
    }
    static File config(Context context){return new File(files(context),"config");}
    static File temporary(Context context){File cache=context.getExternalCacheDir();return cache!=null&&(cache.isDirectory()||cache.mkdirs())?cache:context.getCacheDir();}
    static synchronized void mirrorPreferences(Context context){
        if(preferences!=null)return;Context app=context.getApplicationContext();preferences=app.getSharedPreferences("library",Context.MODE_PRIVATE);
        listener=(prefs,key)->schedule(app);preferences.registerOnSharedPreferenceChangeListener(listener);schedule(app);
    }
    private static synchronized void schedule(Context context){if(pending!=null)pending.cancel(false);pending=writer.schedule(()->writePreferences(context),500,TimeUnit.MILLISECONDS);}
    private static void writePreferences(Context context){
        AtomicFile file=new AtomicFile(new File(config(context),"settings.json"));FileOutputStream output=null;
        try{
            JSONObject values=new JSONObject();for(Map.Entry<String,?> entry:preferences.getAll().entrySet()){
                Object value=entry.getValue();if(value instanceof Set){List<String> ordered=new ArrayList<>();for(Object item:(Set<?>)value)ordered.add(String.valueOf(item));Collections.sort(ordered);value=new JSONArray(ordered);}values.put(entry.getKey(),value);
            }
            JSONObject document=new JSONObject().put("version",1).put("package",context.getPackageName()).put("settings",values);
            config(context).mkdirs();output=file.startWrite();output.write(document.toString(2).getBytes(StandardCharsets.UTF_8));file.finishWrite(output);
        }catch(Exception failure){if(output!=null)file.failWrite(output);android.util.Log.w("MiniVoice","Unable to write settings snapshot",failure);}
    }
}
