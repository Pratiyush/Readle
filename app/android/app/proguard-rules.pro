# Flutter plugins reached through JNI / reflection.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
# flutter_local_notifications (the daily reminder) stores scheduled reminders with Gson.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
# google_mobile_ads → play-services-ads → WorkManager + Room: R8 strips the generated database
# class and the release build crashes at launch without these.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-dontwarn com.google.android.gms.**
