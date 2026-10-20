package com.xcosmos.minivoice;

import java.text.Collator;
import java.util.Comparator;
import java.util.Locale;

/** Matches Mac's tracks/artists/albums ordering categories. */
final class LibraryOrdering {
    static final String[] TRACK_FIELDS={"title","artist","album","duration","sourceAdded","added"};
    static final String[] TRACK_NAMES={"歌曲名称","歌手姓名","专辑名称","播放时长","添加时间","更新时间"};
    static final String[] GROUP_FIELDS={"name","count"};
    static String category(String section,boolean child){return !child&&section.equals("歌手")?"artists":!child&&section.equals("专辑")?"albums":"tracks";}
    static String field(String category,String value){String[] allowed=category.equals("tracks")?TRACK_FIELDS:GROUP_FIELDS;for(String item:allowed)if(item.equals(value))return item;return category.equals("tracks")?"added":"name";}
    private static final java.util.regex.Pattern SEGMENTS=java.util.regex.Pattern.compile("[0-9]+|[^0-9]+");
    private static int name(Collator collator,String left,String right){
        java.util.regex.Matcher a=SEGMENTS.matcher(left),b=SEGMENTS.matcher(right);
        while(a.find()){if(!b.find())return 1;String x=a.group(),y=b.group();int compared;
            if(Character.isDigit(x.charAt(0))&&Character.isDigit(y.charAt(0))){x=x.replaceFirst("^0+(?!$)","");y=y.replaceFirst("^0+(?!$)","");compared=Integer.compare(x.length(),y.length());if(compared==0)compared=x.compareTo(y);}
            else compared=collator.compare(x,y);if(compared!=0)return compared;
        }return b.find()?-1:0;
    }
    static Comparator<Song> comparator(String field,boolean ascending,boolean grouping){
        Collator collator=Collator.getInstance(Locale.CHINA);collator.setStrength(Collator.PRIMARY);
        return (a,b)->{int compared;
            if(grouping)compared=field.equals("count")?Integer.compare(a.groupCount,b.groupCount):name(collator,a.title,b.title);
            else switch(field){case "duration":compared=Long.compare(a.duration,b.duration);break;case "sourceAdded":compared=Long.compare(a.sourceAdded,b.sourceAdded);break;case "added":compared=Long.compare(a.updated,b.updated);break;case "artist":compared=name(collator,a.artist,b.artist);break;case "album":compared=name(collator,a.album,b.album);break;default:compared=name(collator,a.title,b.title);}
            if(compared==0)compared=name(collator,a.title,b.title);if(compared==0)compared=name(collator,a.artist,b.artist);if(compared==0)compared=Long.compare(a.id,b.id);
            return ascending?compared:-compared;
        };
    }
}
