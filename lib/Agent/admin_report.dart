import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Agent/home.dart';
import 'package:cricbuzz/Agent/select_time.dart';

class AdminReportPage extends StatefulWidget {
  final Color themeColor; // Dynamically passed down from previous pages
  final int gameTimeId;
  final String gameTimeLabel;

  const AdminReportPage({Key? key, required this.themeColor, required this.gameTimeId, required this.gameTimeLabel,}) : super(key: key);

  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  // State variables for form elements
  String? _selectedTime = 'KL 3:00PM'; // Default selection point matches list format

  // Setting initial values to match current date system defaults
  DateTime _fromDate = DateTime(2026, 6, 8);
  DateTime _toDate = DateTime(2026, 6, 8);

  // Updated requested list string configurations
  final List<String> _timesList = ['1:00PM', 'KL 3:00PM', '6:00PM', '8:00PM'];

  // Helper method to open the Flutter Date Picker dialog
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
                builder: (context) => AgentHomePage(themeColor: widget.themeColor, gameTimeId: widget.gameTimeId, gameTimeLabel: widget.gameTimeLabel,),
              ),
            );
          },
        ),
        title: const Text(
          'Admin Report',
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
                MaterialPageRoute(builder: (context) => SelectTimePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // --- BODY LAYOUT CONTENT ---
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FROM DATE AND TO DATE ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // From Date Picker
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.42,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedFromDate,
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                            ],
                          ),
                        ),
                      ),
                      // To Date Picker
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.42,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedToDate,
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              const Divider(color: Colors.grey, thickness: 0.6, height: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. NEW STRIPPED TIME DROPDOWN & SEARCH ACTION ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Formatted Time Selection Dropdown Container replacing plain text element
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTime,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 0.5),
                            ),
                          ),
                          items: _timesList.map((String time) {
                            return DropdownMenuItem<String>(
                              value: time,
                              child: Text(
                                time,
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedTime = value),
                        ),
                      ),
                      const SizedBox(width: 40),
                      // Search Action Target Button 
                      ElevatedButton(
                        onPressed: () {
                          // Perform Search Data Query Operations here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'SEARCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 3. UPDATED ADMIN REPORT LAYOUT TABLE HEADER ROW
                  Container(
                    color: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 11,
                          child: Text(
                            'DATE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 12,
                          child: Text(
                            'T.SALE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 11,
                          child: Text(
                            'T.WIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 12,
                          child: Text(
                            'C.SALE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 11,
                          child: Text(
                            'C.WIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 15,
                          child: Text(
                            'BALANCE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM FIXED STATISTICAL FOOTER BAR ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'SALES AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '0',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'WIN AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '0',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'BALANCE',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '0',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
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