import 'package:flutter/material.dart';
import 'package:cricbuzz/Dealer/sales_report.dart';
import 'package:cricbuzz/Dealer/daily_report.dart';
import 'package:cricbuzz/Dealer/admin_report.dart';
import 'package:cricbuzz/Dealer/count_sales_report.dart';
import 'package:cricbuzz/Dealer/winning_report.dart';
import 'package:cricbuzz/Dealer/count_winning.dart';
import 'package:cricbuzz/Dealer/payment_report.dart';
import 'package:cricbuzz/Dealer/home.dart';
import 'package:cricbuzz/Dealer/select_time.dart';


class ReportsMenuPage extends StatelessWidget {
  final Color themeColor; // Holds the color passed down from AdminHomePage
  final int gameTimeId;
  final String gameTimeLabel;

  const ReportsMenuPage({Key? key, required this.themeColor, required this.gameTimeId, required this.gameTimeLabel,}) : super(key: key);

  // Reusable button builder specifically for the Reports Screen items
  Widget buildReportMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconCircleColor,
    required Widget targetPage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Material(
        color: themeColor, // Dynamically uses the inherited time-slot color
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
        backgroundColor:
            themeColor, // Sets AppBar background matching your screenshot style
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DealerHomePage(
                  themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectTimePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 12),

              buildReportMenuButton(
                context,
                title: 'Admin Report',
                icon: Icons.preview_outlined,
                iconCircleColor: const Color(0xFF90CAF9),
                targetPage: AdminReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Daily Report',
                icon: Icons.summarize_outlined,
                iconCircleColor: const Color(0xFFCE93D8),
                targetPage: DailyReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Sales Report',
                icon: Icons.trending_up,
                iconCircleColor: const Color(0xFF8CDAA2),
                targetPage: SalesReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Count Sales Report',
                icon: Icons.calculate_outlined,
                iconCircleColor: const Color(0xFFFFF59D),
                targetPage: CountSalesReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Winning Report',
                icon: Icons.emoji_events_outlined,
                iconCircleColor: const Color(0xFFFFAB91),
                targetPage: WinningReportPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Count Winning',
                icon: Icons.analytics_outlined,
                iconCircleColor: const Color(0xFFA5D6A7),
                targetPage: CountWinningPage(themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,),
              ),
              buildReportMenuButton(
                context,
                title: 'Payment Report',
                icon: Icons.paid,
                iconCircleColor: const Color(0xFFCE93D8),
                targetPage: PaymentReportPage(
                  themeColor: themeColor,
                  gameTimeId: gameTimeId,
                  gameTimeLabel: gameTimeLabel,
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
