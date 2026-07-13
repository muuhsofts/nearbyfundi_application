# android/app/proguard-rules.pro

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# Keep notification classes
-keep class com.example.nearbyfundi.** { *; }

# Keep Kotlin metadata
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata {
    public *;
}

# Keep desugared classes
-keep class com.android.tools.** { *; }

# Keep all classes that implement Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Don't warn about missing AndroidX classes
-dontwarn android.**
-dontwarn androidx.**
# Play Core (Flutter deferred components reference these even if unused)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
