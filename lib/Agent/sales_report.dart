import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Agent/home.dart';
import 'package:cricbuzz/Agent/select_time.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// 1. Data Models to hold table row structure with fromJson parsers
class SubRowData {
  final String date;
  final String number;
  final String bill;
  final int count;
  final double dAmt;
  final double cAmt;

  const SubRowData({
    required this.date,
    required this.number,
    required this.bill,
    required this.count,
    required this.dAmt,
    required this.cAmt,
  });

  factory SubRowData.fromJson(Map<String, dynamic> json) {
    return SubRowData(
      date: json['date'] ?? '#',
      number: json['number'] ?? '',
      bill: json['bill'] ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      dAmt: (json['d_amt'] as num?)?.toDouble() ?? 0.0,
      cAmt: (json['c_amt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MainRowData {
  final String date;
  final String dealer;
  final String bill;
  final double count;
  final double dAmt;
  final double cAmt;
  final List<SubRowData> subRows;
  bool isLocallyExpanded; // Added local state tracking variable

  MainRowData({
    required this.date,
    required this.dealer,
    required this.bill,
    required this.count,
    required this.dAmt,
    required this.cAmt,
    required this.subRows,
    this.isLocallyExpanded = false, // Defaults to closed
  });

  factory MainRowData.fromJson(Map<String, dynamic> json) {
    final list = json['sub_rows'] as List? ?? [];
    final subRowsList = list.map((item) => SubRowData.fromJson(item)).toList();

    return MainRowData(
      date: json['date'] ?? '',
      dealer: json['dealer'] ?? '',
      bill: json['bill'] ?? '',
      count: (json['count'] as num?)?.toDouble() ?? 0.0,
      dAmt: (json['d_amt'] as num?)?.toDouble() ?? 0.0,
      cAmt: (json['c_amt'] as num?)?.toDouble() ?? 0.0,
      subRows: subRowsList,
    );
  }
}

class SalesReportPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const SalesReportPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  // Total elements count including opened sub-rows
  int get _flattenedItemCount {
    int count = 0;
    for (var mainRow in _reportData) {
      count++; // For the main parent row header
      if (mainRow.isLocallyExpanded) {
        count += mainRow.subRows.length; // Count sub-rows if open
      }
    }
    return count + (_hasMore ? 1 : 0);
  }

  // Resolves the absolute flat index to discover if it's a parent or child row
  dynamic _getItemAtFlatIndex(int targetIndex) {
    int currentFlatIndex = 0;

    for (var mainRow in _reportData) {
      if (currentFlatIndex == targetIndex) {
        return _FlatRowWrapper(
          isParent: true,
          parentRow: mainRow,
          indexInParent: -1,
        );
      }
      currentFlatIndex++;

      if (mainRow.isLocallyExpanded) {
        final int subRowsLen = mainRow.subRows.length;
        if (targetIndex < currentFlatIndex + subRowsLen) {
          final int localSubIndex = targetIndex - currentFlatIndex;
          return _FlatRowWrapper(
            isParent: false,
            subRow: mainRow.subRows[localSubIndex],
            indexInParent: localSubIndex,
          );
        }
        currentFlatIndex += subRowsLen;
      }
    }
    return null; // Represents the loading indicator at the bottom edge
  }

  String _selectedRadio = 'ALL';
  bool _isExpandedAll = false; // Master global controller toggle

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final TextEditingController _numberController = TextEditingController();

  bool _opt1A = false;
  bool _opt1B = false;
  bool _opt1C = false;
  bool _opt2AB = false;
  bool _opt2BC = false;
  bool _opt2AC = false;
  bool _opt3Super = false;
  bool _opt3Box = false;

  final ScrollController _scrollController = ScrollController();
  List<MainRowData> _reportData = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _errorMessage;

  // Global Grand Total Tracking Parameters
  double _grandTotalCount = 0.0;
  double _grandTotalDAmount = 0.0;
  double _grandTotalCAmount = 0.0;

  final List<int> _colFlexes = [3, 2, 2, 2, 2, 2];

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  @override
  void initState() {
    super.initState();
    fetchAgentBillReport(isRefresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && !_isLoadingMore && _hasMore) {
          fetchAgentBillReport(isRefresh: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> fetchAgentBillReport({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _reportData.clear();
        _errorMessage = null;
        // Clear numbers between lookups
        _grandTotalCount = 0.0;
        _grandTotalDAmount = 0.0;
        _grandTotalCAmount = 0.0;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final String fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);

    List<String> selectedOptions = [];
    if (_selectedRadio == '1') {
      if (_opt1A) selectedOptions.add('A');
      if (_opt1B) selectedOptions.add('B');
      if (_opt1C) selectedOptions.add('C');
    } else if (_selectedRadio == '2') {
      if (_opt2AB) selectedOptions.add('AB');
      if (_opt2BC) selectedOptions.add('BC');
      if (_opt2AC) selectedOptions.add('AC');
    } else if (_selectedRadio == '3') {
      if (_opt3Super) selectedOptions.add('SUPER');
      if (_opt3Box) selectedOptions.add('BOX');
    }

    final Map<String, String> queryParameters = {
      'start_date': fromDateStr,
      'end_date': toDateStr,
      'game_time_id': widget.gameTimeId.toString(),
      'ticket_type': _selectedRadio,
      'limit': _limit.toString(),
      'offset': _offset.toString(),
    };

    if (_numberController.text.trim().isNotEmpty) {
      queryParameters['number'] = _numberController.text.trim();
    }

    String baseUrlString = '${AppConfig.baseUrl}/agent/api/sales-report/';
    Uri url = Uri.parse(
      baseUrlString,
    ).replace(queryParameters: queryParameters);

    if (selectedOptions.isNotEmpty) {
      final List<String> querySegments = [];
      url.queryParameters.forEach((key, value) {
        querySegments.add('$key=${Uri.encodeQueryComponent(value)}');
      });
      for (var option in selectedOptions) {
        querySegments.add('options=${Uri.encodeQueryComponent(option)}');
      }
      url = url.replace(query: querySegments.join('&'));
    }

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> paginatedJson = json.decode(response.body);
        final List<dynamic> results = paginatedJson['results'] ?? [];

        final List<MainRowData> fetchedRows = results
            .map((jsonItem) => MainRowData.fromJson(jsonItem))
            .toList();

        // Dynamically extract the newly filtered grand sums from payload root level
        final Map<String, dynamic> grandTotals =
            paginatedJson['grand_totals'] ?? {};

        setState(() {
          for (var row in fetchedRows) {
            row.isLocallyExpanded = _isExpandedAll;
          }
          _reportData.addAll(fetchedRows);
          _offset += fetchedRows.length;

          // Binds the global data properties instantly to the persistent visual footer metrics
          _grandTotalCount =
              (grandTotals['total_count'] as num?)?.toDouble() ?? 0.0;
          _grandTotalDAmount =
              (grandTotals['total_d_amount'] as num?)?.toDouble() ?? 0.0;
          _grandTotalCAmount =
              (grandTotals['total_c_amount'] as num?)?.toDouble() ?? 0.0;

          if (paginatedJson['next'] == null || fetchedRows.length < _limit) {
            _hasMore = false;
          }

          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load report data (${response.statusCode})';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred fetching the report. Check connection.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _downloadStreamingFile() async {
    // Direct, low-overhead UI initialization feedback loader
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading full PDF instantly...'),
        duration: Duration(milliseconds: 400),
      ),
    );

    final String fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final Map<String, String> queryParameters = {
      'start_date': fromDateStr,
      'end_date': toDateStr,
      'game_time_id': widget.gameTimeId.toString(),
      'ticket_type': _selectedRadio,
    };

    if (_numberController.text.trim().isNotEmpty) {
      queryParameters['number'] = _numberController.text.trim();
    }

    String urlString = '${AppConfig.baseUrl}/agent/api/sales-report-download/';
    Uri url = Uri.parse(urlString).replace(queryParameters: queryParameters);

    try {
      // AUTOMATIC STORAGE ROUTING: Detects public device storage targets safely
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final String path =
          "${downloadsDir!.path}/SalesReport_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final File outputFile = File(path);
      final IOSink fileSink = outputFile.openWrite();

      // 1. Establish pipeline connection
      final http.Request request = http.Request('GET', url);
      request.headers.addAll(_headers);

      final http.StreamedResponse response = await http.Client().send(request);

      if (response.statusCode == 200) {
        // 2. Stream byte arrays block-by-block directly onto the storage disk
        await response.stream.listen((List<int> chunk) {
          fileSink.add(chunk);
        }).asFuture();

        await fileSink.flush();
        await fileSink.close();

        if (!mounted) return;

        // --- NEW: CLEAN DOCK MODAL DIALOG POPUP ---
        showDialog(
          context: context,
          barrierDismissible:
              false, // Force intentional close interaction action
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'Success',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PDF Downloaded successfully.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved as: ${outputFile.path.split('/').last}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss modal cleanly
                    OpenFilex.open(path); // Fire file viewing intents
                  },
                  child: const Text(
                    'OPEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        await fileSink.close();
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetCheckboxesAndInput() {
    _numberController.clear();
    setState(() {
      _opt1A = false;
      _opt1B = false;
      _opt1C = false;
      _opt2AB = false;
      _opt2BC = false;
      _opt2AC = false;
      _opt3Super = false;
      _opt3Box = false;
    });
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

  Widget _buildCheckboxItem(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          activeColor: widget.themeColor,
          visualDensity: const VisualDensity(
            horizontal: VisualDensity.minimumDensity,
            vertical: VisualDensity.minimumDensity,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildConditionalCheckboxes() {
    if (_selectedRadio == 'ALL') return const SizedBox.shrink();

    List<Widget> checkboxWidgets = [];

    if (_selectedRadio == '1') {
      checkboxWidgets = [
        _buildCheckboxItem(
          'A',
          _opt1A,
          (val) => setState(() => _opt1A = val ?? false),
        ),
        const SizedBox(width: 16),
        _buildCheckboxItem(
          'B',
          _opt1B,
          (val) => setState(() => _opt1B = val ?? false),
        ),
        const SizedBox(width: 16),
        _buildCheckboxItem(
          'C',
          _opt1C,
          (val) => setState(() => _opt1C = val ?? false),
        ),
      ];
    } else if (_selectedRadio == '2') {
      checkboxWidgets = [
        _buildCheckboxItem(
          'AB',
          _opt2AB,
          (val) => setState(() => _opt2AB = val ?? false),
        ),
        const SizedBox(width: 16),
        _buildCheckboxItem(
          'BC',
          _opt2BC,
          (val) => setState(() => _opt2BC = val ?? false),
        ),
        const SizedBox(width: 16),
        _buildCheckboxItem(
          'AC',
          _opt2AC,
          (val) => setState(() => _opt2AC = val ?? false),
        ),
      ];
    } else if (_selectedRadio == '3') {
      checkboxWidgets = [
        _buildCheckboxItem(
          'SUPER',
          _opt3Super,
          (val) => setState(() => _opt3Super = val ?? false),
        ),
        const SizedBox(width: 16),
        _buildCheckboxItem(
          'BOX',
          _opt3Box,
          (val) => setState(() => _opt3Box = val ?? false),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: checkboxWidgets,
      ),
    );
  }

  int _getInputLimit() {
    if (_selectedRadio == '1') return 1;
    if (_selectedRadio == '2') return 2;
    if (_selectedRadio == '3') return 3;
    return 0;
  }

  // --- HIGH PERFORMANCE CELL-ROW ENGINE (With Perfectly Connected Vertical Grid Lines) ---
  Widget _buildOptimizedRow({
    required List<String> values,
    required Color bgColor,
    required Color borderColor,
    required Color insideBorderColor,
    required bool hasOuterBorder,
    required List<TextStyle> textStyles,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: hasOuterBorder
            ? Border(
                left: BorderSide(color: borderColor, width: 1),
                right: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              )
            : null,
      ),
      // IntrinsicHeight stretches all children vertically to make grid lines meet perfectly
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(values.length, (i) {
            final isLast = i == values.length - 1;
            return Expanded(
              flex: _colFlexes[i],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                decoration: BoxDecoration(
                  // This draws the perfectly straight vertical connecting lines
                  border: isLast
                      ? null
                      : Border(
                          right: BorderSide(color: insideBorderColor, width: 1),
                        ),
                ),
                child: Align(
                  alignment: Alignment
                      .centerLeft, // Centers content vertically inside cells
                  child: Text(
                    values[i],
                    style: textStyles[i],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedFromDate = DateFormat('dd/MM/yyyy').format(_fromDate);
    final String formattedToDate = DateFormat('dd/MM/yyyy').format(_toDate);
    final int limit = _getInputLimit();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AgentHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Sales Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 19,
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
          // --- UPDATED FAST PDF DOWNLOAD HANDLER ---
          GestureDetector(
            onTap: _downloadStreamingFile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: const [
                Icon(
                  Icons.cloud_download_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  'PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Static Configuration Box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['ALL', '1', '2', '3'].map((value) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: value,
                                  groupValue: _selectedRadio,
                                  activeColor: widget.themeColor,
                                  visualDensity: const VisualDensity(
                                    horizontal: VisualDensity.minimumDensity,
                                    vertical: VisualDensity.minimumDensity,
                                  ),
                                  onChanged: (newValue) {
                                    _resetCheckboxesAndInput();
                                    setState(() {
                                      _selectedRadio = newValue!;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (_selectedRadio != 'ALL') ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        height: 38,
                        child: TextField(
                          controller: _numberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Number',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(limit),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                _buildConditionalCheckboxes(),
                const SizedBox(height: 10),
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
                            const Divider(
                              color: Colors.grey,
                              thickness: 1,
                              height: 8,
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
                            const Divider(
                              color: Colors.grey,
                              thickness: 1,
                              height: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'EXPAND',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: _isExpandedAll,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.blue,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey[300],
                          onChanged: (value) {
                            // Instant layout modification via background looping mutation
                            setState(() {
                              _isExpandedAll = value;
                              for (var row in _reportData) {
                                row.isLocallyExpanded = value;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => fetchAgentBillReport(isRefresh: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'SEARCH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. STICKY LAYOUT HEADER ROW
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
            child: _buildOptimizedRow(
              values: ['DATE', 'DEALER', 'BILL', 'COUNT', 'D.AMT', 'C.AMT'],
              bgColor: Colors.transparent,
              borderColor: Colors.transparent,
              insideBorderColor: Colors.grey.shade400,
              hasOuterBorder: false,
              textStyles: List.generate(
                6,
                (_) => const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // 3. FLATTENED HIGH-PERFORMANCE LAZY SCROLLABLE LIST VIEW
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _flattenedItemCount,
                    itemBuilder: (context, index) {
                      final resolvedItem = _getItemAtFlatIndex(index);

                      // 1. Handle Pagination Loader At Bottom Edge
                      if (resolvedItem == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // 2. Render Main Parent Row Header (Lazy Loaded)
                      if (resolvedItem.isParent) {
                        final item = resolvedItem.parentRow!;
                        return KeyedSubtree(
                          key: ValueKey('parent_bill_${item.bill}'),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                item.isLocallyExpanded =
                                    !item.isLocallyExpanded;
                              });
                            },
                            child: _buildOptimizedRow(
                              values: [
                                item.date,
                                item.dealer,
                                item.bill,
                                '${item.count}',
                                item.dAmt.toStringAsFixed(2),
                                item.cAmt.toStringAsFixed(2),
                              ],
                              bgColor: Colors.white,
                              borderColor: Colors.grey.shade300,
                              insideBorderColor: Colors.grey.shade300,
                              hasOuterBorder: true,
                              textStyles: [
                                const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // 3. Render Sub-Rows (Completely Flattened & Window-Virtualized)
                      final subItem = resolvedItem.subRow!;
                      return KeyedSubtree(
                        key: ValueKey(
                          'sub_game_${subItem.bill}_${resolvedItem.indexInParent}',
                        ),
                        child: _buildOptimizedRow(
                          values: [
                            subItem.date,
                            subItem.number,
                            subItem.bill,
                            '${subItem.count}',
                            subItem.dAmt.toStringAsFixed(2),
                            subItem.cAmt.toStringAsFixed(2),
                          ],
                          bgColor: const Color(0xFFD81B60),
                          borderColor: Colors.white24,
                          insideBorderColor: Colors.white30,
                          hasOuterBorder: true,
                          textStyles: [
                            const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            const TextStyle(fontSize: 13, color: Colors.white),
                            const TextStyle(fontSize: 13, color: Colors.white),
                            const TextStyle(fontSize: 13, color: Colors.white),
                            const TextStyle(fontSize: 13, color: Colors.white),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // --- BOTTOM FIXED STATISTICAL FOOTER BAR ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1.5),
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
                          'COUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _grandTotalCount.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                          'D.AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _grandTotalDAmount.toStringAsFixed(2),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                          'C.AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _grandTotalCAmount.toStringAsFixed(2),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
          ),
        ],
      ),
    );
  }
}

class _FlatRowWrapper {
  final bool isParent;
  final MainRowData? parentRow;
  final SubRowData? subRow;
  final int indexInParent;

  _FlatRowWrapper({
    required this.isParent,
    this.parentRow,
    this.subRow,
    required this.indexInParent,
  });
}
