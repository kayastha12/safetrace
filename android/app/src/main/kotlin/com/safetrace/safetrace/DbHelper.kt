package com.safetrace.safetrace

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class DbHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "DbHelper"
        private const val DATABASE_NAME = "safetrace.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_LOGS = "logs"
        const val COLUMN_ID = "id"
        const val COLUMN_COMMAND_TYPE = "command_type"
        const val COLUMN_SENDER_NUMBER = "sender_number"
        const val COLUMN_LOCATION_DATA = "location_data"
        const val COLUMN_BATTERY_PERCENTAGE = "battery_percentage"
        const val COLUMN_TIMESTAMP = "timestamp"
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = ("CREATE TABLE " + TABLE_LOGS + "("
                + COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT,"
                + COLUMN_COMMAND_TYPE + " TEXT,"
                + COLUMN_SENDER_NUMBER + " TEXT,"
                + COLUMN_LOCATION_DATA + " TEXT,"
                + COLUMN_BATTERY_PERCENTAGE + " INTEGER,"
                + COLUMN_TIMESTAMP + " TEXT" + ")")
        db.execSQL(createTable)
        Log.d(TAG, "Table created: $TABLE_LOGS")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_LOGS")
        onCreate(db)
    }

    fun insertLog(commandType: String, sender: String, location: String, battery: Int, timestamp: String): Long {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_COMMAND_TYPE, commandType)
            put(COLUMN_SENDER_NUMBER, sender)
            put(COLUMN_LOCATION_DATA, location)
            put(COLUMN_BATTERY_PERCENTAGE, battery)
            put(COLUMN_TIMESTAMP, timestamp)
        }
        val id = db.insert(TABLE_LOGS, null, values)
        db.close()
        Log.d(TAG, "Logged action: $commandType from $sender, success with ID: $id")
        return id
    }
}
