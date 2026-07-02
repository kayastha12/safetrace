import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/config_service.dart';
import '../services/firebase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _trustedNumberController;
  late TextEditingController _keywordWhereController;
  late TextEditingController _keywordRingController;
  late TextEditingController _keywordLockController;
  late TextEditingController _securityPinController;

  String _currentSimDetails = 'Loading current SIM info...';
  String _savedSimDetails = ConfigService.savedSimSerial;

  @override
  void initState() {
    super.initState();
    _trustedNumberController = TextEditingController(text: ConfigService.trustedNumber);
    _keywordWhereController = TextEditingController(text: ConfigService.keywordWhere);
    _keywordRingController = TextEditingController(text: ConfigService.keywordRing);
    _keywordLockController = TextEditingController(text: ConfigService.keywordLock);
    _securityPinController = TextEditingController(text: ConfigService.securityPin);

    _loadCurrentSimDetails();
  }

  @override
  void dispose() {
    _trustedNumberController.dispose();
    _keywordWhereController.dispose();
    _keywordRingController.dispose();
    _keywordLockController.dispose();
    _securityPinController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSimDetails() async {
    final details = await FirebaseService.getCurrentSimDetails();
    setState(() {
      _currentSimDetails = details.isNotEmpty 
          ? details.replaceAll('|', '\n') 
          : 'No active SIM card found or Permission missing.';
    });
  }

  Future<void> _armSimSwapGuard() async {
    final details = await FirebaseService.getCurrentSimDetails();
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot arm: No active SIM details detected.')),
      );
      return;
    }

    await ConfigService.setSavedSimSerial(details);
    setState(() {
      _savedSimDetails = details;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SIM Swap Guard Armed successfully with current SIM!')),
    );
  }

  Future<void> _disarmSimSwapGuard() async {
    await ConfigService.setSavedSimSerial('');
    setState(() {
      _savedSimDetails = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SIM Swap Guard Disarmed.')),
    );
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) return;

    ConfigService.setTrustedNumber(_trustedNumberController.text.trim());
    ConfigService.setKeywordWhere(_keywordWhereController.text.trim());
    ConfigService.setKeywordRing(_keywordRingController.text.trim());
    ConfigService.setKeywordLock(_keywordLockController.text.trim());
    ConfigService.setSecurityPin(_securityPinController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RECOVERY SETTINGS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: _saveSettings,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subsection: Trusted Contact
              _buildSectionHeader('TRUSTED SENDER'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _trustedNumberController,
                label: 'Trusted Phone Number',
                hint: '+1234567890',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a trusted number';
                  }
                  final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                  if (clean.length < 4) {
                    return 'Number must contain at least 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Subsection: Security Settings
              _buildSectionHeader('SECURITY ACCESS'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _securityPinController,
                label: 'App Unlock PIN (4-6 Digits)',
                hint: '123456',
                icon: Icons.password_rounded,
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Unlock PIN is required';
                  }
                  final clean = val.trim();
                  if (clean.length < 4 || clean.length > 6 || int.tryParse(clean) == null) {
                    return 'PIN must be between 4 and 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Subsection: Custom Keywords
              _buildSectionHeader('CUSTOM SMS KEYWORDS'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _keywordWhereController,
                label: 'Retrieve Location Keyword',
                hint: 'WHERE_MY_PHONE',
                icon: Icons.my_location,
                validator: (val) => val == null || val.trim().isEmpty ? 'Keyword cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _keywordRingController,
                label: 'Ring Phone Keyword',
                hint: 'RING_MY_PHONE',
                icon: Icons.volume_up,
                validator: (val) => val == null || val.trim().isEmpty ? 'Keyword cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _keywordLockController,
                label: 'Lock Device Keyword',
                hint: 'LOCK_MY_PHONE',
                icon: Icons.lock,
                validator: (val) => val == null || val.trim().isEmpty ? 'Keyword cannot be empty' : null,
              ),
              const SizedBox(height: 24),

              // Subsection: SIM Swap Guard
              _buildSectionHeader('SIM SWAP DETECTOR'),
              const SizedBox(height: 12),
              _buildSimGuardCard(),
              
              const SizedBox(height: 30),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveSettings,
                  child: Text(
                    'SAVE CONFIGURATION',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white30,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.inter(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: Colors.white12, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF161622),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSimGuardCard() {
    final isArmed = _savedSimDetails.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SIM Protection Status',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isArmed ? Colors.cyanAccent.withOpacity(0.1) : Colors.amberAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isArmed ? 'ARMED' : 'UNARMED',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isArmed ? Colors.cyanAccent : Colors.amberAccent,
                    fontSize: 10,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Armed SIM Identifier:',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            isArmed ? _savedSimDetails.replaceAll('|', '\n') : 'No SIM card armed yet.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Current Detected SIM:',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _currentSimDetails,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                    foregroundColor: Colors.cyanAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('ARM SIM SWAP'),
                  onPressed: _armSimSwapGuard,
                ),
              ),
              if (isArmed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.disabled_by_default_outlined, size: 16),
                    label: const Text('DISARM'),
                    onPressed: _disarmSimSwapGuard,
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }
}
