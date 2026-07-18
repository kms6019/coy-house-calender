package com.example.test_calender

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import org.json.JSONArray

class CalendarMonthWidgetProvider : AppWidgetProvider() {

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
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val title = prefs.getString("calendar_month_title", "") ?: ""
            val cellsJson = prefs.getString("calendar_month_cells", "[]") ?: "[]"

            val views = RemoteViews(context.packageName, R.layout.calendar_month_widget)
            views.setTextViewText(R.id.widget_month_title, title)

            val cellIds = intArrayOf(
                R.id.widget_cell_0,
                R.id.widget_cell_1,
                R.id.widget_cell_2,
                R.id.widget_cell_3,
                R.id.widget_cell_4,
                R.id.widget_cell_5,
                R.id.widget_cell_6,
                R.id.widget_cell_7,
                R.id.widget_cell_8,
                R.id.widget_cell_9,
                R.id.widget_cell_10,
                R.id.widget_cell_11,
                R.id.widget_cell_12,
                R.id.widget_cell_13,
                R.id.widget_cell_14,
                R.id.widget_cell_15,
                R.id.widget_cell_16,
                R.id.widget_cell_17,
                R.id.widget_cell_18,
                R.id.widget_cell_19,
                R.id.widget_cell_20,
                R.id.widget_cell_21,
                R.id.widget_cell_22,
                R.id.widget_cell_23,
                R.id.widget_cell_24,
                R.id.widget_cell_25,
                R.id.widget_cell_26,
                R.id.widget_cell_27,
                R.id.widget_cell_28,
                R.id.widget_cell_29,
                R.id.widget_cell_30,
                R.id.widget_cell_31,
                R.id.widget_cell_32,
                R.id.widget_cell_33,
                R.id.widget_cell_34,
                R.id.widget_cell_35,
                R.id.widget_cell_36,
                R.id.widget_cell_37,
                R.id.widget_cell_38,
                R.id.widget_cell_39,
                R.id.widget_cell_40,
                R.id.widget_cell_41
            )

            for (cellId in cellIds) {
                views.setTextViewText(cellId, "")
                views.setTextColor(cellId, Color.parseColor("#212121"))
                views.setInt(cellId, "setBackgroundColor", Color.TRANSPARENT)
            }

            try {
                val arr = JSONArray(cellsJson)
                for (i in 0 until minOf(arr.length(), cellIds.size)) {
                    val obj = arr.optJSONObject(i) ?: continue
                    val cellId = cellIds[i]
                    val day = obj.optString("d", "")

                    views.setTextColor(cellId, Color.parseColor("#212121"))
                    views.setInt(cellId, "setBackgroundColor", Color.TRANSPARENT)

                    if (day.isEmpty()) {
                        views.setTextViewText(cellId, "")
                        continue
                    }

                    // 날짜 숫자(굵게) + 이벤트 제목들(작은 글씨) 멀티라인
                    val text = SpannableStringBuilder(day)
                    text.setSpan(
                        StyleSpan(Typeface.BOLD),
                        0, day.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                    val titles = obj.optJSONArray("t")
                    if (titles != null) {
                        for (t in 0 until titles.length()) {
                            val start = text.length
                            text.append("\n").append(titles.optString(t, ""))
                            text.setSpan(
                                RelativeSizeSpan(0.85f),
                                start, text.length,
                                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                            )
                        }
                    }
                    views.setTextViewText(cellId, text)

                    if (obj.optBoolean("ev", false)) {
                        views.setTextColor(cellId, Color.parseColor("#D81B60"))
                    }
                    if (obj.optBoolean("today", false)) {
                        views.setInt(
                            cellId,
                            "setBackgroundColor",
                            0xFF7E57C2.toInt()
                        )
                        views.setTextColor(cellId, Color.WHITE)
                    }
                }
            } catch (_: Exception) {
                // 헤더와 초기화된 빈 그리드는 그대로 표시한다.
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
