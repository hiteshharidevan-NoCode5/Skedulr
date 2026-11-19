#!/bin/bash
set -e

mkdir -p .github/workflows
mkdir -p app/src/main/java/com/nocode5/skedar
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/xml

# 1. Root Gradle & Settings
cat << 'INNER' > settings.gradle
rootProject.name = "Skedar"
include ':app'
INNER

cat << 'INNER' > build.gradle
plugins {
    id 'com.android.application' version '8.2.2' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.22' apply false
}
INNER

cat << 'INNER' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
INNER

# 2. App Build Gradle (Outputs Skedar.apk)
cat << 'INNER' > app/build.gradle
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.nocode5.skedar'
    compileSdk 34

    defaultConfig {
        applicationId "com.nocode5.skedar"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0"
        setProperty("archivesBaseName", "Skedar")
    }

    buildTypes {
        release {
            minifyEnabled false
            signingConfig signingConfigs.debug
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
}
INNER

# 3. AndroidManifest.xml (Calendar Read + Widget + Assistant Query Support)
cat << 'INNER' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_CALENDAR" />

    <application
        android:allowBackup="true"
        android:label="Skedar"
        android:supportsRtl="true"
        android:theme="@style/Theme.Skedar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <!-- Assistant / Voice Query Intent Filter -->
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
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/skedar_widget_info" />
        </receiver>

    </application>
</manifest>
INNER

# 4. Widget Metadata
cat << 'INNER' > app/src/main/res/xml/skedar_widget_info.xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_skedar"
    android:minWidth="180dp"
    android:minHeight="180dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
INNER

# 5. Minimal Monochrome Theme
cat << 'INNER' > app/src/main/res/values/styles.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.Skedar" parent="Theme.MaterialComponents.DayNight.NoActionBar">
        <item name="colorPrimary">#FFFFFF</item>
        <item name="colorPrimaryVariant">#CCCCCC</item>
        <item name="colorOnPrimary">#000000</item>
        <item name="android:windowBackground">#0D0D0D</item>
        <item name="android:textColor">#FFFFFF</item>
    </style>
</resources>
INNER

# 6. Widget Layout (Canvas ImageView for True Freeform Shapes)
cat << 'INNER' > app/src/main/res/layout/widget_skedar.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@android:color/transparent">

    <ImageView
        android:id="@+id/widget_canvas"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:scaleType="fitCenter"
        android:contentDescription="Skedar Calendar Widget" />
</FrameLayout>
INNER

# 7. Settings & "What's Next" Screen Layout
cat << 'INNER' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#0D0D0D"
    android:padding="24dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical">

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="SKEDAR"
            android:textSize="28sp"
            android:textStyle="bold"
            android:letterSpacing="0.15"
            android:textColor="#FFFFFF" />

        <TextView
            android:id="@+id/tv_next_event"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="16dp"
            android:padding="16dp"
            android:background="#1A1A1A"
            android:text="Checking next event or chore..."
            android:textColor="#E0E0E0"
            android:textSize="14sp" />

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="28dp"
            android:text="SHAPE OF THE DAY"
            android:textSize="12sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <RadioGroup
            android:id="@+id/rg_shapes"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp">

            <RadioButton android:id="@+id/rb_square" android:text="Square" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_rectangle" android:text="Rectangle" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_circle" android:text="Circle" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_triangle" android:text="Triangle" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_hexagon" android:text="Hexagon" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
        </RadioGroup>

        <TextView
            android:id="@+id/tv_alpha_label"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:text="BACKGROUND OPACITY: 30%"
            android:textSize="12sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <SeekBar
            android:id="@+id/sb_opacity"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:max="100"
            android:progress="30" />

        <CheckBox
            android:id="@+id/cb_show_events"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="20dp"
            android:text="Highlight days with Calendar Events / To-Dos"
            android:textColor="#FFFFFF"
            android:checked="true" />

        <Button
            android:id="@+id/btn_apply"
            android:layout_width="match_parent"
            android:layout_height="52dp"
            android:layout_marginTop="28dp"
            android:text="APPLY TO WIDGET"
            android:backgroundTint="#FFFFFF"
            android:textColor="#000000"
            android:textStyle="bold" />

    </LinearLayout>
</ScrollView>
INNER

# 8. Calendar & Event Helper (Reads local Android Calendar & Next Chore)
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/CalendarHelper.kt
package com.nocode5.skedar

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.*

object CalendarHelper {

    fun hasPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun getEventDaysInMonth(context: Context, year: Int, month: Int): Set<Int> {
        val eventDays = mutableSetOf<Int>()
        if (!hasPermission(context)) return eventDays

        val calStart = Calendar.getInstance().apply {
            set(year, month, 1, 0, 0, 0)
        }
        val calEnd = Calendar.getInstance().apply {
            set(year, month, getActualMaximum(Calendar.DAY_OF_MONTH), 23, 59, 59)
        }

        val projection = arrayOf(CalendarContract.Events.DTSTART)
        val selection = "${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTSTART} <= ?"
        val selectionArgs = arrayOf(calStart.timeInMillis.toString(), calEnd.timeInMillis.toString())

        try {
            context.contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection, selection, selectionArgs, null
            )?.use { cursor ->
                val tempCal = Calendar.getInstance()
                while (cursor.moveToNext()) {
                    val startMillis = cursor.getLong(0)
                    tempCal.timeInMillis = startMillis
                    eventDays.add(tempCal.get(Calendar.DAY_OF_MONTH))
                }
            }
        } catch (_: Exception) {}
        return eventDays
    }

    fun getNextEventSummary(context: Context): String {
        if (!hasPermission(context)) {
            return "Calendar permission needed to read your next event or chore."
        }
        val now = System.currentTimeMillis()
        val projection = arrayOf(CalendarContract.Events.TITLE, CalendarContract.Events.DTSTART)
        val selection = "${CalendarContract.Events.DTSTART} >= ?"
        val selectionArgs = arrayOf(now.toString())
        val sortOrder = "${CalendarContract.Events.DTSTART} ASC LIMIT 1"

        try {
            context.contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection, selection, selectionArgs, sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val title = cursor.getString(0) ?: "Untitled Event"
                    val start = cursor.getLong(1)
                    val fmt = SimpleDateFormat("EEE, d MMM • h:mm a", Locale.getDefault())
                    return "NEXT UP:\n$title\n${fmt.format(Date(start))}"
                }
            }
        } catch (_: Exception) {}
        return "NEXT UP:\nNo upcoming events or chores found."
    }
}
INNER

