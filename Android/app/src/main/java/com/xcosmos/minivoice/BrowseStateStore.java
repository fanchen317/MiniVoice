package com.xcosmos.minivoice;

import android.content.*;
import android.os.*;
import android.util.Base64;
import org.json.*;
import java.util.*;

/** One durable store for navigation, page anchors, queries, expansion and wall cameras. */
final class BrowseStateStore {
    private final SharedPreferences prefs,legacy;
    BrowseStateStore(Context context){prefs=context.getSharedPreferences("browse-state-v1",Context.MODE_PRIVATE);legacy=context.getSharedPreferences("library",Context.MODE_PRIVATE);}
    private String key(String page){return LibraryCache.key(page);}
    JSONObject page(String page){try{return new JSONObject(prefs.getString(key(page),"{}"));}catch(Exception ignored){return new JSONObject();}}
    private JSONObject reduce(JSONObject state,JSONObject action){try{JSONObject request=new JSONObject().put("version",1).put("op","state.reduce").put("state",state).put("action",action);JSONObject response=new JSONObject(SharedCore.execute(request.toString()));if(!response.optBoolean("ok"))throw new IllegalStateException(response.optString("error"));return response.getJSONObject("value");}catch(JSONException failure){throw new IllegalStateException(failure);}}
    void update(String page,java.util.function.Consumer<JSONObject> change){JSONObject value=page(page);change.accept(value);Object nativeState=value.remove("native");try{JSONObject action=new JSONObject().put("type","page").put("key",key(page)).put("patch",value);JSONObject result=reduce(new JSONObject(),action).getJSONObject("pages").getJSONObject(key(page));if(nativeState!=null)result.put("native",nativeState);prefs.edit().putString(key(page),result.toString()).apply();}catch(JSONException failure){throw new IllegalStateException(failure);}}
    private JSONObject root(){try{return new JSONObject(prefs.getString("root","{}"));}catch(JSONException failure){return new JSONObject();}}
    private void rootAction(JSONObject action){prefs.edit().putString("root",reduce(root(),action).toString()).apply();}
    static void put(JSONObject value,String name,Object item){try{value.put(name,item);}catch(JSONException ignored){}}
    void sorting(String category,String field,boolean ascending){prefs.edit().putString("sort_"+category,field).putBoolean("ascending_"+category,ascending).apply();}
    String sortField(String category){return LibraryOrdering.field(category,prefs.getString("sort_"+category,legacy.getString("sort_"+category,null)));}
    boolean ascending(String category){return prefs.getBoolean("ascending_"+category,legacy.getBoolean("ascending_"+category,!category.equals("tracks")));}
    String query(String page){return page(page).optString("query","");}
    void query(String page,String value){update(page,row->put(row,"query",value));}
    void flush(){if(!prefs.edit().putLong("checkpoint",System.currentTimeMillis()).commit())Diagnostics.event("browse state checkpoint failed");}
    void navigation(String section,String group){JSONObject action=new JSONObject();put(action,"type","navigate");put(action,"section",section);put(action,"group",group==null?"":group);rootAction(action);}
    String section(){return root().optString("section",prefs.getString("section","歌曲"));}
    String group(){String group=root().optString("group",prefs.getString("group",""));return group.isEmpty()?null:group;}
    void scroll(String page,List<String> items,int index,int offset,Parcelable nativeState){
        update(page,row->{put(row,"identity",items.get(index));put(row,"index",index);put(row,"offset",offset);put(row,"items",LibraryCache.key(new JSONArray(items).toString()));
            if(nativeState!=null){Parcel parcel=Parcel.obtain();try{parcel.writeParcelable(nativeState,0);put(row,"native",Base64.encodeToString(parcel.marshall(),Base64.NO_WRAP));}finally{parcel.recycle();}}
        });
    }
    Parcelable nativeScroll(String page,List<String> items){JSONObject row=page(page);if(!LibraryCache.key(new JSONArray(items).toString()).equals(row.optString("items")))return null;
        Parcel parcel=Parcel.obtain();try{byte[] bytes=Base64.decode(row.optString("native"),Base64.NO_WRAP);parcel.unmarshall(bytes,0,bytes.length);parcel.setDataPosition(0);return parcel.readParcelable(android.widget.AbsListView.class.getClassLoader());}catch(Exception ignored){return null;}finally{parcel.recycle();}}
    PageScrollMemory.Position scroll(String page,List<String> items){JSONObject row=page(page);if(!row.has("index")||items.isEmpty())return null;int[] anchor=SharedCore.restoreAnchor(items.toArray(new String[0]),row.optString("identity"),row.optInt("index"),row.optInt("offset"));return new PageScrollMemory.Position(anchor[0],anchor[1]);}
    void expansion(String page,boolean player,boolean catalog,boolean lyrics){update(page,row->{put(row,"player",player);put(row,"catalog",catalog);put(row,"lyrics",lyrics);});}
    void camera(String page,WallView.CameraState camera){update(page,row->{put(row,"x",camera.x);put(row,"y",camera.y);put(row,"scale",camera.scale);put(row,"focused",camera.focused);put(row,"column",camera.column);put(row,"row",camera.row);put(row,"expanded",camera.expanded);});}
    WallView.CameraState camera(String page){JSONObject row=page(page);return row.has("scale")?new WallView.CameraState((float)row.optDouble("x"),(float)row.optDouble("y"),(float)row.optDouble("scale",1),row.optLong("focused",Long.MIN_VALUE),row.optInt("column"),row.optInt("row"),row.optBoolean("expanded")):null;}
}
