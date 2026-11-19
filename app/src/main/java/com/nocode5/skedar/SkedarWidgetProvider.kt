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
