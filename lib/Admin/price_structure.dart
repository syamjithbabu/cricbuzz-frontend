import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:cricbuzz/Admin/home.dart';
import 'package:cricbuzz/Admin/select_time.dart';
import 'package:cricbuzz/Admin/new_package.dart';

class PriceStructurePage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const PriceStructurePage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<PriceStructurePage> createState() => _PriceStructurePageState();
}

class _PriceStructurePageState extends State<PriceStructurePage> {
  List<dynamic> packageList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  // 1. READ: Fetch all packages from Django REST Framework
  Future<void> _fetchPackages() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/packages/'), // Adjust path prefix if using /adminapp/api/packages/
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          packageList = jsonDecode(response.body);
        });
      } else {
        _showSnackBar('Failed to load packages: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network communication error.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. DELETE: Remove package via API
  Future<void> _deletePackage(int packageId, int index) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/packages/$packageId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${MySession.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          packageList.removeAt(index);
        });
        _showSnackBar('Package deleted successfully!', Colors.green);
      } else {
        _showSnackBar('Delete failed: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error while deleting.', Colors.red);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  // Logic to show delete confirmation sheet
  void showDeleteConfirmation(Map<String, dynamic> package, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Package?'),
          content: Text('Are you sure you want to completely remove "${package['package_name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('NO', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePackage(package['id'], index);
              },
              child: const Text('YES, DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        elevation: 1,
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
        title: const Text('Packages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            onPressed: () async {
              // Wait for NewPackagePage to close and refresh data if new package saved
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewPackagePage(
                    themeColor: widget.themeColor,
                    gameTimeId: widget.gameTimeId,
                    gameTimeLabel: widget.gameTimeLabel,
                  ),
                ),
              );
              _fetchPackages(); 
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectTimePage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : packageList.isEmpty
              ? const Center(child: Text('No packages found.', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : RefreshIndicator(
                  onRefresh: _fetchPackages,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.0),
                          1: FlexColumnWidth(0.6),
                          2: FlexColumnWidth(0.4),
                        },
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1.0),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), 
                                child: Text('TITLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), 
                                child: Text('EDIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0), 
                                child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              ),
                            ],
                          ),
                          ...packageList.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var package = entry.value;
                            return TableRow(
                              children: [
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    package['package_name'] ?? '',
                                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  ),
                                ),
                                // Inside your PriceStructurePage's build layout table loop:
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () async {
                                      // Route over to NewPackagePage passing the full JSON data structure map
                                      bool? isUpdated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => NewPackagePage(
                                            themeColor: widget.themeColor,
                                            gameTimeId: widget.gameTimeId,
                                            gameTimeLabel: widget.gameTimeLabel,
                                            packageData: package, // <--- Passes the package map structure here
                                          ),
                                        ),
                                      );

                                      // Refresh list dynamic array feed if package updated cleanly
                                      if (isUpdated == true) {
                                        _fetchPackages();
                                      }
                                    },
                                    child: const Text(
                                      'EDIT', 
                                      style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 18),
                                    onPressed: () => showDeleteConfirmation(package, idx),
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