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
        for (appWidgetId in appWidgetIds) updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, opts: Bundle) {
        updateWidget(context, manager, id)
        super.onAppWidgetOptionsChanged(context, manager, id, opts)
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SkedarWidgetProvider::class.java))
            for (id in ids) updateWidget(context, manager, id)
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
            val shape = prefs.getString("shape", "HORIZONTAL") ?: "HORIZONTAL"
            val opacity = prefs.getInt("opacity", 25)
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
            val pxW = if (aspect >= 1f) 720 else (720f * aspect).toInt().coerceIn(280, 720)
            val pxH = if (aspect >= 1f) (720f / aspect).toInt().coerceIn(280, 720) else 720

            val bitmap = renderCalendarBitmap(
                context, pxW, pxH, shape, opacity, showEvents, showHolidays, textColorHex, scalePercent, monthOffset
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
            context: Context, width: Int, height: Int, shape: String, opacityPercent: Int,
            showEvents: Boolean, showHolidays: Boolean, textColorHex: String, scalePercent: Int, monthOffset: Int
        ): Bitmap {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val path = Path().apply { addRoundRect(RectF(8f, 8f, width - 8f, height - 8f), 28f, 28f, Path.Direction.CW) }

            val parsedTextColor = try { Color.parseColor(textColorHex) } catch (_: Exception) { Color.WHITE }
            val shadowColor = if (parsedTextColor == Color.BLACK) Color.argb(190, 255, 255, 255) else Color.argb(215, 0, 0, 0)

            val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(alpha, 15, 15, 15); style = Paint.Style.FILL }
            canvas.drawPath(path, bgPaint)

            val nowCal = Calendar.getInstance()
            val realToday = nowCal.get(Calendar.DAY_OF_MONTH)
            val realMonth = nowCal.get(Calendar.MONTH)
            val realYear = nowCal.get(Calendar.YEAR)

            val cal = Calendar.getInstance().apply { set(Calendar.DAY_OF_MONTH, 1); add(Calendar.MONTH, monthOffset) }
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
                color = parsedTextColor; textSize = titleSize; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER; setShadowLayer(5f, 0f, 2f, shadowColor)
            }
            val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor; textSize = daySize; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER; setShadowLayer(5f, 0f, 2f, shadowColor)
            }
            val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor; this.alpha = 180; textSize = daySize * 0.78f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER; setShadowLayer(4f, 0f, 1f, shadowColor)
            }
            val todayBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = parsedTextColor; style = Paint.Style.FILL; setShadowLayer(4f, 0f, 1f, shadowColor)
            }
            val todayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (parsedTextColor == Color.BLACK) Color.WHITE else Color.BLACK
                textSize = daySize; typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
            }
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; setShadowLayer(3f, 0f, 1f, Color.BLACK) }

            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val dayInitials = arrayOf("S", "M", "T", "W", "T", "F", "S")

            val usableW = (width * 0.84f * scaleFactor).coerceAtMost(width * 0.92f)
            val usableH = (height * 0.76f * scaleFactor).coerceAtMost(height * 0.88f)
            val topHeaderY = (height - usableH) / 2f + titleSize * 0.6f
            val gridLeft = cx - usableW / 2f

            canvas.drawText(monthTitle, cx, topHeaderY, titlePaint)

            val gridTop = topHeaderY + titleSize * 2.1f
            val gridBottom = height - (height - usableH) / 2f
            val gridHeight = (gridBottom - gridTop).coerceAtLeast(100f)

            if (shape == "VERTICAL") {
                val totalWeeks = ((firstDayOfWeek + daysInMonth + 6) / 7).coerceIn(4, 6)
                val colStep = usableW / totalWeeks.coerceAtLeast(1)
                val rowStep = gridHeight / 6f
                for (dow in 0..6) canvas.drawText(dayInitials[dow], gridLeft, gridTop + dow * rowStep, labelPaint)
                var weekCol = 1; var dow = firstDayOfWeek
                for (day in 1..daysInMonth) {
                    val x = gridLeft + weekCol * colStep; val y = gridTop + dow * rowStep
                    if (isCurrentMonth && day == realToday) {
                        canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.76f, todayBgPaint)
                        canvas.drawText(day.toString(), x, y, todayTextPaint)
                    } else canvas.drawText(day.toString(), x, y, dayPaint)
                    val hType = holidayMap[day]; val hasPersonal = eventDays.contains(day)
                    if (hType != null || hasPersonal) {
                        dotPaint.color = when (hType) {
                            "SABARIMALA" -> Color.parseColor("#FFD54F"); "FESTIVAL" -> Color.parseColor("#FF8A65")
                            "BANK_COURT" -> Color.parseColor("#4FC3F7"); else -> Color.parseColor("#81C784")
                        }
                        canvas.drawCircle(x, y + (daySize * 0.44f), max(3.5f, daySize * 0.16f), dotPaint)
                    }
                    dow++; if (dow > 6) { dow = 0; weekCol++ }
                }
            } else {
                val colStep = usableW / 6f
                val totalRows = ((firstDayOfWeek + daysInMonth + 6) / 7) + 1
                val rowStep = gridHeight / (totalRows - 1).coerceAtLeast(1)
                for (c in 0..6) canvas.drawText(dayInitials[c], gridLeft + c * colStep, gridTop, labelPaint)
                var row = 1; var col = firstDayOfWeek
                for (day in 1..daysInMonth) {
                    val x = gridLeft + col * colStep; val y = gridTop + row * rowStep
                    if (isCurrentMonth && day == realToday) {
                        canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.76f, todayBgPaint)
                        canvas.drawText(day.toString(), x, y, todayTextPaint)
                    } else canvas.drawText(day.toString(), x, y, dayPaint)
                    val hType = holidayMap[day]; val hasPersonal = eventDays.contains(day)
                    if (hType != null || hasPersonal) {
                        dotPaint.color = when (hType) {
                            "SABARIMALA" -> Color.parseColor("#FFD54F"); "FESTIVAL" -> Color.parseColor("#FF8A65")
                            "BANK_COURT" -> Color.parseColor("#4FC3F7"); else -> Color.parseColor("#81C784")
                        }
                        canvas.drawCircle(x, y + (daySize * 0.44f), max(3.5f, daySize * 0.16f), dotPaint)
                    }
                    col++; if (col > 6) { col = 0; row++ }
                }
            }
            return bitmap
        }
    }
}
