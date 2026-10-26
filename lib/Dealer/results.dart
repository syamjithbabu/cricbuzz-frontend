import 'package:flutter/material.dart';
import 'package:cricbuzz/Dealer/select_time.dart';
import 'package:cricbuzz/Dealer/home.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class WinningNumbersPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const WinningNumbersPage({
    super.key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  });

  @override
  State<WinningNumbersPage> createState() => _WinningNumbersPageState();
}

class _WinningNumbersPageState extends State<WinningNumbersPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Backend state storage
  Map<String, dynamic> resultData = {};
  List<String> guaranteeNumbers = [];

  @override
  void initState() {
    super.initState();
    fetchResult();
  }

  Future<void> fetchResult() async {
    setState(() {
      _isLoading = true;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final url = Uri.parse(
      '${AppConfig.baseUrl}/dealer/api/result/?game_id=${widget.gameTimeId}&date=$dateStr',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${MySession.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['message'] == 'No result found') {
          setState(() {
            resultData = {};
            guaranteeNumbers = [];
          });
        } else {
          dynamic rawGuarantees = data['guarantees'];
          List<String> parsedGuarantees = [];

          if (rawGuarantees is String && rawGuarantees.isNotEmpty) {
            // Split comma-separated string into a list and trim spaces
            parsedGuarantees = rawGuarantees
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (rawGuarantees is List) {
            parsedGuarantees = rawGuarantees.map((e) => e.toString()).toList();
          }

          setState(() {
            resultData = data;
            guaranteeNumbers = parsedGuarantees;
          });
        }
      } else {
        debugPrint('Failed to fetch result: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching result: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Formatter to display date cleanly as dd/mm/yyyy
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Native Date Picker Selector Action
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      fetchResult();
    }
  }

  // Share result via WhatsApp
  Future<void> _shareToWhatsApp() async {
    if (resultData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No result to share!')),
      );
      return;
    }

    final dateStr = DateFormat("MMM. d, yyyy").format(_selectedDate);

    final buffer = StringBuffer();
    buffer.writeln('$dateStr - ${widget.gameTimeLabel}');
    buffer.writeln('');
    buffer.writeln('1 : ${resultData['first'] ?? '-'}');
    buffer.writeln('2 : ${resultData['second'] ?? '-'}');
    buffer.writeln('3 : ${resultData['third'] ?? '-'}');
    buffer.writeln('4 : ${resultData['fourth'] ?? '-'}');
    buffer.writeln('5 : ${resultData['fifth'] ?? '-'}');
    buffer.writeln('');

    // Add guarantee numbers in rows of 3
    const perRow = 3;
    for (int i = 0; i < guaranteeNumbers.length; i += perRow) {
      final row = guaranteeNumbers
          .skip(i)
          .take(perRow)
          .map((n) => n.padRight(5))
          .join('   ');
      buffer.writeln(row);
    }

    final text = buffer.toString();
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );

    if (!await launchUrl(
      whatsappUrl,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  // Helper method to split guarantees into 3-column rows for design grid
  List<List<String>> _getComplimentsGridData() {
    List<List<String>> grid = [];
    for (int i = 0; i < guaranteeNumbers.length; i += 3) {
      grid.add(
        guaranteeNumbers.skip(i).take(3).toList(),
      );
    }
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    final Color activeThemeColor = widget.themeColor;
    final complimentsData = _getComplimentsGridData();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: activeThemeColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DealerHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Winning Numbers',
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
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Row containing Date Field Selector & Search Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black26, width: 1.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  ElevatedButton(
                    onPressed: fetchResult,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeThemeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'SEARCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )
            else ...[
              const Text(
                'RESULTS KERALA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.3,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),

              // Top Tier Tiers Results Cards Matrix with Backend Data
              _buildResultRow('FIRST :', resultData['first']?.toString() ?? '-', const Color(0xFF19C819)),
              _buildResultRow('SECOND :', resultData['second']?.toString() ?? '-', const Color(0xFF1E73BE)),
              _buildResultRow('THIRD :', resultData['third']?.toString() ?? '-', const Color(0xFF7A23B1)),
              _buildResultRow('FOURTH :', resultData['fourth']?.toString() ?? '-', const Color(0xFFD66A11)),
              _buildResultRow('FIFTH :', resultData['fifth']?.toString() ?? '-', const Color(0xFF0A3382)),

              const SizedBox(height: 12),
              const Text(
                'COMPLIMENTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.3,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),

              // 3-Column Compliments Numbers Grid Block Layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: complimentsData.isEmpty
                    ? const Text(
                        'No Compliments Available',
                        style: TextStyle(color: Colors.grey),
                      )
                    : Column(
                        children: complimentsData.map((rowItems) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: rowItems.map((val) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      val,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              '---END---',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // WhatsApp Share Button wrapped in exact original design badge
            InkWell(
              onTap: _shareToWhatsApp,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            // Live Status Text column blocks
            InkWell(
              onTap: () async {
                final timeName = widget.gameTimeLabel.toLowerCase();
                String url;
                if (timeName.contains('lsk') && timeName.contains('3')) {
                  url = 'https://www.youtube.com/@KeralaLotteryLiveResult';
                } else {
                  url = 'https://www.youtube.com/@DEARLOTTERIESLIVE';
                }
                final Uri uri = Uri.parse(url);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch $url');
                }
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'LIVE RESULTS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Click',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Generates custom horizontal metrics bar blocks
  Widget _buildResultRow(String position, String number, Color rowBgColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      height: 34,
      color: rowBgColor,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                position,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Container(
            width: 1.2,
            color: Colors.white.withOpacity(0.7),
          ),
          Expanded(
            flex: 5,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}