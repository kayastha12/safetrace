import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> reload() async {
    await _prefs.reload();
  }

  // Trusted Phone Number
  static String get trustedNumber => _prefs.getString('trusted_number') ?? '';
  static Future<void> setTrustedNumber(String val) => _prefs.setString('trusted_number', val);

  // Custom keywords
  static String get keywordWhere => _prefs.getString('keyword_where') ?? 'WHERE_MY_PHONE';
  static Future<void> setKeywordWhere(String val) => _prefs.setString('keyword_where', val);

  static String get keywordRing => _prefs.getString('keyword_ring') ?? 'RING_MY_PHONE';
  static Future<void> setKeywordRing(String val) => _prefs.setString('keyword_ring', val);

  static String get keywordLock => _prefs.getString('keyword_lock') ?? 'LOCK_MY_PHONE';
  static Future<void> setKeywordLock(String val) => _prefs.setString('keyword_lock', val);

  // Security PIN for app-level lock screen
  static String get securityPin => _prefs.getString('security_pin') ?? '';
  static Future<void> setSecurityPin(String val) => _prefs.setString('security_pin', val);

  // App Locked status
  static bool get isAppLocked => _prefs.getBool('is_app_locked') ?? false;
  static Future<void> setAppLocked(bool val) => _prefs.setBool('is_app_locked', val);

  // Saved SIM Serial for change detection
  static String get savedSimSerial => _prefs.getString('saved_sim_serial') ?? '';
  static Future<void> setSavedSimSerial(String val) => _prefs.setString('saved_sim_serial', val);

  // Live tracking mode enabled
  static bool get liveTrackingEnabled => _prefs.getBool('live_tracking_enabled') ?? false;
  static Future<void> setLiveTrackingEnabled(bool val) => _prefs.setBool('live_tracking_enabled', val);

  // Last known coordinates (for manual verification or backup sharing)
  static double get lastLatitude => _prefs.getDouble('last_latitude') ?? 0.0;
  static double get lastLongitude => _prefs.getDouble('last_longitude') ?? 0.0;
  static int get lastLocationTime => _prefs.getInt('last_location_time') ?? 0;

  // First launch state
  static bool get isFirstLaunch => _prefs.getBool('is_first_launch') ?? true;
  static Future<void> setFirstLaunch(bool val) => _prefs.setBool('is_first_launch', val);
}
