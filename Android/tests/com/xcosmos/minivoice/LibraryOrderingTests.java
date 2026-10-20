package com.xcosmos.minivoice;

import java.util.*;
public final class LibraryOrderingTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    private static Song song(long id,String title,String artist,String album,long added,long updated){Song song=new Song(id,1,0,title,artist,album,"",null);song.sourceAdded=added;song.updated=updated;return song;}
    public static void main(String[] args){
        check(LibraryOrdering.category("歌手",false).equals("artists"),"artist root keeps artist preferences");
        check(LibraryOrdering.category("专辑",false).equals("albums"),"album root keeps album preferences");
        for(String section:new String[]{"歌手","专辑","歌曲","收藏","歌单:测试"})check(LibraryOrdering.category(section,true).equals("tracks"),"second-level song pages use track choices");
        check(LibraryOrdering.field("tracks","count").equals("added"),"group count cannot leak into song sort");
        check(LibraryOrdering.field("artists","title").equals("name"),"track sort cannot leak into groups");
        Song first=song(1,"歌曲2","B","A",100,300),second=song(2,"歌曲10","A","B",200,100);
        check(LibraryOrdering.comparator("title",true,false).compare(first,second)<0,"numeric title order");
        check(LibraryOrdering.comparator("artist",true,false).compare(first,second)>0,"artist order");
        check(LibraryOrdering.comparator("album",true,false).compare(first,second)<0,"album order");
        check(LibraryOrdering.comparator("sourceAdded",true,false).compare(first,second)<0,"first added order");
        check(LibraryOrdering.comparator("added",false,false).compare(first,second)<0,"newest updated first");
        first.groupCount=8;second.groupCount=3;
        check(LibraryOrdering.comparator("count",false,true).compare(first,second)<0,"group counts descending");
        check(LibraryOrdering.comparator("name",true,true).compare(first,second)<0,"group numeric names");
        for(String field:LibraryOrdering.TRACK_FIELDS){int forward=LibraryOrdering.comparator(field,true,false).compare(first,second);int reverse=LibraryOrdering.comparator(field,false,false).compare(first,second);check(forward==-reverse,"ascending/descending symmetry");}
        System.out.println("PASS: page-specific sort categories, child-page rules, numeric names, timestamps, group counts and directions");
    }
}
