package com.xcosmos.minivoice;

import java.text.Normalizer;
import java.util.*;

/** Exact names win; normalized aliases are accepted only if unambiguous. */
final class LyricIndex<T> {
    private final Map<String,Set<T>> names=new HashMap<>();
    void add(String filename,T value){
        for(String alias:aliases(filename))names.computeIfAbsent(alias,key->new HashSet<>()).add(value);
    }
    T find(String filename,String title,String artist){
        for(String query:new String[]{stem(filename),withoutNumber(stem(filename)),artist+" - "+title,title}){
            Set<T> matches=names.get(normalize(query));if(matches!=null&&matches.size()==1)return matches.iterator().next();
        }
        return null;
    }
    private static List<String> aliases(String filename){
        String stem=stem(filename),plain=withoutNumber(stem);List<String> result=new ArrayList<>();result.add(normalize(stem));result.add(normalize(plain));
        String[] parts=plain.split("\\s+-\\s+",2);if(parts.length==2)result.add(normalize(parts[1]));return result;
    }
    private static String stem(String name){return name==null?"":name.replaceFirst("(?i)\\.(lrc|mp3|flac|m4a|aac|wav|aiff|ogg|opus|wma)$", "");}
    private static String withoutNumber(String name){return name.replaceFirst("^\\s*\\d{1,4}\\s*[-._、]\\s*", "");}
    private static String normalize(String name){return Normalizer.normalize(name,Normalizer.Form.NFKC).toLowerCase(Locale.ROOT).replaceAll("[\\s\\p{Z}]+", " ").trim();}
}
