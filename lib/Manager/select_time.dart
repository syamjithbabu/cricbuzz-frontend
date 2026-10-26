import 'package:flutter/material.dart';
import 'package:cricbuzz/Manager/home.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class SelectTimePage extends StatefulWidget {
  const SelectTimePage({super.key});

  @override
  State<SelectTimePage> createState() => _SelectTimePageState();
}

class _SelectTimePageState extends State<SelectTimePage> {
  late Future<List<dynamic>> _gameTimesFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the API call when the widget mounts
    _gameTimesFuture = fetchGameTimes();
  }

  // Your existing fetch logic
  Future<List<dynamic>> fetchGameTimes() async {
    const url = '${AppConfig.baseUrl}/manager/api/game-times/';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load game times: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method to assign background colors dynamically based on the API label
  Color _getColorForLabel(String label) {
    switch (label) {
      case '01 PM':
        return const Color(0xFF6B0F0F); // Burgundy
      case 'KL 3 PM':
        return const Color(0xFF006D5B); // Teal
      case '06 PM':
        return const Color(0xFF260D4E); // Deep Purple
      case '08 PM':
        return Colors.black;
      default:
        return Colors.blueGrey; // Fallback color if a new time slot is added
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _gameTimesFuture,
        builder: (context, snapshot) {
          // 1. Handle Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // 2. Handle Errors
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          // 3. Handle Empty State
          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const Center(
              child: Text('No game times available.'),
            );
          }

          // 4. Data successfully fetched -> Render layout
          return Column(
            children: data.map((slot) {
              final int gameTimeId = slot['id'] ?? 0;
              final String label = slot['game_time'] ?? 'Unknown';
              final Color backgroundColor = _getColorForLabel(label);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManagerHomePage(
                          themeColor: backgroundColor,
                          gameTimeId: gameTimeId,
                          gameTimeLabel: label,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: backgroundColor,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}