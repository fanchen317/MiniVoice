package com.xcosmos.minivoice;
import java.text.Normalizer;
import java.util.*;
final class ArtistNames {
    static String key(String value){return SharedCore.artistKey(value==null?"":value);}
    static String canonical(String value,Map<String,String> aliases){String[] keys=new String[aliases.size()],values=new String[aliases.size()];int index=0;for(Map.Entry<String,String> entry:aliases.entrySet()){keys[index]=entry.getKey();values[index++]=entry.getValue();}return SharedCore.canonicalArtist(value==null?"未知歌手":value,keys,values);}
    static String duplicateKey(String title,String artist,long duration){if(duration<=0||key(title).isEmpty()||key(artist).equals("未知歌手"))return "";return key(title)+"\n"+key(artist);}
    static boolean similarDuration(long first,long second){return first>0&&second>0&&Math.abs(first-second)<=2000;}
}
