package com.xcosmos.minivoice;

final class WallSearchDismiss {
    static boolean shouldClose(boolean open,int queryLength,boolean inside){return open&&queryLength==0&&!inside;}
}
