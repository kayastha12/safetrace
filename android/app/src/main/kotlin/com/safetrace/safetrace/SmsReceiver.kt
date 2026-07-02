package com.safetrace.safetrace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
        private var lastProcessedSender: String? = null
        private var lastProcessedBody: String? = null
        private var lastProcessedTime: Long = 0
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive triggered with action: ${intent.action}")
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "Action mismatch, ignoring broadcast")
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            Log.d(TAG, "Parsed ${messages?.size ?: 0} messages from intent")
            if (messages == null || messages.isEmpty()) {
                Log.d(TAG, "No messages parsed, exiting")
                return
            }

            val sender = messages[0].displayOriginatingAddress
            Log.d(TAG, "Sender: $sender")
            if (sender == null) {
                Log.d(TAG, "Sender is null, exiting")
                return
            }
            val bodyBuilder = StringBuilder()
            for (msg in messages) {
                bodyBuilder.append(msg.displayMessageBody)
            }
            val body = bodyBuilder.toString().trim()

            // Check for duplicate deliveries (within 5 seconds for same sender and content)
            val currentTime = System.currentTimeMillis()
            if (sender == lastProcessedSender && body == lastProcessedBody && (currentTime - lastProcessedTime) < 5000) {
                Log.d(TAG, "Ignoring duplicate SMS delivery from $sender")
                return
            }
            lastProcessedSender = sender
            lastProcessedBody = body
            lastProcessedTime = currentTime
            Log.d(TAG, "Received SMS from $sender: $body")
            android.widget.Toast.makeText(context, "SafeTrace SMS: $body", android.widget.Toast.LENGTH_LONG).show()

            // Load shared preferences (Flutter prefix is 'flutter.')
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val trustedNumber = prefs.getString("flutter.trusted_number", "") ?: ""
            val keywordWhere = prefs.getString("flutter.keyword_where", "WHERE_MY_PHONE") ?: "WHERE_MY_PHONE"
            val keywordRing = prefs.getString("flutter.keyword_ring", "RING_MY_PHONE") ?: "RING_MY_PHONE"
            val keywordLock = prefs.getString("flutter.keyword_lock", "LOCK_MY_PHONE") ?: "LOCK_MY_PHONE"

            // Verify sender if trusted number is set
            val isTrustedSender = if (trustedNumber.trim().isNotEmpty()) {
                matchPhoneNumbers(sender, trustedNumber)
            } else {
                true // If no trusted number is set, we allow any sender who knows the secret keyword.
            }

            Log.d(TAG, "Verifying sender '$sender' against trusted number '$trustedNumber'. isTrusted: $isTrustedSender")

            if (!isTrustedSender) {
                Log.d(TAG, "SMS ignored: Sender $sender is not trusted ($trustedNumber)")
                return
            }

            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            val dbHelper = DbHelper(context)

            // Normalize SMS body and keywords (remove spaces, underscores, and compare in lowercase)
            val cleanBody = body.replace("[_\\s]".toRegex(), "").lowercase()
            val cleanWhere = keywordWhere.replace("[_\\s]".toRegex(), "").lowercase()
            val cleanRing = keywordRing.replace("[_\\s]".toRegex(), "").lowercase()
            val cleanLock = keywordLock.replace("[_\\s]".toRegex(), "").lowercase()

            Log.d(TAG, "Matching clean body '$cleanBody' against WHERE: '$cleanWhere', RING: '$cleanRing', LOCK: '$cleanLock'")

            if (cleanBody.startsWith(cleanWhere)) {
                Log.d(TAG, "WHERE command matched!")
                android.widget.Toast.makeText(context, "SafeTrace: Executing WHERE command", android.widget.Toast.LENGTH_LONG).show()
                handleWhereCommand(context, sender, dbHelper, timestamp)
            } else if (cleanBody.startsWith(cleanRing)) {
                Log.d(TAG, "RING command matched!")
                android.widget.Toast.makeText(context, "SafeTrace: Executing RING command", android.widget.Toast.LENGTH_LONG).show()
                handleRingCommand(context, sender, dbHelper, timestamp)
            } else if (cleanBody.startsWith(cleanLock)) {
                Log.d(TAG, "LOCK command matched!")
                android.widget.Toast.makeText(context, "SafeTrace: Executing LOCK command", android.widget.Toast.LENGTH_LONG).show()
                handleLockCommand(context, prefs, sender, dbHelper, timestamp)
            } else {
                Log.d(TAG, "No keywords matched the SMS content.")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error in SmsReceiver", e)
        }
    }

    private fun handleWhereCommand(context: Context, sender: String, dbHelper: DbHelper, timestamp: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // 1. Get Battery Info
        val batteryIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else -1
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        val batteryStr = "$batteryPct% ${if (isCharging) "(Charging)" else "(Discharging)"}"

        // 2. Get Location
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        var location: Location? = null
        try {
            if (isGpsEnabled) {
                location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            }
            if (location == null && isNetworkEnabled) {
                location = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException getting last known location", e)
        }

        var lat = 0.0
        var lng = 0.0
        var gotLocation = false
        var gpsNote = ""

        if (location != null) {
            lat = location.latitude
            lng = location.longitude
            gotLocation = true
            // Save as backup
            prefs.edit().putFloat("flutter.last_latitude", lat.toFloat()).putFloat("flutter.last_longitude", lng.toFloat()).apply()
        } else {
            // Read from SharedPreferences backup
            val backupLat = prefs.getFloat("flutter.last_latitude", 0.0f).toDouble()
            val backupLng = prefs.getFloat("flutter.last_longitude", 0.0f).toDouble()
            if (backupLat != 0.0 && backupLng != 0.0) {
                lat = backupLat
                lng = backupLng
                gotLocation = true
                gpsNote = " (Last known, GPS unavailable)"
            } else {
                gpsNote = " (Location unavailable)"
            }
        }

        // 3. Get Internet Status to see if we should send a Google Maps link or coordinates
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        val isInternetOn = capabilities != null && (
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        )

        // 4. Formulate Message
        val replyMessage = StringBuilder().apply {
            append("SafeTrace Recovery Update:\n")
            if (gotLocation) {
                if (isInternetOn) {
                    append("Google Maps: https://maps.google.com/?q=$lat,$lng$gpsNote\n")
                } else {
                    append("Coordinates: Lat: $lat, Lng: $lng$gpsNote\n")
                }
            } else {
                append("Location: $gpsNote\n")
            }
            append("Battery: $batteryStr\n")
            append("Time: $timestamp")
        }.toString()

        // 5. Send SMS
        sendSmsReply(context, sender, replyMessage)

        // 6. Write Log
        val locationData = if (gotLocation) "$lat,$lng$gpsNote" else "Unknown"
        dbHelper.insertLog("WHERE_MY_PHONE", sender, locationData, batteryPct, timestamp)
    }

    private fun handleRingCommand(context: Context, sender: String, dbHelper: DbHelper, timestamp: String) {
        // Start AlarmService
        AlarmService.startAlarm(context)

        // Reply SMS
        val replyMessage = "SafeTrace: Alarm triggered successfully at $timestamp"
        sendSmsReply(context, sender, replyMessage)

        // Write Log
        dbHelper.insertLog("RING_MY_PHONE", sender, "Alarm Triggered", -1, timestamp)
    }

    private fun handleLockCommand(context: Context, prefs: android.content.SharedPreferences, sender: String, dbHelper: DbHelper, timestamp: String) {
        // Enable application lock
        prefs.edit().putBoolean("flutter.is_app_locked", true).apply()

        // Launch MainActivity to show the lock overlay immediately
        try {
            val lockIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }
            context.startActivity(lockIntent)
            Log.d(TAG, "MainActivity started for remote lock")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start MainActivity for lock screen", e)
        }

        // Reply SMS
        val replyMessage = "SafeTrace: Device locked remotely at $timestamp"
        sendSmsReply(context, sender, replyMessage)

        // Write Log
        dbHelper.insertLog("LOCK_MY_PHONE", sender, "Device Locked", -1, timestamp)
    }

    private fun sendSmsReply(context: Context, destination: String, message: String) {
        try {
            val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                var manager: SmsManager? = null
                try {
                    val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                    val activeId = subscriptionManager?.activeSubscriptionInfoList?.firstOrNull()?.subscriptionId
                    if (activeId != null) {
                        manager = context.getSystemService(SmsManager::class.java).createForSubscriptionId(activeId)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error getting active subscription ID, falling back to default SmsManager: ${e.message}")
                }
                manager ?: context.getSystemService(SmsManager::class.java)
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(destination, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(destination, null, message, null, null)
            }
            Log.d(TAG, "Sent reply SMS to $destination: $message")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS reply to $destination", e)
        }
    }

    private fun matchPhoneNumbers(num1: String, num2: String): Boolean {
        val clean1 = num1.replace("[^0-9]".toRegex(), "")
        val clean2 = num2.replace("[^0-9]".toRegex(), "")
        if (clean1.isEmpty() || clean2.isEmpty()) return false
        val len1 = clean1.length
        val len2 = clean2.length
        val matchLen = minOf(len1, len2, 10)
        if (matchLen < 4) return false
        val suffix1 = clean1.substring(len1 - matchLen)
        val suffix2 = clean2.substring(len2 - matchLen)
        return suffix1 == suffix2
    }
}
