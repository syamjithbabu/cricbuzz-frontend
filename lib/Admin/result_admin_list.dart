import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:cricbuzz/Admin/create_result_admin.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class ResultAdminList extends StatefulWidget {
  final Color themeColor; 
  final int gameTimeId;
  final String gameTimeLabel;

  const ResultAdminList({
    Key? key, 
    required this.themeColor, 
    required this.gameTimeId, 
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<ResultAdminList> createState() => _ResultAdminListState();
}

class _ResultAdminListState extends State<ResultAdminList> {
  List<dynamic> adminList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchResultAdmins();
  }

  // Helper configuration helper headers
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  // Fetch data from Django backend
  Future<void> fetchResultAdmins() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/result-admins/');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        setState(() {
          adminList = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load admins (${response.statusCode})';
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

  // Update Password API Call
  Future<void> updatePassword(int adminId, String newPassword, int listIndex) async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/update-password/$adminId/');

    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'password': newPassword}),
      );

      if (response.statusCode == 200) {
        setState(() {
          adminList[listIndex]['password'] = newPassword;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to update password');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating password'), backgroundColor: Colors.red),
      );
    }
  }

  // Persist Block/Unblock toggle step to Django
  Future<void> sendBlockToggleRequest(int adminId, bool targetsBlockState, int listIndex) async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/toggle-block/$adminId/');

    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'isBlocked': targetsBlockState}),
      );

      if (response.statusCode == 200) {
        setState(() {
          adminList[listIndex]['isBlocked'] = targetsBlockState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetsBlockState ? 'Admin blocked successfully' : 'Admin unblocked successfully'),
            backgroundColor: targetsBlockState ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
      );
    }
  }

  // Modal Dialog UI to edit Password with Confirmation Check
  void showEditPasswordModal(Map<String, dynamic> admin, int index) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Password for ${admin['username']}', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // New Password Field
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.trim().length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value.trim() != passwordController.text.trim()) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
              onPressed: () {
                // Triggers validator logic across both TextFormFields
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  updatePassword(admin['id'], passwordController.text.trim(), index);
                }
              },
              child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Confirmation Alert Dialog for Block/Unblock status adjustments
  void showBlockConfirmationDialog(Map<String, dynamic> admin, int index) {
    final bool currentBlockStatus = admin['isBlocked'] == true;
    final String dialogueActionLabel = currentBlockStatus ? "UNBLOCK" : "BLOCK";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$dialogueActionLabel User?'),
          content: Text('Are you sure you want to $dialogueActionLabel result admin "${admin['username']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('NO', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                sendBlockToggleRequest(admin['id'], !currentBlockStatus, index);
              },
              child: Text(
                'YES, $dialogueActionLabel',
                style: TextStyle(color: currentBlockStatus ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
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
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
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
            const Text(
              'Result Admins',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateResultAdminPage(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),
              ).then((_) => fetchResultAdmins());
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SelectTimePage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: fetchResultAdmins,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.3),
                          1: FlexColumnWidth(1.1),
                          2: FlexColumnWidth(0.7),
                          3: FlexColumnWidth(0.5),
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('USERNAME', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('EDIT', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                            ],
                          ),
                          ...adminList.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var admin = entry.value;
                            return TableRow(
                              children: [
                                Container(
                                  height: 28, 
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(admin['username'] ?? '', style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w500, fontSize: 15)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(admin['password'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: GestureDetector(
                                    onTap: () => showEditPasswordModal(admin, idx),
                                    child: const Text('EDIT', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w500, fontSize: 14)),
                                  ),
                                ),
                                Container(
                                  height: 28,
                                  alignment: Alignment.center,
                                  child: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      admin['isBlocked'] == true ? Icons.lock : Icons.lock_open,
                                      color: admin['isBlocked'] == true ? Colors.red[700] : Colors.grey[400],
                                      size: 18,
                                    ),
                                    onPressed: () => showBlockConfirmationDialog(admin, idx),
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