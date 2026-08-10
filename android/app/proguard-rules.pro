# Retain generic signatures for Gson
-keepattributes Signature
-keepattributes *Annotation*

# Retain generic signatures of TypeToken and its subclasses
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Keep Gson-related classes to prevent them from being stripped or renamed
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep flutter_local_notifications classes and generic signatures
-keep class com.dexterous.flutterlocalnotifications.** { *; }
