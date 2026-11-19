#!/bin/bash
set -e

# 1. Update app/build.gradle (Outputs Skedlar.apk)
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
        versionCode 2
        versionName "1.1"
        setProperty("archivesBaseName", "Skedlar")
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

# 2. Update AndroidManifest.xml (Add WRITE_CALENDAR + App Name Skedlar)
cat << 'INNER' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />

    <application
        android:allowBackup="true"
        android:label="Skedlar"
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

# 3. Enable Full Vertical & Horizontal Resizing in Widget Info
cat << 'INNER' > app/src/main/res/xml/skedar_widget_info.xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_skedar"
    android:minWidth="140dp"
    android:minHeight="140dp"
    android:minResizeWidth="110dp"
    android:minResizeHeight="110dp"
    android:maxResizeWidth="600dp"
    android:maxResizeHeight="800dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
INNER

# 4. Update Widget Layout to Fill Resized Bounds Cleanly
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
        android:scaleType="fitXY"
        android:contentDescription="Skedlar Calendar Widget" />
</FrameLayout>
INNER

# 5. Built-in Indian Festivals, Bank/Court Holidays & Sabarimala Opening Dates
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/HolidayRepository.kt
package com.nocode5.skedar

import java.util.Calendar

data class HolidayInfo(
    val title: String,
    val type: String
)

object HolidayRepository {

