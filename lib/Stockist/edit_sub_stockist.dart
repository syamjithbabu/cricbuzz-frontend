import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class EditSubStockistPage extends StatefulWidget {
  final Color themeColor;
  final int stockistId; // Pass the target item ID directly to this frame

  const EditSubStockistPage({
    Key? key,
    required this.themeColor,
    required this.stockistId,
  }) : super(key: key);

  @override
  State<EditSubStockistPage> createState() => _EditSubStockistPageState();
}

class _EditSubStockistPageState extends State<EditSubStockistPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // UI Component State Flags
  bool isLoading = true;
  bool createDealer = false;
  bool enableBooking = false;
  bool _isSaving = false;

  List<dynamic> gameTimes = [];
  List<dynamic> packages = [];
  String? selectedPackage;

  // Holds data matrices mapping directly to dynamic game times
  Map<int, Map<String, TextEditingController>> numberLimits = {};
  Map<int, TextEditingController> salesLimits = {};
  Map<int, bool> appToggles = {};

  @override
  void initState() {
    super.initState();
    _fetchRequirementsAndPopulate();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    numberLimits.forEach((_, map) {
      map.forEach((_, controller) => controller.dispose());
    });
    salesLimits.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Future<void> _fetchRequirementsAndPopulate() async {
    try {
      // 1. Fetch Master structures metadata
      final timeRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}/stockist/api/game-times/'),
        headers: _headers,
      );
      final pkgRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}/stockist/api/packages/'),
        headers: _headers,
      );

      // 2. Fetch direct profile configurations for this targeted Stockist ID
      final stockistRes = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/stockist/api/sub-stockists/${widget.stockistId}/details/',
        ),
        headers: _headers,
      );

      if (timeRes.statusCode == 200 &&
          pkgRes.statusCode == 200 &&
          stockistRes.statusCode == 200) {
        final List fetchedTimes = json.decode(timeRes.body);
        final List fetchedPackages = json.decode(pkgRes.body);
        final Map<String, dynamic> data = json.decode(stockistRes.body);

        setState(() {
          gameTimes = fetchedTimes;
          packages = fetchedPackages;

          // Initialize tracking maps across all fetched game-times
          for (var time in gameTimes) {
            int id = time['id'];
            numberLimits[id] = {
              'Single': TextEditingController(),
              'Double': TextEditingController(),
              'Tripple': TextEditingController(),
              'Box': TextEditingController(),
            };
            salesLimits[id] = TextEditingController();
            appToggles[id] = false;
          }

          // Populate foundational Identity fields
          _usernameController.text = data['username'] ?? '';
          _passwordController.text = data['password'] ?? '';
          createDealer = data['create_dealer_stockist'] ?? false;
          enableBooking = data['enable_booking'] ?? false;

          // --- ROBUST PACKAGE PARSING ---
          // Captures 'package_id', 'package' as an ID, or 'package' as a nested Map object
          var rawPackage = data['package_id'] ?? data['package'];
          if (rawPackage is Map) {
            rawPackage = rawPackage['id'];
          }

          if (rawPackage != null) {
            String targetPackageId = rawPackage.toString();

            // Safety check: ensure this ID actually exists in the packages dropdown list
            bool packageExists = fetchedPackages.any(
              (pkg) => pkg['id'].toString() == targetPackageId,
            );
            if (packageExists) {
              selectedPackage = targetPackageId;
            }
          }

          print(selectedPackage);
          // --------------------------------

          // Normalize and read relation checkboxes
          List<dynamic> rawCheckedTimes = data['checked_times'] ?? [];
          List<int> checkedTimes = rawCheckedTimes
              .map((item) => int.tryParse(item.toString()) ?? 0)
              .where((id) => id != 0)
              .toList();

          for (var id in appToggles.keys) {
            appToggles[id] = checkedTimes.contains(id);
          }

          print("RAW LIMITS FROM BACKEND: ${data['limits']}");

          // Back-map existing numeric rule allocations
          List<dynamic> fetchedLimits = data['limits'] ?? [];
          for (var limitItem in fetchedLimits) {
            int timeId = limitItem['game_time_id'];
            if (numberLimits.containsKey(timeId)) {
              // If the value is null, text controller gets '', otherwise string value
              numberLimits[timeId]?['Single']?.text = limitItem['single_limit']?.toString() ?? '';
              numberLimits[timeId]?['Double']?.text = limitItem['double_limit']?.toString() ?? '';
              numberLimits[timeId]?['Tripple']?.text = limitItem['triple_limit']?.toString() ?? '';
              numberLimits[timeId]?['Box']?.text = limitItem['box_limit']?.toString() ?? '';
              salesLimits[timeId]?.text = limitItem['sales_limit']?.toString() ?? '';
            }
          }

          isLoading = false;
        });
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateStockist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Capture checked app active states
    List<int> checkedGameTimeIds = [];
    appToggles.forEach((id, isChecked) {
      if (isChecked) checkedGameTimeIds.add(id);
    });

    final Map<String, dynamic> payload = {
      'create_dealer_stockist': createDealer,
      'enable_booking': enableBooking,
      'package_id': selectedPackage,
      'checked_times': checkedGameTimeIds,
      'limits': gameTimes.map((time) {
        int id = time['id'];
        
        int? parseOrNull(String text) {
          return text.trim().isEmpty ? null : int.tryParse(text.trim());
        }

        return {
          'game_time_id': id,
          'single_limit': parseOrNull(numberLimits[id]?['Single']?.text ?? ''),
          'double_limit': parseOrNull(numberLimits[id]?['Double']?.text ?? ''),
          'triple_limit': parseOrNull(numberLimits[id]?['Tripple']?.text ?? ''),
          'box_limit': parseOrNull(numberLimits[id]?['Box']?.text ?? ''),
          'sales_limit': parseOrNull(salesLimits[id]?.text ?? ''),
        };
      }).toList(),
    };

    // If an admin provides a new value, ship it; otherwise leave empty to prevent overriding hashes
    if (_passwordController.text.trim().isNotEmpty) {
      payload['password'] = _passwordController.text.trim();
    }

    final url = Uri.parse(
      '${AppConfig.baseUrl}/stockist/api/sub-stockists/${widget.stockistId}/update-details/',
    );

    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        Navigator.pop(
          context,
          true,
        ); // Pass true to notify list view to trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sub Stockist Profile Updated Successfully'),
          ),
        );
      } else {
        final errJson = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errJson['error'] ??
                  errJson['detail'] ??
                  'Failed to complete transaction',
            ),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error experienced.')),
      );
    } finally {
      // <-- Changed 'final' to 'finally'
      setState(() => _isSaving = false);
    }
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildLimitRow(Map<String, TextEditingController> controllers) {
    return Row(
      children: controllers.entries.map((e) {
        // REMOVED the '0' check so 0 displays properly as 0
        if (e.value.text == 'null') {
          e.value.text = '';
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextFormField(
              controller: e.value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: e.key,
                hintText: 'None', 
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        title: Text(
          'Edit Sub Stockist: ${_usernameController.text}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: const Icon(Icons.menu, color: Colors.white),
        actions: [
          const Icon(Icons.home, color: Colors.white),
          const SizedBox(width: 15),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: isLoading || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'USER NAME',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      enabled:
                          false, // Usernames are read-only during modifications
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'PASSWORD',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'Leave blank to retain current password',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text(
                              'CREATE DEALER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: createDealer,
                            onChanged: (v) =>
                                setState(() => createDealer = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text(
                              'ENABLE BOOKING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: enableBooking,
                            onChanged: (v) => setState(() => enableBooking = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),

                    // 1. ALL NUMBER LIMITS MATRIX
                    ...gameTimes.map((time) {
                      int id = time['id'];
                      String label = time['game_time'] ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubHeader('NUMBER LIMIT $label'),
                          _buildLimitRow(numberLimits[id] ?? {}),
                          const SizedBox(height: 10),
                        ],
                      );
                    }).toList(),

                    const Divider(),

                    // 2. ALL SALES LIMITS MATRIX
                    ...gameTimes.map((time) {
                      int id = time['id'];
                      String label = time['game_time'] ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            'SALES LIMIT $label',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          TextFormField(
                            controller: salesLimits[id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Sales Limit',
                              contentPadding: EdgeInsets.only(bottom: 2),
                            ),
                          ),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    const Text(
                      'CATEGORY / PACKAGE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedPackage,
                      hint: const Text('Select Package'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: packages.map<DropdownMenuItem<String>>((pkg) {
                        return DropdownMenuItem<String>(
                          value: pkg['id'].toString(),
                          child: Text(pkg['package_name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedPackage = v),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),

                    ...gameTimes.map((time) {
                      int id = time['id'];
                      String label = time['game_time'] ?? '';
                      return SwitchListTile(
                        title: Text(
                          'APP $label',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: appToggles[id] ?? false,
                        onChanged: (v) => setState(() => appToggles[id] = v),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: isLoading || _isSaving
          ? null
          : Container(
              height: 50,
              color: widget.themeColor,
              child: InkWell(
                onTap: _updateStockist,
                child: const Center(
                  child: Text(
                    'Update',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
