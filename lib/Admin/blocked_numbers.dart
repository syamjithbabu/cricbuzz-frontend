import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:cricbuzz/Admin/create_blocked_number.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class BlockNumbersPage extends StatefulWidget {
  final Color themeColor; 
  final int gameTimeId;
  final String gameTimeLabel;

  const BlockNumbersPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<BlockNumbersPage> createState() => _BlockNumbersPageState();
}

class _BlockNumbersPageState extends State<BlockNumbersPage> {
  List<dynamic> blockedNumbersList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBlockedNumbers();
  }

  // Reusing your app authorization tokens and content headers 
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  // Fetch blocked data from Django Backend filtered by game time if applicable
  Future<void> fetchBlockedNumbers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/blocked-numbers/${widget.gameTimeId}/');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        setState(() {
          blockedNumbersList = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load blocked numbers (${response.statusCode})';
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

  // Persist Delete request to Django 
  Future<void> deleteBlockedNumberRequest(int blockId, int listIndex) async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/blocked-numbers/delete/$blockId/');

    try {
      final response = await http.delete(url, headers: _headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          blockedNumbersList.removeAt(listIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blocked number deleted successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to delete resource');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting target record'), backgroundColor: Colors.red),
      );
    }
  }

  // Confirmation Dialogue before deleting items
  void showDeleteConfirmationDialog(Map<String, dynamic> item, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Blocked Number?'),
          content: Text('Are you sure you want to permanently delete the blocked number "${item['no'] ?? 'this number'}" for user "${item['user'] ?? 'NULL'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteBlockedNumberRequest(item['id'], index);
              },
              child: const Text(
                'DELETE',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              builder: (context) => AdminHomePage(
                themeColor: widget.themeColor,
                gameTimeId: widget.gameTimeId,
                gameTimeLabel: widget.gameTimeLabel,
              ),
            ),
          ),
        ),
        title: const Text(
          'Blocked Numbers',
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectTimePage()));
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateBlockNumberPage(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),
              ).then((_) => fetchBlockedNumbers()); 
            },
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminHomePage(
                  themeColor: widget.themeColor,
                  gameTimeId: widget.gameTimeId,
                  gameTimeLabel: widget.gameTimeLabel,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: fetchBlockedNumbers,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2), // USER
                          1: FlexColumnWidth(1.2), // LSK
                          2: FlexColumnWidth(1.0), // NO
                          3: FlexColumnWidth(1.0), // COUNT
                          4: FlexColumnWidth(0.5), // Action field
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), child: Text('USER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), child: Text('LSK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), child: Text('NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), child: Text('COUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                            ],
                          ),
                          
                          ...blockedNumbersList.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var item = entry.value;
                            return TableRow(
                              children: [
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(item['user'] ?? 'NULL', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(item['lsk'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(item['no'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(item['count'] ?? '0', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.center,
                                  child: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red[400],
                                      size: 18,
                                    ),
                                    onPressed: () => showDeleteConfirmationDialog(item, idx),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}