import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/fake_login.dart';
import 'package:cricbuzz/Dealer/select_time.dart';
import 'package:cricbuzz/Dealer/report.dart';
import 'package:cricbuzz/Dealer/sales_report.dart';
import 'package:cricbuzz/Dealer/delete_sales.dart';
import 'package:cricbuzz/Dealer/booking.dart';
import 'package:cricbuzz/Dealer/results.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Dealer/price_structure.dart';
import 'package:cricbuzz/Dealer/agent_list.dart';
import 'package:cricbuzz/Dealer/blocked_numbers.dart';
import 'package:cricbuzz/Dealer/change_password.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/config.dart';

class DealerHomePage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const DealerHomePage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<DealerHomePage> createState() => _DealerHomePageState();
}

class _DealerHomePageState extends State<DealerHomePage> {
  bool _canCreateAgent = false;
  bool _isLoadingPermission = true;

  @override
  void initState() {
    super.initState();
    fetchAgentCreationPermission();
  }

  Future<void> fetchAgentCreationPermission() async {
    const url = '${AppConfig.baseUrl}/dealer/api/enable-agent-creation/';

    if (MySession.token == null || MySession.token!.isEmpty) {
      setState(() {
        _canCreateAgent = false;
        _isLoadingPermission = false;
      });
      return;
    }

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
          _canCreateAgent = data['can_create_agent'] ?? false;
          _isLoadingPermission = false;
        });
      } else {
        setState(() {
          _canCreateAgent = false;
          _isLoadingPermission = false;
        });
      }
    } catch (e) {
      print("Error fetching agent creation permission: $e");
      setState(() {
        _canCreateAgent = false;
        _isLoadingPermission = false;
      });
    }
  }

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
        color: widget.themeColor,
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
              '${MySession.username ?? ''} (Dealer)',
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
                targetPage: BookingPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Sales Report',
                icon: Icons.trending_up,
                iconCircleColor: const Color(0xFF8CDAA2),
                targetPage: SalesReportPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Delete Sales',
                icon: Icons.delete_outline,
                iconCircleColor: const Color(0xFF42A5F5),
                targetPage: DeleteSalesPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Report',
                icon: Icons.analytics_outlined,
                iconCircleColor: const Color(0xFFE1BEE7),
                targetPage: ReportsMenuPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Results',
                icon: Icons.stars,
                iconCircleColor: const Color(0xFFFF8A80),
                targetPage: WinningNumbersPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Block Numbers',
                icon: Icons.block,
                iconCircleColor: const Color(0xFF4DB6AC),
                targetPage: BlockNumbersPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
              buildMenuButton(
                context,
                title: 'Price Structure',
                icon: Icons.card_giftcard,
                iconCircleColor: const Color(0xFFe62600),
                targetPage: PriceStructurePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),

              // 🔴 CONDITIONAL MENU ITEM: Displays only if _canCreateAgent is true
              if (_canCreateAgent)
                buildMenuButton(
                  context,
                  title: 'Agents',
                  icon: Icons.people,
                  iconCircleColor: const Color(0xFF81C784),
                  targetPage: AgentList(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),

              buildMenuButton(
                context,
                title: 'Change Game',
                icon: Icons.access_time,
                iconCircleColor: const Color(0xFF64B5F6),
                targetPage: const SelectTimePage(),
              ),
              buildMenuButton(
                context,
                title: 'Change Password',
                icon: Icons.password,
                iconCircleColor: const Color(0xFF42A5F5),
                targetPage: ChangePasswordPage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
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