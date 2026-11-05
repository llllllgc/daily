package com.example.daily

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DailyWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { refresh(context) }
    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DailyWidgetProvider::class.java))
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            var current: JSONObject? = null
            try {
                val raw = context.getSharedPreferences("daily_widget", Context.MODE_PRIVATE).getString("content", null)
                val days = JSONObject(raw ?: "{}").optJSONArray("days")
                if (days != null) for (index in 0 until days.length()) {
                    val day = days.getJSONObject(index)
                    if (day.optString("date") == today) { current = day; break }
                }
            } catch (_: Exception) { }
            for (id in ids) {
                val view = RemoteViews(context.packageName, R.layout.daily_widget)
                val completed = current?.optInt("completed") ?: 0
                val total = current?.optInt("total") ?: 0
                view.setTextViewText(R.id.widget_progress, "已完成 $completed/$total")
                view.setProgressBar(R.id.widget_bar, if (total > 0) total else 1, completed, false)
                val tasks = current?.optJSONArray("tasks")
                val lines = mutableListOf<String>()
                if (tasks != null) for (index in 0 until minOf(tasks.length(), 3)) {
                    val task = tasks.getJSONObject(index)
                    lines.add("${task.optString("time")}  ${task.optString("title")}")
                }
                view.setTextViewText(R.id.widget_tasks, if (lines.isEmpty()) if (total == 0) "今天暂无安排" else "今天的事项已处理" else lines.joinToString("\n"))
                val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                view.setOnClickPendingIntent(R.id.widget_root, open)
                manager.updateAppWidget(id, view)
            }
        }
    }
}
