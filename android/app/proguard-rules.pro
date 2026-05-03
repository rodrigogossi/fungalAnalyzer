# TensorFlow Lite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# tflite_flutter plugin
-keep class com.tfliteflutter.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }
