package com.nocode5.skedar

import android.Manifest
import android.app.DatePickerDialog
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.view.View
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
        findViewById<InteractiveCalendarView>(R.id.interactive_calendar).invalidate()
        SkedarWidgetProvider.updateAllWidgets(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val prefs = getSharedPreferences("skedar_prefs", MODE_PRIVATE)
        val calView = findViewById<InteractiveCalendarView>(R.id.interactive_calendar)
        val settingsPanel = findViewById<ScrollView>(R.id.settings_panel)

        calView.monthOffset = prefs.getInt("month_offset", 0)
        calView.onMonthChanged = { newOffset ->
            prefs.edit().putInt("month_offset", newOffset).apply()
            SkedarWidgetProvider.updateAllWidgets(this)
        }

        calView.onDateTapped = { y, m, d ->
            val holidays = HolidayRepository.getHolidaysForDate(y, m, d)
            val local = CalendarHelper.getLocalEntriesForDate(this, y, m, d)
            val msg = buildString {
                if (local.isEmpty() && holidays.isEmpty()) append("No holidays, Sabarimala dates, or saved entries on $d/${m + 1}/$y.")
                else { local.forEach { append("• $it\n") }; holidays.forEach { append("• ${it.title}\n") } }
            }
            AlertDialog.Builder(this).setTitle("$d/${m + 1}/$y").setMessage(msg.trim())
                .setPositiveButton("Close", null)
                .setNeutralButton("Add Entry") { _, _ ->
                    selectedYear = y; selectedMonth = m; selectedDay = d
                    findViewById<Button>(R.id.btn_pick_date).text = "$d/${m + 1}/$y"
                    settingsPanel.visibility = View.VISIBLE
                }.show()
        }

        findViewById<Button>(R.id.btn_today_snap).setOnClickListener {
            calView.monthOffset = 0; prefs.edit().putInt("month_offset", 0).apply(); SkedarWidgetProvider.updateAllWidgets(this)
        }
        findViewById<Button>(R.id.btn_toggle_settings).setOnClickListener { settingsPanel.visibility = View.VISIBLE }
        findViewById<Button>(R.id.btn_close_settings).setOnClickListener { settingsPanel.visibility = View.GONE; calView.invalidate() }

        val rgShapes = findViewById<RadioGroup>(R.id.rg_shapes)
        val sbOpacity = findViewById<SeekBar>(R.id.sb_opacity)
        val tvAlphaLabel = findViewById<TextView>(R.id.tv_alpha_label)
        val sbScale = findViewById<SeekBar>(R.id.sb_scale)
        val tvScaleLabel = findViewById<TextView>(R.id.tv_scale_label)
        val cbShowEvents = findViewById<CheckBox>(R.id.cb_show_events)
        val cbShowHolidays = findViewById<CheckBox>(R.id.cb_show_holidays)
        val spTextColor = findViewById<Spinner>(R.id.sp_text_color)
        val etEntryTitle = findViewById<EditText>(R.id.et_entry_title)
        val spCategory = findViewById<Spinner>(R.id.sp_category)
        val btnPickDate = findViewById<Button>(R.id.btn_pick_date)

        val categories = listOf("Event", "Birthday", "Anniversary", "Chore")
        spCategory.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, categories)

        spTextColor.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, colorOptions.map { it.first })
        val savedHex = prefs.getString("text_color", "#FFFFFF")
        spTextColor.setSelection(colorOptions.indexOfFirst { it.second == savedHex }.coerceAtLeast(0))

        btnPickDate.text = "$selectedDay/${selectedMonth + 1}/$selectedYear"
        btnPickDate.setOnClickListener {
            DatePickerDialog(this, { _, y, m, d ->
                selectedYear = y; selectedMonth = m; selectedDay = d; btnPickDate.text = "$d/${m + 1}/$y"
            }, selectedYear, selectedMonth, selectedDay).show()
        }

        findViewById<Button>(R.id.btn_save_entry).setOnClickListener {
            val title = etEntryTitle.text.toString().trim()
            if (title.isEmpty()) { Toast.makeText(this, "Enter a title first", Toast.LENGTH_SHORT).show(); return@setOnClickListener }
            val cat = categories[spCategory.selectedItemPosition]
            CalendarHelper.addEntry(this, title, cat, selectedYear, selectedMonth, selectedDay)
            etEntryTitle.text.clear(); refreshNextEvent(); calView.invalidate(); SkedarWidgetProvider.updateAllWidgets(this)
            Toast.makeText(this, "Saved $cat: $title", Toast.LENGTH_SHORT).show()
        }

        if (prefs.getString("shape", "HORIZONTAL") == "VERTICAL") rgShapes.check(R.id.rb_vertical) else rgShapes.check(R.id.rb_horizontal)
        sbOpacity.progress = prefs.getInt("opacity", 25); tvAlphaLabel.text = "BACKGROUND OPACITY: ${sbOpacity.progress}%"
        sbScale.progress = prefs.getInt("scale", 100); tvScaleLabel.text = "CALENDAR TEXT SCALE: ${sbScale.progress}%"
        cbShowEvents.isChecked = prefs.getBoolean("show_events", true)
        cbShowHolidays.isChecked = prefs.getBoolean("show_holidays", true)

        sbOpacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { tvAlphaLabel.text = "BACKGROUND OPACITY: $p%" }
            override fun onStartTrackingTouch(s: SeekBar?) {}; override fun onStopTrackingTouch(s: SeekBar?) {}
        })
        sbScale.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { tvScaleLabel.text = "CALENDAR TEXT SCALE: $p%" }
            override fun onStartTrackingTouch(s: SeekBar?) {}; override fun onStopTrackingTouch(s: SeekBar?) {}
        })

        findViewById<Button>(R.id.btn_apply).setOnClickListener {
            val selectedShape = if (rgShapes.checkedRadioButtonId == R.id.rb_vertical) "VERTICAL" else "HORIZONTAL"
            prefs.edit().putString("shape", selectedShape).putInt("opacity", sbOpacity.progress)
                .putInt("scale", sbScale.progress).putString("text_color", colorOptions[spTextColor.selectedItemPosition].second)
                .putBoolean("show_events", cbShowEvents.isChecked).putBoolean("show_holidays", cbShowHolidays.isChecked).apply()
            calView.invalidate(); SkedarWidgetProvider.updateAllWidgets(this)
            settingsPanel.visibility = View.GONE
            Toast.makeText(this, "Skedulr updated ($selectedShape)", Toast.LENGTH_SHORT).show()
        }

        if (!CalendarHelper.hasReadPermission(this) || !CalendarHelper.hasWritePermission(this)) {
            requestPermissionsLauncher.launch(arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR))
        } else refreshNextEvent()

        if (intent?.data?.host == "next") {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.getDefault()
                    tts?.speak(CalendarHelper.getNextEventSummary(this).replace("\n", ". "), TextToSpeech.QUEUE_FLUSH, null, "skedar_next")
                }
            }
        }
    }

    private fun refreshNextEvent() { findViewById<TextView>(R.id.tv_next_event).text = CalendarHelper.getNextEventSummary(this) }
    override fun onDestroy() { tts?.shutdown(); super.onDestroy() }
}
