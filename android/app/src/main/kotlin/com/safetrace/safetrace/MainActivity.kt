package com.safetrace.safetrace

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.telephony.SubscriptionManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.safetrace/native"
    private val smsReceiver = SmsReceiver()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    try {
                        val intent = Intent(this, LocationService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to start location service", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopLocationService" -> {
                    try {
                        val intent = Intent(this, LocationService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to stop location service", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "isLocationServiceRunning" -> {
                    result.success(LocationService.isServiceRunning)
                }
                "startAlarm" -> {
                    try {
                        AlarmService.startAlarm(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to start alarm service", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        AlarmService.stopAlarm(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to stop alarm service", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "isAlarmRinging" -> {
                    result.success(AlarmService.isRinging)
                }
                "getCurrentSimDetails" -> {
                    val simDetails = getCurrentSimSignature()
                    result.success(simDetails)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getCurrentSimSignature(): String {
        try {
            val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            if (subscriptionManager != null) {
                val infoList = subscriptionManager.activeSubscriptionInfoList
                if (!infoList.isNullOrEmpty()) {
                    return infoList.map { info ->
                        "${info.subscriptionId}_${info.displayName}_${info.simSlotIndex}"
                    }.sorted().joinToString("|")
                }
            }
        } catch (e: SecurityException) {
            Log.e("MainActivity", "Permission missing for activeSubscriptionInfoList", e)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error fetching SIM details", e)
        }
        return ""
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED").apply {
            priority = 999
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(smsReceiver)
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun onPause() {
        super.onPause()
        relaunchIfLocked()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        relaunchIfLocked()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("flutter.is_app_locked", false)
        if (isLocked) {
            return // Block back button
        }
        super.onBackPressed()
    }

    private fun relaunchIfLocked() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isLocked = prefs.getBoolean("flutter.is_app_locked", false)
            if (isLocked) {
                val intent = Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error relaunching locked MainActivity", e)
        }
    }
}
