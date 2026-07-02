import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/config_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pinEntered = '';
  final String _correctPin = ConfigService.securityPin;
  String _errorText = '';

  void _onNumberPressed(String number) {
    if (_pinEntered.length >= 6) return;
    setState(() {
      _pinEntered += number;
      _errorText = '';
    });

    if (_pinEntered == _correctPin) {
      ConfigService.setAppLocked(false);
      widget.onUnlocked();
    } else if (_pinEntered.length == _correctPin.length) {
      // Wrong PIN
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _pinEntered = '';
          _errorText = 'Incorrect Security PIN';
        });
      });
    }
  }

  void _onDelete() {
    if (_pinEntered.isEmpty) return;
    setState(() {
      _pinEntered = _pinEntered.substring(0, _pinEntered.length - 1);
      _errorText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A), // Deep dark premium blue
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Shield Icon & Title
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'DEVICE LOCKED',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter Security PIN to access SafeTrace',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),

              // PIN Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _correctPin.length.clamp(4, 6),
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pinEntered.length
                          ? Colors.redAccent
                          : Colors.white10,
                      border: Border.all(
                        color: index < _pinEntered.length
                            ? Colors.redAccent
                            : Colors.white30,
                        width: 1.5,
                      ),
                      boxShadow: index < _pinEntered.length
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Error text
              SizedBox(
                height: 20,
                child: Text(
                  _errorText,
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),

              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) {
                      return const SizedBox.shrink(); // Empty left corner
                    }
                    if (index == 10) {
                      return _buildKeypadButton('0');
                    }
                    if (index == 11) {
                      // Delete button
                      return InkWell(
                        onTap: _onDelete,
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                          child: const Icon(
                            Icons.backspace_outlined,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                      );
                    }
                    return _buildKeypadButton('${index + 1}');
                  },
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Text(
          number,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
