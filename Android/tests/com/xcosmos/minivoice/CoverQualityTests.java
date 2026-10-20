package com.xcosmos.minivoice;

public final class CoverQualityTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        java.util.Set<String> pending=new java.util.HashSet<>();
        check(pending.add(CoverQuality.request("content://song/1","a",640)),"start wall preview request");
        check(pending.add(CoverQuality.request("content://song/1","a",1600)),"focusing must start detail even with preview in flight");
        check(!pending.add(CoverQuality.request("content://song/1","a",1600)),"duplicate detail is suppressed");
        check(pending.add(CoverQuality.request("content://song/1","b",1600)),"updated source can request fresh detail");
        check(CoverQuality.side(200,true)==1600&&CoverQuality.side(900,false)==640&&CoverQuality.side(1200,false)==1600,"quality follows focused and visible size");
        check(CoverQuality.side(200,false)==256&&CoverQuality.side(400,false)==512,"small tiles do not allocate full-size textures");
        check(CoverQuality.repairSmall(96,false),"old tiny disk cover gets one source repair");
        check(!CoverQuality.repairSmall(96,true),"intrinsically tiny source is not reread every startup");
        check(!CoverQuality.repairSmall(1600,false),"existing high quality cache is retained");
        System.out.println("PASS: in-flight previews cannot block detail, source changes invalidate requests, tiny covers repair once and high quality cache is retained");
    }
}
