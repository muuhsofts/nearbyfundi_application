// android/app/src/main/java/com/example/nearbyfundi/MainActivity.java

package com.example.nearbyfundi;

import android.content.Intent;
import android.os.Bundle;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.nearbyfundi/fcm";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleFCMIntent(getIntent());
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("getFCMToken")) {
                        SharedPreferences prefs = getSharedPreferences("fcm_prefs", MODE_PRIVATE);
                        String token = prefs.getString("fcm_token", null);
                        result.success(token);
                    } else if (call.method.equals("setFCMToken")) {
                        String token = call.argument("token");
                        if (token != null) {
                            SharedPreferences prefs = getSharedPreferences("fcm_prefs", MODE_PRIVATE);
                            prefs.edit().putString("fcm_token", token).apply();
                            result.success(true);
                        } else {
                            result.error("INVALID_TOKEN", "Token is null", null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleFCMIntent(intent);
    }

    private void handleFCMIntent(Intent intent) {
        if (intent != null && intent.getExtras() != null) {
            Bundle data = intent.getExtras();
            String requestId = data.getString("request_id");
            String notificationType = data.getString("type"); // Changed from 'type' to 'notificationType'
            String title = data.getString("title");
            String body = data.getString("body");

            if (requestId != null && notificationType != null) {
                // Forward to Flutter via MethodChannel
                FlutterEngine flutterEngine = getFlutterEngine();
                if (flutterEngine != null) {
                    // Create a HashMap instead of anonymous Object
                    java.util.HashMap<String, String> args = new java.util.HashMap<>();
                    args.put("request_id", requestId);
                    args.put("type", notificationType);
                    args.put("title", title != null ? title : "");
                    args.put("body", body != null ? body : "");

                    new MethodChannel(
                            flutterEngine.getDartExecutor().getBinaryMessenger(),
                            "com.example.nearbyfundi/deep_link"
                    ).invokeMethod("handleDeepLink", args);
                }
            }
        }
    }
}