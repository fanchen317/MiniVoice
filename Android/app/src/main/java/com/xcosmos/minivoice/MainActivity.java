package com.xcosmos.minivoice;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/** Compatibility entry for shortcuts and pending intents created before 3.0.0. */
public final class MainActivity extends Activity {
    static final String ACTION_SHOW_SCAN="com.xcosmos.minivoice.SHOW_SCAN";
    static final String ACTION_LOCATE_PLAYING="com.xcosmos.minivoice.LOCATE_PLAYING";
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        startActivity(new Intent(getIntent()).setClass(this, PortablePlayerActivity.class)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP));
        finish();
    }
}
