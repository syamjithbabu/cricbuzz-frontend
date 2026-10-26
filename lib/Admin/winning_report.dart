import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';

// --- DATA MODEL FOR WINNING REPORT ITEM ---
class WinningReportItem {
  final int id;
  final String b; // Combined Bill ID + Customer Name
  final String billId;
  final String u; // User / Agent
  final String t; // Ticket type
  final String pn; // Number
  final String c; // Count
  final String pp; // PP
  final String su; // SU
  final String rs; // RS
  final String customerName;

  WinningReportItem({
    required this.id,
    required this.b,
    required this.billId,
    required this.u,
    required this.t,
    required this.pn,
    required this.c,
    required this.pp,
    required this.su,
    required this.rs,
    required this.customerName,
  });

  factory WinningReportItem.fromJson(Map<String, dynamic> json) {
    return WinningReportItem(
      id: json['id'] ?? 0,
      b: json['bill'] ?? '',
      billId: json['bill_id'] ?? '',
      u: json['user'] ?? '',
      t: json['ticket'] ?? '',
      pn: json['number'] ?? '',
      c: (json['count'] ?? 0).toString(),
      pp: (json['pp'] ?? 0).toString(),
      su: (json['su'] ?? 0).toString(),
      rs: (json['rs'] ?? 0).toString(),
      customerName: json['customer_name'] ?? '',
    );
  }
}

class WinningReportPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const WinningReportPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<WinningReportPage> createState() => _WinningReportPageState();
}

class _WinningReportPageState extends State<WinningReportPage> {
  // --- STATE MANAGEMENT VARIABLES ---
  String _selectedViewType = 'Detailed';
  String _selectedGameType = 'ALL';
  String _selectedDisplayMode = 'List View';

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final List<String> _viewTypes = ['Summary', 'Detailed'];
  final List<String> _gameTypes = [
    'ALL',
    'FIRST',
    'SECOND',
    'THIRD',
    'FOURTH',
    'FIFTH',
    'COMP6',
    'BOX',
    'AB/BC/AC ALL',
    'AB',
    'BC',
    'AC',
    'BOARD ALL',
    'A',
    'B',
    'C',
  ];
  final List<String> _displayModes = ['List View', 'Grid View'];

  // Data & Infinite Scroll State
  final ScrollController _scrollController = ScrollController();
  List<WinningReportItem> _reportData = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _errorMessage;

  String? _selectedStockist;
  String? _selectedSubStockist;
  String? _selectedDealer;
  String? _selectedAgent;

  // Data lists populated with clean initial placeholders
  List<Map<String, dynamic>> _stockistList = [
    {'id': -1, 'username': 'Select Stockist'},
  ];
  List<Map<String, dynamic>> _substockistList = [];
  List<Map<String, dynamic>> _dealersList = [];
  List<Map<String, dynamic>> _agentsList = [];

  bool isLoading = true;
  String? errorMessage;

