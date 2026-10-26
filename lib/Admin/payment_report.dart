import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'dart:convert';

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
  String _selectedMode = 'ALL'; // Modes: ALL, PAID, RECEIVED
  bool _isReportLoading = false;

  String? _selectedStockist;
  bool isLoading = true;

  // Report records state holder
  List<Map<String, dynamic>> _reportList = [];
  double _grandTotalAmount = 0.0;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  List<Map<String, dynamic>> _stockistList = [
    {'id': -1, 'username': 'Select Stockist'},
  ];

  Map<String, dynamic>? _selectedStockistMap;

  @override
  void initState() {
    super.initState();
    fetchStockists();
    _fetchPaymentReport();
  }

  Future<void> fetchStockists() async {
    setState(() => isLoading = true);
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
              'username': user != null ? user['username'].toString() : 'Unknown Stockist',
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

  Future<void> _fetchPaymentReport() async {
    setState(() => _isReportLoading = true);

    final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final String toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final Uri url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/payment-report/').replace(
      queryParameters: {
        'start_date': fromStr,
        'end_date': toStr,
        'mode': _selectedMode,
        if (_selectedStockist != null && _selectedStockist != 'Select Stockist') 'stockist': _selectedStockist!,
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

  Future<void> _handlePaymentAction(int paymentId, String action) async {
    // 1. Prompt confirmation dialog before proceeding
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isApprove = action.toLowerCase() == 'approve' || action.toLowerCase() == 'accept';
        
        return AlertDialog(
          title: Text('${isApprove ? 'Accept' : 'Reject'} Payment'),
          content: Text(
            'Are you sure you want to ${isApprove ? 'accept' : 'reject'} this payment record?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel action
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? Colors.green : Colors.red,
              ),
              onPressed: () => Navigator.of(context).pop(true), // Confirm action
              child: Text(
                isApprove ? 'Accept' : 'Reject',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    // 2. Stop execution if user cancels or closes the dialog
    if (confirmed != true) return;

    // 3. Perform network action upon confirmation
    final Uri url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/payment-report/$paymentId/');

    try {
      final response = await http.patch(
        url,
        headers: _headers,
        body: json.encode({'action': action}),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Action executed successfully.');
        _fetchPaymentReport();
      } else {
        _showErrorSnackBar('Failed to update payment status.');
      }
    } catch (e) {
      _showErrorSnackBar('Network connection problem.');
    }
  }

  Future<void> _deletePayment(int paymentId) async {
    final Uri url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/payment-report/$paymentId/');

    try {
      final response = await http.delete(url, headers: _headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSuccessSnackBar('Payment record deleted successfully.');
        _fetchPaymentReport();
      } else {
        _showErrorSnackBar('Failed to delete payment entry.');
      }
    } catch (e) {
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

  void _confirmDeleteDialog(int paymentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deletePayment(paymentId);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentModal(BuildContext context) {
    DateTime modalDate = DateTime.now();
    Map<String, dynamic>? modalStockistMap;
    String modalType = 'Pay'; // Options: Pay, Receive
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

                  // 1. DATE PICKER
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
                        setModalState(() {
                          modalDate = picked;
                        });
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

                  // 2. STOCKIST DROPDOWN
                  const Text('Stockist', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: modalStockistMap,
                    isExpanded: true,
                    hint: const Text('Select Stockist', style: TextStyle(fontSize: 14)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                    ),
                    items: _stockistList
                        .where((st) => st['id'] != -1)
                        .map((st) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: st,
                        child: Text(st['username'].toString(), style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        modalStockistMap = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. TYPE DROPDOWN (Pay / Receive)
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
                        setModalState(() {
                          modalType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. AMOUNT INPUT
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

                  // 5. ACTION BUTTONS (Cancel & Submit)
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
                                if (modalStockistMap == null) {
                                  _showErrorSnackBar('Please select a Sub Stockist');
                                  return;
                                }
                                if (amountController.text.trim().isEmpty) {
                                  _showErrorSnackBar('Please enter an amount');
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final Uri url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/payment-report/');
                                final body = json.encode({
                                  'date': DateFormat('yyyy-MM-dd').format(modalDate),
                                  'stockist_id': modalStockistMap!['id'],
                                  'type': modalType,
                                  'amount': double.tryParse(amountController.text) ?? 0.0,
                                });

                                try {
                                  final response = await http.post(url, headers: _headers, body: body);
                                  if (response.statusCode == 200 || response.statusCode == 201) {
                                    Navigator.pop(modalContext);
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
          'Payment Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
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
                  // 1. DATE PICKERS ROW
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

                  // 2. MODE & STOCKIST DROPDOWN ROW
                  Row(
                    children: [
                      Expanded(
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
                            DropdownMenuItem(value: 'ALL', child: Text('ALL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'PAID', child: Text('PAID', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 'RECEIVED', child: Text('RECEIVED', style: TextStyle(fontSize: 14))),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMode = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedStockistMap,
                          isExpanded: true,
                          hint: const Text(
                            'Select Stockist',
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
                          items: _stockistList.map((Map<String, dynamic> st) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: st,
                              child: Text(st['username'].toString(), style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStockistMap = value;
                              _selectedStockist = (value != null && value['id'] != -1) ? value['username'].toString() : null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. ACTION SUBMIT BUTTON ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _isReportLoading ? null : _fetchPaymentReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 2,
                        ),
                        child: _isReportLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. PAYMENT REPORT DATA TABLE
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.0), // Date
                      1: FlexColumnWidth(1.1), // User
                      2: FlexColumnWidth(0.8), // Type
                      3: FlexColumnWidth(0.8), // Paid
                      4: FlexColumnWidth(0.8), // Received
                      5: FlexColumnWidth(0.9), // Status
                      6: FlexColumnWidth(1.1), // Actions
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
                          // _buildHeaderCell('TYPE'),
                          _buildHeaderCell('PAID'),
                          _buildHeaderCell('RECEIVED'),
                          _buildHeaderCell('STATUS'),
                          _buildHeaderCell('ACTION'),
                        ],
                      ),
                      ..._reportList.map((item) {
                        final bool isStockistCreated = item['is_stockist_created'] ?? false;
                        final String status = item['status']?.toString() ?? 'Pending';
                        final int paymentId = item['id'];

                        final String itemType = item['type']?.toString().toUpperCase() ?? '';
                        final String rawAmount = (item['amount'] as num?)
                                ?.toDouble()
                                .toStringAsFixed(2)
                                .replaceFirst('.00', '') ??
                            '0';

                        // Split into Paid and Received values
                        final String paidAmount = (itemType == 'PAY' || itemType == 'PAID') ? rawAmount : '-';
                        final String receivedAmount = (itemType == 'RECEIVE' || itemType == 'RECEIVED') ? rawAmount : '-';

                        return TableRow(
                          children: [
                            _buildDataCell(item['date']?.toString() ?? '-'),
                            _buildDataCell(item['user']?.toString() ?? '-'),
                            // _buildDataCell(item['type']?.toString() ?? '-'),
                            // Paid (Outgoing Arrow - Red)
                            _buildDataCell(
                              paidAmount,
                              icon: paidAmount != '-' ? Icons.arrow_upward : null,
                              iconColor: Colors.red,
                            ),
                            // Received (Incoming Arrow - Green)
                            _buildDataCell(
                              receivedAmount,
                              icon: receivedAmount != '-' ? Icons.arrow_downward : null,
                              iconColor: Colors.green,
                            ),
                            _buildStatusCell(status),
                            _buildActionCell(
                              paymentId: paymentId,
                              status: status,
                              isStockistCreated: isStockistCreated,
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. FIXED TOTAL FOOTER BAR
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

  Widget _buildHeaderCell(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
      ),
    );
  }

  Widget _buildActionCell({
    required int paymentId,
    required String status,
    required bool isStockistCreated,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isStockistCreated && status.toLowerCase() == 'pending') ...[
            InkWell(
              onTap: () => _handlePaymentAction(paymentId, 'accept'),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            ),
            InkWell(
              onTap: () => _handlePaymentAction(paymentId, 'reject'),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(Icons.cancel, color: Colors.orange, size: 20),
              ),
            ),
          ],
          InkWell(
            onTap: () => _confirmDeleteDialog(paymentId),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.delete, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}