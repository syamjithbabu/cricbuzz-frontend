import 'package:cricbuzz/Dealer/home.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Dealer/select_time.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Dealer/create_agent.dart'; // Import creation page
import 'package:cricbuzz/Dealer/edit_agent.dart';

class AgentList extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const AgentList({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<AgentList> createState() => _AgentListState();
}

class _AgentListState extends State<AgentList> {
  List<dynamic> stockistList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchStockists();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Future<void> fetchStockists() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final url = Uri.parse('${AppConfig.baseUrl}/dealer/api/agents/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        setState(() {
          stockistList = json.decode(response.body);
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

  Future<void> updatePassword(int id, String newPassword, int listIndex) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/dealer/api/agents/$id/update-password/',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'password': newPassword}),
      );
      if (response.statusCode == 200) {
        setState(() {
          stockistList[listIndex]['password'] = newPassword;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating password'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> toggleBlockStatus(
    int id,
    bool currentStatus,
    int listIndex,
  ) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/dealer/api/agents/$id/toggle-block/',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'block': !currentStatus}),
      );
      if (response.statusCode == 200) {
        setState(() {
          stockistList[listIndex]['block'] = !currentStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus
                  ? 'Agent blocked successfully'
                  : 'Agent unblocked successfully',
            ),
            backgroundColor: !currentStatus ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showEditPasswordModal(Map<String, dynamic> stockist, int index) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Password for ${stockist['user']['username']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 4)
                      ? 'Minimum 4 characters required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value != passwordController.text)
                      ? 'Passwords do not match'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  updatePassword(
                    stockist['id'],
                    passwordController.text.trim(),
                    index,
                  );
                }
              },
              child: const Text(
                'UPDATE',
                style: TextStyle(color: Colors.white),
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
              builder: (context) => DealerHomePage(
                themeColor: widget.themeColor,
                gameTimeId: widget.gameTimeId,
                gameTimeLabel: widget.gameTimeLabel,
              ),
            ),
          ),
        ),
        title: const Text(
          'Agents',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateAgentPage(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),
              ).then((_) => fetchStockists());
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SelectTimePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchStockists,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(0.9),
                      2: FlexColumnWidth(1.4),
                      3: FlexColumnWidth(0.7),
                      4: FlexColumnWidth(0.4),
                    },
                    border: TableBorder.all(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      const TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              'USERNAME',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              'PASSWORD',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              'CATEGORY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              'EDIT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...stockistList.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var item = entry.value;
                        bool isBlocked = item['block'] ?? false;
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                item['user']['username'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(item['password'] ?? ''),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                item['package_name'] ?? 'Default Packages',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: GestureDetector(
                                onTap: () async {
                                  // 1. Extract the stockist ID from your item map/object
                                  final int stockistId = item['id']; 

                                  // 2. Navigate to the new isolated Edit Page
                                  bool? shouldRefresh = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditAgentPage(
                                        themeColor: widget.themeColor, // Pass your standard dashboard color
                                        stockistId: stockistId,
                                      ),
                                    ),
                                  );

                                  // 3. If they hit 'Update' and it returned true, refresh the list data here
                                  if (shouldRefresh == true) {
                                    // Call your list view's fetch function here, for example:
                                    // _fetchAgentList();
                                  }
                                },
                                child: const Text(
                                  'EDIT',
                                  style: TextStyle(
                                    color: Color(0xFF1E88E5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isBlocked ? Icons.lock : Icons.lock_open,
                                color: isBlocked ? Colors.red : Colors.grey,
                                size: 18,
                              ),
                              onPressed: () =>
                                  toggleBlockStatus(item['id'], isBlocked, idx),
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
