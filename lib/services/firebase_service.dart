import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const _platform = MethodChannel('com.safetrace/native');

  // Web fallback states
  static bool _webLiveTracking = false;
  static bool _webAlarmRinging = false;
  static const String _webSimDetails = 'SIM Web Virtual 89911234';

  // Initialize Firebase and trigger anonymous authentication asynchronously in the background
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _signInAnonymouslyInBackground();
    } catch (e) {
      // Firebase might not be configured (e.g. dummy google-services.json), ignore to let app run offline
      print("Firebase initialization skipped or failed: $e");
    }
  }

  static void _signInAnonymouslyInBackground() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously().timeout(const Duration(seconds: 5));
        print("Signed in anonymously to Firebase.");
      }
    } catch (e) {
      print("Firebase anonymous sign-in skipped or timed out: $e");
    }
  }

  // Turn live tracking ON or OFF via Native Foreground Service
  static Future<bool> setLiveTracking(bool enable) async {
    if (kIsWeb) {
      _webLiveTracking = enable;
      return true;
    }
    try {
      if (enable) {
        final success = await _platform.invokeMethod<bool>('startLocationService') ?? false;
        return success;
      } else {
        final success = await _platform.invokeMethod<bool>('stopLocationService') ?? false;
        return success;
      }
    } on PlatformException catch (e) {
      print("Error calling native location service: $e");
      return false;
    }
  }

  // Check if live tracking service is running
  static Future<bool> isLiveTrackingRunning() async {
    if (kIsWeb) {
      return _webLiveTracking;
    }
    try {
      final running = await _platform.invokeMethod<bool>('isLocationServiceRunning') ?? false;
      return running;
    } on PlatformException {
      return false;
    }
  }

  // Fetch live tracking data for this device from Firestore
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getLiveLocationStream(String deviceId) {
    if (kIsWeb) {
      return const Stream.empty();
    }
    return _firestore.collection('tracking').doc(deviceId).snapshots();
  }

  // Start native alarm ringing
  static Future<bool> startAlarm() async {
    if (kIsWeb) {
      _webAlarmRinging = true;
      return true;
    }
    try {
      final success = await _platform.invokeMethod<bool>('startAlarm') ?? false;
      return success;
    } on PlatformException {
      return false;
    }
  }

  // Stop native alarm ringing
  static Future<bool> stopAlarm() async {
    if (kIsWeb) {
      _webAlarmRinging = false;
      return true;
    }
    try {
      final success = await _platform.invokeMethod<bool>('stopAlarm') ?? false;
      return success;
    } on PlatformException {
      return false;
    }
  }

  // Check if alarm is currently ringing
  static Future<bool> isAlarmRinging() async {
    if (kIsWeb) {
      return _webAlarmRinging;
    }
    try {
      final ringing = await _platform.invokeMethod<bool>('isAlarmRinging') ?? false;
      return ringing;
    } on PlatformException {
      return false;
    }
  }

  // Get current SIM details from native code
  static Future<String> getCurrentSimDetails() async {
    if (kIsWeb) {
      return _webSimDetails;
    }
    try {
      final details = await _platform.invokeMethod<String>('getCurrentSimDetails') ?? '';
      return details;
    } on PlatformException {
      return '';
    }
  }
}