# 9. Widget Provider (Draws Freeform Shapes + Calendar Grid on Transparent Canvas)
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/SkedarWidgetProvider.kt
package com.nocode5.skedar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class SkedarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SkedarWidgetProvider::class.java))
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
            val shape = prefs.getString("shape", "SQUARE") ?: "SQUARE"
            val opacity = prefs.getInt("opacity", 30)
            val showEvents = prefs.getBoolean("show_events", true)

            val bitmap = renderCalendarBitmap(context, shape, opacity, showEvents)
            val views = RemoteViews(context.packageName, R.layout.widget_skedar)
            views.setImageViewBitmap(R.id.widget_canvas, bitmap)

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }

        private fun renderCalendarBitmap(context: Context, shape: String, opacityPercent: Int, showEvents: Boolean): Bitmap {
            val width = if (shape == "RECTANGLE") 720 else 600
            val height = if (shape == "RECTANGLE") 460 else 600
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val path = Path()
            val cx = width / 2f
            val cy = height / 2f
            val pad = 12f

            when (shape) {
                "CIRCLE" -> {
                    val radius = min(cx, cy) - pad
                    path.addCircle(cx, cy, radius, Path.Direction.CW)
                }
                "TRIANGLE" -> {
                    path.moveTo(cx, pad)
                    path.lineTo(width - pad, height - pad)
                    path.lineTo(pad, height - pad)
                    path.close()
                }
                "HEXAGON" -> {
                    val radius = min(cx, cy) - pad
                    for (i in 0 until 6) {
                        val angle = Math.toRadians((60 * i - 30).toDouble())
                        val x = (cx + radius * cos(angle)).toFloat()
                        val y = (cy + radius * sin(angle)).toFloat()
                        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                    }
                    path.close()
                }
                else -> { // SQUARE or RECTANGLE
                    val rect = RectF(pad, pad, width - pad, height - pad)
                    path.addRoundRect(rect, 36f, 36f, Path.Direction.CW)
                }
            }

            // Fill background with chosen transparency
            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 15, 15, 15)
                style = Paint.Style.FILL
            }
            canvas.drawPath(path, bgPaint)

            // Crisp minimal border
            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(180, 255, 255, 255)
                style = Paint.Style.STROKE
                strokeWidth = 3f
            }
            canvas.drawPath(path, borderPaint)

            // Draw Calendar Grid centered inside safe area
            val cal = Calendar.getInstance()
            val today = cal.get(Calendar.DAY_OF_MONTH)
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH)
            val eventDays = if (showEvents) CalendarHelper.getEventDaysInMonth(context, year, month) else emptySet()

            val monthTitle = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time).uppercase()
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 26f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val topOffset = if (shape == "TRIANGLE") height * 0.42f else height * 0.22f
            canvas.drawText(monthTitle, cx, topOffset, titlePaint)

            val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 22f
                textAlign = Paint.Align.CENTER
            }
            val todayBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                style = Paint.Style.FILL
            }
            val todayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.BLACK
                textSize = 22f
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#FFD54F")
                style = Paint.Style.FILL
            }

            cal.set(Calendar.DAY_OF_MONTH, 1)
            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

            val gridWidth = if (shape == "TRIANGLE") width * 0.48f else width * 0.68f
            val startX = cx - (gridWidth / 2f)
            val colStep = gridWidth / 6f
            val rowStep = if (shape == "TRIANGLE") 34f else 42f
            var currentY = topOffset + 45f

            var col = firstDayOfWeek
            for (day in 1..daysInMonth) {
                val x = startX + (col * colStep)
                if (day == today) {
                    canvas.drawCircle(x, currentY - 8f, 17f, todayBgPaint)
                    canvas.drawText(day.toString(), x, currentY, todayTextPaint)
                } else {
                    canvas.drawText(day.toString(), x, currentY, dayPaint)
                }
                if (eventDays.contains(day)) {
                    canvas.drawCircle(x, currentY + 10f, 3.5f, dotPaint)
                }
                col++
                if (col > 6) {
                    col = 0
                    currentY += rowStep
                }
            }

            return bitmap
        }
    }
}
INNER

