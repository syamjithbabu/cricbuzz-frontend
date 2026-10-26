import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Dealer/home.dart';
import 'package:cricbuzz/Dealer/select_time.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'dart:convert';

class CountSalesReportPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const CountSalesReportPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<CountSalesReportPage> createState() => _CountSalesReportPageState();
}

class _CountSalesReportPageState extends State<CountSalesReportPage> {
  int? _selectedTimeId;
  List<dynamic> _fetchedTimesList = [];
  bool _isTimesLoading = true;
  bool _isReportLoading = false;
  String? _selectedAgent;
  List<String> _agentsList = [];

  bool isLoading = true;
  String? errorMessage;

  // Real-time parsed metrics state holders
  int _singleCount = 0;
  double _singleAmount = 0.0;
  int _doubleCount = 0;
  double _doubleAmount = 0.0;
  int _trippleCount = 0;
  double _trippleAmount = 0.0;
  double _grandTotalAmount = 0.0;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  @override
  void initState() {
    super.initState();
    _selectedTimeId = widget.gameTimeId <= 0 ? null : widget.gameTimeId;
    _fetchGameTimes();
    fetchAgents();
    _fetchCountReport(); 
  }

  Future<void> _fetchGameTimes() async {
    final url = Uri.parse('${AppConfig.baseUrl}/dealer/api/game-times/');
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
          final fetchedAgents = data.map<String>((item) {
            final user = item['user'];
            return user != null ? user['username'].toString() : 'Unknown Agent';
          }).toList();

          _agentsList = ['Select Agent', 'Myself', ...fetchedAgents];
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

  Future<void> _fetchCountReport() async {
    setState(() => _isReportLoading = true);

    final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toStr = DateFormat('yyyy-MM-dd').format(_toDate);
    
    final Uri url = Uri.parse('${AppConfig.baseUrl}/dealer/api/count-sales-report/').replace(
      queryParameters: {
        'start_date': fromStr,
        'end_date': toStr,
        'game_time_id': _selectedTimeId != null ? _selectedTimeId.toString() : 'null',
        if (_selectedAgent != null && _selectedAgent != 'Select Agent') 'agent': _selectedAgent!,
      },
    );

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _singleCount = data['single']['count'] ?? 0;
          _singleAmount = (data['single']['amount'] as num?)?.toDouble() ?? 0.0;
          _doubleCount = data['double']['count'] ?? 0;
          _doubleAmount = (data['double']['amount'] as num?)?.toDouble() ?? 0.0;
          _trippleCount = data['tripple']['count'] ?? 0;
          _trippleAmount = (data['tripple']['amount'] as num?)?.toDouble() ?? 0.0;
          _grandTotalAmount = (data['grand_total_amount'] as num?)?.toDouble() ?? 0.0;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
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
          'Count Sales Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SelectTimePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FROM DATE AND TO DATE PICKERS ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.42,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formattedFromDate, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                              const SizedBox(height: 4),
                              const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.42,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formattedToDate, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                              const SizedBox(height: 4),
                              const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                            ],
                          ),
                        ),
                      ),
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
                      // Agent Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAgent,
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
                          items: _agentsList.map((String agent) {
                            return DropdownMenuItem<String>(
                              value: agent,
                              child: Text(agent, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedAgent = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. NEW DEDICATED ROW FOR THE OK BUTTON (RIGHT ALIGNED)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _isReportLoading ? null : _fetchCountReport,
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
                  const SizedBox(height: 24),

                  // 4. TABULAR DATA GRID
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(1.0),
                      2: FlexColumnWidth(1.2),
                    },
                    border: TableBorder(
                      verticalInside: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1.0),
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1.0),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[200]),
                        children: [
                          _buildHeaderCell('POSITION', alignment: Alignment.centerLeft),
                          _buildHeaderCell('COUNT', alignment: Alignment.centerLeft),
                          _buildHeaderCell('AMOUNT', alignment: Alignment.centerLeft),
                        ],
                      ),
                      TableRow(
                        children: [
                          _buildDataCell('SINGLE'),
                          _buildDataCell('$_singleCount'),
                          _buildDataCell('${_singleAmount.toStringAsFixed(1).replaceFirst('.0', '')}'),
                        ],
                      ),
                      TableRow(
                        children: [
                          _buildDataCell('DOUBLE'),
                          _buildDataCell('$_doubleCount'),
                          _buildDataCell('${_doubleAmount.toStringAsFixed(1).replaceFirst('.0', '')}'),
                        ],
                      ),
                      TableRow(
                        children: [
                          _buildDataCell('TRIPPLE'),
                          _buildDataCell('$_trippleCount'),
                          _buildDataCell('${_trippleAmount.toStringAsFixed(1).replaceFirst('.0', '')}'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM FIXED TOTAL FOOTER BAR ZONE ---
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: 0.5, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _grandTotalAmount.toStringAsFixed(2).replaceFirst('.00', ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required Alignment alignment}) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _buildDataCell(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black)),
    );
  }
}