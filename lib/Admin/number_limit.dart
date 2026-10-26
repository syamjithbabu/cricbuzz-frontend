import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

class NumberLimitPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const NumberLimitPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId, required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<NumberLimitPage> createState() => _NumberLimitPageState();
}

class _NumberLimitPageState extends State<NumberLimitPage> {
  final _formKey = GlobalKey<FormState>();
  
  List<dynamic> gameTimes = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Local controller storage mapped by game time ID
  final Map<int, Map<String, TextEditingController>> _localNumberLimits = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${MySession.token}',
  };

  // Run both API fetches together before showing the form
  Future<void> _initializeData() async {
    try {
      // 1. Fetch Game Times
      final timeResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/game-times/'), 
        headers: _headers
      );

      // 2. Fetch Existing Limits from DB
      final limitResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/manage-number-limits/'), 
        headers: _headers
      );
      
      if (timeResponse.statusCode == 200 && limitResponse.statusCode == 200) {
        final List fetchedTimes = json.decode(timeResponse.body);
        final List fetchedLimits = json.decode(limitResponse.body);
        
        // Map the backend limits data by game_time_id for lightning fast lookups
        Map<int, dynamic> dynamicLimitsMap = {};
        for (var limit in fetchedLimits) {
          dynamicLimitsMap[limit['game_time_id']] = limit;
        }

        setState(() {
          gameTimes = fetchedTimes;
          
          // Generate controllers and pre-fill them with backend data
          for (var time in gameTimes) {
            int id = time['id'];
            final dbData = dynamicLimitsMap[id];
            
            _localNumberLimits[id] = {
              'Single': TextEditingController(text: dbData?['single_limit']?.toString() ?? ''),
              'Double': TextEditingController(text: dbData?['double_limit']?.toString() ?? ''),
              'Tripple': TextEditingController(text: dbData?['triple_limit']?.toString() ?? ''),
              'Box': TextEditingController(text: dbData?['box_limit']?.toString() ?? ''),
              'Single Retail': TextEditingController(text: dbData?['retail_single_limit']?.toString() ?? ''),
              'Double Retail': TextEditingController(text: dbData?['retail_double_limit']?.toString() ?? ''),
              'Tripple Retail': TextEditingController(text: dbData?['retail_triple_limit']?.toString() ?? ''),
              'Box Retail': TextEditingController(text: dbData?['retail_box_limit']?.toString() ?? ''),
            };
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to sync sync setup configurations.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error experienced.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLimitsToBackend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    List<Map<String, dynamic>> payload = [];

    _localNumberLimits.forEach((gameTimeId, textMap) {
      payload.add({
        'game_time_id': gameTimeId,
        'single_limit': int.tryParse(textMap['Single']!.text.trim()),
        'double_limit': int.tryParse(textMap['Double']!.text.trim()),
        'triple_limit': int.tryParse(textMap['Tripple']!.text.trim()),
        'box_limit': int.tryParse(textMap['Box']!.text.trim()),
        'retail_single_limit': int.tryParse(textMap['Single Retail']!.text.trim()),
        'retail_double_limit': int.tryParse(textMap['Double Retail']!.text.trim()),
        'retail_triple_limit': int.tryParse(textMap['Tripple Retail']!.text.trim()),
        'retail_box_limit': int.tryParse(textMap['Box Retail']!.text.trim()),
      });
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/adminapp/api/manage-number-limits/'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number Limits Updated Successfully')),
        );
        Navigator.pop(context); // Head back to drawer or home
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['error'] ?? 'Failed to update records.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error saving updates.')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    for (var limitMap in _localNumberLimits.values) {
      for (var controller in limitMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        title: const Text('Number Limits', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: gameTimes.map((time) {
                        int id = time['id'];
                        String label = time['game_time'] ?? '';
                        final allControllers = _localNumberLimits[id] ?? {};

                        // Filter into standard limits (keys without "Retail")
                        final standardControllers = Map.fromEntries(
                          allControllers.entries.where((e) => !e.key.contains('Retail')),
                        );

                        // Filter into retail limits (keys containing "Retail")
                        final retailControllers = Map.fromEntries(
                          allControllers.entries.where((e) => e.key.contains('Retail')),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSubHeader('NUMBER LIMIT $label'),
                            _buildLimitRow(standardControllers),
                            const SizedBox(height: 12),
                            // _buildSubHeader('RETAIL LIMIT $label'),
                            _buildLimitRow(retailControllers),
                            const SizedBox(height: 24),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : Container(
              height: 50,
              color: widget.themeColor,
              child: InkWell(
                onTap: _isSaving ? null : _saveLimitsToBackend,
                child: Center(
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Limits',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
    );
  }
}