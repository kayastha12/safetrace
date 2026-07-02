import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/config_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isManualOnly;

  const OnboardingScreen({super.key, this.isManualOnly = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlideData> _slides = [
    OnboardingSlideData(
      title: "SafeTrace Recovery",
      description: "Welcome to SafeTrace! A hybrid recovery system that protects your phone using SMS commands offline and Firebase updates online.",
      icon: Icons.security_rounded,
      color: Colors.blueAccent,
      bullets: [
        "Works even without internet (Offline mode).",
        "Tracks location and battery stats via SMS.",
        "Allows remote locking and alarm sounding.",
      ],
    ),
    OnboardingSlideData(
      title: "1. Grant System Permissions",
      description: "SafeTrace operates in the background and must have system-level access to perform recovery actions when your phone is lost.",
      icon: Icons.rule_folder_rounded,
      color: Colors.greenAccent,
      bullets: [
        "SMS: To intercept secret recovery text commands.",
        "Location: To pinpoint the device's location (Allow all the time).",
        "Phone State: To read SIM info and detect SIM swaps.",
        "Notifications: To keep background services active.",
        "Display Over Other Apps: To overlay the lock screen instantly on SMS commands.",
      ],
    ),
    OnboardingSlideData(
      title: "2. Handle RCS Chat (Crucial)",
      description: "Default messaging apps (Google Messages) use RCS internet chats by default. RCS messages bypass cellular SMS networks, so recovery apps CANNOT read them.",
      icon: Icons.chat_bubble_outline_rounded,
      color: Colors.orangeAccent,
      bullets: [
        "Recovery commands must be sent as standard carrier SMS.",
        "To test: Turn OFF internet on the sending phone, or go to chat details -> Enable 'Send only as SMS/MMS'.",
        "Make sure the SMS bubble is light blue (cellular SMS), not dark blue (RCS data).",
      ],
    ),
    OnboardingSlideData(
      title: "3. Background Launch (Autostart)",
      description: "Aggressive battery optimization on Android devices (Xiaomi, Oppo, Vivo, Samsung) will sleep and freeze background apps.",
      icon: Icons.battery_saver_rounded,
      color: Colors.cyanAccent,
      bullets: [
        "Open phone Settings -> Apps -> SafeTrace.",
        "Enable 'Autostart' or 'Background Launch' permission.",
        "Set Battery Saver to 'No Restrictions' or disable optimization.",
        "This ensures SafeTrace runs even if the app is closed.",
      ],
    ),
    OnboardingSlideData(
      title: "4. Lock PIN & Setup",
      description: "Finalize your setup to lock down your phone and prepare recovery triggers.",
      icon: Icons.settings_suggest_rounded,
      color: Colors.pinkAccent,
      bullets: [
        "Configure your Trusted Contact Number in Settings.",
        "Define your Secure App Unlock PIN (default is '0000').",
        "Send 'WHERE MY PHONE' or 'LOCK MY PHONE' from the trusted phone.",
      ],
    ),
  ];

  void _onNextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    if (widget.isManualOnly) {
      Navigator.of(context).pop();
    } else {
      ConfigService.setFirstLaunch(false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10), // Deep premium dark blue
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isManualOnly ? "USER MANUAL" : "WELCOME GUIDE",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 2,
                    ),
                  ),
                  if (widget.isManualOnly)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        "SKIP",
                        style: GoogleFonts.outfit(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Slides Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _buildSlide(slide);
                },
              ),
            ),

            // Pagination Indicator & Next Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? _slides[_currentPage].color
                              : Colors.white24,
                        ),
                      ),
                    ),
                  ),

                  // Action Button
                  ElevatedButton(
                    onPressed: _onNextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _slides[_currentPage].color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: _slides[_currentPage].color.withOpacity(0.4),
                    ),
                    child: Text(
                      _currentPage == _slides.length - 1
                          ? (widget.isManualOnly ? "CLOSE" : "START")
                          : "NEXT",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlideData slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: slide.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: slide.color.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              slide.icon,
              size: 72,
              color: slide.color,
            ),
          ),
          const SizedBox(height: 36),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Bullet points list
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Column(
              children: slide.bullets.map((bullet) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: slide.color.withOpacity(0.8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bullet,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlideData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> bullets;

  OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bullets,
  });
}
