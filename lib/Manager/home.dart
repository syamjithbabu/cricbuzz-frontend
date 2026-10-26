import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/fake_login.dart';
import 'package:cricbuzz/Manager/select_time.dart';
import 'package:cricbuzz/Manager/sales_report.dart';
import 'package:cricbuzz/Manager/winning_report.dart';
import 'package:cricbuzz/Manager/delete_sales.dart';
import 'package:cricbuzz/Manager/booking.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/config.dart';

class ManagerHomePage extends StatelessWidget {
  final Color themeColor; // Holds the color passed from SelectTimePage
  final int gameTimeId;
  final String gameTimeLabel;


  const ManagerHomePage({Key? key, required this.themeColor, required this.gameTimeId,
    required this.gameTimeLabel}) : super(key: key);

  // Your clean menu button helper
  Widget buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconCircleColor,
    required Widget targetPage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Material(
        color: themeColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => targetPage),
            );
          },
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconCircleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.person_outline, color: Color(0xFF5EB5F7), size: 28),
            const SizedBox(width: 8),
            Text(
              '${MySession.username ?? ''} (Manager)',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final url = '${AppConfig.baseUrl}/api/logout/';
              try {
                final response = await http.post(
                  Uri.parse(url),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${MySession.token}', // Or 'Token ${MySession.token}'
                  },
                );

                if (response.statusCode == 200) {
                  // 2. Clear stored auth tokens/user data locally
                  // final prefs = await SharedPreferences.getInstance();
                  // await prefs.clear();

                  if (!context.mounted) return;

                  // 3. Navigate back to login screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FakeLoginScreen(),
                    ),
                    (route) => false,
                  );
                } else {
                  // Handle logout error response
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to logout. Try again.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Network error during logout: $e')),
                );
              }
            },
            child: const Text(
              'LOGOUT',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 12),
              buildMenuButton(
                context,
                title: 'Booking',
                icon: Icons.add,
                iconCircleColor: const Color(0xFF8CDAA2),
                targetPage: BookingPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildMenuButton(
                context,
                title: 'Sales Report',
                icon: Icons.trending_up,
                iconCircleColor: const Color(0xFF8CDAA2),
                targetPage: SalesReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildMenuButton(
                context,
                title: 'Delete Sales',
                icon: Icons.delete_outline,
                iconCircleColor: const Color(0xFF42A5F5),
                targetPage: DeleteSalesPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildMenuButton(
                context,
                title: 'Winning Report',
                icon: Icons.emoji_events_outlined,
                iconCircleColor: const Color(0xFFFFAB91),
                targetPage: WinningReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildMenuButton(
                context,
                title: 'Change Game',
                icon: Icons.access_time,
                iconCircleColor: const Color(0xFF64B5F6),
                targetPage:
                    const SelectTimePage(), // swap with your real game change page widget
              ),
             

              const SizedBox(height: 16),

              // Fetch and display directly from AppConfig
              Text(
                AppConfig.appVersion,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