    private val fixedDates = mapOf(
        "2026-01-01" to listOf(HolidayInfo("New Year's Day (Court/Bank)", "BANK_COURT")),
        "2026-01-14" to listOf(
            HolidayInfo("Makar Sankranti / Uttarayan / Pongal", "FESTIVAL"),
            HolidayInfo("Sabarimala Makaravilakku Festival", "SABARIMALA")
        ),
        "2026-01-20" to listOf(HolidayInfo("Sabarimala Temple Closes (Makaravilakku)", "SABARIMALA")),
        "2026-01-26" to listOf(HolidayInfo("Republic Day (National/Bank/Court)", "BANK_COURT")),
        "2026-02-12" to listOf(HolidayInfo("Sabarimala Opens - Kumbham Maasa Pooja", "SABARIMALA")),
        "2026-02-15" to listOf(HolidayInfo("Maha Shivaratri (Festival/Bank/Court)", "FESTIVAL")),
        "2026-02-17" to listOf(HolidayInfo("Sabarimala Closes - Kumbham Pooja", "SABARIMALA")),
        "2026-03-04" to listOf(HolidayInfo("Holi / Dhuleti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-03-14" to listOf(HolidayInfo("Sabarimala Opens - Meenam & Uthram", "SABARIMALA")),
        "2026-03-20" to listOf(HolidayInfo("Eid-ul-Fitr (Festival/Bank/Court)", "FESTIVAL")),
        "2026-03-24" to listOf(HolidayInfo("Sabarimala Closes - Meenam Pooja", "SABARIMALA")),
        "2026-03-27" to listOf(HolidayInfo("Ram Navami (Festival/Court)", "FESTIVAL")),
        "2026-03-31" to listOf(HolidayInfo("Mahavir Jayanti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-04-01" to listOf(HolidayInfo("Annual Bank Closing Day (Bank Holiday)", "BANK_COURT")),
        "2026-04-03" to listOf(HolidayInfo("Good Friday (Bank/Court Holiday)", "BANK_COURT")),
        "2026-04-10" to listOf(HolidayInfo("Sabarimala Opens - Vishu Festival", "SABARIMALA")),
        "2026-04-14" to listOf(HolidayInfo("Ambedkar Jayanti / Vishu (Bank/Court/Festival)", "FESTIVAL")),
        "2026-04-18" to listOf(HolidayInfo("Sabarimala Closes - Vishu", "SABARIMALA")),
        "2026-05-01" to listOf(HolidayInfo("Buddha Purnima / Maharashtra & Gujarat Day", "BANK_COURT")),
        "2026-05-14" to listOf(HolidayInfo("Sabarimala Opens - Edavam Maasa Pooja", "SABARIMALA")),
        "2026-05-19" to listOf(HolidayInfo("Sabarimala Closes - Edavam Pooja", "SABARIMALA")),
        "2026-05-27" to listOf(HolidayInfo("Bakrid / Eid-ul-Adha (Bank/Court)", "FESTIVAL")),
        "2026-06-15" to listOf(HolidayInfo("Sabarimala Opens - Mithunam Maasa Pooja", "SABARIMALA")),
        "2026-06-19" to listOf(HolidayInfo("Sabarimala Closes - Mithunam Pooja", "SABARIMALA")),
        "2026-06-26" to listOf(HolidayInfo("Muharram (Bank/Court Holiday)", "BANK_COURT")),
        "2026-07-16" to listOf(HolidayInfo("Sabarimala Opens - Karkidakam Maasa Pooja", "SABARIMALA")),
        "2026-07-20" to listOf(HolidayInfo("Sabarimala Closes - Karkidakam Pooja", "SABARIMALA")),
        "2026-08-15" to listOf(HolidayInfo("Independence Day (National/Bank/Court)", "BANK_COURT")),
        "2026-08-16" to listOf(HolidayInfo("Sabarimala Opens - Chingam & Onam", "SABARIMALA")),
        "2026-08-26" to listOf(HolidayInfo("Onam / Thiruvonam & Eid-e-Milad", "FESTIVAL")),
        "2026-08-28" to listOf(HolidayInfo("Raksha Bandhan (Festival/Court)", "FESTIVAL")),
        "2026-09-04" to listOf(HolidayInfo("Janmashtami (Festival/Bank/Court)", "FESTIVAL")),
        "2026-09-14" to listOf(HolidayInfo("Ganesh Chaturthi (Festival/Bank)", "FESTIVAL")),
        "2026-09-16" to listOf(HolidayInfo("Sabarimala Opens - Kanni Maasa Pooja", "SABARIMALA")),
        "2026-09-21" to listOf(HolidayInfo("Sabarimala Closes - Kanni Pooja", "SABARIMALA")),
        "2026-10-02" to listOf(HolidayInfo("Gandhi Jayanti (National/Bank/Court)", "BANK_COURT")),
        "2026-10-17" to listOf(HolidayInfo("Sabarimala Opens - Thulam Maasa Pooja", "SABARIMALA")),
        "2026-10-20" to listOf(HolidayInfo("Dussehra / Vijayadashami (Festival/Bank/Court)", "FESTIVAL")),
        "2026-10-22" to listOf(HolidayInfo("Sabarimala Closes - Thulam Pooja", "SABARIMALA")),
        "2026-11-08" to listOf(HolidayInfo("Diwali / Deepavali (Festival/Bank/Court)", "FESTIVAL")),
        "2026-11-09" to listOf(HolidayInfo("Gujarati New Year / Govardhan Puja", "FESTIVAL")),
        "2026-11-11" to listOf(HolidayInfo("Bhai Dooj (Festival/Court)", "FESTIVAL")),
        "2026-11-16" to listOf(HolidayInfo("Sabarimala Opens - Mandala Kalam Begins", "SABARIMALA")),
        "2026-11-24" to listOf(HolidayInfo("Guru Nanak Jayanti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-12-25" to listOf(HolidayInfo("Christmas Day (Festival/Bank/Court)", "BANK_COURT")),
        "2026-12-27" to listOf(HolidayInfo("Sabarimala Mandala Pooja (Temple Closes Night)", "SABARIMALA")),
        "2026-12-30" to listOf(HolidayInfo("Sabarimala Reopens - Makaravilakku Season", "SABARIMALA")),
        "2027-01-14" to listOf(
            HolidayInfo("Makar Sankranti / Pongal", "FESTIVAL"),
            HolidayInfo("Sabarimala Makaravilakku Festival", "SABARIMALA")
        ),
        "2027-01-20" to listOf(HolidayInfo("Sabarimala Temple Closes (Makaravilakku)", "SABARIMALA")),
        "2027-01-26" to listOf(HolidayInfo("Republic Day (National/Bank/Court)", "BANK_COURT"))
    )

    fun getHolidaysForDate(year: Int, monthZeroBased: Int, day: Int): List<HolidayInfo> {
        val result = mutableListOf<HolidayInfo>()
        val key = String.format("%04d-%02d-%02d", year, monthZeroBased + 1, day)
        fixedDates[key]?.let { result.addAll(it) }

        val cal = Calendar.getInstance().apply { set(year, monthZeroBased, day) }
        val dow = cal.get(Calendar.DAY_OF_WEEK)
        if (dow == Calendar.SATURDAY) {
            val weekOfMonth = (day - 1) / 7 + 1
            if (weekOfMonth == 2 || weekOfMonth == 4) {
                result.add(HolidayInfo("${if (weekOfMonth == 2) "2nd" else "4th"} Saturday (Bank & Court Holiday)", "BANK_COURT"))
            }
        }
        if ((monthZeroBased == Calendar.NOVEMBER && day in 17..30) ||
            (monthZeroBased == Calendar.DECEMBER && day in 1..26) ||
            (monthZeroBased == Calendar.DECEMBER && day == 31) ||
            (monthZeroBased == Calendar.JANUARY && day in 1..19 && day != 14)) {
            result.add(HolidayInfo("Sabarimala Temple Open (Mandala-Makaravilakku)", "SABARIMALA"))
        }
        return result
    }

    fun getHolidayDaysInMonth(year: Int, monthZeroBased: Int): Map<Int, String> {
        val map = mutableMapOf<Int, String>()
        val cal = Calendar.getInstance().apply { set(year, monthZeroBased, 1) }
        val maxDay = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        for (d in 1..maxDay) {
            val list = getHolidaysForDate(year, monthZeroBased, d)
            if (list.isNotEmpty()) {
                val priority = when {
                    list.any { it.type == "SABARIMALA" } -> "SABARIMALA"
                    list.any { it.type == "FESTIVAL" } -> "FESTIVAL"
                    else -> "BANK_COURT"
                }
                map[d] = priority
            }
        }
        return map
    }
}
INNER

# 6. CalendarHelper
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/CalendarHelper.kt
package com.nocode5.skedar

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

object CalendarHelper {

    fun hasReadPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun hasWritePermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun addEntry(
        context: Context,
        title: String,
        category: String,
        year: Int,
        monthZeroBased: Int,
        day: Int
    ): Boolean {
        val formattedTitle = "[$category] $title"
        val prefs = context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString("items", "[]"))
        val obj = JSONObject().apply {
            put("title", formattedTitle)
            put("category", category)
            put("year", year)
            put("month", monthZeroBased)
            put("day", day)
        }
        arr.put(obj)
        prefs.edit().putString("items", arr.toString()).apply()

        if (hasReadPermission(context) && hasWritePermission(context)) {
            try {
                val calId = getPrimaryCalendarId(context) ?: return true
                val startCal = Calendar.getInstance().apply {
                    set(year, monthZeroBased, day, 9, 0, 0)
                }
                val endCal = Calendar.getInstance().apply {
                    set(year, monthZeroBased, day, 10, 0, 0)
                }
                val values = ContentValues().apply {
                    put(CalendarContract.Events.DTSTART, startCal.timeInMillis)
                    put(CalendarContract.Events.DTEND, endCal.timeInMillis)
                    put(CalendarContract.Events.TITLE, formattedTitle)
                    put(CalendarContract.Events.DESCRIPTION, "Added via Skedlar ($category)")
                    put(CalendarContract.Events.CALENDAR_ID, calId)
                    put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                    if (category == "Birthday" || category == "Anniversary") {
                        put(CalendarContract.Events.RRULE, "FREQ=YEARLY")
                    }
                }
                context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            } catch (_: Exception) {}
        }
        return true
    }

    private fun getPrimaryCalendarId(context: Context): Long? {
        val projection = arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.IS_PRIMARY)
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection, null, null, null
        )?.use { cursor ->
            var fallbackId: Long? = null
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                if (fallbackId == null) fallbackId = id
                if (cursor.getInt(1) == 1) return id
            }
            return fallbackId
        }
        return null
    }

    fun getLocalEntriesForDate(context: Context, year: Int, monthZeroBased: Int, day: Int): List<String> {
        val list = mutableListOf<String>()
        val prefs = context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString("items", "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val cat = o.optString("category", "")
            val isAnnual = (cat == "Birthday" || cat == "Anniversary")
            if (o.getInt("month") == monthZeroBased && o.getInt("day") == day &&
                (isAnnual || o.getInt("year") == year)) {
                list.add(o.getString("title"))
            }
        }
        return list
    }

    fun getEventDaysInMonth(context: Context, year: Int, month: Int): Set<Int> {
        val eventDays = mutableSetOf<Int>()

        val prefs = context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString("items", "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val cat = o.optString("category", "")
            val isAnnual = (cat == "Birthday" || cat == "Anniversary")
            if (o.getInt("month") == month && (isAnnual || o.getInt("year") == year)) {
                eventDays.add(o.getInt("day"))
            }
        }

        if (hasReadPermission(context)) {
            val calStart = Calendar.getInstance().apply { set(year, month, 1, 0, 0, 0) }
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
                        tempCal.timeInMillis = cursor.getLong(0)
                        eventDays.add(tempCal.get(Calendar.DAY_OF_MONTH))
                    }
                }
            } catch (_: Exception) {}
        }
        return eventDays
    }

    fun getNextEventSummary(context: Context): String {
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH)
        val d = cal.get(Calendar.DAY_OF_MONTH)

        val todayHolidays = HolidayRepository.getHolidaysForDate(y, m, d).map { "• ${it.title}" }
        val todayLocal = getLocalEntriesForDate(context, y, m, d).map { "• $it" }

        val sb = StringBuilder()
        if (todayHolidays.isNotEmpty() || todayLocal.isNotEmpty()) {
            sb.append("TODAY'S OBSERVANCES & ENTRIES:\n")
            (todayLocal + todayHolidays).forEach { sb.append("$it\n") }
            sb.append("\n")
        }

        if (!hasReadPermission(context)) {
            sb.append("NEXT UP:\nGrant calendar permission to sync system events.")
            return sb.toString().trim()
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
                    sb.append("NEXT UP:\n$title\n${fmt.format(Date(start))}")
                    return sb.toString().trim()
                }
            }
        } catch (_: Exception) {}

        sb.append("NEXT UP:\nNo upcoming timed events found.")
        return sb.toString().trim()
    }
}
INNER

