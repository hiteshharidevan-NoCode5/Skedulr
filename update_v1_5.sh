#!/bin/bash
set -e

# 1. Bump version in app/build.gradle
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
        versionCode 6
        versionName "1.5"
        setProperty("archivesBaseName", "Skedulr")
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

# 2. Update AndroidManifest.xml (Register Month Navigation Broadcast Actions)
cat << 'INNER' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />

    <application
        android:allowBackup="true"
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
                <action android:name="com.nocode5.skedar.ACTION_PREV_MONTH" />
                <action android:name="com.nocode5.skedar.ACTION_NEXT_MONTH" />
                <action android:name="com.nocode5.skedar.ACTION_RESET_MONTH" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/skedar_widget_info" />
        </receiver>

    </application>
</manifest>
INNER

# 3. Update Widget Layout with Invisible Tap Zones for < Month > and Grid
cat << 'INNER' > app/src/main/res/layout/widget_skedar.xml
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@android:color/transparent">

    <ImageView
        android:id="@+id/widget_canvas"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:scaleType="fitXY"
        android:contentDescription="Skedulr Calendar Widget" />

    <LinearLayout
        android:id="@+id/header_tap_bar"
        android:layout_width="match_parent"
        android:layout_height="44dp"
        android:layout_alignParentTop="true"
        android:orientation="horizontal">

        <TextView
            android:id="@+id/btn_prev_month"
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_weight="1"
            android:background="@android:color/transparent"
            android:contentDescription="Previous Month" />

        <TextView
            android:id="@+id/btn_reset_month"
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_weight="1.5"
            android:background="@android:color/transparent"
            android:contentDescription="Reset to Current Month" />

        <TextView
            android:id="@+id/btn_next_month"
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_weight="1"
            android:background="@android:color/transparent"
            android:contentDescription="Next Month" />
    </LinearLayout>

    <TextView
        android:id="@+id/btn_open_settings"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:layout_below="@id/header_tap_bar"
        android:background="@android:color/transparent"
        android:contentDescription="Open Skedulr Settings" />

</RelativeLayout>
INNER

# 4. Update Widget Provider (Handles Month Offset + Subtle < > Arrows + Breathing Space)
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/SkedarWidgetProvider.kt
package com.nocode5.skedar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Bundle
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min

class SkedarWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
        val currentOffset = prefs.getInt("month_offset", 0)

        when (intent.action) {
            ACTION_PREV_MONTH -> {
                prefs.edit().putInt("month_offset", currentOffset - 1).apply()
                updateAllWidgets(context)
            }
            ACTION_NEXT_MONTH -> {
                prefs.edit().putInt("month_offset", currentOffset + 1).apply()
                updateAllWidgets(context)
            }
            ACTION_RESET_MONTH -> {
                prefs.edit().putInt("month_offset", 0).apply()
                updateAllWidgets(context)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    companion object {
        const val ACTION_PREV_MONTH = "com.nocode5.skedar.ACTION_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.nocode5.skedar.ACTION_NEXT_MONTH"
        const val ACTION_RESET_MONTH = "com.nocode5.skedar.ACTION_RESET_MONTH"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SkedarWidgetProvider::class.java))
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        private fun getActionPendingIntent(context: Context, action: String, reqCode: Int): PendingIntent {
            val intent = Intent(context, SkedarWidgetProvider::class.java).apply {
                this.action = action
            }
            return PendingIntent.getBroadcast(
                context, reqCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
            val shape = prefs.getString("shape", "HORIZONTAL") ?: "HORIZONTAL"
            val opacity = prefs.getInt("opacity", 30)
            val showEvents = prefs.getBoolean("show_events", true)
            val showHolidays = prefs.getBoolean("show_holidays", true)
            val textColorHex = prefs.getString("text_color", "#FFFFFF") ?: "#FFFFFF"
            val scalePercent = prefs.getInt("scale", 100)
            val monthOffset = prefs.getInt("month_offset", 0)

            val options = manager.getAppWidgetOptions(widgetId)
            val defaultW = if (shape == "VERTICAL") 200 else 320
            val defaultH = if (shape == "VERTICAL") 340 else 200
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, defaultW).coerceAtLeast(110)
            val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, defaultH).coerceAtLeast(110)

            val aspect = minW.toFloat() / maxH.toFloat()
            val pxW: Int
            val pxH: Int
            if (aspect >= 1f) {
                pxW = 720
                pxH = (720f / aspect).toInt().coerceIn(280, 720)
            } else {
                pxH = 720
                pxW = (720f * aspect).toInt().coerceIn(280, 720)
            }

            val bitmap = renderCalendarBitmap(
                context, pxW, pxH, shape, opacity, showEvents, showHolidays, textColorHex, scalePercent, monthOffset
            )
            val views = RemoteViews(context.packageName, R.layout.widget_skedar)
            views.setImageViewBitmap(R.id.widget_canvas, bitmap)

            views.setOnClickPendingIntent(R.id.btn_prev_month, getActionPendingIntent(context, ACTION_PREV_MONTH, 101))
            views.setOnClickPendingIntent(R.id.btn_reset_month, getActionPendingIntent(context, ACTION_RESET_MONTH, 102))
            views.setOnClickPendingIntent(R.id.btn_next_month, getActionPendingIntent(context, ACTION_NEXT_MONTH, 103))

            val settingsIntent = Intent(context, MainActivity::class.java)
            val settingsPending = PendingIntent.getActivity(
                context, 0, settingsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_open_settings, settingsPending)

            manager.updateAppWidget(widgetId, views)
        }

        private fun renderCalendarBitmap(
            context: Context,
            width: Int,
            height: Int,
            shape: String,
            opacityPercent: Int,
            showEvents: Boolean,
            showHolidays: Boolean,
            textColorHex: String,
            scalePercent: Int,
            monthOffset: Int
        ): Bitmap {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val pad = 8f
            val rect = RectF(pad, pad, width - pad, height - pad)
            val path = Path().apply {
                addRoundRect(rect, 28f, 28f, Path.Direction.CW)
            }

            val parsedTextColor = try { Color.parseColor(textColorHex) } catch (_: Exception) { Color.WHITE }
            val shadowColor = if (parsedTextColor == Color.BLACK) Color.argb(190, 255, 255, 255) else Color.argb(215, 0, 0, 0)

            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 15, 15, 15)
                style = Paint.Style.FILL
            }
            canvas.drawPath(path, bgPaint)

            val nowCal = Calendar.getInstance()
            val realToday = nowCal.get(Calendar.DAY_OF_MONTH)
            val realMonth = nowCal.get(Calendar.MONTH)
            val realYear = nowCal.get(Calendar.YEAR)

            val cal = Calendar.getInstance().apply {
                set(Calendar.DAY_OF_MONTH, 1)
                add(Calendar.MONTH, monthOffset)
            }
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH)
            val isCurrentMonth = (year == realYear && month == realMonth)

            val eventDays = if (showEvents) CalendarHelper.getEventDaysInMonth(context, year, month) else emptySet()
            val holidayMap = if (showHolidays) HolidayRepository.getHolidayDaysInMonth(year, month) else emptyMap()

            val scaleFactor = (scalePercent / 100f).coerceIn(0.6f, 1.4f)
            val refDim = min(width, height).toFloat()
            val titleSize = (refDim * 0.062f * scaleFactor).coerceIn(16f, 44f)
            val daySize = (refDim * 0.052f * scaleFactor).coerceIn(13f, 38f)

            val cx = width / 2f
            val monthTitle = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time).uppercase()
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                textSize = titleSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(5f, 0f, 2f, shadowColor)
            }
            val arrowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                this.alpha = 180
                textSize = titleSize * 0.95f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(4f, 0f, 1f, shadowColor)
            }

            val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                textSize = daySize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(5f, 0f, 2f, shadowColor)
            }
            val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                this.alpha = 180
                textSize = daySize * 0.78f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(4f, 0f, 1f, shadowColor)
            }
            val todayBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                style = Paint.Style.FILL
                setShadowLayer(4f, 0f, 1f, shadowColor)
            }
            val todayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (parsedTextColor == Color.BLACK) Color.WHITE else Color.BLACK
                textSize = daySize
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                setShadowLayer(3f, 0f, 1f, Color.BLACK)
            }

            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val dayInitials = arrayOf("S", "M", "T", "W", "T", "F", "S")

            val usableW = (width * 0.84f * scaleFactor).coerceAtMost(width * 0.92f)
            val usableH = (height * 0.76f * scaleFactor).coerceAtMost(height * 0.88f)
            val topHeaderY = (height - usableH) / 2f + titleSize * 0.6f
            val gridLeft = cx - usableW / 2f
            val gridRight = cx + usableW / 2f

            // Draw <   MONTH YEAR   >
            canvas.drawText("‹", gridLeft + titleSize * 0.35f, topHeaderY, arrowPaint)
            canvas.drawText(monthTitle, cx, topHeaderY, titlePaint)
            canvas.drawText("›", gridRight - titleSize * 0.35f, topHeaderY, arrowPaint)

            val gridTop = topHeaderY + titleSize * 2.1f
            val gridBottom = height - (height - usableH) / 2f
            val gridHeight = (gridBottom - gridTop).coerceAtLeast(100f)

            if (shape == "VERTICAL") {
                val totalWeeks = ((firstDayOfWeek + daysInMonth + 6) / 7).coerceIn(4, 6)
                val totalCols = totalWeeks + 1
                val colStep = usableW / (totalCols - 1).coerceAtLeast(1)
                val rowStep = gridHeight / 6f

                for (dow in 0..6) {
                    val y = gridTop + dow * rowStep
                    canvas.drawText(dayInitials[dow], gridLeft, y, labelPaint)
                }

                var weekCol = 1
                var dow = firstDayOfWeek
                for (day in 1..daysInMonth) {
                    val x = gridLeft + weekCol * colStep
                    val y = gridTop + dow * rowStep

                    if (isCurrentMonth && day == realToday) {
                        canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.76f, todayBgPaint)
                        canvas.drawText(day.toString(), x, y, todayTextPaint)
                    } else {
                        canvas.drawText(day.toString(), x, y, dayPaint)
                    }

                    val hType = holidayMap[day]
                    val hasPersonal = eventDays.contains(day)
                    if (hType != null || hasPersonal) {
                        dotPaint.color = when {
                            hType == "SABARIMALA" -> Color.parseColor("#FFD54F")
                            hType == "FESTIVAL" -> Color.parseColor("#FF8A65")
                            hType == "BANK_COURT" -> Color.parseColor("#4FC3F7")
                            else -> Color.parseColor("#81C784")
                        }
                        canvas.drawCircle(x, y + (daySize * 0.44f), max(3.5f, daySize * 0.16f), dotPaint)
                    }

                    dow++
                    if (dow > 6) {
                        dow = 0
                        weekCol++
                    }
                }
            } else {
                val colStep = usableW / 6f
                val totalRows = ((firstDayOfWeek + daysInMonth + 6) / 7) + 1
                val rowStep = gridHeight / (totalRows - 1).coerceAtLeast(1)

                for (c in 0..6) {
                    val x = gridLeft + c * colStep
                    canvas.drawText(dayInitials[c], x, gridTop, labelPaint)
                }

                var row = 1
                var col = firstDayOfWeek
                for (day in 1..daysInMonth) {
                    val x = gridLeft + col * colStep
                    val y = gridTop + row * rowStep

                    if (isCurrentMonth && day == realToday) {
                        canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.76f, todayBgPaint)
                        canvas.drawText(day.toString(), x, y, todayTextPaint)
                    } else {
                        canvas.drawText(day.toString(), x, y, dayPaint)
                    }

                    val hType = holidayMap[day]
                    val hasPersonal = eventDays.contains(day)
                    if (hType != null || hasPersonal) {
                        dotPaint.color = when {
                            hType == "SABARIMALA" -> Color.parseColor("#FFD54F")
                            hType == "FESTIVAL" -> Color.parseColor("#FF8A65")
                            hType == "BANK_COURT" -> Color.parseColor("#4FC3F7")
                            else -> Color.parseColor("#81C784")
                        }
                        canvas.drawCircle(x, y + (daySize * 0.44f), max(3.5f, daySize * 0.16f), dotPaint)
                    }

                    col++
                    if (col > 6) {
                        col = 0
                        row++
                    }
                }
            }

            return bitmap
        }
    }
}
INNER

echo "Skedulr v1.5 month navigation ready!"
