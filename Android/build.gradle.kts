// Umpire for Android: :shared (rules engine, plain Kotlin),
// :app (phone and tablet) and :wear (Wear OS).
plugins {
    id("com.android.application") version "9.5.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
    id("org.jetbrains.kotlin.jvm") version "2.2.10" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.10" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.10" apply false
}

// One version for both apps: Play needs the phone and watch apps to share the
// application ID, and it is simplest to keep their versions together too.
// The version name follows iOS. Build-number policy as on iOS: the code always
// holds the NEXT unused number; raise it straight after an upload.
extra["appVersionName"] = "1.6"
extra["appVersionCode"] = 2