# 7. Widget Provider
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
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class SkedarWidgetProvider : AppWidgetProvider() {

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
            val showHolidays = prefs.getBoolean("show_holidays", true)
            val textColorHex = prefs.getString("text_color", "#FFFFFF") ?: "#FFFFFF"
            val scalePercent = prefs.getInt("scale", 100)

            val options = manager.getAppWidgetOptions(widgetId)
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 220).coerceAtLeast(120)
            val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 220).coerceAtLeast(120)

            val density = context.resources.displayMetrics.density
            val pxW = (minW * density).toInt().coerceIn(300, 1400)
            val pxH = (maxH * density).toInt().coerceIn(300, 1600)

            val bitmap = renderCalendarBitmap(
                context, pxW, pxH, shape, opacity, showEvents, showHolidays, textColorHex, scalePercent
            )
            val views = RemoteViews(context.packageName, R.layout.widget_skedar)
            views.setImageViewBitmap(R.id.widget_canvas, bitmap)

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

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
            scalePercent: Int
        ): Bitmap {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val path = Path()
            val cx = width / 2f
            val cy = height / 2f
            val pad = 10f

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
                "RECTANGLE" -> {
                    val rect = RectF(pad, pad, width - pad, height - pad)
                    path.addRoundRect(rect, 28f, 28f, Path.Direction.CW)
                }
                else -> {
                    val side = min(width, height) - (pad * 2)
                    val left = cx - side / 2f
                    val top = cy - side / 2f
                    val rect = RectF(left, top, left + side, top + side)
                    path.addRoundRect(rect, 36f, 36f, Path.Direction.CW)
                }
            }

            val parsedTextColor = try { Color.parseColor(textColorHex) } catch (_: Exception) { Color.WHITE }

            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 15, 15, 15)
                style = Paint.Style.FILL
            }
            canvas.drawPath(path, bgPaint)

            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                this.alpha = 170
                style = Paint.Style.STROKE
                strokeWidth = 3f
            }
            canvas.drawPath(path, borderPaint)

            val cal = Calendar.getInstance()
            val today = cal.get(Calendar.DAY_OF_MONTH)
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH)

            val eventDays = if (showEvents) CalendarHelper.getEventDaysInMonth(context, year, month) else emptySet()
            val holidayMap = if (showHolidays) HolidayRepository.getHolidayDaysInMonth(year, month) else emptyMap()

            val scaleFactor = (scalePercent / 100f).coerceIn(0.6f, 1.4f)
            val refDim = min(width, height).toFloat()
            val titleSize = (refDim * 0.052f * scaleFactor).coerceIn(16f, 54f)
            val daySize = (refDim * 0.042f * scaleFactor).coerceIn(13f, 44f)

            val monthTitle = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time).uppercase()
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                textSize = titleSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val usableW = when (shape) {
                "TRIANGLE" -> width * 0.46f * scaleFactor
                "SQUARE" -> (min(width, height) * 0.72f * scaleFactor)
                else -> width * 0.74f * scaleFactor
            }.coerceAtMost(width * 0.88f)

            val usableH = when (shape) {
                "TRIANGLE" -> height * 0.44f * scaleFactor
                "SQUARE" -> (min(width, height) * 0.56f * scaleFactor)
                else -> height * 0.60f * scaleFactor
            }.coerceAtMost(height * 0.78f)

            val topOffset = if (shape == "TRIANGLE") {
                cy - (usableH * 0.15f)
            } else {
                cy - (usableH * 0.45f)
            }

            canvas.drawText(monthTitle, cx, topOffset, titlePaint)

            val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                textSize = daySize
                textAlign = Paint.Align.CENTER
            }
            val todayBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                style = Paint.Style.FILL
            }
            val todayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (parsedTextColor == Color.BLACK) Color.WHITE else Color.BLACK
                textSize = daySize
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
            }

            cal.set(Calendar.DAY_OF_MONTH, 1)
            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

            val startX = cx - (usableW / 2f)
            val colStep = usableW / 6f
            val rowStep = usableH / 5.5f
            var currentY = topOffset + (rowStep * 1.15f)

            var col = firstDayOfWeek
            for (day in 1..daysInMonth) {
                val x = startX + (col * colStep)
                if (day == today) {
                    canvas.drawCircle(x, currentY - (daySize * 0.34f), daySize * 0.76f, todayBgPaint)
                    canvas.drawText(day.toString(), x, currentY, todayTextPaint)
                } else {
                    canvas.drawText(day.toString(), x, currentY, dayPaint)
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
                    canvas.drawCircle(x, currentY + (daySize * 0.45f), (daySize * 0.16f).coerceAtLeast(3f), dotPaint)
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

# 8. Updated Settings, Color Picker, Add Entry & Holiday Inspector Layout
cat << 'INNER' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#0D0D0D"
    android:padding="20dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical">

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="SKEDLAR"
            android:textSize="26sp"
            android:textStyle="bold"
            android:letterSpacing="0.16"
            android:textColor="#FFFFFF" />

        <TextView
            android:id="@+id/tv_next_event"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="14dp"
            android:padding="14dp"
            android:background="#1A1A1A"
            android:text="Checking observances and next event..."
            android:textColor="#E0E0E0"
            android:textSize="13sp" />

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="22dp"
            android:text="ADD ENTRY / BIRTHDAY / ANNIVERSARY"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <EditText
            android:id="@+id/et_entry_title"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:hint="Title (e.g., Birthday, Court Hearing)"
            android:textColor="#FFFFFF"
            android:textColorHint="#666666"
            android:backgroundTint="#555555"
            android:inputType="textCapSentences" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:orientation="horizontal">

            <Spinner
                android:id="@+id/sp_category"
                android:layout_width="0dp"
                android:layout_height="44dp"
                android:layout_weight="1"
                android:background="#1A1A1A" />

            <Button
                android:id="@+id/btn_pick_date"
                android:layout_width="0dp"
                android:layout_height="44dp"
                android:layout_weight="1"
                android:layout_marginStart="8dp"
                android:text="Pick Date"
                android:backgroundTint="#262626"
                android:textColor="#FFFFFF" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:orientation="horizontal">

            <Button
                android:id="@+id/btn_save_entry"
                android:layout_width="0dp"
                android:layout_height="44dp"
                android:layout_weight="1"
                android:text="Save Entry"
                android:backgroundTint="#FFFFFF"
                android:textColor="#000000"
                android:textStyle="bold" />

            <Button
                android:id="@+id/btn_inspect_date"
                android:layout_width="0dp"
                android:layout_height="44dp"
                android:layout_weight="1"
                android:layout_marginStart="8dp"
                android:text="Inspect Holidays"
                android:backgroundTint="#262626"
                android:textColor="#FFD54F" />
        </LinearLayout>

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:text="SHAPE OF THE DAY"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <RadioGroup
            android:id="@+id/rg_shapes"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp">
            <RadioButton android:id="@+id/rb_square" android:text="Square" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_rectangle" android:text="Rectangle (Fills Vertical + Horizontal Drag)" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_circle" android:text="Circle" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_triangle" android:text="Triangle" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
            <RadioButton android:id="@+id/rb_hexagon" android:text="Hexagon" android:textColor="#FFFFFF" android:layout_width="wrap_content" android:layout_height="wrap_content"/>
        </RadioGroup>

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:text="TEXT &amp; BORDER COLOR"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <Spinner
            android:id="@+id/sp_text_color"
            android:layout_width="match_parent"
            android:layout_height="44dp"
            android:layout_marginTop="6dp"
            android:background="#1A1A1A" />

        <TextView
            android:id="@+id/tv_scale_label"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:text="CALENDAR TEXT SCALE: 100%"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <SeekBar
            android:id="@+id/sb_scale"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:min="60"
            android:max="140"
            android:progress="100" />

        <TextView
            android:id="@+id/tv_alpha_label"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:text="BACKGROUND OPACITY: 30%"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <SeekBar
            android:id="@+id/sb_opacity"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:max="100"
            android:progress="30" />

        <CheckBox
            android:id="@+id/cb_show_events"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="14dp"
            android:text="Show Personal Events, Birthdays &amp; Anniversaries"
            android:textColor="#FFFFFF"
            android:checked="true" />

        <CheckBox
            android:id="@+id/cb_show_holidays"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Show Festivals, Bank/Court Holidays &amp; Sabarimala"
            android:textColor="#FFFFFF"
            android:checked="true" />

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:text="Dot Key: Gold = Sabarimala • Coral = Festival • Blue = Bank/Court • Green = Personal"
            android:textSize="11sp"
            android:textColor="#999999" />

        <Button
            android:id="@+id/btn_apply"
            android:layout_width="match_parent"
            android:layout_height="52dp"
            android:layout_marginTop="22dp"
            android:layout_marginBottom="24dp"
            android:text="APPLY TO WIDGET"
            android:backgroundTint="#FFFFFF"
            android:textColor="#000000"
            android:textStyle="bold" />

    </LinearLayout>
</ScrollView>
INNER

# 9. Updated MainActivity
cat << 'INNER' > app/src/main/java/com/nocode5/skedar/MainActivity.kt
package com.nocode5.skedar

import android.Manifest
import android.app.DatePickerDialog
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import java.util.*

class MainActivity : AppCompatActivity() {

    private var tts: TextToSpeech? = null
    private var selectedYear = Calendar.getInstance().get(Calendar.YEAR)
    private var selectedMonth = Calendar.getInstance().get(Calendar.MONTH)
    private var selectedDay = Calendar.getInstance().get(Calendar.DAY_OF_MONTH)

    private val colorOptions = listOf(
        "Pure White (#FFFFFF)" to "#FFFFFF",
        "Matte Black (#000000)" to "#000000",
        "Warm Gold (#FFD54F)" to "#FFD54F",
        "Coral Red (#FF8A65)" to "#FF8A65",
        "Mint Green (#81C784)" to "#81C784",
        "Sky Blue (#4FC3F7)" to "#4FC3F7"
    )

    private val requestPermissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
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
        val sbScale = findViewById<SeekBar>(R.id.sb_scale)
        val tvScaleLabel = findViewById<TextView>(R.id.tv_scale_label)
        val cbShowEvents = findViewById<CheckBox>(R.id.cb_show_events)
        val cbShowHolidays = findViewById<CheckBox>(R.id.cb_show_holidays)
        val spTextColor = findViewById<Spinner>(R.id.sp_text_color)
        val btnApply = findViewById<Button>(R.id.btn_apply)

        val etEntryTitle = findViewById<EditText>(R.id.et_entry_title)
        val spCategory = findViewById<Spinner>(R.id.sp_category)
        val btnPickDate = findViewById<Button>(R.id.btn_pick_date)
        val btnSaveEntry = findViewById<Button>(R.id.btn_save_entry)
        val btnInspectDate = findViewById<Button>(R.id.btn_inspect_date)

        val categories = listOf("Event", "Birthday", "Anniversary", "Chore")
        spCategory.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, categories)

        val colorNames = colorOptions.map { it.first }
        spTextColor.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, colorNames)
        val savedHex = prefs.getString("text_color", "#FFFFFF")
        val savedColorIdx = colorOptions.indexOfFirst { it.second == savedHex }.coerceAtLeast(0)
        spTextColor.setSelection(savedColorIdx)

        btnPickDate.text = "$selectedDay/${selectedMonth + 1}/$selectedYear"
        btnPickDate.setOnClickListener {
            DatePickerDialog(this, { _, y, m, d ->
                selectedYear = y
                selectedMonth = m
                selectedDay = d
                btnPickDate.text = "$d/${m + 1}/$y"
            }, selectedYear, selectedMonth, selectedDay).show()
        }

        btnSaveEntry.setOnClickListener {
            val title = etEntryTitle.text.toString().trim()
            if (title.isEmpty()) {
                Toast.makeText(this, "Enter a title first", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val cat = categories[spCategory.selectedItemPosition]
            CalendarHelper.addEntry(this, title, cat, selectedYear, selectedMonth, selectedDay)
            etEntryTitle.text.clear()
            refreshNextEvent()
            SkedarWidgetProvider.updateAllWidgets(this)
            Toast.makeText(this, "Saved $cat: $title", Toast.LENGTH_SHORT).show()
        }

        btnInspectDate.setOnClickListener {
            DatePickerDialog(this, { _, y, m, d ->
                val holidays = HolidayRepository.getHolidaysForDate(y, m, d)
                val local = CalendarHelper.getLocalEntriesForDate(this, y, m, d)
                val msg = buildString {
                    if (local.isEmpty() && holidays.isEmpty()) {
                        append("No holidays, Sabarimala dates, or saved entries on $d/${m + 1}/$y.")
                    } else {
                        local.forEach { append("• $it\n") }
                        holidays.forEach { append("• ${it.title}\n") }
                    }
                }
                AlertDialog.Builder(this)
                    .setTitle("Observances on $d/${m + 1}/$y")
                    .setMessage(msg.trim())
                    .setPositiveButton("OK", null)
                    .show()
            }, selectedYear, selectedMonth, selectedDay).show()
        }

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

        val savedScale = prefs.getInt("scale", 100)
        sbScale.progress = savedScale
        tvScaleLabel.text = "CALENDAR TEXT SCALE: $savedScale%"

        cbShowEvents.isChecked = prefs.getBoolean("show_events", true)
        cbShowHolidays.isChecked = prefs.getBoolean("show_holidays", true)

        sbOpacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { tvAlphaLabel.text = "BACKGROUND OPACITY: $p%" }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })

        sbScale.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { tvScaleLabel.text = "CALENDAR TEXT SCALE: $p%" }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })

        btnApply.setOnClickListener {
            val selectedShape = when (rgShapes.checkedRadioButtonId) {
                R.id.rb_rectangle -> "RECTANGLE"
                R.id.rb_circle -> "CIRCLE"
                R.id.rb_triangle -> "TRIANGLE"
                R.id.rb_hexagon -> "HEXAGON"
                else -> "SQUARE"
            }
            val chosenHex = colorOptions[spTextColor.selectedItemPosition].second
            prefs.edit()
                .putString("shape", selectedShape)
                .putInt("opacity", sbOpacity.progress)
                .putInt("scale", sbScale.progress)
                .putString("text_color", chosenHex)
                .putBoolean("show_events", cbShowEvents.isChecked)
                .putBoolean("show_holidays", cbShowHolidays.isChecked)
                .apply()

            SkedarWidgetProvider.updateAllWidgets(this)
            Toast.makeText(this, "Skedlar updated ($selectedShape)", Toast.LENGTH_SHORT).show()
        }

        if (!CalendarHelper.hasReadPermission(this) || !CalendarHelper.hasWritePermission(this)) {
            requestPermissionsLauncher.launch(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
            )
        } else {
            refreshNextEvent()
        }

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
        findViewById<TextView>(R.id.tv_next_event).text = CalendarHelper.getNextEventSummary(this)
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
INNER

# 10. Update GitHub Actions Workflow (Outputs Skedlar.apk & Skedlar.zip)
cat << 'INNER' > .github/workflows/build_skedar.yml
name: Build Skedlar APK and ZIP

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

      - name: Build Skedlar APK
        run: gradle assembleDebug

      - name: Package Skedlar.apk and Skedlar.zip
        run: |
          mkdir -p release_out
          cp app/build/outputs/apk/debug/Skedlar-debug.apk release_out/Skedlar.apk
          zip -r release_out/Skedlar.zip app build.gradle settings.gradle gradle.properties release_out/Skedlar.apk

      - name: Upload Skedlar Build Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: Skedlar-Release
          path: |
            release_out/Skedlar.apk
            release_out/Skedlar.zip
INNER

echo "Skedlar v1.1 updated successfully!"
