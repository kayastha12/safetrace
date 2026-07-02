package com.safetrace.safetrace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.location.LocationManager
import android.os.BatteryManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SimChangeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SimChangeReceiver"
        private var lastAlertTime: Long = 0
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Received action: $action")

        if (action == "android.intent.action.SIM_STATE_CHANGED" || action == Intent.ACTION_BOOT_COMPLETED) {
            // Check SIM state from extras if SIM_STATE_CHANGED
            if (action == "android.intent.action.SIM_STATE_CHANGED") {
                val state = intent.getStringExtra("ss")
                Log.d(TAG, "SIM State: $state")
                if (state != "LOADED" && state != "READY") {
                    return // SIM is not fully ready/loaded yet
                }
            }

            // Perform check
            checkSimSwap(context)
        }
    }

    private fun checkSimSwap(context: Context) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedSimSerial = prefs.getString("flutter.saved_sim_serial", "") ?: ""
            val trustedNumber = prefs.getString("flutter.trusted_number", "") ?: ""

            if (savedSimSerial.isEmpty()) {
                Log.d(TAG, "SIM Swap detection not armed. No saved SIM configuration.")
                return
            }

            if (trustedNumber.isEmpty()) {
                Log.d(TAG, "SIM Swap detected but no trusted number configured to send alert.")
                return
            }

            // Get current SIM signature
            val currentSimSerial = getCurrentSimSignature(context)
            if (currentSimSerial.isEmpty()) {
                Log.d(TAG, "Current SIM info is empty or permissions missing.")
                return
            }

            Log.d(TAG, "Saved SIM: $savedSimSerial, Current SIM: $currentSimSerial")

            if (savedSimSerial != currentSimSerial) {
                // SIM Change Detected!
                val currentTime = System.currentTimeMillis()
                if (currentTime - lastAlertTime < 300000) { // 5 minutes rate limit
                    Log.d(TAG, "SIM swap detected but rate limited (last alert within 5 mins).")
                    return
                }
                lastAlertTime = currentTime

                Log.d(TAG, "ALERT: SIM Card Change Detected!")
                triggerSimAlert(context, trustedNumber, currentSimSerial)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in checkSimSwap", e)
        }
    }

    private fun getCurrentSimSignature(context: Context): String {
        try {
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            if (subscriptionManager != null) {
                val infoList = subscriptionManager.activeSubscriptionInfoList
                if (!infoList.isNullOrEmpty()) {
                    return infoList.map { info ->
                        "${info.subscriptionId}_${info.displayName}_${info.simSlotIndex}"
                    }.sorted().joinToString("|")
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission missing for activeSubscriptionInfoList", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching SIM details", e)
        }
        return ""
    }

    private fun triggerSimAlert(context: Context, trustedNumber: String, newSimDetails: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())

        // Get location backup
        val backupLat = prefs.getFloat("flutter.last_latitude", 0.0f).toDouble()
        val backupLng = prefs.getFloat("flutter.last_longitude", 0.0f).toDouble()
        var locationStr = "Unknown"
        if (backupLat != 0.0 && backupLng != 0.0) {
            locationStr = "https://maps.google.com/?q=$backupLat,$backupLng"
        }

        // Get Battery Info
        val batteryIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else -1

        val alertMessage = "SafeTrace ALERT: A new SIM card has been inserted into your phone!\n" +
                "Last Location: $locationStr\n" +
                "Battery: $batteryPct%\n" +
                "Time: $timestamp"

        // Send SMS
        try {
            val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                context.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(alertMessage)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(trustedNumber, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(trustedNumber, null, alertMessage, null, null)
            }
            Log.d(TAG, "Alert SMS sent to $trustedNumber: $alertMessage")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send alert SMS", e)
        }

        // Write Log
        val dbHelper = DbHelper(context)
        dbHelper.insertLog("SIM_CHANGE_DETECTED", "SYSTEM", "New SIM: $newSimDetails, Loc: $locationStr", batteryPct, timestamp)
    }
}
