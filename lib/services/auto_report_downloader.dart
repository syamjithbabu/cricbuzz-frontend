import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cricbuzz/Screens/config.dart';

@pragma('vm:entry-point')
void autoDownloadCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    print("🔔 WORKMANAGER TRIGGERED | Task Name: $taskName | Data: $inputData");

    final client = http.Client();

    try {
      const storage = FlutterSecureStorage();
      final String? refreshToken = await storage.read(key: 'jwt_refresh_token');

      if (refreshToken == null || refreshToken.isEmpty) {
        print("❌ ABORT: No refresh token found.");
        return Future.value(false);
      }

      // 1. Refresh Access Token
      final refreshUrl = Uri.parse('${AppConfig.baseUrl}/api/token/refresh/');
      final refreshResponse = await client.post(
        refreshUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (refreshResponse.statusCode != 200) {
        print("❌ ABORT: Token refresh failed.");
        return Future.value(false);
      }

      final accessToken = jsonDecode(refreshResponse.body)['access'];
      await storage.write(key: 'jwt_access_token', value: accessToken);

      // 2. Prepare query parameters & download file
      final String gameTimeId = inputData?['game_time_id']?.toString() ?? '';
      final String endTimeStr = inputData?['end_time']?.toString() ?? '';
      
      // 👈 Parse interval dynamically (default to 5 if missing)
      final int intervalMinutes = int.tryParse(inputData?['interval_minutes']?.toString() ?? '5') ?? 5;
      
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final Map<String, String> queryParameters = {
        'start_date': todayStr,
        'end_date': todayStr,
        'game_time_id': gameTimeId,
        'ticket_type': 'ALL',
      };

      final Uri downloadUrl = Uri.parse(
        '${AppConfig.baseUrl}/adminapp/api/auto-sales-report-download/',
      ).replace(queryParameters: queryParameters);

      Directory targetDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final String fileName =
          "Auto_SalesReport_Game${gameTimeId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf";
      final File outputFile = File("${targetDir.path}/$fileName");

      final http.Request request = http.Request('GET', downloadUrl);
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/pdf',
      });

      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode == 200) {
        final IOSink fileSink = outputFile.openWrite();
        await response.stream.pipe(fileSink);
        print("✅ SUCCESS: File saved -> ${outputFile.path}");
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
      }

      // 3. RE-SCHEDULE FOR NEXT INTERVAL IF STILL WITHIN WINDOW
      if (endTimeStr.isNotEmpty) {
        final DateTime endTime = DateTime.parse(endTimeStr);
        final DateTime nextRunTime = DateTime.now().add(Duration(minutes: intervalMinutes));

        if (nextRunTime.isBefore(endTime)) {
          print("🔄 Re-scheduling task for Game $gameTimeId in $intervalMinutes minutes...");
          
          await Workmanager().registerOneOffTask(
            // 👈 Use static name without timestamp so it replaces existing tasks properly
            "auto_sales_report_gt_$gameTimeId",
            "auto_sales_report_task",
            initialDelay: Duration(minutes: intervalMinutes),
            inputData: {
              'game_time_id': gameTimeId,
              'end_time': endTimeStr,
              'interval_minutes': intervalMinutes,
            },
            constraints: Constraints(networkType: NetworkType.connected),
            existingWorkPolicy: ExistingWorkPolicy.replace, // Overwrites existing task
          );
        } else {
          print("🛑 End time ($endTimeStr) reached for Game $gameTimeId. Stopping chain for today.");
        }
      }

      return Future.value(true);
    } catch (e, stack) {
      print("💥 Task Exception: $e\n$stack");
      return Future.value(false);
    } finally {
      client.close();
    }
  });
}