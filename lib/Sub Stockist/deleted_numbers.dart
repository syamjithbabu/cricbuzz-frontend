import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeletedNumbersPage extends StatefulWidget {
  final Color themeColor; // Matches your app's primary color palette (e.g., Color(0xFF00695C))
  final int gameTimeId;
  final String gameTimeLabel;

  const DeletedNumbersPage({Key? key, required this.themeColor, required this.gameTimeId, required this.gameTimeLabel,}) : super(key: key);

  @override
  State<DeletedNumbersPage> createState() => _DeletedNumbersPageState();
}

class _DeletedNumbersPageState extends State<DeletedNumbersPage> {
  // --- STATE MANAGEMENT VARIABLES ---
  DateTime _selectedDate = DateTime(2026, 6, 9);

  // --- MOCK TABLE DATA EMPTY STATE TEMPLATE ---
  // Ready to handle incoming backend data payload dictionaries matching headers
  final List<Map<String, String>> _deletedNumbersData = [];

  // Native Date Picker Dialog Builder
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,

      // --- APPBAR LAYOUT ---
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: const Text(
          'Deleted Numbers',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),

      // --- MAIN BODY CONTENT ---
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DATE CALENDAR TARGET & ACTION SEARCH BUTTON ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end, // Aligns button exactly to baseline setup
                    children: [
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.44,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              const Divider(
                                color: Colors.grey,
                                thickness: 0.6,
                                height: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Perform background data queries/filtering routines here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

                  // --- GRID DATA HEADER ROW ---
                  Container(
                    color: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                    child: Row(
                      children: const [
                        Expanded(flex: 2, child: Text('BILL', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('LSK', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
                        Expanded(flex: 3, child: Text('TICKET', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('COUNT', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('TIME', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87), textAlign: TextAlign.end)),
                      ],
                    ),
                  ),

                  // --- DATA ROWS MAPPER (EMPTY STATE OR POPULATED LIST) ---
                  _deletedNumbersData.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _deletedNumbersData.length,
                          itemBuilder: (context, index) {
                            final item = _deletedNumbersData[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(item["BILL"]!, style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Text(item["LSK"]!, style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 3, child: Text(item["TICKET"]!, style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Text(item["COUNT"]!, style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Text(item["TIME"]!, style: const TextStyle(fontSize: 13), textAlign: TextAlign.end)),
                                ],
                              ),
                            );
                          },
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