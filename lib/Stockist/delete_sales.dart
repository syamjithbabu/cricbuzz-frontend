import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cricbuzz/Stockist/home.dart';
import 'package:cricbuzz/Stockist/select_time.dart';
// Import your custom dependencies here as needed
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Screens/session.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================

class SubRowData {
  final int gamesId; // Maps to AgentGame.id
  final String source; // "agent" or "dealer"
  final String date;
  final String number;
  final String bill;
  final int count;
  final double dAmt;
  final double cAmt;

  SubRowData({
    required this.gamesId,
    required this.source,
    required this.date,
    required this.number,
    required this.bill,
    required this.count,
    required this.dAmt,
    required this.cAmt,
  });

  factory SubRowData.fromJson(Map<String, dynamic> json) {
    return SubRowData(
      gamesId: (json['games_id'] as num?)?.toInt() ?? 0,
      source: json['source'] ?? 'dealer', // Fallback default
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
  double count;
  double dAmt;
  double cAmt;
  final List<SubRowData> subRows;
  bool isLocallyExpanded;

  MainRowData({
    required this.date,
    required this.dealer,
    required this.bill,
    required this.count,
    required this.dAmt,
    required this.cAmt,
    required this.subRows,
    this.isLocallyExpanded = false,
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

// ==========================================
// 2. MAIN DELETE SALES PAGE
// ==========================================

class DeleteSalesPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const DeleteSalesPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<DeleteSalesPage> createState() => _DeleteSalesPageState();
}

class _DeleteSalesPageState extends State<DeleteSalesPage> {
  // Dates
  late DateTime _fromDate;
  late DateTime _toDate;

  // UI Table & Virtualization State
  bool _isExpandedAll = false;
  final List<MainRowData> _deleteSalesData = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _errorMessage;

  // Global Totals
  double _grandTotalCount = 0.0;
  double _grandTotalDAmount = 0.0;
  double _grandTotalCAmount = 0.0;

  // Adjusted flex widths to include the delete action column
  final List<int> _colFlexes = [3, 2, 2, 2, 2, 2, 1];

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  int get _flattenedItemCount {
    int count = 0;
    for (var mainRow in _deleteSalesData) {
      count++;
      if (mainRow.isLocallyExpanded) {
        count += mainRow.subRows.length;
      }
    }
    return count + (_hasMore ? 1 : 0);
  }

  _FlatRowWrapper? _getItemAtFlatIndex(int targetIndex) {
    int currentFlatIndex = 0;

    for (var mainRow in _deleteSalesData) {
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
            parentRow: mainRow,
            subRow: mainRow.subRows[localSubIndex],
            indexInParent: localSubIndex,
          );
        }
        currentFlatIndex += subRowsLen;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = now;
    _toDate = now;

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
    super.dispose();
  }

  Future<void> fetchAgentBillReport({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _deleteSalesData.clear();
        _errorMessage = null;
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

    final Map<String, String> queryParameters = {
      'start_date': fromDateStr,
      'end_date': toDateStr,
      'game_time_id': widget.gameTimeId.toString(),
      'limit': _limit.toString(),
      'offset': _offset.toString(),
    };

    String baseUrlString = '${AppConfig.baseUrl}/stockist/api/sales-report/';
    Uri url = Uri.parse(
      baseUrlString,
    ).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> paginatedJson = json.decode(response.body);
        final List<dynamic> results = paginatedJson['results'] ?? [];

        final List<MainRowData> fetchedRows = results
            .map((jsonItem) => MainRowData.fromJson(jsonItem))
            .toList();

        final Map<String, dynamic> grandTotals =
            paginatedJson['grand_totals'] ?? {};

        setState(() {
          for (var row in fetchedRows) {
            row.isLocallyExpanded = _isExpandedAll;
          }
          _deleteSalesData.addAll(fetchedRows);
          _offset += fetchedRows.length;

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

  // Helper modal dialog confirmation
  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('DELETE', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // 1. Delete Entire Bill
  Future<void> _deleteBillRow(MainRowData parentRow) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Bill #${parentRow.bill}?',
      message: 'This will permanently delete this entire bill and all included games.',
    );

    if (!confirmed) return;

    final Uri url = Uri.parse('${AppConfig.baseUrl}/stockist/api/delete-bill/${parentRow.bill}/');

    try {
      final response = await http.delete(url, headers: _headers);

      if (response.statusCode == 200) {
        setState(() {
          _grandTotalCount -= parentRow.count;
          _grandTotalDAmount -= parentRow.dAmt;
          _grandTotalCAmount -= parentRow.cAmt;
          _deleteSalesData.remove(parentRow);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill deleted successfully.')),
          );
        }
      } else {
        _showErrorSnackBar('Failed to delete bill. (${response.statusCode})');
      }
    } catch (e) {
      _showErrorSnackBar('Network error occurred while deleting bill.');
    }
  }

  // 2. Delete Individual Game Entry
  Future<void> _deleteGameRow(MainRowData parentRow, int subIndex) async {
    final subRow = parentRow.subRows[subIndex];

    final confirmed = await _showConfirmDialog(
      title: 'Delete Game Entry?',
      message: 'Are you sure you want to delete number "${subRow.number}"?',
    );

    if (!confirmed) return;

    // 🔹 Append query parameter source="agent" or source="dealer"
    final Uri url = Uri.parse(
      '${AppConfig.baseUrl}/stockist/api/delete-game/${subRow.gamesId}/?source=${subRow.source}',
    );

    try {
      final response = await http.delete(url, headers: _headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> resData = json.decode(response.body);
        final bool isBillDeleted = resData['bill_deleted'] ?? false;

        setState(() {
          // Adjust parent totals locally
          parentRow.count -= subRow.count;
          parentRow.dAmt -= subRow.dAmt;
          parentRow.cAmt -= subRow.cAmt;

          // Adjust grand totals locally
          _grandTotalCount -= subRow.count;
          _grandTotalDAmount -= subRow.dAmt;
          _grandTotalCAmount -= subRow.cAmt;

          // Remove sub-row from memory
          parentRow.subRows.removeAt(subIndex);

          // Remove parent row if empty or if backend deleted the parent bill
          if (parentRow.subRows.isEmpty || isBillDeleted) {
            _deleteSalesData.remove(parentRow);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game entry deleted.')),
          );
        }
      } else {
        // 🔹 Extract exact error message from Django backend if available
        try {
          final Map<String, dynamic> errData = json.decode(response.body);
          final String errorMessage = errData['error'] ?? 'Failed to delete game entry.';
          _showErrorSnackBar(errorMessage);
        } catch (_) {
          _showErrorSnackBar('Failed to delete game entry. (${response.statusCode})');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Network error occurred while deleting game entry.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }


  Widget _buildOptimizedRow({
    required List<String> values,
    required Color bgColor,
    required Color borderColor,
    required Color insideBorderColor,
    required bool hasOuterBorder,
    required List<TextStyle> textStyles,
    required bool isHeader,
    VoidCallback? onDelete,
    Color deleteIconColor = Colors.grey,
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Standard Data Columns
            ...List.generate(values.length, (i) {
              return Expanded(
                flex: _colFlexes[i],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: insideBorderColor, width: 1),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
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

            // Action / Delete Column
            Expanded(
              flex: _colFlexes.last,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: isHeader
                    ? const Icon(
                        Icons.delete_outline,
                        color: Colors.black54,
                        size: 18,
                      )
                    : Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            color: deleteIconColor,
                            size: 18,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subRowBgColor = const Color(0xFFD81B60);

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
                builder: (context) => StockistHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            );
          },
        ),
        title: Text(
          'Delete Sales',
          style: const TextStyle(
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
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Expand Toggle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
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
                      activeTrackColor: widget.themeColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey[300],
                      onChanged: (value) {
                        setState(() {
                          _isExpandedAll = value;
                          for (var row in _deleteSalesData) {
                            row.isLocallyExpanded = value;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Header
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
              isHeader: true,
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

          // ListView Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: widget.themeColor),
                  )
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _flattenedItemCount,
                    itemBuilder: (context, index) {
                      final resolvedItem = _getItemAtFlatIndex(index);

                      if (resolvedItem == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: widget.themeColor,
                            ),
                          ),
                        );
                      }

                      // 1. Parent Row (Main Bill Row)
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
                              isHeader: false,
                              deleteIconColor: Colors.red.shade400,
                              onDelete: () => _deleteBillRow(item),
                              textStyles: const [
                                TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                TextStyle(fontSize: 13, color: Colors.black),
                                TextStyle(fontSize: 13, color: Colors.black),
                                TextStyle(fontSize: 13, color: Colors.black),
                                TextStyle(fontSize: 13, color: Colors.black),
                              ],
                            ),
                          ),
                        );
                      }

                      // 2. Sub-Row (Individual Game Row)
                      final subItem = resolvedItem.subRow!;
                      final parentItem = resolvedItem.parentRow!;
                      final subIndex = resolvedItem.indexInParent;

                      return KeyedSubtree(
                        key: ValueKey('sub_game_${subItem.bill}_$subIndex'),
                        child: _buildOptimizedRow(
                          values: [
                            subItem.date,
                            subItem.number,
                            subItem.bill,
                            '${subItem.count}',
                            subItem.dAmt.toStringAsFixed(2),
                            subItem.cAmt.toStringAsFixed(2),
                          ],
                          bgColor: subRowBgColor,
                          borderColor: Colors.white24,
                          insideBorderColor: Colors.white30,
                          hasOuterBorder: true,
                          isHeader: false,
                          deleteIconColor: Colors.white70,
                          onDelete: () => _deleteGameRow(parentItem, subIndex),
                          textStyles: const [
                            TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            TextStyle(fontSize: 13, color: Colors.white),
                            TextStyle(fontSize: 13, color: Colors.white),
                            TextStyle(fontSize: 13, color: Colors.white),
                            TextStyle(fontSize: 13, color: Colors.white),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Totals Footer
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
                  _buildFooterMetric(
                    'COUNT',
                    _grandTotalCount.toStringAsFixed(1),
                  ),
                  _buildFooterMetric(
                    'D.AMOUNT',
                    _grandTotalDAmount.toStringAsFixed(2),
                  ),
                  _buildFooterMetric(
                    'C.AMOUNT',
                    _grandTotalCAmount.toStringAsFixed(2),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
