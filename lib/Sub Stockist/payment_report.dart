import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Sub Stockist/home.dart';

class PaymentReportPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const PaymentReportPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  String _selectedUserFilter = 'ALL';
  String _selectedMode = 'ALL';
  bool _isReportLoading = false;
  bool isLoading = true;

  List<Map<String, dynamic>> _reportList = [];
  double _grandTotalAmount = 0.0;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  List<Map<String, dynamic>> _dealerList = [
    {'id': -1, 'username': 'STOCKIST'},
  ];

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  @override
  void initState() {
    super.initState();
    _fetchPaymentReport();
    fetchDealers();
  }

  Future<void> fetchDealers() async {
    setState(() => isLoading = true);
    final url = Uri.parse('${AppConfig.baseUrl}/substockist/api/dealers/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          final List<Map<String, dynamic>> fetchedData = data
              .map<Map<String, dynamic>>((item) {
                // Extract username from nested 'user' object or top-level item
                String extractedUsername = 'Unknown Dealer';
                if (item['user'] != null && item['user'] is Map) {
                  extractedUsername = item['user']['username']?.toString() ?? 'Unknown Dealer';
                } else if (item['username'] != null) {
                  extractedUsername = item['username'].toString();
                }

                return {
                  'id': item['id'],
                  'username': extractedUsername,
                };
              })
              .toList();

          _dealerList = [
            {'id': -1, 'username': 'STOCKIST'},
          ]..addAll(fetchedData);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPaymentReport() async {
    setState(() => _isReportLoading = true);

    final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final Uri url = Uri.parse('${AppConfig.baseUrl}/substockist/api/payment-report/').replace(
      queryParameters: {
        'start_date': fromStr,
        'end_date': toStr,
        'mode': _selectedMode,
        'user_filter': _selectedUserFilter,
      },
    );

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _reportList = List<Map<String, dynamic>>.from(data['records'] ?? []);
          _grandTotalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
          _isReportLoading = false;
        });
      } else {
        setState(() => _isReportLoading = false);
        _showErrorSnackBar('Failed to retrieve payment data.');
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showAddPaymentModal(BuildContext context) {
    DateTime modalDate = DateTime.now();
    String modalType = 'Pay';
    int selectedTargetId = -1; // -1 means STOCKIST
    final TextEditingController amountController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 20.0,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Payment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // TARGET DROPDOWN (STOCKIST or Dealer)
                  const Text('Pay To / From', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButtonFormField<int>(
                    value: selectedTargetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                    ),
                    items: _dealerList.map((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          item['username'].toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedTargetId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // DATE PICKER
                  const Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: modalDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() => modalDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(modalDate),
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TYPE DROPDOWN (Pay / Receive)
                  const Text('Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButtonFormField<String>(
                    value: modalType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Pay', child: Text('Pay', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'Receive', child: Text('Receive', style: TextStyle(fontSize: 14))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => modalType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // AMOUNT INPUT
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ACTION BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (amountController.text.trim().isEmpty) {
                                  _showErrorSnackBar('Please enter an amount');
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final Uri url = Uri.parse('${AppConfig.baseUrl}/substockist/api/payment-report/');
                                final body = json.encode({
                                  'date': DateFormat('yyyy-MM-dd').format(modalDate),
                                  'type': modalType,
                                  'amount': double.tryParse(amountController.text) ?? 0.0,
                                  'dealer_id': selectedTargetId,
                                });

                                try {
                                  final response = await http.post(url, headers: _headers, body: body);
                                  if (response.statusCode == 200 || response.statusCode == 201) {
                                    Navigator.pop(modalContext);
                                    _showSuccessSnackBar(
                                      selectedTargetId == -1
                                          ? 'Payment submitted. Pending stockist approval.'
                                          : 'Dealer payment recorded.',
                                    );
                                    _fetchPaymentReport();
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    _showErrorSnackBar('Failed to save payment.');
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  _showErrorSnackBar('Network connection problem.');
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('SUBMIT', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
          'Payment Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddPaymentModal(context),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DATE PICKERS ROW
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

                  // MODES & DEALER FILTER DROPDOWNS
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedMode,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 0.6),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('ALL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'PAID', child: Text('PAID', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'RECEIVED', child: Text('RECEIVED', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMode = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUserFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 0.6),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text('ALL USERS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const DropdownMenuItem(
                              value: 'STOCKIST',
                              child: Text('STOCKIST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            ..._dealerList
                                .where((dealer) => dealer['id'] != -1)
                                .map((dealer) {
                              return DropdownMenuItem<String>(
                                value: dealer['id'].toString(),
                                child: Text(
                                  dealer['username']?.toString() ?? 'Dealer',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedUserFilter = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isReportLoading ? null : _fetchPaymentReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          minimumSize: const Size(60, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 2,
                        ),
                        child: _isReportLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // REPORT DATA TABLE
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.1),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.0),
                      3: FlexColumnWidth(1.0),
                      4: FlexColumnWidth(1.0),
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
                          _buildHeaderCell('DATE'),
                          _buildHeaderCell('USER'),
                          _buildHeaderCell('PAID'),
                          _buildHeaderCell('RECEIVED'),
                          _buildHeaderCell('STATUS'),
                        ],
                      ),
                      ..._reportList.map((item) {
                        final String status = item['status']?.toString() ?? 'Pending';
                        final String userName = item['user']?.toString() ?? '-';
                        final String itemType = item['type']?.toString().toUpperCase() ?? '';

                        final String rawAmount = (item['amount'] as num?)
                                ?.toDouble()
                                .toStringAsFixed(2)
                                .replaceFirst('.00', '') ??
                            '0';

                        final String paidAmount = (itemType == 'PAY' || itemType == 'PAID') ? rawAmount : '-';
                        final String receivedAmount = (itemType == 'RECEIVE' || itemType == 'RECEIVED') ? rawAmount : '-';

                        return TableRow(
                          children: [
                            _buildDataCell(item['date']?.toString() ?? '-'),
                            _buildDataCell(userName),
                            _buildDataCell(
                              paidAmount,
                              icon: paidAmount != '-' ? Icons.arrow_upward : null,
                              iconColor: Colors.red,
                            ),
                            _buildDataCell(
                              receivedAmount,
                              icon: receivedAmount != '-' ? Icons.arrow_downward : null,
                              iconColor: Colors.green,
                            ),
                            _buildStatusCell(status),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // TOTAL FOOTER BAR
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
                    style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 13, fontStyle: FontStyle.italic),
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

  Widget _buildHeaderCell(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
    );
  }

  Widget _buildDataCell(String text, {IconData? icon, Color? iconColor}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'approved') {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'rejected') {
      statusColor = Colors.red;
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
      ),
    );
  }
}