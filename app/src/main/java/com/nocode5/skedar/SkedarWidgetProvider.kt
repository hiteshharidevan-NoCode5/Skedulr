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
import kotlin.math.max
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

            // Cap max dimension at 680px while preserving exact aspect ratio (keeps bitmap < 1.5MB)
            val aspect = minW.toFloat() / maxH.toFloat()
            val pxW: Int
            val pxH: Int
            if (aspect >= 1f) {
                pxW = 680
                pxH = (680f / aspect).toInt().coerceIn(260, 680)
            } else {
                pxH = 680
                pxW = (680f * aspect).toInt().coerceIn(260, 680)
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
            val shadowColor = if (parsedTextColor == Color.BLACK) Color.argb(190, 255, 255, 255) else Color.argb(210, 0, 0, 0)

            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 15, 15, 15)
                style = Paint.Style.FILL
            }
            canvas.drawPath(path, bgPaint)

            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                this.alpha = 190
                style = Paint.Style.STROKE
                strokeWidth = 3f
                setShadowLayer(4f, 0f, 1f, shadowColor)
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
            val titleSize = (refDim * 0.055f * scaleFactor).coerceIn(16f, 46f)
            val daySize = (refDim * 0.045f * scaleFactor).coerceIn(13f, 38f)

            val monthTitle = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time).uppercase()
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor
                textSize = titleSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(5f, 0f, 2f, shadowColor)
            }

            val usableW = when (shape) {
                "TRIANGLE" -> width * 0.46f * scaleFactor
                "SQUARE" -> (min(width, height) * 0.72f * scaleFactor)
                else -> width * 0.76f * scaleFactor
            }.coerceAtMost(width * 0.88f)

            val usableH = when (shape) {
                "TRIANGLE" -> height * 0.44f * scaleFactor
                "SQUARE" -> (min(width, height) * 0.56f * scaleFactor)
                else -> height * 0.62f * scaleFactor
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
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                setShadowLayer(5f, 0f, 2f, shadowColor)
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
                    canvas.drawCircle(x, currentY + (daySize * 0.45f), max(3.5f, daySize * 0.17f), dotPaint)
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
