package com.xcosmos.minivoice;

public final class ScanServiceTests {
    static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        ScanRequestQueue queue=new ScanRequestQueue();
        check(queue.offer(false,true,false).restore,"startup may restore existing index");
        check(queue.offer(false,true,false)==null,"reopening UI must not restart ongoing scan");
        check(queue.complete()==null,"reopening UI queues no work");
        check(queue.offer(false,false,false)!=null,"explicit rescan starts work");
        queue.offer(true,false,false);queue.offer(false,false,true);queue.offer(false,true,false);
        ScanRequestQueue.Request next=queue.complete();check(next!=null&&next.rebuild&&!next.restore,"source change and reopen preserve pending full rebuild");
        check(queue.complete()==null,"repeated requests coalesce into one follow-up");
        queue.offer(false,false,false);queue.offer(false,false,true);next=queue.complete();check(next!=null&&!next.restore,"source change performs a fresh scan");
        check(queue.complete()==null,"source follow-up drains");
        check(ScanStatusText.percent(4,0)==0&&ScanStatusText.percent(200,100)==100&&ScanStatusText.percent(-1,100)==0,"unknown total and progress bounds");
        check(ScanStatusText.percent(Integer.MAX_VALUE,Integer.MAX_VALUE)==100,"large-library percent avoids overflow");
        String phase=ScanStatusText.stage("准备扫描","正在查找音乐文件（已发现 27 首）");check(phase.equals("查找音乐文件"),"discovery stays indeterminate");
        phase=ScanStatusText.stage(phase,"读取歌曲信息与封面");check(phase.equals("读取歌曲信息"),"metadata is distinct from artwork cache");
        check(ScanStatusText.stage(phase,"026 - artist - title.flac").equals(phase),"file detail retains notification phase");
        check(ScanStatusText.stage(phase,"读取歌词 · 歌曲").equals("匹配歌词"),"lyrics phase");
        check(ScanStatusText.stage(phase,"缓存封面 · 歌曲").equals("缓存封面"),"artwork phase");
        System.out.println("PASS: scan restoration/deduplication, queued rebuild/source changes, phase-specific notification progress and overflow bounds");
    }
}
