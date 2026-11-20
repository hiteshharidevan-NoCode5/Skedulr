package com.nocode5.skedar

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class InteractiveCalendarView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    var monthOffset = 0
        set(value) { field = value; invalidate() }

    var onDateTapped: ((year: Int, monthZeroBased: Int, day: Int) -> Unit)? = null
    var onMonthChanged: ((newOffset: Int) -> Unit)? = null

    private data class DayHitBox(val day: Int, val cx: Float, val cy: Float, val radius: Float)
    private val hitBoxes = mutableListOf<DayHitBox>()
    private var renderedYear = Calendar.getInstance().get(Calendar.YEAR)
    private var renderedMonth = Calendar.getInstance().get(Calendar.MONTH)

    private val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean = true
        override fun onFling(e1: MotionEvent?, e2: MotionEvent, vx: Float, vy: Float): Boolean {
            if (e1 == null) return false
            val dx = e2.x - e1.x
            val dy = e2.y - e1.y
            if (abs(dx) > abs(dy) && abs(dx) > 80f) {
                monthOffset += if (dx < 0) 1 else -1
                onMonthChanged?.invoke(monthOffset)
                return true
            } else if (abs(dy) > abs(dx) && abs(dy) > 80f) {
                monthOffset += if (dy < 0) 1 else -1
                onMonthChanged?.invoke(monthOffset)
                return true
            }
            return false
        }
        override fun onSingleTapUp(e: MotionEvent): Boolean {
            for (box in hitBoxes) {
                val dist = Math.hypot((e.x - box.cx).toDouble(), (e.y - box.cy).toDouble())
                if (dist <= box.radius * 1.45) {
                    onDateTapped?.invoke(renderedYear, renderedMonth, box.day)
                    return true
                }
            }
            return false
        }
    })

    override fun onTouchEvent(event: MotionEvent): Boolean =
        gestureDetector.onTouchEvent(event) || super.onTouchEvent(event)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        hitBoxes.clear()
        if (width == 0 || height == 0) return

        val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
        val shape = prefs.getString("shape", "HORIZONTAL") ?: "HORIZONTAL"
        val opacityPercent = prefs.getInt("opacity", 25)
        val showEvents = prefs.getBoolean("show_events", true)
        val showHolidays = prefs.getBoolean("show_holidays", true)
        val textColorHex = prefs.getString("text_color", "#FFFFFF") ?: "#FFFFFF"
        val scalePercent = prefs.getInt("scale", 100)

        val parsedTextColor = try { Color.parseColor(textColorHex) } catch (_: Exception) { Color.WHITE }
        val shadowColor = if (parsedTextColor == Color.BLACK) Color.argb(190, 255, 255, 255) else Color.argb(220, 0, 0, 0)

        val alpha = ((opacityPercent / 100f) * 255).toInt().coerceIn(0, 255)
        if (alpha > 0) {
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 12, 12, 12)
                style = Paint.Style.FILL
            }
            canvas.drawRoundRect(RectF(24f, 24f, width - 24f, height - 24f), 36f, 36f, bgPaint)
        }

        val nowCal = Calendar.getInstance()
        val realToday = nowCal.get(Calendar.DAY_OF_MONTH)
        val realMonth = nowCal.get(Calendar.MONTH)
        val realYear = nowCal.get(Calendar.YEAR)

        val cal = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_MONTH, 1)
            add(Calendar.MONTH, monthOffset)
        }
        renderedYear = cal.get(Calendar.YEAR)
        renderedMonth = cal.get(Calendar.MONTH)
        val isCurrentMonth = (renderedYear == realYear && renderedMonth == realMonth)

        val eventDays = if (showEvents) CalendarHelper.getEventDaysInMonth(context, renderedYear, renderedMonth) else emptySet()
        val holidayMap = if (showHolidays) HolidayRepository.getHolidayDaysInMonth(renderedYear, renderedMonth) else emptyMap()

        val scaleFactor = (scalePercent / 100f).coerceIn(0.6f, 1.4f)
        val refDim = min(width, height).toFloat()
        val titleSize = (refDim * 0.056f * scaleFactor).coerceIn(22f, 64f)
        val daySize = (refDim * 0.046f * scaleFactor).coerceIn(18f, 52f)

        val cx = width / 2f
        val monthTitle = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time).uppercase()
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = parsedTextColor; textSize = titleSize
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER; setShadowLayer(6f, 0f, 2f, shadowColor)
        }
        val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = parsedTextColor; textSize = daySize
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER; setShadowLayer(6f, 0f, 2f, shadowColor)
        }
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = parsedTextColor; this.alpha = 180; textSize = daySize * 0.78f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER; setShadowLayer(5f, 0f, 1f, shadowColor)
        }
        val todayBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = parsedTextColor; style = Paint.Style.FILL; setShadowLayer(5f, 0f, 1f, shadowColor)
        }
        val todayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (parsedTextColor == Color.BLACK) Color.WHITE else Color.BLACK
            textSize = daySize; typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
        }
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL; setShadowLayer(4f, 0f, 1f, Color.BLACK)
        }

        val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        val dayInitials = arrayOf("S", "M", "T", "W", "T", "F", "S")

        val usableW = (width * 0.84f * scaleFactor).coerceAtMost(width * 0.90f)
        val usableH = (height * 0.72f * scaleFactor).coerceAtMost(height * 0.84f)
        val topHeaderY = (height - usableH) / 2f + titleSize * 0.6f
        val gridLeft = cx - usableW / 2f

        canvas.drawText(monthTitle, cx, topHeaderY, titlePaint)

        val gridTop = topHeaderY + titleSize * 2.1f
        val gridBottom = height - (height - usableH) / 2f
        val gridHeight = (gridBottom - gridTop).coerceAtLeast(160f)

        if (shape == "VERTICAL") {
            val totalWeeks = ((firstDayOfWeek + daysInMonth + 6) / 7).coerceIn(4, 6)
            val colStep = usableW / totalWeeks.coerceAtLeast(1)
            val rowStep = gridHeight / 6f
            for (dow in 0..6) canvas.drawText(dayInitials[dow], gridLeft, gridTop + dow * rowStep, labelPaint)
            var weekCol = 1; var dow = firstDayOfWeek
            for (day in 1..daysInMonth) {
                val x = gridLeft + weekCol * colStep
                val y = gridTop + dow * rowStep
                hitBoxes.add(DayHitBox(day, x, y - daySize * 0.3f, daySize * 0.95f))
                if (isCurrentMonth && day == realToday) {
                    canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.78f, todayBgPaint)
                    canvas.drawText(day.toString(), x, y, todayTextPaint)
                } else {
                    canvas.drawText(day.toString(), x, y, dayPaint)
                }
                val hType = holidayMap[day]; val hasPersonal = eventDays.contains(day)
                if (hType != null || hasPersonal) {
                    dotPaint.color = when (hType) {
                        "SABARIMALA" -> Color.parseColor("#FFD54F")
                        "FESTIVAL" -> Color.parseColor("#FF8A65")
                        "BANK_COURT" -> Color.parseColor("#4FC3F7")
                        else -> Color.parseColor("#81C784")
                    }
                    canvas.drawCircle(x, y + (daySize * 0.46f), max(4f, daySize * 0.16f), dotPaint)
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
                val x = gridLeft + col * colStep
                val y = gridTop + row * rowStep
                hitBoxes.add(DayHitBox(day, x, y - daySize * 0.3f, daySize * 0.95f))
                if (isCurrentMonth && day == realToday) {
                    canvas.drawCircle(x, y - (daySize * 0.34f), daySize * 0.78f, todayBgPaint)
                    canvas.drawText(day.toString(), x, y, todayTextPaint)
                } else {
                    canvas.drawText(day.toString(), x, y, dayPaint)
                }
                val hType = holidayMap[day]; val hasPersonal = eventDays.contains(day)
                if (hType != null || hasPersonal) {
                    dotPaint.color = when (hType) {
                        "SABARIMALA" -> Color.parseColor("#FFD54F")
                        "FESTIVAL" -> Color.parseColor("#FF8A65")
                        "BANK_COURT" -> Color.parseColor("#4FC3F7")
                        else -> Color.parseColor("#81C784")
                    }
                    canvas.drawCircle(x, y + (daySize * 0.46f), max(4f, daySize * 0.16f), dotPaint)
                }
                col++; if (col > 6) { col = 0; row++ }
            }
        }
    }
}
