package com.example.weekly_task

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

class WeeklyGoalWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { update(context, manager, it) }
    }

    companion object {
        private const val preferencesName = "FlutterSharedPreferences"
        private const val stateKey = "flutter.weekly_task_state_v1"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, WeeklyGoalWidget::class.java)
            manager.getAppWidgetIds(component).forEach { update(context, manager, it) }
        }

        private fun update(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.weekly_goal_widget)
            val raw = context
                .getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .getString(stateKey, null)
            val current = try {
                raw?.let { JSONObject(it).optJSONObject("current") }
            } catch (_: Exception) {
                null
            }
            val week = current?.optInt("weekNumber", 0) ?: 0
            val goal = current?.optString("text", "")?.takeIf { it.isNotBlank() }
                ?: "No weekly goal set"
            views.setTextViewText(
                R.id.widget_week,
                if (week > 0) "Week $week" else "Weekly goal",
            )
            views.setTextViewText(R.id.widget_goal, goal)
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(widgetId, views)
        }
    }
}
