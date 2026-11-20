#!/bin/bash
set -e

mkdir -p app/src/main/res/drawable app/src/main/res/mipmap-anydpi-v26

# 1. Clean Teal Clock-Face Foreground (Centered in 108x108 Adaptive Safe Zone)
cat << 'INNER' > app/src/main/res/drawable/ic_launcher_foreground.xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:strokeColor="#26A69A"
        android:strokeWidth="3.2"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M 54,28 C 42,28 33,39.5 33,54 C 33,68.5 42,80 54,80 C 66,80 75,68.5 75,54 C 75,39.5 66,28 54,28 Z" />
    <path
        android:strokeColor="#26A69A"
        android:strokeWidth="3.2"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M 47,46 L 54,58 L 64,40" />
    <path
        android:strokeColor="#26A69A"
        android:strokeWidth="3.2"
        android:strokeLineCap="round"
        android:pathData="M 39,53 L 43,53" />
    <path
        android:strokeColor="#26A69A"
        android:strokeWidth="3.2"
        android:strokeLineCap="round"
        android:pathData="M 65,53 L 69,53" />
    <path
        android:strokeColor="#26A69A"
        android:strokeWidth="3.2"
        android:strokeLineCap="round"
        android:pathData="M 46,68 C 48.5,71.5 59.5,71.5 62,68" />
</vector>
INNER

# 2. Adaptive Icon with Fully Transparent Background
cat << 'INNER' > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/transparent" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
INNER

cp app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml

# 3. Clean AndroidManifest.xml (Removes any duplicate attributes)
cat << 'INNER' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:label="Skedulr"
        android:supportsRtl="true"
        android:theme="@style/Theme.Skedar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="skedar" android:host="next" />
            </intent-filter>
        </activity>

        <receiver
            android:name=".SkedarWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="android.appwidget.action.APPWIDGET_OPTIONS_CHANGED" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/skedar_widget_info" />
        </receiver>

    </application>
</manifest>
INNER

# 4. Bump versionCode to 8 in app/build.gradle
sed -i 's/versionCode 7/versionCode 8/g' app/build.gradle
sed -i 's/versionName "2.0"/versionName "2.1"/g' app/build.gradle

echo "Icon fix applied!"
