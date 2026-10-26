import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class CreateStockistPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const CreateStockistPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<CreateStockistPage> createState() => _CreateStockistPageState();
}

class _CreateStockistPageState extends State<CreateStockistPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // New Category Table Configuration (Rate Controllers replaced static string values)
  final Map<String, TextEditingController> rateControllers = {
    'SINGLE(1)': TextEditingController(text: '12'),
    'DOUBLE(2)': TextEditingController(text: '10'),
    'LSK SUPER': TextEditingController(text: '10'),
    'BOX': TextEditingController(text: '10'),
  };
  final Map<String, TextEditingController> dcControllers = {
    'SINGLE(1)': TextEditingController(),
    'DOUBLE(2)': TextEditingController(),
    'LSK SUPER': TextEditingController(),
    'BOX': TextEditingController(),
  };
  final Map<String, TextEditingController> retailrateControllers = {
    'SINGLE(1)': TextEditingController(),
    'DOUBLE(2)': TextEditingController(),
    'LSK SUPER': TextEditingController(),
    'BOX': TextEditingController(),
  };

  // States
  bool createSubStockist = false;
  bool enableBooking = false;
  bool newCategoryToggle = false;
  
  List<dynamic> gameTimes = [];
  List<dynamic> packages = [];
  String? selectedPackage;

  // Holds data matrices for limitations matching layout strings
  Map<int, Map<String, TextEditingController>> numberLimits = {};
  Map<int, TextEditingController> salesLimits = {};
  Map<int, bool> appToggles = {};

  @override
  void initState() {
    super.initState();
    _fetchRequirements();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  Future<void> _fetchRequirements() async {
    try {
      final timeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/adminapp/api/game-times/'), headers: _headers);
      final pkgRes = await http.get(Uri.parse('${AppConfig.baseUrl}/adminapp/api/packages/'), headers: _headers);
      
      if (timeRes.statusCode == 200 && pkgRes.statusCode == 200) {
        final List fetchedTimes = json.decode(timeRes.body);
        final List fetchedPackages = json.decode(pkgRes.body);
        
        setState(() {
          gameTimes = fetchedTimes;
          packages = fetchedPackages;
          
          // Automatically select the first package if the list isn't empty
          if (packages.isNotEmpty) {
            selectedPackage = packages.first['id'].toString();
          }
          
          for (var time in gameTimes) {
            int id = time['id'];
            numberLimits[id] = {
              'Single': TextEditingController(),
              'Double': TextEditingController(),
              'Tripple': TextEditingController(),
              'Box': TextEditingController(),
            };
            salesLimits[id] = TextEditingController();
            appToggles[id] = true; // Default to app enabled
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveStockist() async {
    if (!_formKey.currentState!.validate()) return;

    if (!newCategoryToggle && (selectedPackage == null || packages.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a package first or enable "New Category"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String baseUsername = _usernameController.text.trim();

    // Prepare payload fields for a dynamic standalone stockist package if toggle is on
    Map<String, dynamic>? dynamicPackagePayload;
    if (newCategoryToggle) {
      dynamicPackagePayload = {
        'package_name': '${baseUsername.toUpperCase()}_PACKAGE',
        'single_rate': double.tryParse(rateControllers['SINGLE(1)']!.text) ?? 12.0,
        'single_dc': double.tryParse(dcControllers['SINGLE(1)']!.text) ?? 0.0,
        'double_rate': double.tryParse(rateControllers['DOUBLE(2)']!.text) ?? 10.0,
        'double_dc': double.tryParse(dcControllers['DOUBLE(2)']!.text) ?? 0.0,
        'super_rate': double.tryParse(rateControllers['LSK SUPER']!.text) ?? 10.0,
        'super_dc': double.tryParse(dcControllers['LSK SUPER']!.text) ?? 0.0,
        'box_rate': double.tryParse(rateControllers['BOX']!.text) ?? 10.0,
        'box_dc': double.tryParse(dcControllers['BOX']!.text) ?? 0.0,

        'single_retail_rate': double.tryParse(retailrateControllers['SINGLE(1)']!.text) ?? 14,
        'double_retail_rate': double.tryParse(retailrateControllers['DOUBLE(2)']!.text) ?? 14,
        'super_retail_rate': double.tryParse(retailrateControllers['LSK SUPER']!.text) ?? 14,
        'box_retail_rate': double.tryParse(retailrateControllers['BOX']!.text) ?? 14,

        
        // Appending provided default fallback variables
        'first_win': 5000.0,
        'first_dc': 400.0,
        'second_win': 500.0,
        'second_dc': 50.0,
        'third_win': 250.0,
        'third_dc': 20.0,
        'fourth_win': 100.0,
        'fourth_dc': 20.0,
        'fifth_win': 50.0,
        'fifth_dc': 20.0,
        'guarantee_win': 20.0,
        'guarantee_dc': 10.0,
        'box_first_win': 3000.0,
        'box_first_dc': 300.0,
        'box_series_win': 800.0,
        'box_series_dc': 30.0,
        'single_win': 100.0,
        'single_win_dc': 0.0,
        'double_win': 700.0,
        'double_win_dc': 30.0,
      };
    }

    // Filter appToggles to identify checked game times
    List<int> checkedGameTimeIds = [];
    appToggles.forEach((id, isChecked) {
      if (isChecked) {
        checkedGameTimeIds.add(id);
      }
    });

    final Map<String, dynamic> payload = {
      'username': baseUsername,
      'password': _passwordController.text.trim(),
      'create_sub_stockist': createSubStockist,
      'enable_booking': enableBooking,
      'new_category_custom': newCategoryToggle,
      'package_id': newCategoryToggle ? null : selectedPackage,
      'custom_package_data': dynamicPackagePayload,
      'checked_times': checkedGameTimeIds,
      'limits': gameTimes.map((time) {
        int id = time['id'];
        return {
          'game_time_id': id,
          // If empty string, int.tryParse returns null, which is exactly what we want to send
          'single_limit': int.tryParse(numberLimits[id]?['Single']?.text ?? ''),
          'double_limit': int.tryParse(numberLimits[id]?['Double']?.text ?? ''),
          'triple_limit': int.tryParse(numberLimits[id]?['Tripple']?.text ?? ''),
          'box_limit': int.tryParse(numberLimits[id]?['Box']?.text ?? ''),
          'sales_limit': int.tryParse(salesLimits[id]?.text ?? ''),
        };
      }).toList()
    };

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/create-stockist/'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stockist Created Successfully')));
      } else {
        final errJson = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errJson['error'] ?? 'Failed to complete transaction')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error experienced.')));
    }
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
    );
  }

  Widget _buildLimitRow(Map<String, TextEditingController> controllers) {
    return Row(
      children: controllers.entries.map((e) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextFormField(
              controller: e.value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: e.key,
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNewCategoryTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Table(
        border: TableBorder.all(color: Colors.grey[200]!, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: const [
              Padding(padding: EdgeInsets.all(10.0), child: Text('TICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
              Padding(padding: EdgeInsets.all(10.0), child: Text('RATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
              Padding(padding: EdgeInsets.all(10.0), child: Text('DC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
              Padding(padding: EdgeInsets.all(10.0), child: Text('R. RATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
            ],
          ),
          ...rateControllers.entries.map((entry) {
            String ticketType = entry.key;

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(ticketType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextFormField(
                    controller: rateControllers[ticketType],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter Rate',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextFormField(
                    controller: dcControllers[ticketType],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter DC',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextFormField(
                    controller: retailrateControllers[ticketType],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter R. Rate',
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        title: const Text('New Stockist', style: TextStyle(color: Colors.white)),
        leading: const Icon(Icons.menu, color: Colors.white),
        actions: [
          const Icon(Icons.home, color: Colors.white),
          const SizedBox(width: 15),
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'USER NAME', labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PASSWORD', labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('CREATE SUB STOCKIST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      value: createSubStockist,
                      onChanged: (v) => setState(() => createSubStockist = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('ENABLE BOOKING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      value: enableBooking,
                      onChanged: (v) => setState(() => enableBooking = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // 1. ALL NUMBER LIMITS
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

              // 2. ALL SALES LIMITS
              ...gameTimes.map((time) {
                int id = time['id'];
                String label = time['game_time'] ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text('SALES LIMIT $label', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                    TextFormField(
                      controller: salesLimits[id],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Sales Limit', contentPadding: EdgeInsets.only(bottom: 2)),
                    ),
                  ],
                );
              }).toList(),

              const SizedBox(height: 16),
              
              SwitchListTile(
                title: const Text('NEW CATEGORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                value: newCategoryToggle,
                onChanged: (v) => setState(() => newCategoryToggle = v),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.blue,
              ),

              if (newCategoryToggle)
                _buildNewCategoryTable()
              else ...[
                const Text('CATEGORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                DropdownButtonFormField<String>(
                  value: selectedPackage,
                  hint: const Text('Default Packages'),
                  isExpanded: true,
                  items: packages.map<DropdownMenuItem<String>>((pkg) {
                    return DropdownMenuItem<String>(value: pkg['id'].toString(), child: Text(pkg['package_name'] ?? ''));
                  }).toList(),
                  onChanged: (v) => setState(() => selectedPackage = v),
                ),
              ],
              
              const SizedBox(height: 20),
              ...gameTimes.map((time) {
                int id = time['id'];
                String label = time['game_time'] ?? '';
                return SwitchListTile(
                  title: Text('APP $label', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  value: appToggles[id] ?? false,
                  onChanged: (v) => setState(() => appToggles[id] = v),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: 50,
          color: widget.themeColor,
          child: InkWell(
            onTap: _saveStockist,
            child: const Center(
              child: Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}