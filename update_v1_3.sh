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
        versionCode 4
        versionName "1.3"
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

# 2. Update Widget Provider (Borderless + Horizontal vs. Vertical Sun-to-Sat Layout)
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
            val shape = prefs.getString("shape", "HORIZONTAL") ?: "HORIZONTAL"
            val opacity = prefs.getInt("opacity", 30)
            val showEvents = prefs.getBoolean("show_events", true)
            val showHolidays = prefs.getBoolean("show_holidays", true)
            val textColorHex = prefs.getString("text_color", "#FFFFFF") ?: "#FFFFFF"
            val scalePercent = prefs.getInt("scale", 100)

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

            val pad = 8f
            val rect = RectF(pad, pad, width - pad, height - pad)
            val path = Path().apply {
                addRoundRect(rect, 28f, 28f, Path.Direction.CW)
            }

            val parsedTextColor = try { Color.parseColor(textColorHex) } catch (_: Exception) { Color.WHITE }
            val shadowColor = if (parsedTextColor == Color.BLACK) Color.argb(190, 255, 255, 255) else Color.argb(215, 0, 0, 0)

            // Background fill only (outer border removed)
            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 15, 15, 15)
                style = Paint.Style.FILL
            }
            canvas.drawPath(path, bgPaint)

            val cal = Calendar.getInstance()
            val today = cal.get(Calendar.DAY_OF_MONTH)
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH)

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

            cal.set(Calendar.DAY_OF_MONTH, 1)
            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0 = Sun .. 6 = Sat
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val dayInitials = arrayOf("S", "M", "T", "W", "T", "F", "S")

            val usableW = (width * 0.84f * scaleFactor).coerceAtMost(width * 0.92f)
            val usableH = (height * 0.76f * scaleFactor).coerceAtMost(height * 0.88f)
            val topHeaderY = (height - usableH) / 2f + titleSize * 0.8f
            canvas.drawText(monthTitle, cx, topHeaderY, titlePaint)

            val gridTop = topHeaderY + titleSize * 1.15f
            val gridBottom = height - (height - usableH) / 2f
            val gridHeight = (gridBottom - gridTop).coerceAtLeast(100f)
            val gridLeft = cx - usableW / 2f

            if (shape == "VERTICAL") {
                // VERTICAL RECTANGLE: Sunday -> Saturday stacked top-to-bottom (7 rows), weeks left-to-right (up to 6 cols)
                val totalWeeks = ((firstDayOfWeek + daysInMonth + 6) / 7).coerceIn(4, 6)
                val totalCols = totalWeeks + 1 // Col 0 = S M T W T F S labels, Cols 1..totalWeeks = week columns
                val colStep = usableW / (totalCols - 1).coerceAtLeast(1)
                val rowStep = gridHeight / 6f

                // Draw S-M-T-W-T-F-S vertically on the left column
                for (dow in 0..6) {
                    val y = gridTop + dow * rowStep
                    canvas.drawText(dayInitials[dow], gridLeft, y, labelPaint)
                }

                var weekCol = 1
                var dow = firstDayOfWeek
                for (day in 1..daysInMonth) {
                    val x = gridLeft + weekCol * colStep
                    val y = gridTop + dow * rowStep

                    if (day == today) {
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
                // HORIZONTAL RECTANGLE: Standard Sunday -> Saturday left-to-right (7 cols), weeks top-to-bottom
                val colStep = usableW / 6f
                val totalRows = ((firstDayOfWeek + daysInMonth + 6) / 7) + 1 // +1 for S M T W T F S header row
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

                    if (day == today) {
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

# 3. Update Settings Layout (Only Horizontal Rectangle & Vertical Rectangle)
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
            android:text="SKEDULR"
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
            android:text="CALENDAR ORIENTATION"
            android:textSize="11sp"
            android:letterSpacing="0.1"
            android:textColor="#888888" />

        <RadioGroup
            android:id="@+id/rg_shapes"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp">
            <RadioButton
                android:id="@+id/rb_horizontal"
                android:text="Horizontal Rectangle (Sun → Sat left to right)"
                android:textColor="#FFFFFF"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"/>
            <RadioButton
                android:id="@+id/rb_vertical"
                android:text="Vertical Rectangle (Sun → Sat top to bottom)"
                android:textColor="#FFFFFF"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"/>
        </RadioGroup>

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:text="TEXT COLOR"
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

# 4. Update MainActivity for Horizontal / Vertical Selection
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

        when (prefs.getString("shape", "HORIZONTAL")) {
            "VERTICAL" -> rgShapes.check(R.id.rb_vertical)
            else -> rgShapes.check(R.id.rb_horizontal)
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
                R.id.rb_vertical -> "VERTICAL"
                else -> "HORIZONTAL"
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
            Toast.makeText(this, "Skedulr updated ($selectedShape)", Toast.LENGTH_SHORT).show()
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

echo "Skedulr v1.3 updated successfully!"
