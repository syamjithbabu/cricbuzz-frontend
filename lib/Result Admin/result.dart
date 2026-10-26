import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Imports from your project structure
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Screens/session.dart';

class AddResultsPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const AddResultsPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<AddResultsPage> createState() => _AddResultsPageState();
}

class _AddResultsPageState extends State<AddResultsPage> {
  String? _selectedTimeId;
  List<dynamic> _fetchedTimesList = [];
  bool _isTimesLoading = true;

  bool _isResultLoading = false;
  bool _isFullyPublished = false; // Tracks if fetched data had all fields filled
  DateTime selectedDate = DateTime.now();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${MySession.token}',
      };

  Map<String, dynamic> resultData = {};
  List<String> guaranteeNumbers = [];

  final TextEditingController firstCtrl = TextEditingController();
  final TextEditingController secondCtrl = TextEditingController();
  final TextEditingController thirdCtrl = TextEditingController();
  final TextEditingController fourthCtrl = TextEditingController();
  final TextEditingController fifthCtrl = TextEditingController();

  late List<TextEditingController> guaranteeCtrls;
  late List<FocusNode> allFocusNodes;

  @override
  void initState() {
    super.initState();
    guaranteeCtrls = List.generate(30, (i) => TextEditingController());

    allFocusNodes = [
      FocusNode(),
      FocusNode(),
      FocusNode(),
      FocusNode(),
      FocusNode(),
      ...List.generate(30, (_) => FocusNode()),
    ];

    if (widget.gameTimeId > 0) {
      _selectedTimeId = widget.gameTimeId.toString();
    }

    _fetchGameTimesAndResult();
  }

  @override
  void dispose() {
    firstCtrl.dispose();
    secondCtrl.dispose();
    thirdCtrl.dispose();
    fourthCtrl.dispose();
    fifthCtrl.dispose();
    for (var ctrl in guaranteeCtrls) {
      ctrl.dispose();
    }
    for (var node in allFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // --- API CALLS ---

  Future<void> _fetchGameTimesAndResult() async {
    await _fetchGameTimes();
    await fetchResult();
  }

  Future<void> _fetchGameTimes() async {
    final url = Uri.parse('${AppConfig.baseUrl}/resultadmin/api/game-times/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _fetchedTimesList = data;
          _isTimesLoading = false;

          if (_selectedTimeId != null) {
            bool hasNavId = data.any((time) => time['id'].toString() == _selectedTimeId);
            if (!hasNavId) {
              _selectedTimeId = data.isNotEmpty ? data.first['id'].toString() : null;
            }
          } else if (data.isNotEmpty) {
            _selectedTimeId = data.first['id'].toString();
          }
        });
      } else {
        setState(() => _isTimesLoading = false);
      }
    } catch (e) {
      setState(() => _isTimesLoading = false);
    }
  }

  /// Dynamic GET Request: Retrieves existing result for selected game_id and date
  Future<void> fetchResult() async {
    if (_selectedTimeId == null) return;

    setState(() => _isResultLoading = true);

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final url = Uri.parse(
      '${AppConfig.baseUrl}/resultadmin/api/result/?game_id=$_selectedTimeId&date=$formattedDate',
    );

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic> && data.containsKey('first')) {
          _populateFields(data);
        } else {
          _clearFields();
        }
      } else {
        _clearFields();
      }
    } catch (e) {
      _clearFields();
    } finally {
      setState(() => _isResultLoading = false);
    }
  }

  /// Dynamic POST Request: Creates or updates result in backend
  Future<void> publishResult() async {
    if (_selectedTimeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a game first.")),
      );
      return;
    }

    // Input Validation
    List<TextEditingController> allCtrls = [
      firstCtrl, secondCtrl, thirdCtrl, fourthCtrl, fifthCtrl, ...guaranteeCtrls
    ];

    for (var c in allCtrls) {
      final text = c.text.trim();
      if (text.isNotEmpty && text.length != 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Each filled field must contain exactly 3 digits!"),
            backgroundColor: Colors.black,
          ),
        );
        return;
      }
    }

    // Modal check: Stop execution if result is already fully published
    if (_isFullyPublished) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Admin Action Required'),
            ],
          ),
          content: const Text(
            'This result has already been fully published. Only an admin can update published results.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      return; // Stop flow; do not publish
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dynamicGuarantees = guaranteeCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .join(',');

    final body = json.encode({
      'time_id': _selectedTimeId,
      'date': formattedDate,
      'first': firstCtrl.text.trim(),
      'second': secondCtrl.text.trim(),
      'third': thirdCtrl.text.trim(),
      'fourth': fourthCtrl.text.trim(),
      'fifth': fifthCtrl.text.trim(),
      'guarantees': dynamicGuarantees,
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(width: 20),
            Text('Publishing Result...'),
          ],
        ),
      ),
    );

    final url = Uri.parse('${AppConfig.baseUrl}/resultadmin/api/publish-result/');

    try {
      final response = await http.post(url, headers: _headers, body: body);
      Navigator.of(context).pop(); // Dismiss Dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Result Published Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh local data
        fetchResult();
      } else {
        final resData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['error'] ?? 'Failed to publish result.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- HELPER METHODS ---

  void _populateFields(Map<String, dynamic> data) {
    firstCtrl.text = data['first']?.toString() ?? '';
    secondCtrl.text = data['second']?.toString() ?? '';
    thirdCtrl.text = data['third']?.toString() ?? '';
    fourthCtrl.text = data['fourth']?.toString() ?? '';
    fifthCtrl.text = data['fifth']?.toString() ?? '';

    String rawGuarantees = data['guarantees']?.toString() ?? '';
    List<String> parsedGuarantees = rawGuarantees.isNotEmpty
        ? rawGuarantees.split(',').map((e) => e.trim()).toList()
        : [];

    for (int i = 0; i < guaranteeCtrls.length; i++) {
      guaranteeCtrls[i].text = i < parsedGuarantees.length ? parsedGuarantees[i] : '';
    }

    // Check if all 5 main inputs and all 30 guarantee fields were filled
    bool topFiveFilled = firstCtrl.text.trim().isNotEmpty &&
        secondCtrl.text.trim().isNotEmpty &&
        thirdCtrl.text.trim().isNotEmpty &&
        fourthCtrl.text.trim().isNotEmpty &&
        fifthCtrl.text.trim().isNotEmpty;

    bool allGuaranteesFilled = parsedGuarantees.length == 30 &&
        parsedGuarantees.every((g) => g.isNotEmpty);

    setState(() {
      _isFullyPublished = topFiveFilled && allGuaranteesFilled;
      resultData = {
        'first': firstCtrl.text,
        'second': secondCtrl.text,
        'third': thirdCtrl.text,
        'fourth': fourthCtrl.text,
        'fifth': fifthCtrl.text,
      };
      guaranteeNumbers = parsedGuarantees;
    });
  }

  void _clearFields() {
    firstCtrl.clear();
    secondCtrl.clear();
    thirdCtrl.clear();
    fourthCtrl.clear();
    fifthCtrl.clear();
    for (var c in guaranteeCtrls) {
      c.clear();
    }
    setState(() {
      _isFullyPublished = false;
      resultData = {};
      guaranteeNumbers = [];
    });
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      fetchResult(); // Trigger API update on date change
    }
  }

  Future<void> pasteFromWhatsapp() async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) return;

    String text = data.text!.trim();
    final regex = RegExp(r'\b\d{3}\b');
    final matches = regex.allMatches(text).map((m) => m.group(0)!).toList();

    if (matches.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not enough 3-digit numbers found in clipboard"),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    firstCtrl.text = matches[0];
    secondCtrl.text = matches[1];
    thirdCtrl.text = matches[2];
    fourthCtrl.text = matches[3];
    fifthCtrl.text = matches[4];

    final extractedGuarantees = matches.sublist(5);
    for (int i = 0; i < guaranteeCtrls.length; i++) {
      guaranteeCtrls[i].text = i < extractedGuarantees.length ? extractedGuarantees[i] : "";
    }

    setState(() {
      resultData = {
        'first': firstCtrl.text,
        'second': secondCtrl.text,
        'third': thirdCtrl.text,
        'fourth': fourthCtrl.text,
        'fifth': fifthCtrl.text,
      };
      guaranteeNumbers = extractedGuarantees;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Results Table',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17.0, color: Color(0xFF1E1E24)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.copy,
              color: Color(0xFF00ACC1),
              size: 22,
            ),
            onPressed: pasteFromWhatsapp,
          ),
          IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366),
              size: 22,
            ),
            onPressed: () async {
              if (resultData.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No result to share!')),
                );
                return;
              }

              final dateStr = DateFormat("MMM. d, yyyy").format(selectedDate);
              final currentGame = _fetchedTimesList.firstWhere(
                (g) => g['id'].toString() == _selectedTimeId,
                orElse: () => {},
              );
              final gameTime = currentGame['game_time']?.toString() ?? widget.gameTimeLabel;

              final buffer = StringBuffer();
              buffer.writeln('$dateStr - $gameTime');
              buffer.writeln('');
              buffer.writeln('1 : ${firstCtrl.text.isNotEmpty ? firstCtrl.text : '-'}');
              buffer.writeln('2 : ${secondCtrl.text.isNotEmpty ? secondCtrl.text : '-'}');
              buffer.writeln('3 : ${thirdCtrl.text.isNotEmpty ? thirdCtrl.text : '-'}');
              buffer.writeln('4 : ${fourthCtrl.text.isNotEmpty ? fourthCtrl.text : '-'}');
              buffer.writeln('5 : ${fifthCtrl.text.isNotEmpty ? fifthCtrl.text : '-'}');
              buffer.writeln('');

              final currentGuarantees = guaranteeCtrls
                  .map((c) => c.text.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();

              const perRow = 6;
              for (int i = 0; i < currentGuarantees.length; i += perRow) {
                final row = currentGuarantees
                    .skip(i)
                    .take(perRow)
                    .map((n) => n.padRight(4))
                    .join('  ');
                buffer.writeln(row);
              }

              final Uri whatsappUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');
              if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open WhatsApp')),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdowns & Date Selector Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _isTimesLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedTimeId,
                              items: _fetchedTimesList.map<DropdownMenuItem<String>>((g) {
                                return DropdownMenuItem<String>(
                                  value: g['id'].toString(),
                                  child: Text(
                                    g['game_time']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() => _selectedTimeId = v);
                                fetchResult(); // Trigger API update on game selection
                              },
                              decoration: InputDecoration(
                                labelText: 'Select Game',
                                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Results Container (Top 5 Positions)
              _isResultLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator(color: Colors.amber)),
                    )
                  : Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFCA28),
                                Color(0xFFFFB300),
                                Color(0xFFFFA000),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB300).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          child: Column(
                            children: List.generate(5, (i) {
                              final ctrls = [firstCtrl, secondCtrl, thirdCtrl, fourthCtrl, fifthCtrl];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${i + 1} : ',
                                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: ctrls[i],
                                        focusNode: allFocusNodes[i],
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(3),
                                        ],
                                        onChanged: (val) {
                                          if (val.length == 3) {
                                            FocusScope.of(context).requestFocus(allFocusNodes[i + 1]);
                                          }
                                        },
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          fillColor: Colors.white,
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(color: Colors.amber.shade700, width: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Guarantee Matrix (30 Fields)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFECB3)),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: guaranteeCtrls.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 8,
                              childAspectRatio: 3.2,
                            ),
                            itemBuilder: (context, index) {
                              return TextField(
                                controller: guaranteeCtrls[index],
                                focusNode: allFocusNodes[index + 5],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onChanged: (val) {
                                  if (val.length == 3 && index + 6 < allFocusNodes.length) {
                                    FocusScope.of(context).requestFocus(allFocusNodes[index + 6]);
                                  }
                                },
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFFFD54F), width: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),

              // Publish Action Button
              ElevatedButton(
                onPressed: publishResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'Publish Result',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}