package com.example.test_calender

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            // home_widget 플러그인은 HomeWidgetPreferences에 prefix 없이 저장한다
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val todayLabel = prefs.getString("calendar_widget_today", "") ?: ""
            val eventsJson = prefs.getString("calendar_widget_events", "[]") ?: "[]"

            val views = RemoteViews(context.packageName, R.layout.calendar_widget)
            views.setTextViewText(R.id.widget_today_label, todayLabel)

            val ddayLine = prefs.getString("calendar_widget_dday", "") ?: ""
            if (ddayLine.isNotEmpty()) {
                views.setTextViewText(R.id.widget_dday, ddayLine)
                views.setViewVisibility(R.id.widget_dday, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_dday, View.GONE)
            }

            val eventIds = listOf(R.id.widget_event_1, R.id.widget_event_2, R.id.widget_event_3)
            eventIds.forEach { views.setViewVisibility(it, View.GONE) }
            views.setViewVisibility(R.id.widget_no_events, View.GONE)

            try {
                val arr = JSONArray(eventsJson)
                if (arr.length() == 0) {
                    views.setViewVisibility(R.id.widget_no_events, View.VISIBLE)
                } else {
                    for (i in 0 until minOf(arr.length(), 3)) {
                        val obj = arr.getJSONObject(i)
                        val time = obj.optString("time", "")
                        val title = obj.optString("title", "")
                        val label = if (time.isNotEmpty()) "• $time  $title" else "• $title"
                        views.setTextViewText(eventIds[i], label)
                        views.setViewVisibility(eventIds[i], View.VISIBLE)
                    }
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.widget_no_events, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
