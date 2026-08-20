package com.netsaf.fundapp;

import android.os.Bundle;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String SECURITY_CHANNEL = "com.netsaf.security";
    private static final String BADGE_CHANNEL   = "com.fundiapp/badge";   // ← match the channel name used in Dart

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        enableSecureScreen();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Security Channel (Screenshot protection)
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SECURITY_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "enableSecureScreen":
                            enableSecureScreen();
                            result.success(true);
                            break;
                        case "disableSecureScreen":
                            disableSecureScreen();
                            result.success(true);
                            break;
                        case "isSecureScreenEnabled":
                            result.success(isSecureScreenEnabled());
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Badge Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BADGE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "setBadgeCount":
                            // Android has no universal badge API.
                            // Just acknowledge the call so the MissingPluginException disappears.
                            // (Real badge support is launcher-dependent – see notes below)
                            Integer count = call.argument("count");
                            // Optional: you can log it
                            // Log.d("Badge", "setBadgeCount called with: " + count);
                            result.success(true);
                            break;

                        case "removeBadge":
                        case "clearBadge":
                            result.success(true);
                            break;

                        case "getBadgeCount":
                            // You can return 0 or keep a local variable if you want
                            result.success(0);
                            break;

                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }

    // ============================================================
    // SECURITY METHODS (unchanged)
    // ============================================================
    private void enableSecureScreen() {
        runOnUiThread(() -> getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
        ));
    }

    private void disableSecureScreen() {
        runOnUiThread(() -> getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE));
    }

    private boolean isSecureScreenEnabled() {
        return (getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_SECURE) != 0;
    }

    @Override
    protected void onResume() {
        super.onResume();
        enableSecureScreen();
    }
}