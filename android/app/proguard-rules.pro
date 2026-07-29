# App-specific R8/ProGuard rules.
#
# Flutter's engine and the plugins we use ship their own consumer rules, so this
# file only needs to cover cases R8 cannot infer. Keep it minimal — every broad
# `-keep` gives back size.

# Plugins reached over the platform channels are looked up reflectively by the
# generated registrant; keep their entry points.
-keep class io.flutter.plugins.** { *; }

# Silence warnings for optional desugaring/annotation classes that are not on
# the runtime classpath. These are warnings only, not missing app code.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
