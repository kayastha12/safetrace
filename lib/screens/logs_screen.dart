import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DatabaseService.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _clearAllLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        title: Text('Clear Logs', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('Are you sure you want to clear all recovery logs?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white30)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.clearLogs();
      _loadLogs();
    }
  }

  Color _getCommandColor(String command) {
    switch (command.toUpperCase()) {
      case 'WHERE_MY_PHONE':
        return Colors.greenAccent;
      case 'RING_MY_PHONE':
        return Colors.amberAccent;
      case 'LOCK_MY_PHONE':
        return Colors.redAccent;
      case 'SIM_CHANGE_DETECTED':
        return Colors.cyanAccent;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _getCommandIcon(String command) {
    switch (command.toUpperCase()) {
      case 'WHERE_MY_PHONE':
        return Icons.location_on_outlined;
      case 'RING_MY_PHONE':
        return Icons.volume_up_outlined;
      case 'LOCK_MY_PHONE':
        return Icons.lock_outline;
      case 'SIM_CHANGE_DETECTED':
        return Icons.sim_card_alert_outlined;
      default:
        return Icons.history;
    }
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
          'RECOVERY LOGS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: _clearAllLogs,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _logs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final cmd = log['command_type'] ?? 'Unknown';
                    final sender = log['sender_number'] ?? 'Unknown';
                    final location = log['location_data'] ?? 'Unknown';
                    final battery = log['battery_percentage'] ?? -1;
                    final timestamp = log['timestamp'] ?? '';
                    final cardColor = _getCommandColor(cmd);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                          width: 1,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Accent Bar
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            
                            // Log content details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(_getCommandIcon(cmd), color: cardColor, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              cmd,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          timestamp,
                                          style: GoogleFonts.inter(
                                            color: Colors.white24,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Details grid
                                    _buildDetailRow('Sender', sender),
                                    const SizedBox(height: 6),
                                    _buildDetailRow('Location', location, isLink: location.startsWith('http')),
                                    if (battery >= 0) ...[
                                      const SizedBox(height: 6),
                                      _buildDetailRow('Battery', '$battery%'),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white30,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: isLink ? Colors.blueAccent : Colors.white70,
              fontSize: 12,
              fontWeight: isLink ? FontWeight.bold : FontWeight.normal,
              decoration: isLink ? TextDecoration.underline : TextDecoration.none,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history,
              size: 64,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Recovery Logs',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Actions triggered via secret SMS commands or system events will be logged here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white30,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
