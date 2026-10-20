package com.xcosmos.minivoice;

/** Thumbnail and detail requests must never suppress each other. */
final class CoverQuality {
    static int side(float screenSide,boolean focused){return focused||screenSide>960?1600:640;}
    static String request(String uri,String version,int side){return uri+"\n"+version+"\n"+side;}
    static boolean repairSmall(int storedSide,boolean checked){return !checked&&storedSide<=512;}
}
