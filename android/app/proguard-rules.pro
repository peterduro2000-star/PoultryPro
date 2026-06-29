# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Google Play Billing (in_app_purchase)
-keep class com.android.billingclient.** { *; }
-keep class com.android.billingclient.api.** { *; }

# Play Core removed — no longer a dependency
-dontwarn com.google.android.play.core.**

# Supabase
-keep class io.supabase.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Shared Preferences
-keep class androidx.security.crypto.** { *; }

# Prevent obfuscation of model fields used by database/serialization
-keepclassmembers class * {
    @androidx.room.* <fields>;
    @com.google.gson.annotations.* <fields>;
}
