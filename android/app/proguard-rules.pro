# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep all classes that might be accessed via reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Keep the application class
-keep public class * extends android.app.Application
-keep public class * extends androidx.multidex.MultiDexApplication

# Keep the FlutterActivity
-keep public class io.flutter.app.FlutterActivity
-keep public class io.flutter.embedding.android.FlutterActivity
-keep public class io.flutter.embedding.android.FlutterFragmentActivity

# Keep the FlutterView
-keep class io.flutter.view.FlutterView { *; }

# Keep the FlutterMain class
-keep class io.flutter.view.FlutterMain { *; }

# Keep the FlutterJNI class
-keep class io.flutter.embedding.engine.FlutterJNI { *; }

# Keep the FlutterEngine class
-keep class io.flutter.embedding.engine.FlutterEngine { *; }

# Keep the FlutterLoader class
-keep class io.flutter.embedding.engine.loader.FlutterLoader { *; }

# Keep the FlutterShellArgs class
-keep class io.flutter.embedding.engine.FlutterShellArgs { *; }

# Keep the FlutterInjector class
-keep class io.flutter.FlutterInjector { *; }

# Keep the GeneratedPluginRegistrant class
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep the Flutter plugins
-keep class * extends io.flutter.plugin.common.PluginRegistry$GeneratedPluginRegistrant
-keep class * extends io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback

# Keep the Flutter platform channels
-keep class * extends io.flutter.plugin.common.MethodCallHandler { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel { *; }
-keep class * extends io.flutter.plugin.common.EventChannel { *; }
-keep class * extends io.flutter.plugin.common.BasicMessageChannel { *; }

# Keep Play Core classes for Flutter deferred components
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallException { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManager { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManagerFactory { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest$Builder { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallSessionState { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.Task { *; }
