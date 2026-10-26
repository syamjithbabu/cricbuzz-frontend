import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:cricbuzz/Admin/create_manager.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class ManagerList extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const ManagerList({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<ManagerList> createState() => _ManagerListState();
}

class _ManagerListState extends State<ManagerList> {
  List<dynamic> adminList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchManager();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Future<void> fetchManager() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/managers/');

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

  // Fetch package details for a specific manager and trigger edit modal
  Future<void> fetchAndShowManagerPackage(int managerId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/manager-package/$managerId/');

    try {
      final response = await http.get(url, headers: _headers);
      Navigator.pop(context); // Dismiss loading spinner

      if (response.statusCode == 200) {
        final packageData = json.decode(response.body);
        _showEditPackageModal(managerId, packageData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load manager package details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Dismiss loading spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error fetching package details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Modal Dialog UI to edit package configuration
  void _showEditPackageModal(int managerId, Map<String, dynamic> pkg) {
    final controllers = <String, TextEditingController>{};

    TextEditingController getController(String key) {
      return controllers.putIfAbsent(
        key,
        () => TextEditingController(text: pkg[key]?.toString() ?? '0.0'),
      );
    }

    Widget buildInputCell(String key) {
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: TextFormField(
          controller: getController(key),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: OutlineInputBorder(),
          ),
        ),
      );
    }

    TableRow buildRowTickets(String label, String rateKey, String dcKey, String retailRateKey) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          buildInputCell(rateKey),
          buildInputCell(dcKey),
          buildInputCell(retailRateKey),
        ],
      );
    }

    TableRow buildRowWin(String label, String winKey, String dcKey) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          buildInputCell(winKey),
          buildInputCell(dcKey),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> savePackage() async {
              setModalState(() => isSaving = true);

              final bodyData = <String, dynamic>{};
              controllers.forEach((key, controller) {
                bodyData[key] = double.tryParse(controller.text.trim()) ?? 0.0;
              });

              final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/manager-package/$managerId/');

              try {
                final response = await http.put(
                  url,
                  headers: _headers,
                  body: jsonEncode(bodyData),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Package updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update package: ${response.body}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Network communication error.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setModalState(() => isSaving = false);
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.all(12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: const Text('Edit Package Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.5),
                          1: FlexColumnWidth(1.0),
                          2: FlexColumnWidth(1.0),
                          3: FlexColumnWidth(1.0),
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            children: const [
                              Padding(padding: EdgeInsets.all(6.0), child: Text('TICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text('RATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text('DC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text('R. RATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          buildRowTickets('SINGLE(1)', 'single_rate', 'single_dc', 'single_retail_rate'),
                          buildRowTickets('DOUBLE(2)', 'double_rate', 'double_dc', 'double_retail_rate'),
                          buildRowTickets('LSK SUPER', 'super_rate', 'super_dc', 'super_retail_rate'),
                          buildRowTickets('BOX', 'box_rate', 'box_dc', 'box_retail_rate'),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        color: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: const Text('WIN PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.5),
                          1: FlexColumnWidth(1.0),
                          2: FlexColumnWidth(1.0),
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            children: const [
                              Padding(padding: EdgeInsets.all(6.0), child: Text('POSITION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text('WIN PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text('DC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          buildRowWin('FIRST', 'first_win', 'first_dc'),
                          buildRowWin('SECOND', 'second_win', 'second_dc'),
                          buildRowWin('THIRD', 'third_win', 'third_dc'),
                          buildRowWin('FOURTH', 'fourth_win', 'fourth_dc'),
                          buildRowWin('FIFTH', 'fifth_win', 'fifth_dc'),
                          buildRowWin('GUARANTEE', 'guarantee_win', 'guarantee_dc'),
                          buildRowWin('BOX FIRST', 'box_first_win', 'box_first_dc'),
                          buildRowWin('BOX SERIES', 'box_series_win', 'box_series_dc'),
                          buildRowWin('SINGLE(1)', 'single_win', 'single_win_dc'),
                          buildRowWin('DOUBLE(2)', 'double_win', 'double_win_dc'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
                  onPressed: isSaving ? null : savePackage,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('UPDATE', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> updatePassword(int adminId, String newPassword, int listIndex) async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/update-password-manager/$adminId/');

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
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update password');
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

  Future<void> sendBlockToggleRequest(int adminId, bool targetsBlockState, int listIndex) async {
    final url = Uri.parse('${AppConfig.baseUrl}/adminapp/api/toggle-block-manager/$adminId/');

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
            content: Text(
              targetsBlockState ? 'Admin blocked successfully' : 'Admin unblocked successfully',
            ),
            backgroundColor: targetsBlockState ? Colors.orange : Colors.green,
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

  void showBlockConfirmationDialog(Map<String, dynamic> admin, int index) {
    final bool currentBlockStatus = admin['isBlocked'] == true;
    final String dialogueActionLabel = currentBlockStatus ? "UNBLOCK" : "BLOCK";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$dialogueActionLabel User?'),
          content: Text('Are you sure you want to $dialogueActionLabel manager "${admin['username']}"?'),
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
                style: TextStyle(
                  color: currentBlockStatus ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
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
              'Manager',
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
                  builder: (context) => CreateManager(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),
              ).then((_) => fetchManager());
            },
          ),
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
                  onRefresh: fetchManager,
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
                          3: FlexColumnWidth(1.1),
                          4: FlexColumnWidth(0.5),
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('USERNAME', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('EDIT', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0), child: Text('PACKAGE', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
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
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: GestureDetector(
                                    onTap: () => fetchAndShowManagerPackage(admin['id']),
                                    child: const Text('PACKAGE', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w500, fontSize: 14)),
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