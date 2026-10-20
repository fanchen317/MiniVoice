package com.xcosmos.minivoice;

final class ScanStatusText {
    static int percent(int completed,int total){return total<=0?0:(int)Math.min(100,Math.max(0,(long)completed*100/total));}
    static String stage(String previous,String detail){
        if(detail.contains("清理"))return "清理旧缓存";
        if(detail.contains("恢复"))return "恢复音乐库";
        if(detail.contains("查找")||detail.contains("已发现"))return "查找音乐文件";
        if(detail.contains("读取歌曲"))return "读取歌曲信息";
        if(detail.contains("歌词"))return "匹配歌词";
        if(detail.contains("缓存封面"))return "缓存封面";
        return previous;
    }
}
