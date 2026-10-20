package com.xcosmos.minivoice;

/** Coalesces repeated refreshes and never lets reopening the UI restart an active scan. */
final class ScanRequestQueue {
    static final class Request {
        final boolean rebuild,restore;
        Request(boolean rebuild,boolean restore){this.rebuild=rebuild;this.restore=restore&&!rebuild;}
    }
    private Request current,pending;
    Request offer(boolean rebuild,boolean restore,boolean sourceChange){
        if(current==null){current=new Request(rebuild,restore);return current;}
        if(restore&&!rebuild&&!sourceChange)return null;
        pending=new Request(rebuild||(pending!=null&&pending.rebuild),false);return null;
    }
    Request complete(){current=pending;pending=null;return current;}
}
