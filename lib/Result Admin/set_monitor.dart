import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SetMonitor extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const SetMonitor({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<SetMonitor> createState() => _SetMonitorState();
}

class _SetMonitorState extends State<SetMonitor> {
  bool isLoading = true;
  List<Map<String, dynamic>> rateData = [];

  // Standalone ticket names without prefixes
  List<String> get ticketTypes => [
    widget.gameTimeId == 2 ? "SUPER" : "DEAR",
    "BOX",
    "AB",
    "BC",
    "AC",
    "A",
    "B",
    "C",
  ];

  @override
  void initState() {
    super.initState();
    fetchSetMonitor();
  }

  // Fetch set monitor data for the given gameTimeId
  Future<void> fetchSetMonitor() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/resultadmin/api/set-monitor/?game_time_id=${widget.gameTimeId}',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
      );

      List<Map<String, dynamic>> fetchedLimits = [];
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        fetchedLimits = List<Map<String, dynamic>>.from(data['limits']);
      }

      // Direct match against standalone ticket names
      List<Map<String, dynamic>> mergedData = [];

      for (String ticketName in ticketTypes) {
        var existingRow = fetchedLimits.firstWhere(
          (item) => item['ticket'] == ticketName,
          orElse: () => {},
        );

        mergedData.add({
          'id': existingRow.containsKey('id') ? existingRow['id'] : null,
          'name': ticketName,
          'limit': existingRow.containsKey('limit')
              ? existingRow['limit'].toString()
              : "0",
        });
      }

      setState(() {
        rateData = mergedData;
      });
    } catch (e) {
      _showMessage('Error processing data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveSetMonitor() async {
    final List<Map<String, dynamic>> payload = rateData.map((row) {
      return {'id': row['id'], 'ticket': row['name'], 'limit': row['limit']};
    }).toList();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/resultadmin/api/update-set-monitor/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
        body: jsonEncode({'game_time_id': widget.gameTimeId, 'rates': payload}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Monitor limits saved successfully!');
        fetchSetMonitor();
      } else {
        _showMessage('Failed to save settings');
      }
    } catch (e) {
      _showMessage('Connection Error: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: widget.themeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Monitor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.gameTimeLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
              ),
            )
          : Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withOpacity(0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: widget.themeColor.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: widget.themeColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Set Limits for ${widget.gameTimeLabel}',
                        style: TextStyle(
                          color: widget.themeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Header Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            "TICKET TYPE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "LIMIT",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // List Items Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: rateData.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final row = rateData[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      row['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 42,
                                    child: TextFormField(
                                      key: ValueKey(
                                        '${widget.gameTimeId}_${row['name']}',
                                      ),
                                      initialValue: row['limit'],
                                      onChanged: (value) =>
                                          row['limit'] = value,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: widget.themeColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Floating Action Save Button Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: saveSetMonitor,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text(
                          'SAVE SETTINGS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
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
