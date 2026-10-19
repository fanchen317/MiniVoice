package com.xcosmos.minivoice;

interface ScanProgress {
    void update(int completed,int total,String detail);
}
