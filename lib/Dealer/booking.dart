import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Dealer/view_bill_screen.dart';
import 'package:cricbuzz/Dealer/home.dart';
import 'package:cricbuzz/Dealer/select_time.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const BookingPage({
    super.key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _selectedRadio = 3;
  // Change this to nullable String, starting as null (which represents "Me")
  String? _selectedAgent;
  List<String?> _agentsList = [null]; // Initialize with null ("Me") ready
  String _selectedBookOption = 'BOOK';

  String _activeSelectionBarValue = 'SUPER';

  // Table Data State
  final List<Map<String, dynamic>> _tableRows = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchActivePackages();
    fetchAgents();
  }

  // Controllers
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _bCountController = TextEditingController();

  // Focus nodes
  final FocusNode _numberFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  final FocusNode _countFocusNode = FocusNode();

  bool get _isRangeMode =>
      ['RANGE', '10S', '100S', '111S'].contains(_selectedBookOption);

  List<String> _getSelectionLabels() {
    if (_selectedRadio == 1) return ['A', 'B', 'C', 'ALL'];
    if (_selectedRadio == 2) return ['AB', 'BC', 'AC', 'ALL'];
    final String firstOption = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';
    return [firstOption, 'BOX', 'SET', 'BOTH'];
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Map<String, dynamic>? dealerPackage;
  Map<String, dynamic>? subStockistPackage;
  Map<String, dynamic>? stockistPackage;

  Future<void> fetchActivePackages({String? agentUsername}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Append query parameter if an agent username is passed
    String urlString = '${AppConfig.baseUrl}/dealer/api/active-hierarchy/';
    if (agentUsername != null) {
      urlString += '?agent_username=$agentUsername';
    }

    final url = Uri.parse(urlString);

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        setState(() {
          dealerPackage = decodedData['dealer'];
          subStockistPackage = decodedData['sub_stockist'];
          stockistPackage = decodedData['stockist'];
          isLoading = false;

          // RECALCULATE EXISTING TABLE ROWS IF CODES ARE ALREADY ADDED
          if (_tableRows.isNotEmpty) {
            final List<Map<String, dynamic>> updatedRows = [];
            for (var row in _tableRows) {
              updatedRows.add(
                buildRowPayload(
                  resolvedLsk: row['lsk'],
                  formattedNumber: row['number'],
                  countVal: row['count'],
                ),
              );
            }
            _tableRows.clear();
            _tableRows.addAll(updatedRows);
          }
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load package rates (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred fetching packages. Check connection.';
        isLoading = false;
      });
    }
  }

  Future<void> fetchAgents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final url = Uri.parse('${AppConfig.baseUrl}/dealer/api/agents/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          // Map the API usernames
          final fetchedUsernames = data.map<String>((item) {
            final user = item['user'];
            return user != null ? user['username'].toString() : 'Unknown Agent';
          }).toList();

          // Put null (representing "Me") at the top, followed by fetched agents
          _agentsList = [null, ...fetchedUsernames];

          // Default to "Me" (null)
          _selectedAgent = null;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load agents (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Check connection.';
        isLoading = false;
      });
    }
  }

  // final bool isAgentSelected = _selectedAgent != 'Me';
  // 'agent_name': isAgentSelected ? _selectedAgent : null,
  // 'is_agent_booking': isAgentSelected,

  Future<void> _saveEntriesToBackend() async {
    final bool isAgentSelected = _selectedAgent != 'Me';
    final bool isRetail = (_selectedBookOption == 'RETAIL');

    final Map<String, dynamic> requestPayload = {
      'customer_name': _customerController.text.trim(),
      'agent_name': isAgentSelected ? _selectedAgent : null,
      'is_agent_booking': isAgentSelected,

      'game_time_id': widget.gameTimeId,
      'entries': _tableRows,
      'is_retail': isRetail,
    };

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/dealer/api/save-entries/');

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestPayload),
      );

      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 400) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 1. Handle Standard Time Over Error
        if (responseData['error'] == 'Booking is disabled') {
          if (mounted) _showBookingDisabledDialog(context);
          return;
        }

        // 1. Handle Standard Time Over Error
        if (responseData['error'] == 'Time Over') {
          if (mounted) _showTimeOverDialog(context);
          return;
        }

        // 2. Handle Retail Specific Time Over Error
        if (responseData['error'] == 'Retail ticket booking time over') {
          if (mounted) _showRetailTimeOverDialog(context);
          return;
        }

        // 3. Handle generic 400 errors without failed_entries
        if (response.statusCode == 400 &&
            !responseData.containsKey('failed_entries')) {
          if (mounted)
            _showErrorDialog(context, responseData['error'] ?? 'Bad Request');
          return;
        }

        // 4. Process partially or fully saved entries
        final int billId = responseData['bill_id'] ?? 0;
        final int savedCount = responseData['saved_count'] ?? 0;
        final List<dynamic> failedEntries =
            responseData['failed_entries'] ?? [];
        final int failedCount =
            responseData['failed_count'] ?? failedEntries.length;

        if (savedCount > 0) {
          setState(() {
            _tableRows.clear();
            _clearInputs();
            _customerController.clear();
            _selectedRadio = 3;
            _selectedBookOption = 'BOOK'; // Reset option back to BOOK
          });
        }

        if (mounted) {
          _showSaveResultDialog(
            context: context,
            billId: billId,
            savedCount: savedCount,
            failedCount: failedCount,
            failedEntries: failedEntries,
          );
        }
      } else {
        throw Exception('Server returned error status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Save failed: $e')));
      }
    }
  }

  /// Alert Dialog for Retail Time Over
  void _showRetailTimeOverDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.storefront, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                'Retail Time Over',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Retail ticket booking window is currently closed for this game time slot.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Displays a Time Over alert dialog
  void _showTimeOverDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.timer_off, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Time Over', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Booking for this game slot is now closed. Please select an active game time.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Displays a Booking Disabled alert dialog
  void _showBookingDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                'Booking Disabled',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Booking is currently disabled for your account or partner network. Please contact support.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Displays a general error dialog for 400 responses
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Notice'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSaveResultDialog({
    required BuildContext context,
    required int billId,
    required int savedCount,
    required int failedCount,
    required List<dynamic> failedEntries,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0), // Matching sharp styling
          ),
          contentPadding: const EdgeInsets.only(
            top: 32.0,
            left: 20.0,
            right: 20.0,
            bottom: 12.0,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // -------------------------------------------------------------
                // SCENARIO 1: ALL ENTRIES SAVED
                // -------------------------------------------------------------
                if (failedCount == 0) ...[
                  Text(
                    'BILL NO - #$billId',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],

                // -------------------------------------------------------------
                // SCENARIO 2: PARTIAL SAVED (SOME PASSED, SOME FAILED)
                // -------------------------------------------------------------
                if (savedCount > 0 && failedCount > 0) ...[
                  Text(
                    'Bill No #$billId',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Not Saved Entries',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFailedEntriesList(failedEntries),
                  const SizedBox(height: 16),

                  // Green Share Button for Unsaved
                  OutlinedButton.icon(
                    onPressed: () =>
                        _shareUnsavedToWhatsApp(failedEntries, billId: billId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(
                      Icons.share,
                      color: Colors.green,
                      size: 18,
                    ),
                    label: const Text(
                      'Share Unsaved',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                // -------------------------------------------------------------
                // SCENARIO 3: ALL ENTRIES FAILED
                // -------------------------------------------------------------
                if (savedCount == 0 && failedCount > 0) ...[
                  const Text(
                    'All Entries Failed',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All entries exceeded limits or are blocked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.0, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _buildFailedEntriesList(failedEntries),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
          actions: [
            // BUTTONS: ALL SAVED
            if (failedCount == 0) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToViewBill(billId);
                },
                child: const Text(
                  'VIEW BILL',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],

            // BUTTONS: PARTIAL SAVED
            if (savedCount > 0 && failedCount > 0) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToViewBill(billId);
                },
                child: const Text(
                  'VIEW BILL',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],

            // BUTTONS: ALL FAILED
            if (savedCount == 0 && failedCount > 0) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _shareUnsavedToWhatsApp(failedEntries),
                child: const Text(
                  'SHARE',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // Helper widget to format entries as: TICKET - NUMBER - COUNT
  Widget _buildFailedEntriesList(List<dynamic> failedEntries) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: failedEntries.length,
          itemBuilder: (context, index) {
            final item = failedEntries[index];
            final String ticket = item['lsk']?.toString().trim() ?? '';
            final String number = item['number']?.toString().trim() ?? '';
            final String count = item['count']?.toString().trim() ?? '0';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Text(
                '$ticket - $number - $count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Navigation helper
  void _navigateToViewBill(int billId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ViewBillScreen(
          billId: billId,
          themeColor: widget.themeColor,
          gameTimeId: widget.gameTimeId,
          gameTimeLabel: widget.gameTimeLabel,
        ),
      ),
    );
  }

  // WhatsApp Share Handler
  Future<void> _shareUnsavedToWhatsApp(
    List<dynamic> failedEntries, {
    int? billId,
  }) async {
    final StringBuffer sb = StringBuffer();

    if (billId != null && billId > 0) {
      sb.writeln("⚠️ *Bill #$billId - Unsaved Entries*");
    } else {
      sb.writeln("❌ *All Entries Failed/Blocked*");
    }

    sb.writeln("Time: ${widget.gameTimeLabel}");
    sb.writeln("--------------------------------");

    for (var item in failedEntries) {
      final String ticket = item['lsk']?.toString().trim() ?? '';
      final String number = item['number']?.toString().trim() ?? '';
      final String count = item['count']?.toString().trim() ?? '0';
      sb.writeln("$ticket - $number - $count");
    }

    final String encodedText = Uri.encodeComponent(sb.toString());
    final Uri whatsappUri = Uri.parse("whatsapp://send?text=$encodedText");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to launch WhatsApp: $e");
    }
  }

  int _getStepInterval() {
    if (_selectedBookOption == 'RANGE') return 1;

    if (_selectedBookOption == '10S') {
      if (_selectedRadio == 3) return 10;
      if (_selectedRadio == 2) return 10;
      return 1;
    }
    if (_selectedBookOption == '100S') {
      if (_selectedRadio == 3) return 100;
      if (_selectedRadio == 2) return 10;
      return 1;
    }
    if (_selectedBookOption == '111S') {
      if (_selectedRadio == 3) return 111;
      if (_selectedRadio == 2) return 11;
      return 1;
    }
    return 1;
  }

  List<String> _getUniquePermutations(String text) {
    List<String> results = [];
    if (text.isEmpty) return results;

    void permute(List<String> chars, int index) {
      if (index == chars.length - 1) {
        results.add(chars.join());
        return;
      }
      Set<String> processed = {};
      for (int i = index; i < chars.length; i++) {
        if (processed.contains(chars[i])) continue;
        processed.add(chars[i]);

        var temp = chars[index];
        chars[index] = chars[i];
        chars[i] = temp;

        permute(chars, index + 1);

        temp = chars[index];
        chars[index] = chars[i];
        chars[i] = temp;
      }
    }

    permute(text.split(''), 0);
    return results;
  }

  // Confirmation dialog prompt before wiping data records
  void _showClearAllConfirmationDialog() {
    if (_tableRows.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Bookings?'),
          content: const Text(
            'Are you sure you want to delete all rows from the table? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _tableRows.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                'CLEAR ALL',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, double> calculateAmounts(
    String targetLsk,
    int count,
    Map<String, dynamic>? package, {
    bool isRetail = false,
  }) {
    if (package == null) return {'d_amount': 0.0, 'c_amount': 0.0};

    double rate = 0.0;
    double dc = 0.0;

    if (targetLsk == 'SUPER' || targetLsk == 'DEAR') {
      final rateKey = isRetail ? 'retail_super_rate' : 'super_rate';
      final dcKey = isRetail ? 'retail_super_dc' : 'super_dc';
      rate = (package[rateKey] as num?)?.toDouble() ?? 0.0;
      dc = (package[dcKey] as num?)?.toDouble() ?? 0.0;
    } else if (targetLsk == 'BOX') {
      final rateKey = isRetail ? 'retail_box_rate' : 'box_rate';
      final dcKey = isRetail ? 'retail_box_dc' : 'box_dc';
      rate = (package[rateKey] as num?)?.toDouble() ?? 0.0;
      dc = (package[dcKey] as num?)?.toDouble() ?? 0.0;
    } else if (['A', 'B', 'C'].contains(targetLsk)) {
      final rateKey = isRetail ? 'retail_single_rate' : 'single_rate';
      final dcKey = isRetail ? 'retail_single_dc' : 'single_dc';
      rate = (package[rateKey] as num?)?.toDouble() ?? 0.0;
      dc = (package[dcKey] as num?)?.toDouble() ?? 0.0;
    } else if (['AB', 'BC', 'AC'].contains(targetLsk)) {
      final rateKey = isRetail ? 'retail_double_rate' : 'double_rate';
      final dcKey = isRetail ? 'retail_double_dc' : 'double_dc';
      rate = (package[rateKey] as num?)?.toDouble() ?? 0.0;
      dc = (package[dcKey] as num?)?.toDouble() ?? 0.0;
    } else {
      final rateKey = isRetail ? 'retail_single_rate' : 'single_rate';
      final dcKey = isRetail ? 'retail_single_dc' : 'single_dc';
      rate = (package[rateKey] as num?)?.toDouble() ?? 0.0;
      dc = (package[dcKey] as num?)?.toDouble() ?? 0.0;
    }

    return {'d_amount': rate * count, 'c_amount': (rate - dc) * count};
  }

  Map<String, dynamic> buildRowPayload({
    required String resolvedLsk,
    required String formattedNumber,
    required int countVal,
  }) {
    final bool isRetail = (_selectedBookOption == 'RETAIL');

    final dealerAmts = calculateAmounts(
      resolvedLsk,
      countVal,
      dealerPackage,
      isRetail: isRetail,
    );

    final subStockistAmts = calculateAmounts(
      resolvedLsk,
      countVal,
      subStockistPackage,
      isRetail: isRetail,
    );

    final stockistAmts = calculateAmounts(
      resolvedLsk,
      countVal,
      stockistPackage,
      isRetail: isRetail,
    );

    return {
      'lsk': resolvedLsk,
      'number': formattedNumber,
      'count': countVal,
      'is_retail': isRetail,

      // UI Table displays this
      'd_amount_dealer': dealerAmts['d_amount'],
      'c_amount_dealer': dealerAmts['c_amount'],

      // Hidden multi-tier values bound for your backend payload
      'd_amount_sub_stockist': subStockistAmts['d_amount'],
      'c_amount_sub_stockist': subStockistAmts['c_amount'],
      'd_amount_stockist': stockistAmts['d_amount'],
      'c_amount_stockist': stockistAmts['c_amount'],
    };
  }

  void _addBookingRow(String lskLabel) {
    if (_isRangeMode) {
      final startText = _numberController.text.trim();
      final endText = _endController.text.trim();
      final countText = _countController.text.trim();

      if (startText.isEmpty || endText.isEmpty || countText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Start, End, and Count.')),
        );
        return;
      }

      final int startVal = int.tryParse(startText) ?? -1;
      final int endVal = int.tryParse(endText) ?? -1;
      final int countVal = int.tryParse(countText) ?? 0;

      if (startVal < 0 || endVal < 0 || countVal <= 0 || startVal > endVal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid numeric range sequence.'),
          ),
        );
        return;
      }

      int step = _getStepInterval();
      List<Map<String, dynamic>> batchRows = [];

      for (int i = endVal; i >= startVal; i -= step) {
        final String formattedNumber = i.toString().padLeft(
          _selectedRadio,
          '0',
        );

        if (lskLabel == 'BOTH') {
          final String primaryLsk = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';

          batchRows.add(
            buildRowPayload(
              resolvedLsk: primaryLsk,
              formattedNumber: formattedNumber,
              countVal: countVal,
            ),
          );
          batchRows.add(
            buildRowPayload(
              resolvedLsk: 'BOX',
              formattedNumber: formattedNumber,
              countVal: countVal,
            ),
          );
        } else if (lskLabel == 'ALL') {
          if (_selectedRadio == 1) {
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'C',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'B',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'A',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
          } else if (_selectedRadio == 2) {
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'AC',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'BC',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
            batchRows.add(
              buildRowPayload(
                resolvedLsk: 'AB',
                formattedNumber: formattedNumber,
                countVal: countVal,
              ),
            );
          }
        } else {
          batchRows.add(
            buildRowPayload(
              resolvedLsk: lskLabel,
              formattedNumber: formattedNumber,
              countVal: countVal,
            ),
          );
        }
      }

      setState(() {
        _activeSelectionBarValue = lskLabel;
        _tableRows.insertAll(0, batchRows);
        _clearInputs();
      });
    } else {
      final numberText = _numberController.text.trim();
      final countText = _countController.text.trim();
      final bCountText = _bCountController.text.trim();

      if (numberText.isEmpty || countText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter both Number and Count.')),
        );
        return;
      }

      final int countVal = int.tryParse(countText) ?? 0;
      if (countVal <= 0) return;

      setState(() {
        _activeSelectionBarValue = lskLabel;

        if (lskLabel == 'BOTH') {
          final String primaryLsk = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';
          final int bCountVal = int.tryParse(bCountText) ?? countVal;

          _tableRows.insert(
            0,
            buildRowPayload(
              resolvedLsk: 'BOX',
              formattedNumber: numberText,
              countVal: bCountVal,
            ),
          );
          _tableRows.insert(
            0,
            buildRowPayload(
              resolvedLsk: primaryLsk,
              formattedNumber: numberText,
              countVal: countVal,
            ),
          );
        } else if (lskLabel == 'ALL') {
          if (_selectedRadio == 1) {
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'C',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'B',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'A',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
          } else if (_selectedRadio == 2) {
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'AC',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'BC',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: 'AB',
                formattedNumber: numberText,
                countVal: countVal,
              ),
            );
          }
        } else if (lskLabel == 'SET') {
          final String primaryLsk = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';
          final uniquePermutations = _getUniquePermutations(numberText);
          for (final variant in uniquePermutations.reversed) {
            _tableRows.insert(
              0,
              buildRowPayload(
                resolvedLsk: primaryLsk,
                formattedNumber: variant,
                countVal: countVal,
              ),
            );
          }
        } else {
          _tableRows.insert(
            0,
            buildRowPayload(
              resolvedLsk: lskLabel,
              formattedNumber: numberText,
              countVal: countVal,
            ),
          );
        }

        _clearInputs();
      });
    }
  }

  void _clearInputs() {
    _numberController.clear();
    _endController.clear();
    _countController.clear();
    _bCountController.clear();
    _numberFocusNode.requestFocus();
  }

  int get _totalCount =>
      _tableRows.fold(0, (sum, item) => sum + (item['count'] as int));
  double get _totalDAmount => _tableRows.fold(
    0.0,
    (sum, item) => sum + (item['d_amount_dealer'] as double),
  );
  double get _totalCAmount => _tableRows.fold(
    0.0,
    (sum, item) => sum + (item['c_amount_dealer'] as double),
  );

  @override
  void dispose() {
    _customerController.dispose();
    _numberController.dispose();
    _endController.dispose();
    _countController.dispose();
    _bCountController.dispose();
    _numberFocusNode.dispose();
    _endFocusNode.dispose();
    _countFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.themeColor;
    final currentLabels = _getSelectionLabels();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: activeColor,
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
        title: Text(
          widget.gameTimeLabel,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment, color: Colors.white),
            tooltip: 'Paste from Clipboard',
            onPressed: () async {
              // Triggers your clipboard validation and parsing workflow
              await processClipboardEntries();
            },
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: ElevatedButton(
              onPressed: _tableRows.isEmpty ? null : _saveEntriesToBackend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Colors.white),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SelectTimePage()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Row 1: Customer and Agent
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerController,
                    decoration: const InputDecoration(
                      hintText: 'Customer',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    // Safeguard: fall back to null ("Me") if current selection is missing
                    value: _agentsList.contains(_selectedAgent)
                        ? _selectedAgent
                        : null,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                    ),
                    // Map our list of nullable strings to DropdownMenuItems
                    items: _agentsList.map<DropdownMenuItem<String?>>((
                      String? value,
                    ) {
                      return DropdownMenuItem<String?>(
                        value: value,
                        child: Text(
                          value ??
                              'Me', // If the value is null, show "Me" in UI
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedAgent =
                            newValue; // null means "Me", otherwise agent name string
                      });
                      // Clear the table data instantly when a new option is selected
                      _tableRows.clear();
                      // Triggers the package reload based on selection state
                      fetchActivePackages(agentUsername: newValue);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Row 2: Radio Buttons and Book Options
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            child: Row(
              children: [
                Row(
                  children: [1, 2, 3].map((int i) {
                    return Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: _selectedRadio,
                          activeColor: activeColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedRadio = val!;

                              if (_selectedRadio == 1)
                                _activeSelectionBarValue = 'A';
                              else if (_selectedRadio == 2)
                                _activeSelectionBarValue = 'AB';
                              else
                                _activeSelectionBarValue = 'SUPER';

                              _customerController.clear();
                              _numberController.clear();
                              _endController.clear();
                              _countController.clear();
                              _bCountController.clear();

                              _numberFocusNode.requestFocus();
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Text('$i'),
                        const SizedBox(width: 14),
                      ],
                    );
                  }).toList(),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedBookOption,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                  underline: const SizedBox(),
                  isDense: true,
                  items:
                      <String>[
                        'BOOK',
                        'RANGE',
                        'SET',
                        '10S',
                        '100S',
                        '111S',
                        'RETAIL',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBookOption = newValue!;
                      _numberController.clear();
                      _endController.clear();
                      _countController.clear();
                      _bCountController.clear();
                      _numberFocusNode.requestFocus();
                      // Clear table rows if switching TO or FROM RETAIL
                      if (newValue == 'RETAIL' ||
                          _selectedBookOption == 'RETAIL') {
                        _tableRows.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 12, thickness: 1),

          // Row 3: Text Input Configs
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    focusNode: _numberFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: _selectedRadio,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.length == _selectedRadio) {
                        FocusScope.of(context).requestFocus(
                          _isRangeMode ? _endFocusNode : _countFocusNode,
                        );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _isRangeMode ? 'Start' : 'Number',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
                      counterText: "",
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                if (_isRangeMode) ...[
                  Expanded(
                    child: TextField(
                      controller: _endController,
                      focusNode: _endFocusNode,
                      keyboardType: TextInputType.number,
                      maxLength: _selectedRadio,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.length == _selectedRadio) {
                          FocusScope.of(context).requestFocus(_countFocusNode);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'End',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                        counterText: "",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _countController,
                      focusNode: _countFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Count',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: TextField(
                      controller: _countController,
                      focusNode: _countFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Count',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                      ),
                    ),
                  ),
                  if (_selectedRadio == 3) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _bCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'B Count',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Dynamic Colored Selection Bar
          Container(
            color: activeColor,
            child: Row(
              children: currentLabels.map((label) {
                final isSelected = _activeSelectionBarValue == label;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _addBookingRow(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor
                            : activeColor.withOpacity(0.85),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // Header Row
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 32,
            child: Row(
              children: [
                Expanded(flex: 2, child: _headerText('LSK')),
                Container(
                  width: 1,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _headerText('NUMBER'),
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _headerText('COUNT'),
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _headerText('D.AMOUNT'),
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _headerText('C.AMOUNT'),
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),

                // UPDATED: Global clear button container with automated context safety
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showClearAllConfirmationDialog,
                  child: Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.delete,
                      color: _tableRows.isEmpty
                          ? Colors.grey.shade400
                          : Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // High Performance Scrollable Ledger List View
          Expanded(
            child: _tableRows.isEmpty
                ? Center(
                    child: Text(
                      'No bookings added yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _tableRows.length,
                    itemExtent: 32.0,
                    itemBuilder: (context, index) {
                      final rowData = _tableRows[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                rowData['lsk'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  rowData['number'],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  rowData['count'].toString(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  rowData['d_amount_dealer'].toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  rowData['c_amount_dealer'].toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),

                            Container(
                              width: 24,
                              alignment: Alignment.center,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _tableRows.removeAt(index);
                                  });
                                },
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Summary Dashboard
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Row(
              children: [
                _bottomSummaryBlock('COUNT', _totalCount.toString()),
                _bottomSummaryBlock(
                  'CAMOUNT',
                  _totalCAmount.toStringAsFixed(1),
                ),
                _bottomSummaryBlock(
                  'DAMOUNT',
                  _totalDAmount.toStringAsFixed(1),
                ),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _tableRows.isEmpty ? null : _saveEntriesToBackend,
                    child: Container(
                      color: activeColor,
                      padding: const EdgeInsets.all(18),
                      alignment: Alignment.center,
                      child: Text(
                        widget.gameTimeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Colors.black87,
      ),
    );
  }

  Widget _bottomSummaryBlock(String title, String aggregateValue) {
    return Expanded(
      flex: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            aggregateValue,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> processClipboardEntries() async {
    try {
      final ClipboardData? data = await Clipboard.getData('text/plain');

      if (data == null || data.text == null || data.text!.trim().isEmpty)
        return;
      String rawText = data.text!;

      // 1. Normalization Step
      rawText = rawText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ')
          .replaceAll('\u200B', '')
          .replaceAll('\u200C', '')
          .replaceAll('\u200D', '')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('−', '-')
          .replaceAll('／', '/')
          .replaceAll('＝', '=');

      /// Clean up WhatsApp timestamps/sender tags
      final RegExp whatsappHeaderRegex = RegExp(
        r'^\[\d{1,2}[\/\-]\d{1,2}(?:[\/\-]\d{2,4})?,?\s*\d{1,2}:\d{2}(?:\s*[ap]m)?\]\s*.*?:\s*',
        caseSensitive: false,
        multiLine: true,
      );
      final cleanedText = rawText.replaceAll(whatsappHeaderRegex, '');

      // Normalize structural text variations to match permutation keywords
      final RegExp boxToSetRegex = RegExp(
        r'(?<=\d+[\s*-]*)(?:box|bx|b|bb|kb|kbox)(?=\s|$|\d+)',
        caseSensitive: false,
      );
      final normalizedText = cleanedText.replaceAll(boxToSetRegex, 'set');
      final lines = normalizedText.trim().split('\n');

      List<String> invalidRows = [];
      List<Map<String, dynamic>> parsedRows = [];

      // 2. Regex Mapping Setup
      final RegExp numCountKeywordSuffixRegex = RegExp(
        r'^(\d+)[*\s\W]+(\d+)[*\s\W]*(?:set)[*\s\W]*$',
        caseSensitive: false,
      );
      final RegExp boxPrefixRegex = RegExp(
        r'^(?:set|box)[*\s\W]*(\d+)[*\s\W]*(\d+)[*\s\W]*$',
        caseSensitive: false,
      );
      final RegExp numKeywordCountRegex = RegExp(
        r'^(\d+)[*\s\W]+(?:set)[*\s\W/]+(\d+)[*\s\W]*$',
        caseSensitive: false,
      );
      final RegExp dashEqualRegex = RegExp(
        r'^[A-Z0-9]+\s*-\s*(\d+)\s*=\s*(\d+)\s*$',
        caseSensitive: false,
      );
      final RegExp splitMatchRegex = RegExp(
        r'^((?:(?:ab|bc|ac|abc|abbcac|a|b|c)[\s.]*)+)[*\s\W]+(\d+)[*\s\W]+(\d+)[*\s\W]*$',
        caseSensitive: false,
      );
      final RegExp singleLetterTicketRegex = RegExp(
        r'^([A-Z])[*\s\W]*(\d+)[*\s\W]*(\d+)[*\s\W]*$',
        caseSensitive: false,
      );
      final RegExp superBoxDualRegex = RegExp(r'^(\d+)\D+(\d+)\D+(\d+)$');
      final RegExp standardFallbackRegex = RegExp(r'^(\d+)\D+(\d+)');

      // 3. Processing Lines
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.toUpperCase().startsWith("GT") ||
            line.toUpperCase().contains("GT :")) {
          continue;
        }

        // Format A: Direct Straight Mapping (Dash Equal) -> e.g. "KL - 012 = 1"
        final dashEqualMatch = dashEqualRegex.firstMatch(line);
        if (dashEqualMatch != null) {
          final exactNumber = dashEqualMatch.group(1)!;
          final count = int.tryParse(dashEqualMatch.group(2)!) ?? 1;
          parsedRows.add(
            buildRowPayload(
              resolvedLsk: 'SUPER',
              formattedNumber: exactNumber,
              countVal: count,
            ),
          );
          continue;
        }

        // Format B: Permutations / SET keywords -> e.g. "123 1set", "set-449*2"
        RegExpMatch? matchResult =
            boxPrefixRegex.firstMatch(line) ??
            numCountKeywordSuffixRegex.firstMatch(line) ??
            numKeywordCountRegex.firstMatch(line);

        if (matchResult != null) {
          final baseNumber = matchResult.group(1)!;
          final count = int.tryParse(matchResult.group(2)!) ?? 1;
          final permutations = _getUniquePermutations(baseNumber);

          for (final permNum in permutations) {
            parsedRows.add(
              buildRowPayload(
                resolvedLsk: 'SUPER',
                formattedNumber: permNum,
                countVal: count,
              ),
            );
          }
          continue;
        }

        // Format C: Dynamic Splits -> e.g. "ab 12 5"
        final splitMatch = splitMatchRegex.firstMatch(line);
        if (splitMatch != null) {
          final rawKeyword = splitMatch.group(1)!;
          final number = splitMatch.group(2)!;
          final count = int.tryParse(splitMatch.group(3)!) ?? 1;

          final normalizedKeyword = rawKeyword.toLowerCase().replaceAll(
            RegExp(r'[\s\W]'),
            '',
          );
          List<String> suffixes = [];

          if (normalizedKeyword == 'ab') {
            suffixes = (number.length == 1) ? ['A', 'B'] : ['AB'];
          } else if (normalizedKeyword == 'abc') {
            suffixes = ['A', 'B', 'C'];
          } else if (normalizedKeyword == 'abbcac') {
            suffixes = ['AB', 'BC', 'AC'];
          }

          if (suffixes.isNotEmpty) {
            for (final suffix in suffixes) {
              parsedRows.add(
                buildRowPayload(
                  resolvedLsk: suffix,
                  formattedNumber: number,
                  countVal: count,
                ),
              );
            }
            continue;
          } else {
            invalidRows.add(line);
            continue;
          }
        }

        // Format D: Dual Entry Layout -> e.g. "123-10-5" (SUPER count, then BOX count)
        final superBoxMatch = superBoxDualRegex.firstMatch(line);
        if (superBoxMatch != null) {
          final number = superBoxMatch.group(1)!;
          final superCount = int.parse(superBoxMatch.group(2)!);
          final boxCount = int.parse(superBoxMatch.group(3)!);

          parsedRows.add(
            buildRowPayload(
              resolvedLsk: 'SUPER',
              formattedNumber: number,
              countVal: superCount,
            ),
          );
          parsedRows.add(
            buildRowPayload(
              resolvedLsk: 'BOX',
              formattedNumber: number,
              countVal: boxCount,
            ),
          );
          continue;
        }

        // Format E: Single Character Assignment Rules -> e.g. "C...6*5"
        final singleLetterMatch = singleLetterTicketRegex.firstMatch(line);
        if (singleLetterMatch != null) {
          final suffix = singleLetterMatch.group(1)!.toUpperCase();
          final number = singleLetterMatch.group(2)!;
          final count = int.tryParse(singleLetterMatch.group(3)!) ?? 1;

          parsedRows.add(
            buildRowPayload(
              resolvedLsk: suffix,
              formattedNumber: number,
              countVal: count,
            ),
          );
          continue;
        }

        // Catch explicit dangling invalid keywords
        if (line.toLowerCase().contains('box') ||
            line.toLowerCase().contains('set')) {
          invalidRows.add(line);
          continue;
        }

        // Format F: Standard Separator Fallback (Handles: 890%10, 888*10, 777!10, 123,10)
        final fallbackMatch = standardFallbackRegex.firstMatch(line);
        if (fallbackMatch != null) {
          final number = fallbackMatch.group(1)!;
          final count = int.parse(fallbackMatch.group(2)!);
          parsedRows.add(
            buildRowPayload(
              resolvedLsk: 'SUPER',
              formattedNumber: number,
              countVal: count,
            ),
          );
          continue;
        }

        // None matched
        invalidRows.add(line);
      }

      // 4. Update ledger view context
      if (parsedRows.isNotEmpty) {
        setState(() {
          // Inserts everything using the lightning-fast batch array mutation mechanism
          _tableRows.insertAll(0, parsedRows);
        });
      }

      // 5. Present Exception Dialog for Unprocessed Items
      if (invalidRows.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Invalid Entry Items"),
            content: SingleChildScrollView(
              child: ListBody(
                children: invalidRows
                    .map(
                      (e) => Text(
                        e,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error reading clipboard text system context parsing: $e");
    }
  }
}
