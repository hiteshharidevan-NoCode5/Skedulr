package com.nocode5.skedar

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.*

object CalendarHelper {

    fun hasPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun getEventDaysInMonth(context: Context, year: Int, month: Int): Set<Int> {
        val eventDays = mutableSetOf<Int>()
        if (!hasPermission(context)) return eventDays

        val calStart = Calendar.getInstance().apply {
            set(year, month, 1, 0, 0, 0)
        }
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
                    val startMillis = cursor.getLong(0)
                    tempCal.timeInMillis = startMillis
                    eventDays.add(tempCal.get(Calendar.DAY_OF_MONTH))
                }
            }
        } catch (_: Exception) {}
        return eventDays
    }

    fun getNextEventSummary(context: Context): String {
        if (!hasPermission(context)) {
            return "Calendar permission needed to read your next event or chore."
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
                    return "NEXT UP:\n$title\n${fmt.format(Date(start))}"
                }
            }
        } catch (_: Exception) {}
        return "NEXT UP:\nNo upcoming events or chores found."
    }
}
