import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for inputFormatters
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/services/schedule_manager.dart'; // Adjust path if needed

class GameTimeSettings extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const GameTimeSettings({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<GameTimeSettings> createState() => _GameTimeSettingsState();
}

class _GameTimeSettingsState extends State<GameTimeSettings> {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  TimeOfDay? deletionTime;
  TimeOfDay? nextDayGameTime;
  TimeOfDay? autoDownloadTime;
  TimeOfDay? retailStartTime;
  TimeOfDay? retailEndTime;

  // Controller for Auto Download Number Field
  final TextEditingController _autoDownloadValueController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentTimes();
  }

  @override
  void dispose() {
    _autoDownloadValueController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeForBackend(TimeOfDay? time) {
    if (time == null) return "00:00";
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Future<void> _fetchCurrentTimes() async {
    setState(() => _isLoading = true);
    final url = '${AppConfig.baseUrl}/adminapp/api/game-times/${widget.gameTimeId}/';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          startTime = _parseTimeString(data['start_time']);
          endTime = _parseTimeString(data['end_time']);
          deletionTime = _parseTimeString(data['deletion_time']);
          nextDayGameTime = _parseTimeString(data['next_day_game_time']);
          autoDownloadTime = _parseTimeString(data['auto_download_time']);
          retailStartTime = _parseTimeString(data['retail_start_time']);
          retailEndTime = _parseTimeString(data['retail_end_time']);
          
          // Set fetched auto download value (defaults to 1 if null)
          _autoDownloadValueController.text = (data['auto_download_interval'] ?? 1).toString();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading configurations: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper to convert TimeOfDay into total minutes since midnight for easy comparisons
  int _timeToMinutes(TimeOfDay? time) {
    if (time == null) return 0;
    return (time.hour * 60) + time.minute;
  }

  Future<void> _saveTimes() async {
    // 1. Ensure ALL times are set before validating
    if (startTime == null ||
        endTime == null ||
        deletionTime == null ||
        nextDayGameTime == null ||
        autoDownloadTime == null ||
        retailStartTime == null ||
        retailEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set all time fields before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Validate numeric input field
    final String autoDownloadInput = _autoDownloadValueController.text.trim();
    final int? autoDownloadVal = int.tryParse(autoDownloadInput);

    if (autoDownloadInput.isEmpty || autoDownloadVal == null || autoDownloadVal < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Auto Download Value must be a number greater than or equal to 1.')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 3. Convert times to integer minutes
    final int startMin = _timeToMinutes(startTime);
    final int endMin = _timeToMinutes(endTime);
    final int deletionMin = _timeToMinutes(deletionTime);
    final int nextDayMin = _timeToMinutes(nextDayGameTime);
    final int retailStartMin = _timeToMinutes(retailStartTime);
    final int retailEndMin = _timeToMinutes(retailEndTime);

    // 4. Execute Chronological Validations
    String? errorMessage;

    if (startMin >= endMin) {
      errorMessage = 'Start Time must be earlier than End Time.';
    } else if (startMin >= nextDayMin) {
      errorMessage = 'Start Time must be earlier than Next Day Game Time.';
    } else if (nextDayMin <= endMin) {
      errorMessage = 'Next Day Game Time must be later than End Time.';
    } else if (deletionMin >= endMin) {
      errorMessage = 'Deletion Time must be earlier than End Time.';
    } else if (retailStartMin >= retailEndMin) {
      errorMessage = 'Retail Start Time must be earlier than End Time.';
    }

    // 5. Show error if validation fails
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 6. Proceed with HTTP Patch Request if validations pass
    setState(() => _isLoading = true);
    final url = '${AppConfig.baseUrl}/adminapp/api/game-times/${widget.gameTimeId}/update/';

    final body = {
      'start_time': _formatTimeForBackend(startTime),
      'end_time': _formatTimeForBackend(endTime),
      'deletion_time': _formatTimeForBackend(deletionTime),
      'next_day_game_time': _formatTimeForBackend(nextDayGameTime),
      'auto_download_time': _formatTimeForBackend(autoDownloadTime),
      'auto_download_interval': autoDownloadVal, // 👈 Added to request body
      'retail_start_time': _formatTimeForBackend(retailStartTime),
      'retail_end_time': _formatTimeForBackend(retailEndTime),
    };

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // 👈 RE-SYNC WORKMANAGER SCHEDULES WITH NEW BACKEND TIMINGS
        await AutoDownloadScheduler.syncSchedulesWithBackend();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving configurations: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context, String field) async {
    TimeOfDay initialTime = const TimeOfDay(hour: 12, minute: 0);

    if (field == 'start' && startTime != null) initialTime = startTime!;
    if (field == 'end' && endTime != null) initialTime = endTime!;
    if (field == 'deletion' && deletionTime != null) initialTime = deletionTime!;
    if (field == 'nextDay' && nextDayGameTime != null) initialTime = nextDayGameTime!;
    if (field == 'autoDay' && autoDownloadTime != null) initialTime = autoDownloadTime!;
    if (field == 'retailstart' && retailStartTime != null) initialTime = retailStartTime!;
    if (field == 'retailend' && retailEndTime != null) initialTime = retailEndTime!;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (field == 'start') startTime = picked;
        if (field == 'end') endTime = picked;
        if (field == 'deletion') deletionTime = picked;
        if (field == 'nextDay') nextDayGameTime = picked;
        if (field == 'autoDay') autoDownloadTime = picked;
        if (field == 'retailstart') retailStartTime = picked;
        if (field == 'retailend') retailEndTime = picked;
      });
    }
  }

  Widget _buildTimeCard({
    required String title,
    required String subtitle,
    required TimeOfDay? time,
    required String field,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: widget.themeColor,
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: widget.themeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _selectTime(context, field),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          time != null ? time.format(context) : '--:--',
                          style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.access_time_filled_rounded, size: 16, color: widget.themeColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New Custom Numeric Input Card Widget
  Widget _buildNumberInputCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: widget.themeColor,
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: widget.themeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 75,
                  height: 40,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Numeric input only
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.themeColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.themeColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Time Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Editing Slot: ${widget.gameTimeLabel}',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor)))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      _buildTimeCard(
                        title: 'Start Time',
                        subtitle: 'When the game setup opens for inputs',
                        time: startTime,
                        field: 'start',
                        icon: Icons.play_arrow_rounded,
                      ),
                      _buildTimeCard(
                        title: 'End Time',
                        subtitle: 'Closing line limit for modifications',
                        time: endTime,
                        field: 'end',
                        icon: Icons.gavel_rounded,
                      ),
                      _buildTimeCard(
                        title: 'Deletion Time',
                        subtitle: 'Grace timeframe for structural clearups',
                        time: deletionTime,
                        field: 'deletion',
                        icon: Icons.delete_sweep_rounded,
                      ),
                      _buildTimeCard(
                        title: 'Next Day Game Time',
                        subtitle: 'Rollover activation point for next cycle',
                        time: nextDayGameTime,
                        field: 'nextDay',
                        icon: Icons.update_rounded,
                      ),
                      _buildTimeCard(
                        title: 'Auto Download Time',
                        subtitle: 'Automated sales report schedule trigger point',
                        time: autoDownloadTime,
                        field: 'autoDay',
                        icon: Icons.file_download_outlined,
                      ),

                      // 👈 NEW NUMERIC INPUT FIELD UNDER AUTO DOWNLOAD TIME
                      _buildNumberInputCard(
                        title: 'Auto Download Value',
                        subtitle: 'Set total count/value (minimum 1)',
                        controller: _autoDownloadValueController,
                        icon: Icons.numbers_rounded,
                      ),

                      _buildTimeCard(
                        title: 'Retail Start Time',
                        subtitle: 'When the game setup opens for retail inputs',
                        time: retailStartTime,
                        field: 'retailstart',
                        icon: Icons.start,
                      ),
                      _buildTimeCard(
                        title: 'Retail End Time',
                        subtitle: 'Closing line limit for retail inputs',
                        time: retailEndTime,
                        field: 'retailend',
                        icon: Icons.closed_caption_rounded,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        offset: const Offset(0, -4),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _saveTimes,
                        label: const Text(
                          'SAVE',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}