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

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom classes that might be used by reflection
-keep class gym.com.** { *; }

# Keep Play Core classes for deferred components
-keep class com.google.android.play.** { *; }
-keep class com.android.tools.r8.** { *; }
-dontwarn com.google.android.play.**
-dontwarn com.android.tools.r8.**

