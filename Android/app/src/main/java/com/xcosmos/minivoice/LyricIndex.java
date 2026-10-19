package com.xcosmos.minivoice;

import java.text.Normalizer;
import java.util.*;

/** Match the original audio filename stem; never substitute title metadata or remove track numbers. */
final class LyricIndex<T> {
    boolean readFailed;
    private final Map<String,Set<T>> names=new HashMap<>();
    void add(String filename,T value){
        for(String alias:aliases(filename))names.computeIfAbsent(alias,key->new HashSet<>()).add(value);
    }
    T find(String filename,String title,String artist){
        Set<T> matches=names.get(normalize(stem(filename)));
        if(matches!=null&&matches.size()==1)return matches.iterator().next();
        return null;
    }
    private static List<String> aliases(String filename){return java.util.Collections.singletonList(normalize(stem(filename)));}
    private static String stem(String name){return name==null?"":name.replaceFirst("\\.[^.]+$", "");}
    private static String normalize(String name){return Normalizer.normalize(name,Normalizer.Form.NFKC).toLowerCase(Locale.ROOT).replaceAll("[\\s\\p{Z}]+", " ").trim();}
}
