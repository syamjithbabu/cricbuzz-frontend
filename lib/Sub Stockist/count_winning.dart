import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'dart:convert';
import 'package:cricbuzz/Sub Stockist/home.dart';
import 'package:cricbuzz/Sub Stockist/select_time.dart';

class CountWinningPage extends StatefulWidget {
  final Color themeColor; // Matches your master color palette (e.g., Color(0xFF00695C))
  final int gameTimeId;
  final String gameTimeLabel;

  const CountWinningPage({
    Key? key, 
    required this.themeColor, 
    required this.gameTimeId, 
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<CountWinningPage> createState() => _CountWinningPageState();
}

class _CountWinningPageState extends State<CountWinningPage> {

  int? _selectedTimeId;
  List<dynamic> _fetchedTimesList = [];
  bool _isTimesLoading = true;
  bool _isReportLoading = false;

  String? _selectedDealer;
  String? _selectedAgent;
  List<Map<String, dynamic>> _dealersList = [];
  List<Map<String, dynamic>> _agentsList = [];

  bool isLoading = true;
  String? errorMessage;

  // Real-time dynamic list & total calculated from model data
  List<Map<String, dynamic>> _reportData = [];
  double _grandTotalAmount = 0.0;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  Map<String, dynamic>? _selectedDealerMap;
  Map<String, dynamic>? _selectedAgentMap;

  @override
  void initState() {
    super.initState();
    _selectedTimeId = widget.gameTimeId <= 0 ? null : widget.gameTimeId;
    _fetchGameTimes();
    fetchDealers();
    _fetchWinningCountReport(); // Fetch report data initially on load
  }

  Future<void> _fetchGameTimes() async {
    final url = Uri.parse('${AppConfig.baseUrl}/substockist/api/game-times/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _fetchedTimesList = data;
          _isTimesLoading = false;
          if (_selectedTimeId != null) {
            bool hasNavId = data.any((time) => time['id'] == _selectedTimeId);
            if (!hasNavId) _selectedTimeId = null;
          }
        });
      } else {
        setState(() => _isTimesLoading = false);
      }
    } catch (e) {
      setState(() => _isTimesLoading = false);
    }
  }

  // --- POSITION & TICKET DISPLAY TRANSFORMER ---
  String _getDisplayPosition(String rawTicket, String rawPosition) {
    final ticket = rawTicket.trim().toUpperCase();
    final pos = rawPosition.trim().toUpperCase();

    // Board Single Tickets
    if (ticket == 'A') return 'BOARD - A';
    if (ticket == 'B') return 'BOARD - B';
    if (ticket == 'C') return 'BOARD - C';

    // Double Tickets
    if (ticket == 'AB') return 'DOUBLE - AB';
    if (ticket == 'BC') return 'DOUBLE - BC';
    if (ticket == 'AC') return 'DOUBLE - AC';

    // Box Ticket
    if (ticket == 'BOX') return 'BOX';

    // Super / Numbered Positions
    if (ticket == 'SUPER' || ticket == 'GUARANTEE') {
      if (pos == '1' || pos == 'FIRST') return 'FIRST';
      if (pos == '2' || pos == 'SECOND') return 'SECOND';
      if (pos == '3' || pos == 'THIRD') return 'THIRD';
      if (pos == '4' || pos == 'FOURTH') return 'FOURTH';
      if (pos == '5' || pos == 'FIFTH') return 'FIFTH';
      if (ticket == 'GUARANTEE' || pos == 'COMP6' || pos == '6') return 'COMP6';
    }

    // Fallback if positional data varies
    if (pos == '1') return 'FIRST';
    if (pos == '2') return 'SECOND';
    if (pos == '3') return 'THIRD';
    if (pos == '4') return 'FOURTH';
    if (pos == '5') return 'FIFTH';
    if (pos == '6') return 'COMP6';

    return pos.isNotEmpty ? pos : ticket;
  }

  Future<void> fetchDealers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final url = Uri.parse('${AppConfig.baseUrl}/substockist/api/dealers/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          final List<Map<String, dynamic>> fetchedDealers = data.map<Map<String, dynamic>>((item) {
            final user = item['user'];
            return {
              'id': item['id'],
              'username': user != null ? user['username'].toString() : 'Unknown Dealer',
            };
          }).toList();

          _dealersList = [
            {'id': -1, 'username': 'Select Dealer'}
          ]..addAll(fetchedDealers);

          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load dealers (${response.statusCode})';
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

  Future<void> fetchAgentsForDealer(int dealerId) async {
    setState(() {
      _agentsList = [];
      _selectedAgentMap = null;
      _selectedAgent = null; 
    });

    if (dealerId == -1) return;

    final url = Uri.parse(
      '${AppConfig.baseUrl}/substockist/api/dealer-agents/?dealer_id=$dealerId',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          final List<Map<String, dynamic>> fetchedAgents = data.map<Map<String, dynamic>>((item) {
            final user = item['user'];
            return {
              'id': item['id'],
              'username': user != null ? user['username'].toString() : 'Unknown Agent',
            };
          }).toList();

          _agentsList = [
            {'id': -1, 'username': 'Select Agent'}
          ]..addAll(fetchedAgents);
        });
      }
    } catch (e) {
      // Fallback silent handler
    }
  }

  // Fetch Winning Report Metrics dynamically from backend API
  Future<void> _fetchWinningCountReport() async {
    setState(() => _isReportLoading = true);

    final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    // Build query parameters map cleanly
    final Map<String, String> queryParams = {
      'start_date': fromStr,
      'end_date': toStr,
    };

    if (_selectedTimeId != null) {
      queryParams['game_time_id'] = _selectedTimeId.toString();
    }

    if (_selectedDealer != null &&
        _selectedDealer != 'Select Dealer' &&
        _selectedDealer != 'ALL') {
      queryParams['selected_dealer'] = _selectedDealer!;
    }

    if (_selectedAgent != null &&
        _selectedAgent != 'Select Agent' &&
        _selectedAgent != 'ALL') {
      queryParams['selected_agent'] = _selectedAgent!;
    }

    final Uri url = Uri.parse('${AppConfig.baseUrl}/substockist/api/count-winning-report/').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);

        List<dynamic> rawList = [];
        if (decodedData is List) {
          rawList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('results')) {
          rawList = decodedData['results'];
        }

        // Aggregate counts & amounts grouped by mapped display label
        Map<String, Map<String, dynamic>> aggregatedMap = {};
        double totalSum = 0.0;

        for (var item in rawList) {
          String ticket = item['ticket']?.toString() ?? '';
          String position = item['position']?.toString() ?? '';

          String displayLabel = _getDisplayPosition(ticket, position);

          num countVal = item['total_count'] ?? 0;
          num amountVal = item['win_c_amount_agent'] ?? 0;

          if (!aggregatedMap.containsKey(displayLabel)) {
            aggregatedMap[displayLabel] = {
              'POSITION': displayLabel,
              'COUNT': 0.0,
              'AMOUNT': 0.0,
            };
          }

          aggregatedMap[displayLabel]!['COUNT'] += countVal.toDouble();
          aggregatedMap[displayLabel]!['AMOUNT'] += amountVal.toDouble();
          totalSum += amountVal.toDouble();
        }

        // Format aggregated values for Table display
        List<Map<String, dynamic>> formattedList = aggregatedMap.values.map((e) {
          double countDouble = e['COUNT'];
          String countStr = (countDouble % 1 == 0)
              ? countDouble.toInt().toString()
              : countDouble.toStringAsFixed(1);

          return {
            "POSITION": e['POSITION'],
            "COUNT": countStr,
            "AMOUNT": (e['AMOUNT'] as double).toStringAsFixed(0),
          };
        }).toList();

        setState(() {
          _reportData = formattedList;
          _grandTotalAmount = totalSum;
          _isReportLoading = false;
        });
      } else {
        setState(() => _isReportLoading = false);
        _showErrorSnackBar('Failed to retrieve server data.');
      }
    } catch (e) {
      setState(() => _isReportLoading = false);
      _showErrorSnackBar('Network connection problem.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Native Date Picker Dialog Builder
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedFromDate = DateFormat('dd/MM/yyyy').format(_fromDate);
    final String formattedToDate = DateFormat('dd/MM/yyyy').format(_toDate);
    final BorderSide verticalBorder = BorderSide(color: Colors.grey.shade400, width: 1);

    // Boolean flag logic to decide if layout space should accommodate the structural chain
    bool showAgentDropdown = _selectedDealerMap != null && _selectedDealerMap!['id'] != -1;

    return Scaffold(
      backgroundColor: Colors.white,

      // --- APPBAR LAYOUT ---
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubStockistHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Count Winning Report',
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
        ],
      ),

      // --- MAIN BODY CONTENT ---
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CALENDAR DATE RANGE ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDatePickerTarget(formattedFromDate, () => _selectDate(context, true), context),
                      _buildDatePickerTarget(formattedToDate, () => _selectDate(context, false), context),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. EQUAL SPACE DROPDOWNS ROW
                  Row(
                    children: [
                      // Time Dropdown
                      Expanded(
                        child: _isTimesLoading
                            ? const LinearProgressIndicator(minHeight: 2)
                            : DropdownButtonFormField<int?>(
                                value: _selectedTimeId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey, width: 0.6),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('ALL', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._fetchedTimesList.map((dynamic timeItem) {
                                    return DropdownMenuItem<int?>(
                                      value: timeItem['id'] as int,
                                      child: Text(timeItem['game_time']?.toString() ?? '', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                                    );
                                  }),
                                ],
                                onChanged: (value) => setState(() => _selectedTimeId = value),
                              ),
                      ),
                      const SizedBox(width: 16), // Padding between dropdown grids
                      
                      // Dealer Dropdown
                      Expanded(
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedDealerMap,
                          isExpanded: true,
                          hint: const Text(
                            'Select Dealer',
                            style: TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 0.8),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          items: _dealersList.map((Map<String, dynamic> dealer) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: dealer,
                              child: Text(
                                dealer['username'].toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDealerMap = value;
                              _selectedDealer = value?['username'];
                              // Reset agent sub-selection states cleanly
                              _selectedAgentMap = null;
                              _selectedAgent = null;
                            });
                            if (value != null) {
                              fetchAgentsForDealer(value['id']);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- DROPDOWN & MUTATION BUTTON ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: showAgentDropdown
                            ? DropdownButtonFormField<Map<String, dynamic>>(
                                value: _selectedAgentMap,
                                isExpanded: true,
                                hint: const Text(
                                  'Select Agent',
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey, width: 0.8),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                items: _agentsList.map((Map<String, dynamic> agent) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: agent,
                                    child: Text(
                                      agent['username'].toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAgentMap = value;
                                    _selectedAgent = value?['username'];
                                  });
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (!showAgentDropdown) const Spacer(), 
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isReportLoading ? null : _fetchWinningCountReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 2,
                        ),
                        child: _isReportLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // --- GRID SYSTEM HEADER ROW WITH VERTICAL DIVIDERS ---
                  Container(
                    color: Colors.grey[300],
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(border: Border(right: verticalBorder)),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            child: const Text(
                              'POSITION', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(border: Border(right: verticalBorder)),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            child: const Text(
                              'COUNT', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            child: const Text(
                              'AMOUNT', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- DATA ROWS MAPPER OR EMPTY STATE ---
                  _isReportLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _reportData.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32.0),
                              child: Center(
                                child: Text(
                                  'No winning records found.',
                                  style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reportData.length,
                              itemBuilder: (context, index) {
                                final item = _reportData[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Container(
                                          decoration: BoxDecoration(border: Border(right: verticalBorder)),
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                          child: Text(
                                            item["POSITION"]!, 
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          decoration: BoxDecoration(border: Border(right: verticalBorder)),
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                          child: Text(
                                            item["COUNT"]!, 
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                          child: Text(
                                            item["AMOUNT"]!, 
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),

          // --- BOTTOM FIXED STATISTICAL FOOTER BAR WITH DYNAMIC TOTAL ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade400, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _grandTotalAmount.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Underlined Date Selector UI Helper Widget
  Widget _buildDatePickerTarget(String text, VoidCallback onTap, BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.44,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text, 
              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Divider(color: Colors.grey, thickness: 0.6, height: 2),
          ],
        ),
      ),
    );
  }
}