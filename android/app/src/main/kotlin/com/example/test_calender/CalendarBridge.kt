package com.example.test_calender

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CalendarBridge private constructor(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val contentResolver = context.contentResolver

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "queryCalendars" -> execute(
                result = result,
                permissions = arrayOf(Manifest.permission.READ_CALENDAR),
                errorCode = "QUERY_CALENDARS_FAILED",
            ) {
                queryCalendars()
            }

            "ensureCalendar" -> execute(
                result = result,
                permissions = arrayOf(
                    Manifest.permission.READ_CALENDAR,
                    Manifest.permission.WRITE_CALENDAR,
                ),
                errorCode = "ENSURE_CALENDAR_FAILED",
            ) {
                ensureCalendar(call.requiredString("name"))
            }

            "deleteCalendarsByName" -> execute(
                result = result,
                permissions = arrayOf(
                    Manifest.permission.READ_CALENDAR,
                    Manifest.permission.WRITE_CALENDAR,
                ),
                errorCode = "DELETE_CALENDARS_FAILED",
            ) {
                deleteCalendarsByName(call.requiredString("name"))
            }

            "queryEvents" -> execute(
                result = result,
                permissions = arrayOf(Manifest.permission.READ_CALENDAR),
                errorCode = "QUERY_EVENTS_FAILED",
            ) {
                queryEvents(call.requiredString("calendarId"))
            }

            "upsertEvent" -> execute(
                result = result,
                permissions = arrayOf(Manifest.permission.WRITE_CALENDAR),
                errorCode = "UPSERT_EVENT_FAILED",
            ) {
                upsertEvent(call)
            }

            "deleteEvent" -> execute(
                result = result,
                permissions = arrayOf(Manifest.permission.WRITE_CALENDAR),
                errorCode = "DELETE_EVENT_FAILED",
            ) {
                deleteEvent(call.requiredString("eventId"))
            }

            else -> result.notImplemented()
        }
    }

    private fun queryCalendars(): List<Map<String, Any>> {
        val calendars = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
        )

        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            null,
            null,
            "${CalendarContract.Calendars._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val displayNameIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            )
            val nameIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.NAME)
            val accountNameIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.ACCOUNT_NAME,
            )
            val accountTypeIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.ACCOUNT_TYPE,
            )

            while (cursor.moveToNext()) {
                val displayName = cursor.getString(displayNameIndex)
                val name = displayName.takeUnless { it.isNullOrEmpty() }
                    ?: cursor.getString(nameIndex).orEmpty()
                val accountName = cursor.getString(accountNameIndex).orEmpty()
                val accountType = cursor.getString(accountTypeIndex).orEmpty()

                calendars += mapOf(
                    "id" to cursor.getLong(idIndex).toString(),
                    "name" to name,
                    "accountName" to accountName,
                    "accountType" to accountType,
                    "isLocal" to (accountType == CalendarContract.ACCOUNT_TYPE_LOCAL),
                )
            }
        }

        return calendars
    }

    private fun ensureCalendar(name: String): String {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} = ? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE} = ?"
        val selectionArgs = arrayOf(name, CalendarContract.ACCOUNT_TYPE_LOCAL)

        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${CalendarContract.Calendars._ID} ASC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(
                    cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID),
                ).toString()
            }
        }

        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, name)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, name)
            put(CalendarContract.Calendars.NAME, name)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, name)
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
            put(CalendarContract.Calendars.CALENDAR_COLOR, 0xFF7E57C2.toInt())
        }

        // 로컬 캘린더 생성은 동기화 어댑터 권한으로 호출해야 계정 필드를 직접 지정할 수 있다.
        val insertedUri = contentResolver.insert(
            asSyncAdapter(
                CalendarContract.Calendars.CONTENT_URI,
                accountName = name,
                accountType = CalendarContract.ACCOUNT_TYPE_LOCAL,
            ),
            values,
        ) ?: throw IllegalStateException("캘린더 생성 결과 URI가 없습니다.")

        return ContentUris.parseId(insertedUri).toString()
    }

    private fun deleteCalendarsByName(name: String): Int {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
        )
        val selection =
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} = ? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE} = ?"
        val selectionArgs = arrayOf(name, CalendarContract.ACCOUNT_TYPE_LOCAL)
        val targets = mutableListOf<CalendarToDelete>()

        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${CalendarContract.Calendars._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val accountNameIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.ACCOUNT_NAME,
            )
            val accountTypeIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.ACCOUNT_TYPE,
            )

            while (cursor.moveToNext()) {
                targets += CalendarToDelete(
                    id = cursor.getLong(idIndex),
                    accountName = cursor.getString(accountNameIndex) ?: name,
                    accountType = cursor.getString(accountTypeIndex)
                        ?: CalendarContract.ACCOUNT_TYPE_LOCAL,
                )
            }
        }

        var deletedCount = 0
        for (target in targets) {
            val calendarUri = ContentUris.withAppendedId(
                CalendarContract.Calendars.CONTENT_URI,
                target.id,
            )
            // 일반 delete는 일부 제조사 캘린더에서 삭제 플래그만 남길 수 있어 실제 제거용 URI를 쓴다.
            val syncAdapterUri = asSyncAdapter(
                calendarUri,
                accountName = target.accountName,
                accountType = target.accountType,
            )
            deletedCount += contentResolver.delete(syncAdapterUri, null, null)
        }

        return deletedCount
    }

    private fun queryEvents(calendarId: String): List<Map<String, Any?>> {
        calendarId.toLongOrNull()
            ?: throw IllegalArgumentException("calendarId는 숫자 문자열이어야 합니다.")

        val events = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.ALL_DAY,
            CalendarContract.Events.CUSTOM_APP_URI,
            CalendarContract.Events.RRULE,
        )
        val selection =
            "${CalendarContract.Events.CALENDAR_ID} = ? AND ${CalendarContract.Events.DELETED} = 0"

        // Instances는 기간 범위가 필수이므로, 원본 이벤트를 한 행씩 얻기 위해 Events를 직접 조회한다.
        contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            selection,
            arrayOf(calendarId),
            "${CalendarContract.Events._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events._ID)
            val titleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.TITLE)
            val startIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTSTART)
            val endIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTEND)
            val allDayIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ALL_DAY)
            val customAppUriIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Events.CUSTOM_APP_URI,
            )
            val rruleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.RRULE)

            while (cursor.moveToNext()) {
                events += mapOf(
                    "id" to cursor.getLong(idIndex).toString(),
                    "title" to cursor.getString(titleIndex),
                    "dtstart" to cursor.getLong(startIndex),
                    "dtend" to if (cursor.isNull(endIndex)) null else cursor.getLong(endIndex),
                    "allDay" to (cursor.getInt(allDayIndex) != 0),
                    "customAppUri" to cursor.getString(customAppUriIndex),
                    "rrule" to cursor.getString(rruleIndex),
                )
            }
        }

        return events
    }

    private fun upsertEvent(call: MethodCall): String {
        val calendarId = call.requiredString("calendarId").toLongOrNull()
            ?: throw IllegalArgumentException("calendarId는 숫자 문자열이어야 합니다.")
        val eventId = call.argument<String>("eventId")
        val title = call.requiredString("title")
        val description = call.argument<String>("description")
        val dtstart = call.requiredLong("dtstart")
        val dtend = call.requiredLong("dtend")
        val allDay = call.requiredBoolean("allDay")
        val timeZone = call.requiredString("timeZone")
        val rrule = call.argument<String>("rrule")?.takeUnless { it.isEmpty() }
        val customAppUri = call.argument<String>("customAppUri")

        if (dtend < dtstart) {
            throw IllegalArgumentException("dtend는 dtstart보다 빠를 수 없습니다.")
        }

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, description)
            put(CalendarContract.Events.DTSTART, dtstart)
            put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
            // 종일 일정은 CalendarContract 규약상 UTC 기준 밀리초와 UTC 시간대를 사용한다.
            put(CalendarContract.Events.EVENT_TIMEZONE, if (allDay) "UTC" else timeZone)
            put(CalendarContract.Events.CUSTOM_APP_URI, customAppUri)

            if (rrule != null) {
                put(CalendarContract.Events.RRULE, rrule)
                // 반복 일정은 DTEND와 DURATION을 함께 둘 수 없어 DTEND를 비우고 길이를 저장한다.
                putNull(CalendarContract.Events.DTEND)
                put(CalendarContract.Events.DURATION, toRfc2445Duration(dtend - dtstart, allDay))
            } else {
                putNull(CalendarContract.Events.RRULE)
                putNull(CalendarContract.Events.DURATION)
                put(CalendarContract.Events.DTEND, dtend)
            }
        }

        if (eventId != null) {
            val numericEventId = eventId.toLongOrNull()
                ?: throw IllegalArgumentException("eventId는 숫자 문자열이어야 합니다.")
            val eventUri = ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI,
                numericEventId,
            )
            val updatedRows = contentResolver.update(eventUri, values, null, null)
            if (updatedRows == 0) {
                throw IllegalStateException("수정할 이벤트를 찾지 못했습니다: $eventId")
            }
            return eventId
        }

        val insertedUri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            ?: throw IllegalStateException("이벤트 생성 결과 URI가 없습니다.")
        return ContentUris.parseId(insertedUri).toString()
    }

    private fun deleteEvent(eventId: String): Boolean {
        val numericEventId = eventId.toLongOrNull()
            ?: throw IllegalArgumentException("eventId는 숫자 문자열이어야 합니다.")
        val eventUri = ContentUris.withAppendedId(
            CalendarContract.Events.CONTENT_URI,
            numericEventId,
        )
        return contentResolver.delete(eventUri, null, null) > 0
    }

    private fun toRfc2445Duration(durationMillis: Long, allDay: Boolean): String {
        val dayMillis = 24L * 60L * 60L * 1000L
        if (allDay && durationMillis % dayMillis == 0L) {
            return "P${durationMillis / dayMillis}D"
        }

        val durationSeconds = (durationMillis + 999L) / 1000L
        return "P${durationSeconds}S"
    }

    private fun asSyncAdapter(
        uri: Uri,
        accountName: String,
        accountType: String,
    ): Uri = uri.buildUpon()
        .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
        .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, accountName)
        .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, accountType)
        .build()

    private fun execute(
        result: MethodChannel.Result,
        permissions: Array<String>,
        errorCode: String,
        block: () -> Any?,
    ) {
        val missingPermissions = permissions.filter {
            context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missingPermissions.isNotEmpty()) {
            result.error(
                "PERMISSION_DENIED",
                "캘린더 권한이 없습니다: ${missingPermissions.joinToString()}",
                null,
            )
            return
        }

        try {
            result.success(block())
        } catch (exception: SecurityException) {
            result.error("PERMISSION_DENIED", exception.message ?: "캘린더 권한이 없습니다.", null)
        } catch (exception: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", exception.message ?: "잘못된 인자입니다.", null)
        } catch (exception: Exception) {
            result.error(errorCode, exception.message ?: exception.javaClass.simpleName, null)
        }
    }

    private fun MethodCall.requiredString(key: String): String =
        argument<String>(key) ?: throw IllegalArgumentException("$key 인자가 필요합니다.")

    private fun MethodCall.requiredLong(key: String): Long =
        argument<Number>(key)?.toLong()
            ?: throw IllegalArgumentException("$key 인자는 숫자여야 합니다.")

    private fun MethodCall.requiredBoolean(key: String): Boolean =
        argument<Boolean>(key) ?: throw IllegalArgumentException("$key 인자는 Boolean이어야 합니다.")

    private data class CalendarToDelete(
        val id: Long,
        val accountName: String,
        val accountType: String,
    )

    companion object {
        private const val CHANNEL_NAME = "coyhouse/calendar"

        fun register(context: Context, messenger: BinaryMessenger) {
            val bridge = CalendarBridge(context.applicationContext)
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(bridge)
        }
    }
}