# 10. MainActivity (Minimal Settings Screen + Assistant Speech/Prompt Output)
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/MainActivity.kt
package com.nocode5.skedar

import android.Manifest
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private var tts: TextToSpeech? = null

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ ->
        refreshNextEvent()
        SkedarWidgetProvider.updateAllWidgets(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val prefs = getSharedPreferences("skedar_prefs", MODE_PRIVATE)
        val rgShapes = findViewById<RadioGroup>(R.id.rg_shapes)
        val sbOpacity = findViewById<SeekBar>(R.id.sb_opacity)
        val tvAlphaLabel = findViewById<TextView>(R.id.tv_alpha_label)
        val cbShowEvents = findViewById<CheckBox>(R.id.cb_show_events)
        val btnApply = findViewById<Button>(R.id.btn_apply)

        // Load saved state
        when (prefs.getString("shape", "SQUARE")) {
            "RECTANGLE" -> rgShapes.check(R.id.rb_rectangle)
            "CIRCLE" -> rgShapes.check(R.id.rb_circle)
            "TRIANGLE" -> rgShapes.check(R.id.rb_triangle)
            "HEXAGON" -> rgShapes.check(R.id.rb_hexagon)
            else -> rgShapes.check(R.id.rb_square)
        }

        val savedOpacity = prefs.getInt("opacity", 30)
        sbOpacity.progress = savedOpacity
        tvAlphaLabel.text = "BACKGROUND OPACITY: $savedOpacity%"
        cbShowEvents.isChecked = prefs.getBoolean("show_events", true)

        sbOpacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tvAlphaLabel.text = "BACKGROUND OPACITY: $progress%"
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        btnApply.setOnClickListener {
            val selectedShape = when (rgShapes.checkedRadioButtonId) {
                R.id.rb_rectangle -> "RECTANGLE"
                R.id.rb_circle -> "CIRCLE"
                R.id.rb_triangle -> "TRIANGLE"
                R.id.rb_hexagon -> "HEXAGON"
                else -> "SQUARE"
            }
            prefs.edit()
                .putString("shape", selectedShape)
                .putInt("opacity", sbOpacity.progress)
                .putBoolean("show_events", cbShowEvents.isChecked)
                .apply()

            SkedarWidgetProvider.updateAllWidgets(this)
            Toast.makeText(this, "Skedar updated ($selectedShape)", Toast.LENGTH_SHORT).show()
        }

        if (!CalendarHelper.hasPermission(this)) {
            requestPermissionLauncher.launch(Manifest.permission.READ_CALENDAR)
        } else {
            refreshNextEvent()
        }

        // If launched via assistant deep-link (skedar://next), speak the next chore aloud
        if (intent?.data?.host == "next") {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.getDefault()
                    val summary = CalendarHelper.getNextEventSummary(this).replace("\n", ". ")
                    tts?.speak(summary, TextToSpeech.QUEUE_FLUSH, null, "skedar_next")
                }
            }
        }
    }

    private fun refreshNextEvent() {
        val tvNext = findViewById<TextView>(R.id.tv_next_event)
        tvNext.text = CalendarHelper.getNextEventSummary(this)
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
INNER

# 11. GitHub Actions Workflow (Builds Skedar.apk & Skedar.zip automatically)
cat << 'INNER' > .github/workflows/build_skedar.yml
name: Build Skedar APK and ZIP

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Source
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3
        with:
          gradle-version: '8.5'

      - name: Build Skedar APK
        run: gradle assembleDebug

      - name: Package Skedar.apk and Skedar.zip
        run: |
          mkdir -p release_out
          cp app/build/outputs/apk/debug/Skedar-debug.apk release_out/Skedar.apk
          zip -r release_out/Skedar.zip app build.gradle settings.gradle gradle.properties release_out/Skedar.apk

      - name: Upload Skedar Build Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: Skedar-Release
          path: |
            release_out/Skedar.apk
            release_out/Skedar.zip
INNER

echo "Skedar files generated successfully!"
