import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Filtering/Length limit formatters
import 'package:cricbuzz/Sub Stockist/select_time.dart';
import 'package:cricbuzz/Sub Stockist/home.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Sub Stockist/blocked_numbers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CreateBlockNumberPage extends StatefulWidget {
  final Color themeColor; // Dynamically passed down from previous pages
  final int gameTimeId;
  final String gameTimeLabel;

  const CreateBlockNumberPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<CreateBlockNumberPage> createState() => _CreateBlockNumberPageState();
}

class _CreateBlockNumberPageState extends State<CreateBlockNumberPage> {
  // State variables matching form elements
  String? _selectedDealer;
  int _selectedDigitType = 3; // Defaults to 3
  String? _selectedTicketType;

  final TextEditingController _numbersController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final FocusNode _countFocusNode = FocusNode();

  // Mock stockists list for selection drop-down layout
  List<String> _dealersList = [];
  bool isLoading = true;
  String? errorMessage;

  // Dynamic Ticket Types mapping based on selected digit selection type and gameTimeId
  List<String> _getTicketOptions() {
    final String primaryTicket = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';

    if (_selectedDigitType == 1) {
      return ['ALL', 'A', 'B', 'C'];
    } else if (_selectedDigitType == 2) {
      return ['ALL', 'AB', 'BC', 'AC'];
    } else {
      return [primaryTicket, 'BOX', 'BOTH'];
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTicketType = _getTicketOptions().first;
    fetchDealers();
  }

  @override
  void dispose() {
    _numbersController.dispose();
    _countController.dispose();
    _countFocusNode.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

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
          _dealersList = data.map<String>((item) {
            final user = item['user'];
            return user != null
                ? user['username'].toString()
                : 'Unknown Dealer';
          }).toList();

          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load stockists (${response.statusCode})';
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

  Future<void> saveBlockedNumber() async {
    if (_countController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a count.')),
      );
      return;
    }

    // Show loading indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final url = Uri.parse(
      '${AppConfig.baseUrl}/substockist/api/create-block-number/',
    );

    final String primaryTicket = (widget.gameTimeId == 2) ? 'SUPER' : 'DEAR';

    // Determine target tickets based on dynamic selections
    List<String> ticketsToSave = [];
    if (_selectedTicketType == 'BOTH') {
      ticketsToSave = [primaryTicket, 'BOX'];
    } else if (_selectedTicketType == 'ALL') {
      if (_selectedDigitType == 1) {
        ticketsToSave = ['A', 'B', 'C'];
      } else if (_selectedDigitType == 2) {
        ticketsToSave = ['AB', 'BC', 'AC'];
      }
    } else {
      ticketsToSave = [_selectedTicketType ?? primaryTicket];
    }

    try {
      bool allSuccessful = true;
      String? serverError;

      // Handle individual or split multiple payloads seamlessly
      for (String ticket in ticketsToSave) {
        final Map<String, dynamic> payload = {
          'dealer_name': _selectedDealer,
          'game_time_id': widget.gameTimeId,
          'group': _selectedDigitType.toString(),
          'ticket': ticket,
          'number': _numbersController.text,
          'count': double.tryParse(_countController.text) ?? 0.0,
        };

        final response = await http.post(
          url,
          headers: _headers,
          body: json.encode(payload),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          allSuccessful = false;
          final responseData = json.decode(response.body);
          serverError =
              responseData['error'] ?? 'Failed to save entry for $ticket.';
          break; // Stop execution if any request fails
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator

      if (allSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blocked number saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _numbersController.clear();
        _countController.clear();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BlockNumbersPage(
              themeColor: widget.themeColor,
              gameTimeId: widget.gameTimeId,
              gameTimeLabel: widget.gameTimeLabel,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverError ?? 'Failed to save entries.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Failed to save entry.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> dynamicOptions = _getTicketOptions();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubStockistHomePage(
                themeColor: widget.themeColor,
                gameTimeId: widget.gameTimeId,
                gameTimeLabel: widget.gameTimeLabel,
              ),
            ),
          ),
        ),
        title: const Text(
          'New Blocked',
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
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUSTOMER',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedDealer,
                    hint: const Text(
                      'Select Dealer',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 1.5),
                      ),
                    ),
                    items: _dealersList.map((String dealer) {
                      return DropdownMenuItem<String>(
                        value: dealer,
                        child: Text(
                          dealer,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedDealer = value),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TICKET TYPE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [1, 2, 3].map((int digit) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<int>(
                            value: digit,
                            groupValue: _selectedDigitType,
                            activeColor: Colors.blue,
                            onChanged: (int? value) {
                              setState(() {
                                _selectedDigitType = value!;
                                _numbersController.clear();
                                _selectedTicketType =
                                    _getTicketOptions().first;
                              });
                            },
                          ),
                          Text(
                            '$digit',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                  const SizedBox(height: 20),
                  const Text(
                    'TICKET TYPE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: dynamicOptions.map((String option) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: option,
                            groupValue: _selectedTicketType,
                            activeColor: Colors.blue,
                            onChanged: (String? value) {
                              setState(() => _selectedTicketType = value);
                            },
                          ),
                          Text(
                            option,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                  const SizedBox(height: 24),
                  const Text(
                    'BLOCKED NUMBERS',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  TextField(
                    controller: _numbersController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_selectedDigitType),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      // Move focus to count field when maximum digits are reached
                      if (value.length == _selectedDigitType) {
                        FocusScope.of(context).requestFocus(_countFocusNode);
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Number',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'COUNT',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  TextField(
                    controller: _countController,
                    focusNode: _countFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Count',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 0.6),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final textLength = _numbersController.text.length;

              if (textLength != _selectedDigitType) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'You must enter exactly $_selectedDigitType digits.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              saveBlockedNumber();
            },
            child: Container(
              color: widget.themeColor,
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}