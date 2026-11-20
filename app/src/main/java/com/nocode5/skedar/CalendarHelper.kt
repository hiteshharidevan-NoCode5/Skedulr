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
                    put(CalendarContract.Events.DESCRIPTION, "Added via Skedulr ($category)")
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
