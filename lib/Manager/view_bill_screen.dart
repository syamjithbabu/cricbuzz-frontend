import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for compute() isolate parsing
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

/// Top-level global function required by Dart's `compute` isolate.
/// Processes large JSON data entirely off the main UI thread to prevent lag spikes.
Map<String, dynamic> _parseAndDecodeJson(String responseBody) {
  return json.decode(responseBody) as Map<String, dynamic>;
}

class ViewBillScreen extends StatefulWidget {
  final int billId;
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const ViewBillScreen({
    super.key,
    required this.billId,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  });

  @override
  State<ViewBillScreen> createState() => _ViewBillScreenState();
}

class _ViewBillScreenState extends State<ViewBillScreen> {
  List<dynamic> _billEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalCount = 0;
  double _totalDAmt = 0.0;
  double _totalCAmt = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchBillDetails();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  Future<void> _fetchBillDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/manager/api/bills/${widget.billId}/'); 
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        // Offload JSON decoding to a background worker Thread
        final Map<String, dynamic> data = await compute(_parseAndDecodeJson, response.body);
        
        final List<dynamic> entries = data['entries'] ?? [];
        
        // Dynamically calculate sum of d_amt and c_amt
        double calculatedDAmt = 0.0;
        double calculatedCAmt = 0.0;
        for (var item in entries) {
          calculatedDAmt += (item['d_amt'] as num? ?? 0).toDouble();
          calculatedCAmt += (item['c_amt'] as num? ?? 0).toDouble();
        }

        setState(() {
          _billEntries = entries;
          _totalCount = (data['total_count'] as num? ?? 0).toInt();
          _totalDAmt = calculatedDAmt;
          _totalCAmt = calculatedCAmt;
          _isLoading = false;
        });
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Failed to load bill details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred connection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        title: Text(
          widget.gameTimeLabel,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: _fetchBillDetails,
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Static Details Panel
                    Padding(
                      padding: const EdgeInsets.only(left: 14.0, right: 14.0, top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BILL NO : ${widget.billId}',
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'CLOSE BILL',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),

                    // Table Header (Frozen on top during scrolling)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.0),
                      child: _HeaderRow(),
                    ),

                    // Main Scrollable Table Area with trailing total row and bottom close button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        child: ListView.builder(
                          // We add +2: One for the footer summary, and one for the bottom static action link
                          itemCount: _billEntries.length + 2,
                          padding: const EdgeInsets.only(bottom: 24.0),
                          itemBuilder: (context, index) {
                            // 1. Total Summary Row
                            if (index == _billEntries.length) {
                              return _FooterRow(
                                totalCount: _totalCount,
                                totalDAmt: _totalDAmt,
                                totalCAmt: _totalCAmt,
                              );
                            }
                            
                            // 2. Bottom Close Bill button directly below the footer
                            if (index == _billEntries.length + 1) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 14.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: const Text(
                                      'CLOSE BILL',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            // 3. Normal Data Row
                            final item = _billEntries[index];
                            return _DataRow(item: item);
                          },
                        ),
                      ),
                    ),

                    
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------
// REUSABLE LAYOUT BLOCKS FOR HIGH VELOCITY PERFORMANCE
// ---------------------------------------------------------

/// Precise column ratio sizes matching original layout configuration ratios
const Map<int, double> _columnWeights = {
  0: 1.1, // DATE
  1: 1.6, // DEALER
  2: 1.3, // BILL
  3: 1.3, // COUNT
  4: 1.5, // D.AMT
  5: 1.5, // C.AMT
  6: 0.9, // TRASH ACTION (#)
};

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: (_columnWeights[0]! * 10).toInt(), child: const _CellText('DATE', isBold: true)),
          Expanded(flex: (_columnWeights[1]! * 10).toInt(), child: const _CellText('DEALER', isBold: true)),
          Expanded(flex: (_columnWeights[2]! * 10).toInt(), child: const _CellText('BILL', isBold: true)),
          Expanded(flex: (_columnWeights[3]! * 10).toInt(), child: const _CellText('COUNT', isBold: true)),
          Expanded(flex: (_columnWeights[4]! * 10).toInt(), child: const _CellText('D.AMT', isBold: true)),
          Expanded(flex: (_columnWeights[5]! * 10).toInt(), child: const _CellText('C.AMT', isBold: true)),
          Expanded(flex: (_columnWeights[6]! * 10).toInt(), child: const _CellText('#', isBold: true)),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DataRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD81B60),
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 0.8),
          right: BorderSide(color: Colors.grey.shade300, width: 0.8),
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(flex: (_columnWeights[0]! * 10).toInt(), child: _CellText(item['date'].toString(), color: Colors.white)),
          Expanded(flex: (_columnWeights[1]! * 10).toInt(), child: _CellText(item['dealer'].toString(), color: Colors.white)),
          Expanded(flex: (_columnWeights[2]! * 10).toInt(), child: _CellText(item['bill'].toString(), color: Colors.white)),
          Expanded(flex: (_columnWeights[3]! * 10).toInt(), child: _CellText(item['count'].toString(), color: Colors.white)),
          Expanded(flex: (_columnWeights[4]! * 10).toInt(), child: _CellText((item['d_amt'] as num? ?? 0).toDouble().toStringAsFixed(2), color: Colors.white)),
          Expanded(flex: (_columnWeights[5]! * 10).toInt(), child: _CellText((item['c_amt'] as num? ?? 0).toDouble().toStringAsFixed(2), color: Colors.white)),
          Expanded(
            flex: (_columnWeights[6]! * 10).toInt(),
            child: const Center(
              child: Icon(
                Icons.delete_outline_outlined,
                size: 19,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  final int totalCount;
  final double totalDAmt;
  final double totalCAmt;

  const _FooterRow({
    required this.totalCount,
    required this.totalDAmt,
    required this.totalCAmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 0.8),
          right: BorderSide(color: Colors.grey.shade300, width: 0.8),
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: (_columnWeights[0]! * 10).toInt(), child: const SizedBox.shrink()),
          Expanded(flex: (_columnWeights[1]! * 10).toInt(), child: const _CellText('TOTAL', isBold: true)),
          Expanded(flex: (_columnWeights[2]! * 10).toInt(), child: const SizedBox.shrink()),
          Expanded(flex: (_columnWeights[3]! * 10).toInt(), child: _CellText(totalCount.toString(), isBold: true)),
          Expanded(flex: (_columnWeights[4]! * 10).toInt(), child: _CellText(totalDAmt.toStringAsFixed(2), isBold: true)),
          Expanded(flex: (_columnWeights[5]! * 10).toInt(), child: _CellText(totalCAmt.toStringAsFixed(2), isBold: true)),
          Expanded(flex: (_columnWeights[6]! * 10).toInt(), child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color color;

  const _CellText(
    this.text, {
    this.isBold = false,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.0,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        color: color,
      ),
    );
  }
}