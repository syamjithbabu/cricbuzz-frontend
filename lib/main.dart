import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/fake_login.dart';
import 'package:cricbuzz/services/schedule_manager.dart'; // Adjust path if needed

void main() async {
  // Ensure Flutter engine bindings are initialized before background service setup
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the automatic report downloader background scheduler
  await AutoDownloadScheduler.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FakeLoginScreen(),
    );
  }
}