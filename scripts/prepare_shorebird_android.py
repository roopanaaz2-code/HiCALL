#!/usr/bin/env python3
"""Prepare Flutter-generated Android files for HiCALL's Shorebird builds."""
from pathlib import Path

MIRROR = 'maven { url = uri("https://maven-central-eu.storage-download.googleapis.com/maven2/") }'

def add_repository(path: Path) -> None:
    if not path.exists():
        return
    text = path.read_text()
    if "maven-central-eu.storage-download.googleapis.com" not in text:
        text = text.replace("repositories {", "repositories {\n        " + MIRROR, 1)
    path.write_text(text)

settings = Path("android/settings.gradle.kts")
if not settings.exists():
    raise SystemExit("Missing generated android/settings.gradle.kts")
text = settings.read_text()
plugin_marker = 'id("com.google.gms.google-services") version "4.4.4" apply false'
if plugin_marker not in text:
    text = text.replace("plugins {", "plugins {\n    " + plugin_marker, 1)
settings.write_text(text)
add_repository(settings)
add_repository(Path("android/build.gradle.kts"))

app = Path("android/app/build.gradle.kts")
if not app.exists():
    raise SystemExit("Missing generated android/app/build.gradle.kts")
app_text = app.read_text()
google_plugin = 'id("com.google.gms.google-services")'
if google_plugin not in app_text:
    app_text = app_text.replace("plugins {", "plugins {\n    " + google_plugin, 1)

imports = "import java.io.FileInputStream\nimport java.util.Properties\n"
if "import java.util.Properties" not in app_text:
    app_text = imports + app_text
properties_block = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    throw GradleException("Android release signing key.properties is required")
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

"""
if "val keystoreProperties = Properties()" not in app_text:
    plugins_start = app_text.find("plugins {")
    if plugins_start < 0:
        raise SystemExit("Generated Gradle template has no plugins block")
    plugins_end = app_text.find("\\n}", plugins_start)
    if plugins_end < 0:
        raise SystemExit("Unable to locate end of generated plugins block")
    plugins_end += 2
    app_text = app_text[:plugins_end] + "\\n\\n" + properties_block + app_text[plugins_end:]

signing_block = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

"""
if 'create("release")' not in app_text:
    if "    buildTypes {" not in app_text:
        raise SystemExit("Unrecognized Flutter Gradle template: buildTypes block missing")
    app_text = app_text.replace("    buildTypes {", signing_block + "    buildTypes {", 1)
debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
if debug_signing in app_text:
    app_text = app_text.replace(debug_signing, 'signingConfig = signingConfigs.getByName("release")')
elif 'signingConfig = signingConfigs.getByName("release")' not in app_text:
    raise SystemExit("Unrecognized Flutter Gradle template: release signing line missing")
app.write_text(app_text)

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit("Missing generated AndroidManifest.xml")
manifest_text = manifest.read_text()
permissions = [
    '    <uses-permission android:name="android.permission.INTERNET"/>',
    '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>',
    '    <uses-permission android:name="android.permission.CAMERA"/>',
    '    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>',
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '    <uses-permission android:name="android.permission.WAKE_LOCK"/>',
    '    <uses-feature android:name="android.hardware.camera" android:required="false"/>',
    '    <uses-feature android:name="android.hardware.microphone" android:required="false"/>',
]
for item in permissions:
    if item not in manifest_text:
        manifest_text = manifest_text.replace("<application", item + "\n    <application", 1)
manifest_text = manifest_text.replace('android:label="hicall"', 'android:label="HiCALL"')
deep_link = """            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="hicall" android:host="auth-callback" />
            </intent-filter>"""
if 'android:scheme="hicall"' not in manifest_text:
    manifest_text = manifest_text.replace("</activity>", deep_link + "\n        </activity>", 1)
manifest.write_text(manifest_text)

if not Path("firebase/google-services.json").is_file():
    raise SystemExit("firebase/google-services.json is missing")
Path("android/app/google-services.json").write_bytes(Path("firebase/google-services.json").read_bytes())
print("Android Firebase, Gradle, manifest, and persistent release-signing configuration prepared.")
