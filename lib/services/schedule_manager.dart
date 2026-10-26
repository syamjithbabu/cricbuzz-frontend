import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auto_report_downloader.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Screens/session.dart'; // Ensure MySession is imported

class AutoDownloadScheduler {
  static const storage = FlutterSecureStorage();

  static Future<void> initialize() async {
    await Workmanager().initialize(
      autoDownloadCallbackDispatcher,
      isInDebugMode: true, // Set to true while testing
    );
  }

  static Future<void> syncSchedulesWithBackend() async {
    print('🚀 [AutoDownload] Starting schedule synchronization...');
    try {
      // 🛑 CANCEL ALL PREVIOUS WORKMANAGER TASKS TO KILL ZOMBIE CHAINS
      await Workmanager().cancelAll();
      print('🧹 [AutoDownload] Canceled all existing background tasks.');

      String? token = await storage.read(key: 'jwt_access_token');
      token ??= MySession.token;

      if (token == null || token.isEmpty) {
        print('❌ [AutoDownload] Error: No access token found!');
        return;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/auto-download-schedules/');
      print('📡 [AutoDownload] Requesting endpoint: $url');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      print('📊 [AutoDownload] HTTP Response Status: ${response.statusCode}');
      print('📄 [AutoDownload] HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List schedules = data['schedules'] ?? [];

        print('✅ [AutoDownload] Found ${schedules.length} schedules.');

        for (var item in schedules) {
          final String gameTimeId = item['game_time_id'].toString();
          final int initialDelaySeconds = item['initial_delay_seconds'];
          final String endTime = item['end_time'];
          final int intervalMinutes = item['auto_download_interval'] ?? 5; // 👈 Extract interval

          print('⏰ [AutoDownload] Scheduling Game ID $gameTimeId with delay of $initialDelaySeconds s (Interval: $intervalMinutes min)');

          await Workmanager().registerOneOffTask(
            "auto_sales_report_gt_$gameTimeId",
            "auto_sales_report_task",
            initialDelay: Duration(seconds: initialDelaySeconds),
            inputData: {
              'game_time_id': gameTimeId,
              'end_time': endTime,
              'interval_minutes': intervalMinutes, // 👈 Pass to background task
            },
            constraints: Constraints(
              networkType: NetworkType.connected,
            ),
            existingWorkPolicy: ExistingWorkPolicy.replace,
          );
        }
      } else {
        print('❌ [AutoDownload] Backend request failed with status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('💥 [AutoDownload] Exception thrown: $e');
      print('📜 StackTrace: $stackTrace');
    }
  }
}