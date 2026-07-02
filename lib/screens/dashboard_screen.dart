import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/config_service.dart';
import '../services/firebase_service.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import 'lock_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isServiceRunning = false;
  bool _isAlarmRinging = false;
  bool _hasLocationPermission = false;
  bool _hasSmsPermission = false;
  
  late AnimationController _radarController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _checkPermissions().then((_) {
      if (!_hasSmsPermission || !_hasLocationPermission) {
        _requestAllPermissions();
      }
    });
    _updateNativeStatus();

    // Periodically poll native service status & alarm status (every 2 seconds)
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateNativeStatus();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      setState(() {
        _hasLocationPermission = true;
        _hasSmsPermission = true;
      });
      return;
    }
    final loc = await Permission.location.isGranted;
    final sms = await Permission.sms.isGranted;
    setState(() {
      _hasLocationPermission = loc;
      _hasSmsPermission = sms;
    });
  }

  Future<void> _requestAllPermissions() async {
    if (kIsWeb) {
      return;
    }
    // Request location, sms, phone state, and notification permissions
    final statuses = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.notification,
      Permission.systemAlertWindow,
    ].request();

    // Background location should be requested separately on Android 10+
    if (statuses[Permission.location] == PermissionStatus.granted) {
      await Permission.locationAlways.request();
    }

    _checkPermissions();
  }


  Future<void> _updateNativeStatus() async {
    final running = await FirebaseService.isLiveTrackingRunning();
    final ringing = await FirebaseService.isAlarmRinging();

    if (running && !_radarController.isAnimating) {
      _radarController.repeat();
    } else if (!running && _radarController.isAnimating) {
      _radarController.stop();
    }

    if (mounted) {
      setState(() {
        _isServiceRunning = running;
        _isAlarmRinging = ringing;
      });
    }
  }

  Future<void> _toggleTracking() async {
    if (!_hasLocationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant Location permission first!')),
      );
      return;
    }

    final nextState = !_isServiceRunning;
    final success = await FirebaseService.setLiveTracking(nextState);
    if (success) {
      ConfigService.setLiveTrackingEnabled(nextState);
      _updateNativeStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to toggle tracking service.')),
      );
    }
  }

  Future<void> _stopAlarm() async {
    final success = await FirebaseService.stopAlarm();
    if (success) {
      _updateNativeStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm stopped.')),
      );
    }
  }

  Future<void> _testRing() async {
    final success = await FirebaseService.startAlarm();
    if (success) {
      _updateNativeStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test Alarm triggered.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to trigger test alarm.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10), // Ultra dark obsidian background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SAFETRACE',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            tooltip: 'User Manual',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingScreen(isManualOnly: true)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _checkPermissions());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alarm Warning Banner
              if (_isAlarmRinging)
                _buildAlarmBanner(),

              const SizedBox(height: 10),

              // Animated Radar Indicator
              Center(child: _buildRadarIndicator()),

              const SizedBox(height: 40),

              // Overview Title
              Text(
                'SYSTEM STATUS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Security Stats Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: [
                  _buildStatusCard(
                    title: 'Offline Recovery',
                    subtitle: _hasSmsPermission ? 'ARMED & ACTIVE' : 'MISSING PERMISSIONS',
                    icon: Icons.sms_outlined,
                    color: _hasSmsPermission ? Colors.greenAccent : Colors.amberAccent,
                    onTap: _hasSmsPermission ? null : _requestAllPermissions,
                  ),
                  _buildStatusCard(
                    title: 'Live Tracking',
                    subtitle: _isServiceRunning ? 'STREAMING GPS' : 'INACTIVE',
                    icon: Icons.gps_fixed,
                    color: _isServiceRunning ? Colors.blueAccent : Colors.white30,
                    onTap: _toggleTracking,
                  ),
                  _buildStatusCard(
                    title: 'SIM Swap Guard',
                    subtitle: ConfigService.savedSimSerial.isNotEmpty ? 'ARMED' : 'NOT CONFIGURED',
                    icon: Icons.sim_card_outlined,
                    color: ConfigService.savedSimSerial.isNotEmpty ? Colors.cyanAccent : Colors.amberAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                  _buildStatusCard(
                    title: 'Device Lock',
                    subtitle: ConfigService.securityPin.isNotEmpty ? 'PIN CONFIGURED' : 'NO PIN SET',
                    icon: Icons.lock_outline,
                    color: ConfigService.securityPin.isNotEmpty ? Colors.purpleAccent : Colors.redAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Quick Commands card
              _buildQuickCommandsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALARM IS RINGING',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Ringtone is playing at max volume.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _stopAlarm,
            child: const Text('STOP'),
          )
        ],
      ),
    );
  }

  Widget _buildRadarIndicator() {
    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radar pulse animations
          if (_isServiceRunning)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  final progress = (_radarController.value + (index / 3)) % 1.0;
                  return Container(
                    width: 140 + (progress * 120),
                    height: 140 + (progress * 120),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity((1.0 - progress) * 0.25),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity((1.0 - progress) * 0.5),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              );
            }),

          // Center hub circle
          GestureDetector(
            onTap: _toggleTracking,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isServiceRunning
                      ? [const Color(0xFF0F2042), const Color(0xFF2C5EBD)]
                      : [const Color(0xFF1E1E2C), const Color(0xFF32324D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isServiceRunning
                        ? Colors.blueAccent.withOpacity(0.4)
                        : Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
                border: Border.all(
                  color: _isServiceRunning ? Colors.blueAccent.withOpacity(0.5) : Colors.white10,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isServiceRunning ? Icons.radar : Icons.power_settings_new_rounded,
                    size: 48,
                    color: _isServiceRunning ? Colors.white : Colors.white30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isServiceRunning ? 'TRACKING ON' : 'ACTIVATE',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isServiceRunning ? Colors.white : Colors.white30,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCommandsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OFFLINE CONTROL COMMANDS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white60,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildCommandRow(ConfigService.keywordWhere, 'Sends back Google Maps URL, Battery Info, GPS Status.'),
          const Divider(color: Colors.white10, height: 24),
          _buildCommandRow(ConfigService.keywordRing, 'Triggers maximum volume looping ringtone.'),
          const Divider(color: Colors.white10, height: 24),
          _buildCommandRow(ConfigService.keywordLock, 'Enables a secure lock screen on the application.'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: const Text('TEST RING'),
                  onPressed: _testRing,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_open_outlined, size: 20),
                  label: const Text('MANUAL LOCK'),
                  onPressed: () {
                    ConfigService.setAppLocked(true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LockScreen(
                          onUnlocked: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCommandRow(String keyword, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            keyword,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
