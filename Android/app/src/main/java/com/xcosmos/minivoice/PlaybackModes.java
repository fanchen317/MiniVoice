package com.xcosmos.minivoice;

final class PlaybackModes {
    static final String[] NAMES={"单曲播放","列表播放","随机播放","单曲循环","列表循环"};
    static final String[] DETAILS={"当前歌曲结束后停止","按顺序播放，到列表末尾停止","随机播放队列中的歌曲","重复播放当前歌曲","顺序播放并循环整个列表"};
    static int valid(int mode){return mode>=0&&mode<NAMES.length?mode:1;}
}
