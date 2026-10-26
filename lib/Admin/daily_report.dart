import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'dart:convert';

// Model for Table Rows
class DailyReportRowData {
  final String date;
  final String dealer;
  final String totalSale;
  final String totalWinAmount;
  final String balance;

  DailyReportRowData({
    required this.date,
    required this.dealer,
    required this.totalSale,
    required this.totalWinAmount,
    required this.balance,
  });

  factory DailyReportRowData.fromJson(Map<String, dynamic> json) {
    return DailyReportRowData(
      date: json['date'] ?? '',
      dealer: json['dealer'] ?? 'ME',
      totalSale: json['totalSale'] ?? '0.00',
      totalWinAmount: json['totalWinAmount'] ?? '0.00',
      balance: json['balance'] ?? '0.00',
    );
  }
}

class DailyReportPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const DailyReportPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  int? _selectedTimeId;
  List<dynamic> _fetchedTimesList = [];
  bool _isTimesLoading = true;

  String? _selectedStockist;
  List<Map<String, dynamic>> _stockistList = [
    {'id': -1, 'username': 'Select Stockist'},
  ];

  bool isLoading = true;
  String? errorMessage;

  bool _isReportLoading = false;
  List<DailyReportRowData> _reportItems = [];

  // Footer Totals
  String _totalSalesAmount = '0.00';
  String _totalWinAmount = '0.00';
  String _totalBalanceAmount = '0.00';

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
    fetchStockists();
    _fetchDailyReport();
  }

  Future<void> _fetchGameTimes() async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/game-times/');
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

  Map<String, dynamic>? _selectedStockistMap;

  Future<void> fetchStockists() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/stockists/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          final fetched = data.map<Map<String, dynamic>>((item) {
            final user = item['user'];
            return {
              'id': item['id'],
              'username': user != null
                  ? user['username'].toString()
                  : 'Unknown Stockist',
            };
          }).toList();
          _stockistList = [
            {'id': -1, 'username': 'Select Stockist'},
          ]..addAll(fetched);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDailyReport() async {
    setState(() => _isReportLoading = true);

    final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final Map<String, String> queryParams = {
      'from_date': fromStr,
      'to_date': toStr,
    };

    if (_selectedTimeId != null) {
      queryParams['game_time_id'] = _selectedTimeId.toString();
    }

    // Pass selected dealer parameter instead of selected agent
    if (_selectedStockist != null &&
        _selectedStockist != 'Select Stockist' &&
        _selectedStockist != 'ALL') {
      queryParams['selected_stockist'] = _selectedStockist!;
    }

    final Uri url = Uri.parse(
      '${AppConfig.baseUrl}/adminapp/api/daily-report/',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> itemsList = data['report_items'] ?? [];

        setState(() {
          _reportItems = itemsList
              .map((item) => DailyReportRowData.fromJson(item))
              .toList();
          _totalSalesAmount = data['overall_sales'] ?? '0.00';
          _totalWinAmount = data['overall_wins'] ?? '0.00';
          _totalBalanceAmount = data['overall_balance'] ?? '0.00';
          _isReportLoading = false;
        });
      } else {
        setState(() => _isReportLoading = false);
        _showSnackBar('Failed to fetch daily report.');
      }
    } catch (e) {
      setState(() => _isReportLoading = false);
      _showSnackBar('Connection error.');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                builder: (context) => AdminHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Daily Report',
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
                MaterialPageRoute(builder: (context) => SelectTimePage()),
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. FROM & TO DATE SELECTION ---
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
                              Text(
                                formattedFromDate,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                color: Colors.grey,
                                thickness: 0.8,
                                height: 1,
                              ),
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
                              Text(
                                formattedToDate,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                color: Colors.grey,
                                thickness: 0.8,
                                height: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 2. SELECT DEALER ---
                  Row(
                    children: [
                      // Dealer Dropdown
                      Expanded(
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedStockistMap,
                          isExpanded: true,
                          hint: const Text(
                            'Select Stockist',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 0.8,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items: _stockistList.map((
                            Map<String, dynamic> stockist,
                          ) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: stockist,
                              child: Text(
                                stockist['username'].toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStockistMap = value;
                              // Extract the ID or username from the selected Map
                              if (value != null && value['id'] != -1) {
                                _selectedStockist = value['id']
                                    .toString(); // or value['username']
                              } else {
                                _selectedStockist =
                                    null; // Reset if 'Select Dealer' is picked
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 3. TIME DROPDOWN AND SEARCH BUTTON ROW ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _isTimesLoading
                            ? const LinearProgressIndicator(minHeight: 2)
                            : DropdownButtonFormField<int?>(
                                value: _selectedTimeId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 0.6,
                                    ),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      'ALL',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ..._fetchedTimesList.map((dynamic timeItem) {
                                    return DropdownMenuItem<int?>(
                                      value: timeItem['id'] as int,
                                      child: Text(
                                        timeItem['game_time']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedTimeId = value),
                              ),
                      ),
                      const SizedBox(width: 40),
                      ElevatedButton(
                        onPressed: _fetchDailyReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 1,
                        ),
                        child: const Text(
                          'SEARCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // --- DATA TABLE SECTION ---
                  _isReportLoading
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2), // DATE
                              1: FlexColumnWidth(1.0), // DEALER
                              2: FlexColumnWidth(1.4), // T.SALE
                              3: FlexColumnWidth(1.5), // T.W AMNT
                              4: FlexColumnWidth(1.6), // BALANCE
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.grey.shade300,
                                width: 0.8,
                              ),
                              verticalInside: BorderSide(
                                color: Colors.grey.shade300,
                                width: 0.8,
                              ),
                            ),
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              // Header Row
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0E0E0),
                                ),
                                children: const [
                                  _TableCellText(
                                    'DATE',
                                    isHeader: true,
                                    align: TextAlign.left,
                                  ),
                                  _TableCellText(
                                    'DEALER',
                                    isHeader: true,
                                    align: TextAlign.left,
                                  ),
                                  _TableCellText(
                                    'T.SALE',
                                    isHeader: true,
                                    align: TextAlign.left,
                                  ),
                                  _TableCellText(
                                    'T.W AMNT',
                                    isHeader: true,
                                    align: TextAlign.left,
                                  ),
                                  _TableCellText(
                                    'BALANCE',
                                    isHeader: true,
                                    align: TextAlign.left,
                                  ),
                                ],
                              ),

                              // Data Rows
                              if (_reportItems.isEmpty)
                                TableRow(
                                  children: [
                                    const SizedBox.shrink(),
                                    const SizedBox.shrink(),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        'No data available',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox.shrink(),
                                    const SizedBox.shrink(),
                                  ],
                                )
                              else
                                ..._reportItems.map((item) {
                                  return TableRow(
                                    children: [
                                      _TableCellText(
                                        item.date,
                                        align: TextAlign.left,
                                      ),
                                      _TableCellText(
                                        item.dealer,
                                        align: TextAlign.left,
                                      ),
                                      _TableCellText(
                                        item.totalSale,
                                        align: TextAlign.left,
                                      ),
                                      _TableCellText(
                                        item.totalWinAmount,
                                        align: TextAlign.left,
                                      ),
                                      _TableCellText(
                                        item.balance,
                                        align: TextAlign.left,
                                      ),
                                    ],
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),

          // --- BOTTOM FIXED FOOTER ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SALES AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _totalSalesAmount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'WIN AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _totalWinAmount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'BALANCE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _totalBalanceAmount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widget for Cell Formatting
class _TableCellText extends StatelessWidget {
  final String text;
  final bool isHeader;
  final TextAlign align;

  const _TableCellText(
    this.text, {
    Key? key,
    this.isHeader = false,
    this.align = TextAlign.left,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
}
