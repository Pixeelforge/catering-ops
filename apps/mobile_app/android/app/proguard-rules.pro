# Basic ProGuard rules for Flutter
# If you have specific libraries that require ProGuard rules, add them here.

-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Avoid shrinking Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Jackson JSON
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# OpenTelemetry (often used by Supabase/gRPC)
-keep class io.opentelemetry.** { *; }
-dontwarn io.opentelemetry.**

# Google AutoValue
-keep class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**
