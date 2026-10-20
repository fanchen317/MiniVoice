package com.xcosmos.minivoice;

/** Same whitening coefficients as the Mac CoverPalette. No Android dependency. */
final class CoverAtmosphereColors {
    static int bright(int rgb){return soften(rgb,.38f);}
    static int soft(int rgb){return soften(rgb,.20f);}
    private static int soften(int rgb,float amount){int r=Math.round(((rgb>>16)&255)*amount+255*(1-amount)),g=Math.round(((rgb>>8)&255)*amount+255*(1-amount)),b=Math.round((rgb&255)*amount+255*(1-amount));return 0xFF000000|(r<<16)|(g<<8)|b;}
}
