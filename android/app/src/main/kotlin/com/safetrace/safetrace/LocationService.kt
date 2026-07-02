package com.safetrace.safetrace

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationService : Service(), LocationListener {

    private var locationManager: LocationManager? = null
    private val smsReceiver = SmsReceiver()

    companion object {
        private const val TAG = "LocationService"
        var isServiceRunning = false
        private const val NOTIFICATION_ID = 1003
        private const val CHANNEL_ID = "location_channel"
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        Log.d(TAG, "LocationService created")
        createNotificationChannel()

        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED").apply {
            priority = 999
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "LocationService starting")

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        val serviceNotification = notificationBuilder
            .setContentTitle("SafeTrace Live Tracking")
            .setContentText("SafeTrace is continuously updating your device location.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, serviceNotification)

        // Start location updates
        startLocationUpdates()

        return START_STICKY
    }

    private fun startLocationUpdates() {
        try {
            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isGpsEnabled = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
            val isNetworkEnabled = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false

            if (isGpsEnabled) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    10000L, // 10 seconds
                    10f,    // 10 meters significant movement
                    this
                )
                Log.d(TAG, "GPS location updates requested")
            } else if (isNetworkEnabled) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    10000L,
                    10f,
                    this
                )
                Log.d(TAG, "Network location updates requested")
            } else {
                Log.e(TAG, "No location providers enabled")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException requesting location updates", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting location updates", e)
        }
    }

    override fun onLocationChanged(location: Location) {
        Log.d(TAG, "Location changed: ${location.latitude}, ${location.longitude}")

        // Save location locally to shared preferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putFloat("flutter.last_latitude", location.latitude.toFloat())
            putFloat("flutter.last_longitude", location.longitude.toFloat())
            putLong("flutter.last_location_time", System.currentTimeMillis())
            apply()
        }

        // Upload to Firestore
        uploadLocationToFirestore(location)
    }

    private fun uploadLocationToFirestore(location: Location) {
        try {
            // Get battery info
            val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else -1
            val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

            val deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown_device"
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())

            val db = FirebaseFirestore.getInstance()
            val data = hashMapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "battery" to batteryPct,
                "isCharging" to isCharging,
                "timestamp" to timestamp
            )

            db.collection("tracking").document(deviceId)
                .set(data)
                .addOnSuccessListener {
                    Log.d(TAG, "Location updated in Firestore")
                }
                .addOnFailureListener { e: Exception ->
                    Log.e(TAG, "Failed to upload location to Firestore", e)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Firestore initialization/write error inside LocationService", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeTrace Location Tracking Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        try {
            locationManager?.removeUpdates(this)
            Log.d(TAG, "Location updates stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing location updates", e)
        }
        try {
            unregisterReceiver(smsReceiver)
            Log.d(TAG, "Dynamic SMS receiver unregistered inside LocationService")
        } catch (e: Exception) {
            // Ignore
        }
        Log.d(TAG, "LocationService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
}
