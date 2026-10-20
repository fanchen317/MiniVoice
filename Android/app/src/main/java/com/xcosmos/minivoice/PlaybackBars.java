package com.xcosmos.minivoice;

/** Shared waveform timing for the card badge and the compact dock. */
final class PlaybackBars {
    static float height(int bar,long time,boolean playing){
        if(!playing)return .38f;
        double phase=time/1000d*5.4+bar*1.9;
        return .3f+.7f*(float)((Math.sin(phase)+1)/2);
    }
}
