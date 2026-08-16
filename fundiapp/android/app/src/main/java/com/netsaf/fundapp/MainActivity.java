package com.netsaf.fundapp;

import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String BADGE_CHANNEL = "com.fundiapp/badge";
    private static final String SECURITY_CHANNEL = "com.netsaf.security";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        enableSecureScreen();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Badge Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BADGE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("setBadgeCount".equals(call.method)) {
                        Integer count = call.argument("count");
                        if (count == null) {
                            result.error("INVALID_ARGUMENT", "count is required", null);
                            return;
                        }
                        try {
                            setBadgeCount(count);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("BADGE_ERROR", e.getMessage(), null);
                        }
                    } else if ("removeBadge".equals(call.method)) {
                        try {
                            setBadgeCount(0);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("BADGE_ERROR", e.getMessage(), null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });

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
    }

    // ============================================================
    // SECURITY METHODS
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

    // ============================================================
    // BADGE METHODS
    // ============================================================

    private void setBadgeCount(int count) {
        String launcherPackage = getDefaultLauncherPackage();
        if (launcherPackage == null) {
            sendGenericBroadcast(count);
            return;
        }

        String pkg = launcherPackage.toLowerCase();

        try {
            if (pkg.contains("samsung") || pkg.contains("touchwiz")) {
                setSamsungBadge(count);
            } else if (pkg.contains("htc")) {
                setHtcBadge(count);
            } else if (pkg.contains("sonyericsson") || pkg.contains("sony")) {
                setSonyBadge(count);
            } else if (pkg.contains("huawei")) {
                setHuaweiBadge(count);
            } else if (pkg.contains("com.anddoes.launcher")) {
                setApexBadge(count);
            } else if (pkg.contains("teslacoilsw") || pkg.contains("nova")) {
                setNovaBadge(count);
            } else if (pkg.contains("solidlauncher")) {
                setSolidBadge(count);
            } else {
                sendGenericBroadcast(count);
            }
        } catch (Exception e) {
            sendGenericBroadcast(count);
        }
    }

    private String getDefaultLauncherPackage() {
        Intent intent = new Intent(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_HOME);
        PackageManager pm = getPackageManager();
        ResolveInfo resolveInfo = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
        return (resolveInfo != null && resolveInfo.activityInfo != null)
                ? resolveInfo.activityInfo.packageName
                : null;
    }

    private void sendGenericBroadcast(int count) {
        String launcherClassName = getLauncherClassName();
        if (launcherClassName == null) return;

        Intent intent = new Intent("android.intent.action.BADGE_COUNT_UPDATE");
        intent.putExtra("badge_count", count);
        intent.putExtra("badge_count_package_name", getPackageName());
        intent.putExtra("badge_count_class_name", launcherClassName);
        getApplicationContext().sendBroadcast(intent);
    }

    private void setSamsungBadge(int count) {
        String launcherClassName = getLauncherClassName();
        if (launcherClassName == null) return;

        sendGenericBroadcast(count);

        try {
            ContentValues values = new ContentValues();
            values.put("class", launcherClassName);
            values.put("package", getPackageName());
            values.put("badgecount", count);
            ContentResolver resolver = getContentResolver();
            Uri uri = Uri.parse("content://com.sec.badge/apps?notify=true");
            if (resolver.update(uri, values, "package=?", new String[]{getPackageName()}) == 0) {
                values.put("_id", getPackageName());
                resolver.insert(uri, values);
            }
        } catch (Exception ignored) {}
    }

    private void setHtcBadge(int count) {
        Intent intent1 = new Intent("com.htc.launcher.action.SET_NOTIFICATION");
        intent1.putExtra("com.htc.launcher.extra.COMPONENT",
                new ComponentName(getPackageName(), getLauncherClassName()).flattenToShortString());
        intent1.putExtra("com.htc.launcher.extra.COUNT", count);
        getApplicationContext().sendBroadcast(intent1);

        Intent intent2 = new Intent("com.htc.launcher.action.UPDATE_SHORTCUT");
        intent2.putExtra("packagename", getPackageName());
        intent2.putExtra("count", count);
        getApplicationContext().sendBroadcast(intent2);
    }

    private void setSonyBadge(int count) {
        String launcherClassName = getLauncherClassName();
        if (launcherClassName == null) return;

        Intent intent = new Intent("com.sonyericsson.home.action.UPDATE_BADGE");
        intent.putExtra("com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE", count > 0);
        intent.putExtra("com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME", launcherClassName);
        intent.putExtra("com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME", getPackageName());
        intent.putExtra("com.sonyericsson.home.intent.extra.badge.MESSAGE", String.valueOf(count));
        getApplicationContext().sendBroadcast(intent);
    }

    private void setHuaweiBadge(int count) {
        try {
            Bundle bundle = new Bundle();
            bundle.putString("package", getPackageName());
            bundle.putString("class", getLauncherClassName());
            bundle.putInt("badgenumber", count);
            getContentResolver().call(
                    Uri.parse("content://com.huawei.android.launcher.settings/badge/"),
                    "change_badge",
                    "",
                    bundle
            );
        } catch (Exception ignored) {}
    }

    private void setApexBadge(int count) {
        Intent intent = new Intent("com.anddoes.launcher.COUNTER_CHANGED");
        intent.putExtra("package", getPackageName());
        intent.putExtra("count", count);
        intent.putExtra("class", getLauncherClassName());
        getApplicationContext().sendBroadcast(intent);
    }

    private void setNovaBadge(int count) {
        Intent intent = new Intent("com.teslacoilsw.launcher.action.SET_COUNT");
        intent.putExtra("com.teslacoilsw.launcher.extra.KEY_PACKAGE", getPackageName());
        intent.putExtra("com.teslacoilsw.launcher.extra.COUNT", count);
        getApplicationContext().sendBroadcast(intent);
    }

    private void setSolidBadge(int count) {
        Intent intent = new Intent("com.majeur.launcher.CHANGE_BADGE");
        intent.putExtra("package", getPackageName());
        intent.putExtra("count", count);
        intent.putExtra("class", getLauncherClassName());
        getApplicationContext().sendBroadcast(intent);
    }

    private String getLauncherClassName() {
        Intent intent = new Intent(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_LAUNCHER);
        intent.setPackage(getPackageName());
        ComponentName componentName = intent.resolveActivity(getPackageManager());
        return componentName != null ? componentName.getClassName() : getClass().getName();
    }
}