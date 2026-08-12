// android/app/src/main/java/com/nearbyfundi/MainActivity.java
package com.example.nearbyfundi;

import android.content.Intent;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.nearbyfundi/fcm";
    private static final String SECURITY_CHANNEL = "com.nearbyfundi/security";
    private static final String DEEP_LINK_CHANNEL = "com.nearbyfundi/deep_link";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // ✅ Enable secure flag to prevent screenshots
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
        );

        handleFCMIntent(getIntent());
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // FCM Token Channel
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

        // Security Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SECURITY_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("enableSecureScreen")) {
                        enableSecureScreen();
                        result.success(true);
                    } else if (call.method.equals("disableSecureScreen")) {
                        disableSecureScreen();
                        result.success(true);
                    } else {
                        result.notImplemented();
                    }
                });

        // Deep Link Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DEEP_LINK_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("handleDeepLink")) {
                        String requestId = call.argument("request_id");
                        String type = call.argument("type");
                        String title = call.argument("title");
                        String body = call.argument("body");

                        android.util.Log.d("DeepLink", "Request ID: " + requestId + ", Type: " + type);
                        result.success(true);
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
            String notificationType = data.getString("type");
            String title = data.getString("title");
            String body = data.getString("body");

            if (requestId != null && notificationType != null) {
                FlutterEngine flutterEngine = getFlutterEngine();
                if (flutterEngine != null) {
                    java.util.HashMap<String, String> args = new java.util.HashMap<>();
                    args.put("request_id", requestId);
                    args.put("type", notificationType);
                    args.put("title", title != null ? title : "");
                    args.put("body", body != null ? body : "");

                    new MethodChannel(
                            flutterEngine.getDartExecutor().getBinaryMessenger(),
                            DEEP_LINK_CHANNEL
                    ).invokeMethod("handleDeepLink", args);
                }
            }
        }
    }

    private void enableSecureScreen() {
        runOnUiThread(() -> {
            getWindow().setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
            );
        });
    }

    private void disableSecureScreen() {
        runOnUiThread(() -> {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        enableSecureScreen();
    }
}