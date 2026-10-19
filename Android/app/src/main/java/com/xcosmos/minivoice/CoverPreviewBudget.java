package com.xcosmos.minivoice;

final class CoverPreviewBudget {
    static final int BYTES=24*1024*1024;
    static int side(int count){return Math.max(1,Math.min(96,(int)Math.sqrt(BYTES/(double)Math.max(1,count)/4)));}
}
