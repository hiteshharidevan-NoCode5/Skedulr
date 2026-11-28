package com.nocode5.skedar

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

object CalendarHelper {
    fun hasReadPermission(c: Context) = ContextCompat.checkSelfPermission(c, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
    fun hasWritePermission(c: Context) = ContextCompat.checkSelfPermission(c, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun addEntry(context: Context, title: String, category: String, year: Int, monthZeroBased: Int, day: Int): Boolean {
        val formattedTitle = "[$category] $title"
        val prefs = context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString("items", "[]"))
        arr.put(JSONObject().apply {
            put("title", formattedTitle); put("category", category); put("year", year); put("month", monthZeroBased); put("day", day)
        })
        prefs.edit().putString("items", arr.toString()).apply()

        if (hasReadPermission(context) && hasWritePermission(context)) {
            try {
                val calId = getPrimaryCalendarId(context) ?: return true
                val startCal = Calendar.getInstance().apply { set(year, monthZeroBased, day, 9, 0, 0) }
                val endCal = Calendar.getInstance().apply { set(year, monthZeroBased, day, 10, 0, 0) }
                val values = ContentValues().apply {
                    put(CalendarContract.Events.DTSTART, startCal.timeInMillis)
                    put(CalendarContract.Events.DTEND, endCal.timeInMillis)
                    put(CalendarContract.Events.TITLE, formattedTitle)
                    put(CalendarContract.Events.DESCRIPTION, "Added via Skedulr ($category)")
                    put(CalendarContract.Events.CALENDAR_ID, calId)
                    put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                    if (category == "Birthday" || category == "Anniversary") put(CalendarContract.Events.RRULE, "FREQ=YEARLY")
                }
                context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            } catch (_: Exception) {}
        }
        return true
    }

    fun deleteLocalEntriesForDate(context: Context, year: Int, monthZeroBased: Int, day: Int): Int {
        val prefs = context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString("items", "[]"))
        val kept = JSONArray(); var removed = 0
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val isAnnual = o.optString("category", "") in listOf("Birthday", "Anniversary")
            if (o.getInt("month") == monthZeroBased && o.getInt("day") == day && (isAnnual || o.getInt("year") == year)) removed++ else kept.put(o)
        }
        prefs.edit().putString("items", kept.toString()).apply()
        return removed
    }

    private fun getPrimaryCalendarId(context: Context): Long? {
        context.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.IS_PRIMARY), null, null, null)?.use { c ->
            var fallback: Long? = null
            while (c.moveToNext()) {
                val id = c.getLong(0); if (fallback == null) fallback = id
                if (c.getInt(1) == 1) return id
            }
            return fallback
        }
        return null
    }

    fun getLocalEntriesForDate(context: Context, year: Int, monthZeroBased: Int, day: Int): List<String> {
        val list = mutableListOf<String>()
        val arr = JSONArray(context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE).getString("items", "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val isAnnual = o.optString("category", "") in listOf("Birthday", "Anniversary")
            if (o.getInt("month") == monthZeroBased && o.getInt("day") == day && (isAnnual || o.getInt("year") == year)) list.add(o.getString("title"))
        }
        return list
    }

    fun getGoogleEventsForDate(context: Context, year: Int, monthZeroBased: Int, day: Int): List<String> {
        val results = mutableListOf<String>()
        if (!hasReadPermission(context)) return results
        val s = Calendar.getInstance().apply { set(year, monthZeroBased, day, 0, 0, 0); set(Calendar.MILLISECOND, 0) }
        val e = Calendar.getInstance().apply { set(year, monthZeroBased, day, 23, 59, 59); set(Calendar.MILLISECOND, 999) }
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, s.timeInMillis); ContentUris.appendId(builder, e.timeInMillis)
        val timeFmt = SimpleDateFormat("h:mm a", Locale.getDefault())
        try {
            context.contentResolver.query(builder.build(), arrayOf(CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN, CalendarContract.Instances.ALL_DAY), null, null, "${CalendarContract.Instances.BEGIN} ASC")?.use { c ->
                val seen = mutableSetOf<String>()
                while (c.moveToNext()) {
                    val t = c.getString(0)?.takeIf { it.isNotBlank() } ?: "Untitled Event"
                    val label = if (c.getInt(2) == 1) "$t (All day)" else "$t (${timeFmt.format(Date(c.getLong(1)))})"
                    if (seen.add(label)) results.add(label)
                }
            }
        } catch (_: Exception) {}
        return results
    }

    fun getEventDaysInMonth(context: Context, year: Int, month: Int): Set<Int> {
        val days = mutableSetOf<Int>()
        val arr = JSONArray(context.getSharedPreferences("skedar_entries", Context.MODE_PRIVATE).getString("items", "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val isAnnual = o.optString("category", "") in listOf("Birthday", "Anniversary")
            if (o.getInt("month") == month && (isAnnual || o.getInt("year") == year)) days.add(o.getInt("day"))
        }
        if (hasReadPermission(context)) {
            val s = Calendar.getInstance().apply { set(year, month, 1, 0, 0, 0); set(Calendar.MILLISECOND, 0) }
            val e = Calendar.getInstance().apply { set(year, month, getActualMaximum(Calendar.DAY_OF_MONTH), 23, 59, 59); set(Calendar.MILLISECOND, 999) }
            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(builder, s.timeInMillis); ContentUris.appendId(builder, e.timeInMillis)
            try {
                context.contentResolver.query(builder.build(), arrayOf(CalendarContract.Instances.BEGIN), null, null, null)?.use { c ->
                    val tmp = Calendar.getInstance()
                    while (c.moveToNext()) { tmp.timeInMillis = c.getLong(0); if (tmp.get(Calendar.MONTH) == month) days.add(tmp.get(Calendar.DAY_OF_MONTH)) }
                }
            } catch (_: Exception) {}
        }
        return days
    }

    fun getNextEventSummary(context: Context): String {
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR); val m = cal.get(Calendar.MONTH); val d = cal.get(Calendar.DAY_OF_MONTH)
        val combined = (getLocalEntriesForDate(context, y, m, d) + getGoogleEventsForDate(context, y, m, d) + HolidayRepository.getHolidaysForDate(y, m, d).map { it.title }).distinct()
        val sb = StringBuilder()
        if (combined.isNotEmpty()) {
            sb.append("TODAY'S AGENDA & OBSERVANCES:\n")
            combined.forEach { sb.append("• $it\n") }; sb.append("\n")
        }
        if (!hasReadPermission(context)) return sb.append("NEXT UP:\nGrant calendar permission to sync Google Calendar.").toString().trim()
        val now = System.currentTimeMillis()
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, now); ContentUris.appendId(builder, now + 30L * 24 * 60 * 60 * 1000)
        try {
            context.contentResolver.query(builder.build(), arrayOf(CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN), "${CalendarContract.Instances.BEGIN} >= ?", arrayOf(now.toString()), "${CalendarContract.Instances.BEGIN} ASC")?.use { c ->
                if (c.moveToFirst()) {
                    val fmt = SimpleDateFormat("EEE, d MMM • h:mm a", Locale.getDefault())
                    return sb.append("NEXT UP:\n${c.getString(0) ?: "Untitled Event"}\n${fmt.format(Date(c.getLong(1)))}").toString().trim()
                }
            }
        } catch (_: Exception) {}
        return sb.append("NEXT UP:\nNo upcoming events in the next 30 days.").toString().trim()
    }
}