  // Footer Totals
  int _summaryCount = 0;
  int _summaryTotal = 0;
  int _summaryNet = 0;
  int _summaryComm = 0;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  @override
  void initState() {
    super.initState();
    fetchStockists();
    fetchWinningReport(isRefresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && !_isLoadingMore && _hasMore) {
          fetchWinningReport(isRefresh: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Dropdown UI Active Selection Maps
  Map<String, dynamic>? _selectedStockistMap;
  Map<String, dynamic>? _selectedSubStockistMap;
  Map<String, dynamic>? _selectedDealerMap;
  Map<String, dynamic>? _selectedAgentMap;

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

  Future<void> fetchSubStockistsForStockist(int stockistId) async {
    setState(() {
      _substockistList = [];
      _dealersList = [];
      _agentsList = [];
      _selectedSubStockistMap = null;
      _selectedDealerMap = null;
      _selectedAgentMap = null;
      _selectedSubStockist = null;
      _selectedDealer = null;
      _selectedAgent = null;
    });

    if (stockistId == -1) return;

    final url = Uri.parse(
      '${AppConfig.baseUrl}/adminapp/api/stockist-substockists/?stockist_id=$stockistId',
    );
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
                  : 'Unknown Subst',
            };
          }).toList();
          _substockistList = [
            {'id': -1, 'username': 'Select Subst'},
          ]..addAll(fetched);
        });
      }
    } catch (_) {}
  }

  Future<void> fetchDealersForSubStockist(int substockistId) async {
    setState(() {
      _dealersList = [];
      _agentsList = [];
      _selectedDealerMap = null;
      _selectedAgentMap = null;
      _selectedDealer = null;
      _selectedAgent = null;
    });

    if (substockistId == -1) return;

    final url = Uri.parse(
      '${AppConfig.baseUrl}/adminapp/api/substockist-dealers/?substockist_id=$substockistId',
    );
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
                  : 'Unknown Dealer',
            };
          }).toList();
          _dealersList = [
            {'id': -1, 'username': 'Select Dealer'},
          ]..addAll(fetched);
        });
      }
    } catch (_) {}
  }

  Future<void> fetchAgentsForDealer(int dealerId) async {
    setState(() {
      _agentsList = [];
      _selectedAgentMap = null;
      _selectedAgent = null;
    });

    if (dealerId == -1) return;

    final url = Uri.parse(
      '${AppConfig.baseUrl}/adminapp/api/dealer-agents/?dealer_id=$dealerId',
    );
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
                  : 'Unknown Agent',
            };
          }).toList();
          _agentsList = [
            {'id': -1, 'username': 'Select Agent'},
          ]..addAll(fetched);
        });
      }
    } catch (_) {}
  }

  Future<void> fetchWinningReport({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _reportData.clear();
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final String fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);

    // Construct URL with Uri class to handle query parameters cleanly
    Map<String, String> queryParams = {
      'from_date': fromDateStr,
      'to_date': toDateStr,
      'game_type': _selectedGameType,
      'view_type': _selectedViewType,
      'game_time_id': widget.gameTimeId.toString(),
      'offset': _offset.toString(),
      'limit': _limit.toString(),
    };

    if (_selectedStockist != null &&
        _selectedStockist != 'Select Stockist') {
      queryParams['selected_stockist'] =
          _selectedStockist!; // <--- Look here
    }

    if (_selectedSubStockist != null &&
        _selectedSubStockist != 'Select SubStockist') {
      queryParams['selected_substockist'] =
          _selectedSubStockist!; // <--- Look here
    }

    if (_selectedDealer != null && _selectedDealer != 'Select Dealer') {
      queryParams['selected_dealer'] = _selectedDealer!;
    }

    if (_selectedAgent != null && _selectedAgent != 'Select Agent') {
      queryParams['selected_agent'] = _selectedAgent!;
    }

    final Uri uri = Uri.parse(
      '${AppConfig.baseUrl}/adminapp/api/winning-report/',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final Map<String, dynamic> summary = data['summary'] ?? {};

        final List<WinningReportItem> fetchedList = results
            .map((json) => WinningReportItem.fromJson(json))
            .toList();

        setState(() {
          _reportData.addAll(fetchedList);
          _hasMore = data['has_more'] ?? false;
          _offset += fetchedList.length;

          _summaryCount = summary['count'] ?? 0;
          _summaryTotal = summary['total'] ?? 0;
          _summaryNet = summary['net'] ?? 0;
          _summaryComm = summary['comm'] ?? 0;

          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load report (Error ${response.statusCode})';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error occurred. Please check your connection.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
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
          'Winning Report',
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
                MaterialPageRoute(builder: (context) => const SelectTimePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),

      // --- MAIN BODY ---
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- ROW 1: VIEW TYPE & SELECT STOCKIST DROPDOWNS ---
                        Row(
                          children: [
                            // View Type Dropdown
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _selectedViewType,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 0.6,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 0.6,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey,
                                ),
                                items: _viewTypes.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null &&
                                      newValue != _selectedViewType) {
                                    setState(
                                      () => _selectedViewType = newValue,
                                    );
                                  }
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Stockist Dropdown
                            Expanded(
                              flex: 2,
                              child:
                                  DropdownButtonFormField<Map<String, dynamic>>(
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
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
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
                                      Map<String, dynamic> st,
                                    ) {
                                      return DropdownMenuItem<
                                        Map<String, dynamic>
                                      >(
                                        value: st,
                                        child: Text(
                                          st['username'].toString(),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStockistMap = value;
                                        _selectedStockist =
                                            (value != null && value['id'] != -1)
                                            ? value['username'].toString()
                                            : null;
                                        // Reset downstream selection tree
                                        _selectedSubStockistMap = null;
                                        _selectedSubStockist = null;
                                        _selectedDealerMap = null;
                                        _selectedDealer = null;
                                        _selectedAgentMap = null;
                                        _selectedAgent = null;
                                        _substockistList = [];
                                        _dealersList = [];
                                        _agentsList = [];
                                      });
                                      if (value != null && value['id'] != -1) {
                                        fetchSubStockistsForStockist(
                                          value['id'],
                                        );
                                      }
                                    },
                                  ),
                            ),
                          ],
                        ),

                        // --- ROW 2: SELECT SUBSTOCKIST, DEALER & AGENT DROPDOWNS ---
                        if (_selectedStockistMap != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // SubStockist Dropdown
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                      Map<String, dynamic>
                                    >(
                                      value: _selectedSubStockistMap,
                                      isExpanded: true,
                                      hint: const Text(
                                        'Select Subst',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
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
                                      items: _substockistList.map((
                                        Map<String, dynamic> subst,
                                      ) {
                                        return DropdownMenuItem<
                                          Map<String, dynamic>
                                        >(
                                          value: subst,
                                          child: Text(
                                            subst['username'].toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedSubStockistMap = value;
                                          _selectedSubStockist =
                                              (value != null &&
                                                  value['id'] != -1)
                                              ? value['username']
                                              : null;
                                          // Reset downstream selections
                                          _selectedDealerMap = null;
                                          _selectedDealer = null;
                                          _selectedAgentMap = null;
                                          _selectedAgent = null;
                                          _dealersList = [];
                                          _agentsList = [];
                                        });
                                        if (value != null &&
                                            value['id'] != -1) {
                                          fetchDealersForSubStockist(
                                            value['id'],
                                          );
                                        }
                                      },
                                    ),
                              ),

                              // Dealer Dropdown (Rendered when SubStockist is active)
                              if (_selectedSubStockistMap != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                        Map<String, dynamic>
                                      >(
                                        value: _selectedDealerMap,
                                        isExpanded: true,
                                        hint: const Text(
                                          'Select Dealer',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
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
                                        items: _dealersList.map((
                                          Map<String, dynamic> dealer,
                                        ) {
                                          return DropdownMenuItem<
                                            Map<String, dynamic>
                                          >(
                                            value: dealer,
                                            child: Text(
                                              dealer['username'].toString(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedDealerMap = value;
                                            _selectedDealer =
                                                value?['username'];
                                            _selectedAgentMap = null;
                                            _selectedAgent = null;
                                            _agentsList = [];
                                          });
                                          if (value != null) {
                                            fetchAgentsForDealer(value['id']);
                                          }
                                        },
                                      ),
                                ),
                              ],

                              // Agent Dropdown (Rendered when Dealer is active)
                              if (_selectedDealerMap != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                        Map<String, dynamic>
                                      >(
                                        value: _selectedAgentMap,
                                        isExpanded: true,
                                        hint: const Text(
                                          'Select Agent',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
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
                                        items: _agentsList.map((
                                          Map<String, dynamic> agent,
                                        ) {
                                          return DropdownMenuItem<
                                            Map<String, dynamic>
                                          >(
                                            value: agent,
                                            child: Text(
                                              agent['username'].toString(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedAgentMap = value;
                                            _selectedAgent = value?['username'];
                                          });
                                        },
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // --- DATE RANGE SELECTION ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDatePickerTarget(
                              formattedFromDate,
                              () => _selectDate(context, true),
                              context,
                            ),
                            _buildDatePickerTarget(
                              formattedToDate,
                              () => _selectDate(context, false),
                              context,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // --- GAME TYPE, DISPLAY MODE & SEARCH BUTTON ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildInlineDropdown(
                              _selectedGameType,
                              _gameTypes,
                              (val) {
                                setState(() => _selectedGameType = val!);
                              },
                              context,
                              widthFactor: 0.35,
                            ),
                            _buildInlineDropdown(
                              _selectedDisplayMode,
                              _displayModes,
                              (val) {
                                setState(() => _selectedDisplayMode = val!);
                              },
                              context,
                              widthFactor: 0.30,
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  fetchWinningReport(isRefresh: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.themeColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
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
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Content Body State Handling
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (_reportData.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No winning records found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    _selectedDisplayMode == 'List View'
                        ? _buildListViewTable()
                        : _buildGridViewCards(),

                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),

          // --- FOOTER STATS BAR ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFooterMetric('COUNT', '$_summaryCount'),
                  _buildFooterMetric('TOTAL', '$_summaryTotal'),
                  _buildFooterMetric('NET', '$_summaryNet'),
                  _buildFooterMetric('COMM', '$_summaryComm'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. LIST VIEW TABLE
  // =========================================================================
  Widget _buildListViewTable() {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(), // Column 'B' fits strictly to text length
        1: FlexColumnWidth(1.2), // U
        2: FlexColumnWidth(0.9), // T
        3: FlexColumnWidth(0.6), // PN
        4: FlexColumnWidth(0.3), // C
        5: FlexColumnWidth(0.3), // PP
        6: FlexColumnWidth(0.9), // SU
        7: FlexColumnWidth(1.0), // RS
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300, width: 0.8),
        verticalInside: BorderSide(color: Colors.grey.shade300, width: 1.0),
        bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // --- TABLE HEADER ROW ---
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[300]),
          children: const [
            _TableCellText('B', isHeader: true),
            _TableCellText('U', isHeader: true),
            _TableCellText('T', isHeader: true),
            _TableCellText('PN', isHeader: true),
            _TableCellText('C', isHeader: true),
            _TableCellText('P', isHeader: true),
            _TableCellText('SU', isHeader: true),
            _TableCellText('RS', isHeader: true),
          ],
        ),

        // --- DATA ROWS ---
        ..._reportData.map((item) {
          final String billText = item.billId.isNotEmpty
              ? item.billId
              : item.b.split('\n').first;
          final String customer = item.customerName;

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 3.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      billText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    // Render Customer Name at 13px font size matching all other table cells
                    if (customer.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer,
                        style: const TextStyle(
                          fontSize: 13, // Same size as user/bill text
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _TableCellText(item.u),
              _TableCellText(item.t),
              _TableCellText(item.pn),
              _TableCellText(item.c),
              _TableCellText(item.pp),
              _TableCellText(item.su),
              _TableCellText(item.rs),
            ],
          );
        }).toList(),
      ],
    );
  }

  // ==========================================
  // 2. DYNAMIC GRID VIEW CARD LAYOUT
  // ==========================================
  Widget _buildGridViewCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: List.generate(_reportData.length, (index) {
          final item = _reportData[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: widget.themeColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${item.t} PRIZE",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "NUMBER : ${item.pn}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Details Body
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "COUNT : ${item.c}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "TOTAL : ${item.rs}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "BILL ID: ${item.billId}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "COMM : ${item.su}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "AGENT : ${item.u}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "NET     : ${item.pp}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.grey),

                // Footer (Customer)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 10.0,
                  ),
                  child: Text(
                    "CUSTOMER: ${item.customerName}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- HELPER BUILDERS ---
  Widget _buildDatePickerTarget(
    String text,
    VoidCallback onTap,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.44,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            const Divider(color: Colors.grey, thickness: 0.6, height: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDropdown(
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
    BuildContext context, {
    required double widthFactor,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * widthFactor,
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.6),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.6),
          ),
        ),
        icon: const SizedBox.shrink(),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFooterMetric(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// --- HELPER CLASS FOR BOLD TABLE CELL TEXT ---
class _TableCellText extends StatelessWidget {
  final String text;
  final bool isHeader;

  const _TableCellText(this.text, {this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 3.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isHeader ? Colors.black87 : Colors.black,
        ),
      ),
    );
  }
}
