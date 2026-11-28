package com.nocode5.skedar

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.Calendar

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("daily_reminder", true)) return
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR); val m = cal.get(Calendar.MONTH); val d = cal.get(Calendar.DAY_OF_MONTH)
        val items = (CalendarHelper.getLocalEntriesForDate(context, y, m, d) +
            CalendarHelper.getGoogleEventsForDate(context, y, m, d) +
            HolidayRepository.getHolidaysForDate(y, m, d).map { it.title }).distinct()
        if (items.isNotEmpty()) showNotification(context, items.joinToString(" • "))
        scheduleDaily8AM(context)
    }

    private fun showNotification(context: Context, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val channelId = "skedulr_daily"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(channelId, "Skedulr Daily Agenda", NotificationManager.IMPORTANCE_DEFAULT))
        val pendingTap = PendingIntent.getActivity(context, 200, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notif = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Skedulr • Today's Agenda")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingTap)
            .setAutoCancel(true).build()
        manager.notify(1001, notif)
    }

    companion object {
        fun scheduleDaily8AM(context: Context) {
            val prefs = context.getSharedPreferences("skedar_prefs", Context.MODE_PRIVATE)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = PendingIntent.getBroadcast(context, 201, Intent(context, DailyReminderReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            if (!prefs.getBoolean("daily_reminder", true)) { alarmManager.cancel(pending); return }
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 8); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }
            alarmManager.setInexactRepeating(AlarmManager.RTC_WAKEUP, target.timeInMillis, AlarmManager.INTERVAL_DAY, pending)
        }
    }
}
