# Basic ProGuard rules for Flutter
# If you have specific libraries that require ProGuard rules, add them here.

# Jackson
-dontwarn com.fasterxml.jackson.**
-keep class com.fasterxml.jackson.** { *; }

# OpenTelemetry
-dontwarn io.opentelemetry.**
-keep class io.opentelemetry.** { *; }

# AutoValue
-dontwarn com.google.auto.value.**

# OneSignal (if used)
-dontwarn com.onesignal.**
-keep class com.onesignal.** { *; }
