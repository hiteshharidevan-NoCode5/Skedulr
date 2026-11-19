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
