package com.xcosmos.minivoice;
public final class MiniVoiceApplication extends android.app.Application {
    @Override public void onCreate(){super.onCreate();Diagnostics.install(this);}
}
