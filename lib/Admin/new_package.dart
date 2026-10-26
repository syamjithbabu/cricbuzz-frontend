import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class NewPackagePage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;
  final Map<String, dynamic>? packageData; // Added parameter to capture runtime data payload

  const NewPackagePage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
    this.packageData, // Optional argument
  }) : super(key: key);

  @override
  State<NewPackagePage> createState() => _NewPackagePageState();
}

class _NewPackagePageState extends State<NewPackagePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;

  // Form Field Controllers
  late TextEditingController _packageNameController;

  // Ticket Controllers
  late TextEditingController singleRate;
  late TextEditingController singleDc;
  late TextEditingController doubleRate;
  late TextEditingController doubleDc;
  late TextEditingController superRate;
  late TextEditingController superDc;
  late TextEditingController boxRate;
  late TextEditingController boxDc;
  late TextEditingController singleRetailRate;
  late TextEditingController doubleRetailRate;
  late TextEditingController superRetailRate;
  late TextEditingController boxRetailRate;

  // Win Price Controllers
  late TextEditingController firstWin;
  late TextEditingController firstDc;
  late TextEditingController secondWin;
  late TextEditingController secondDc;
  late TextEditingController thirdWin;
  late TextEditingController thirdDc;
  late TextEditingController fourthWin;
  late TextEditingController fourthDc;
  late TextEditingController fifthWin;
  late TextEditingController fifthDc;
  late TextEditingController guaranteeWin;
  late TextEditingController guaranteeDc;
  late TextEditingController boxFirstWin;
  late TextEditingController boxFirstDc;
  late TextEditingController boxSeriesWin;
  late TextEditingController boxSeriesDc;
  late TextEditingController singleWin;
  late TextEditingController singleWinDc;
  late TextEditingController doubleWin;
  late TextEditingController doubleWinDc;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.packageData != null;
    var data = widget.packageData;

    // Checks if edit model runtime exists; maps old attributes or populates default values
    _packageNameController = TextEditingController(text: _isEditMode ? data!['package_name']?.toString() : "");
    singleRate = TextEditingController(text: _isEditMode ? data!['single_rate']?.toString() : "12");
    singleDc = TextEditingController(text: _isEditMode ? data!['single_dc']?.toString() : "1.5");
    doubleRate = TextEditingController(text: _isEditMode ? data!['double_rate']?.toString() : "10");
    doubleDc = TextEditingController(text: _isEditMode ? data!['double_dc']?.toString() : "2");
    superRate = TextEditingController(text: _isEditMode ? data!['super_rate']?.toString() : "10");
    superDc = TextEditingController(text: _isEditMode ? data!['super_dc']?.toString() : "2");
    boxRate = TextEditingController(text: _isEditMode ? data!['box_rate']?.toString() : "10");
    boxDc = TextEditingController(text: _isEditMode ? data!['box_dc']?.toString() : "2");

    singleRetailRate = TextEditingController(text: _isEditMode ? data!['single_retail_rate']?.toString() : "14");
    doubleRetailRate = TextEditingController(text: _isEditMode ? data!['double_retail_rate']?.toString() : "14");
    superRetailRate = TextEditingController(text: _isEditMode ? data!['super_retail_rate']?.toString() : "14");
    boxRetailRate = TextEditingController(text: _isEditMode ? data!['box_retail_rate']?.toString() : "14");

    firstWin = TextEditingController(text: _isEditMode ? data!['first_win']?.toString() : "5000");
    firstDc = TextEditingController(text: _isEditMode ? data!['first_dc']?.toString() : "400");
    secondWin = TextEditingController(text: _isEditMode ? data!['second_win']?.toString() : "500");
    secondDc = TextEditingController(text: _isEditMode ? data!['second_dc']?.toString() : "50");
    thirdWin = TextEditingController(text: _isEditMode ? data!['third_win']?.toString() : "250");
    thirdDc = TextEditingController(text: _isEditMode ? data!['third_dc']?.toString() : "20");
    fourthWin = TextEditingController(text: _isEditMode ? data!['fourth_win']?.toString() : "100");
    fourthDc = TextEditingController(text: _isEditMode ? data!['fourth_dc']?.toString() : "20");
    fifthWin = TextEditingController(text: _isEditMode ? data!['fifth_win']?.toString() : "50");
    fifthDc = TextEditingController(text: _isEditMode ? data!['fifth_dc']?.toString() : "20");
    guaranteeWin = TextEditingController(text: _isEditMode ? data!['guarantee_win']?.toString() : "20");
    guaranteeDc = TextEditingController(text: _isEditMode ? data!['guarantee_dc']?.toString() : "10");
    boxFirstWin = TextEditingController(text: _isEditMode ? data!['box_first_win']?.toString() : "3000");
    boxFirstDc = TextEditingController(text: _isEditMode ? data!['box_first_dc']?.toString() : "300");
    boxSeriesWin = TextEditingController(text: _isEditMode ? data!['box_series_win']?.toString() : "800");
    boxSeriesDc = TextEditingController(text: _isEditMode ? data!['box_series_dc']?.toString() : "30");
    singleWin = TextEditingController(text: _isEditMode ? data!['single_win']?.toString() : "100");
    singleWinDc = TextEditingController(text: _isEditMode ? data!['single_win_dc']?.toString() : "0");
    doubleWin = TextEditingController(text: _isEditMode ? data!['double_win']?.toString() : "700");
    doubleWinDc = TextEditingController(text: _isEditMode ? data!['double_win_dc']?.toString() : "30");
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    singleRate.dispose(); singleDc.dispose(); doubleRate.dispose(); doubleDc.dispose();
    superRate.dispose(); superDc.dispose(); boxRate.dispose(); boxDc.dispose();
    firstWin.dispose(); firstDc.dispose(); secondWin.dispose(); secondDc.dispose();
    thirdWin.dispose(); thirdDc.dispose(); fourthWin.dispose(); fourthDc.dispose();
    fifthWin.dispose(); fifthDc.dispose(); guaranteeWin.dispose(); guaranteeDc.dispose();
    boxFirstWin.dispose(); boxFirstDc.dispose(); boxSeriesWin.dispose(); boxSeriesDc.dispose();
    singleWin.dispose(); singleWinDc.dispose(); doubleWin.dispose(); doubleWinDc.dispose();
    super.dispose();
  }

  Future<void> _savePackage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final Map<String, dynamic> bodyData = {
      "package_name": _packageNameController.text.trim(),
      "single_rate": double.tryParse(singleRate.text) ?? 0.0,
      "single_dc": double.tryParse(singleDc.text) ?? 0.0,
      "double_rate": double.tryParse(doubleRate.text) ?? 0.0,
      "double_dc": double.tryParse(doubleDc.text) ?? 0.0,
      "super_rate": double.tryParse(superRate.text) ?? 0.0,
      "super_dc": double.tryParse(superDc.text) ?? 0.0,
      "box_rate": double.tryParse(boxRate.text) ?? 0.0,
      "box_dc": double.tryParse(boxDc.text) ?? 0.0,

      "single_retail_rate": double.tryParse(singleRetailRate.text) ?? 0.0,
      "double_retail_rate": double.tryParse(doubleRetailRate.text) ?? 0.0,
      "super_retail_rate": double.tryParse(superRetailRate.text) ?? 0.0,
      "box_retail_rate": double.tryParse(boxRetailRate.text) ?? 0.0,

      "first_win": double.tryParse(firstWin.text) ?? 0.0,
      "first_dc": double.tryParse(firstDc.text) ?? 0.0,
      "second_win": double.tryParse(secondWin.text) ?? 0.0,
      "second_dc": double.tryParse(secondDc.text) ?? 0.0,
      "third_win": double.tryParse(thirdWin.text) ?? 0.0,
      "third_dc": double.tryParse(thirdDc.text) ?? 0.0,
      "fourth_win": double.tryParse(fourthWin.text) ?? 0.0,
      "fourth_dc": double.tryParse(fourthDc.text) ?? 0.0,
      "fifth_win": double.tryParse(fifthWin.text) ?? 0.0,
      "fifth_dc": double.tryParse(fifthDc.text) ?? 0.0,
      "guarantee_win": double.tryParse(guaranteeWin.text) ?? 0.0,
      "guarantee_dc": double.tryParse(guaranteeDc.text) ?? 0.0,
      "box_first_win": double.tryParse(boxFirstWin.text) ?? 0.0,
      "box_first_dc": double.tryParse(boxFirstDc.text) ?? 0.0,
      "box_series_win": double.tryParse(boxSeriesWin.text) ?? 0.0,
      "box_series_dc": double.tryParse(boxSeriesDc.text) ?? 0.0,
      "single_win": double.tryParse(singleWin.text) ?? 0.0,
      "single_win_dc": double.tryParse(singleWinDc.text) ?? 0.0,
      "double_win": double.tryParse(doubleWin.text) ?? 0.0,
      "double_win_dc": double.tryParse(doubleWinDc.text) ?? 0.0,
    };

    try {
      // Direct routing selection: PUT if edit mode exists, otherwise standard collection POST
      final url = _isEditMode 
          ? '${AppConfig.baseUrl}/adminapp/api/packages/${widget.packageData!['id']}/'
          : '${AppConfig.baseUrl}/adminapp/api/packages/';

      final response = await (_isEditMode 
          ? http.put(Uri.parse(url), headers: _headers(), body: jsonEncode(bodyData))
          : http.post(Uri.parse(url), headers: _headers(), body: jsonEncode(bodyData)));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Package updated successfully!' : 'Package saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Send true value back upon exit to signal reload execution
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save package: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network communication error.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  TableRow _buildRow(String cellText, TextEditingController c1, TextEditingController c2) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(cellText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextFormField(controller: c1, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextFormField(controller: c2, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
      ],
    );
  }

  TableRow _buildRowTickets(String cellText, TextEditingController c1, TextEditingController c2, TextEditingController c3) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(cellText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextFormField(controller: c1, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextFormField(controller: c2, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextFormField(controller: c3, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {}),
        title: const Text('New Package', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.home, color: Colors.white), onPressed: () => Navigator.pop(context)),
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NAME', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                          TextFormField(
                            controller: _packageNameController,
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSectionHeader('TICKET PRICE DETAILS'),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0)},
                      border: TableBorder.all(color: Colors.grey[200]!, width: 1.0),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[200]),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('TICKET', style: TextStyle(fontWeight: FontWeight.w500))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('RATE', style: TextStyle(fontWeight: FontWeight.w500))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('DC', style: TextStyle(fontWeight: FontWeight.w500))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('R. RATE', style: TextStyle(fontWeight: FontWeight.w500))),
                          ],
                        ),
                        _buildRowTickets('SINGLE(1)', singleRate, singleDc, singleRetailRate),
                        _buildRowTickets('DOUBLE(2)', doubleRate, doubleDc, doubleRetailRate),
                        _buildRowTickets('LSK SUPER', superRate, superDc, superRetailRate),
                        _buildRowTickets('BOX', boxRate, boxDc, boxRetailRate),
                      ],
                    ),
                    _buildSectionHeader('WIN PRICE'),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0)},
                      border: TableBorder.all(color: Colors.grey[200]!, width: 1.0),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[200]),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('POSITION', style: TextStyle(fontWeight: FontWeight.w500))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('WIN PRICE', style: TextStyle(fontWeight: FontWeight.w500))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('DC', style: TextStyle(fontWeight: FontWeight.w500))),
                          ],
                        ),
                        _buildRow('FIRST', firstWin, firstDc),
                        _buildRow('SECOND', secondWin, secondDc),
                        _buildRow('THIRD', thirdWin, thirdDc),
                        _buildRow('FOURT', fourthWin, fourthDc),
                        _buildRow('FIVE', fifthWin, fifthDc),
                        _buildRow('GUARANTEE (SIX)', guaranteeWin, guaranteeDc),
                        _buildRow('BOX FIRST PRICE', boxFirstWin, boxFirstDc),
                        _buildRow('BOX SERIES', boxSeriesWin, boxSeriesDc),
                        _buildRow('SINGLE(1)', singleWin, singleWinDc),
                        _buildRow('DOUBLE(2)', doubleWin, doubleWinDc),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _isSaving ? null : _savePackage,
              child: Container(
                width: double.infinity,
                height: 50,
                color: widget.themeColor, // Preserved exact dynamic structural theme property usage here
                alignment: Alignment.center,
                child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_isEditMode ? 'UPDATE' : 'UPDATE', style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}