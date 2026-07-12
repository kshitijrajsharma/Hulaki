# ML Kit finds its component registrars by reflection, from metadata in the
# merged manifest. R8 cannot see those constructors being called, strips them,
# and the barcode scanner then resolves to null at runtime, which breaks joining
# a group by QR code in release builds only.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.firebase.components.** { *; }
-dontwarn com.google.mlkit.**
