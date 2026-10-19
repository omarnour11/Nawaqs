# R8 keep rules for Nawakes (Flutter, RTL Arabic UI).
#
# The Flutter engine and plugins ship their own consumer rules; these cover
# reflection-based paths that R8 cannot see. Keep this list narrowly scoped —
# broad `-keep class **` rules defeat shrinking.

# Flutter embedding + plugin registration
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_secure_storage (JNI / reflection on Android Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# mobile_scanner / ML Kit barcode + text recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# google_maps_flutter
-keep class com.google.android.gms.maps.** { *; }
-keep class io.flutter.plugins.googlemaps.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep annotation + signature metadata needed by reflective serializers
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*, RuntimeVisibleAnnotations

# Preserve source file/line info for readable crash reports
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# Suppress warnings for optional dependencies of bundled libraries
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
-dontwarn kotlin.**
