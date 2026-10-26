import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cricbuzz/Result Admin/set_monitor.dart';

class PremiumMonitorPage extends StatefulWidget {
  final Color themeColor;
  final int gameTimeId;
  final String gameTimeLabel;

  const PremiumMonitorPage({
    Key? key,
    required this.themeColor,
    required this.gameTimeId,
    required this.gameTimeLabel,
  }) : super(key: key);

  @override
  State<PremiumMonitorPage> createState() => _PremiumMonitorPageState();
}

class _PremiumMonitorPageState extends State<PremiumMonitorPage> {
  DateTime selectedDate = DateTime.now();
  String selectedType = 'ALL';

  bool isLoading = false;
  bool isFetchingMore = false;
  bool isSilentRefreshing = false;

  bool sortCustomer = false;
  bool hideZeroCount = false;

  final TextEditingController _searchController = TextEditingController();

  Map<String, bool> checkboxStates = {
    "A": false,
    "B": false,
    "C": false,
    "AB": false,
    "BC": false,
    "AC": false,
    "SUPER": false,
    "BOX": false,
  };

  List<Map<String, dynamic>> tableData = [];
  final ScrollController _scrollController = ScrollController();
  int offset = 0;
  int limit = 15;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    fetchMonitorData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!isLoading && !isFetchingMore && hasMore) {
        fetchMonitorData(isLoadMore: true);
      }
    }
  }

  void _copyTableToClipboard() {
    if (tableData.isEmpty) return;
    StringBuffer buffer = StringBuffer();
    for (var row in tableData) {
      String fullTicket = row['ticket'].toString();
      String ticketSuffix = fullTicket.contains('-')
          ? fullTicket.split('-').last
          : fullTicket;
      buffer.writeln("$ticketSuffix - ${row['number']} - ${row['limit']}");
    }
    Clipboard.setData(ClipboardData(text: buffer.toString())).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Data copied to clipboard!"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.themeColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });
  }

  Future<void> fetchMonitorData({
    bool isLoadMore = false,
    bool isSilent = false,
  }) async {
    if (isLoadMore) {
      setState(() => isFetchingMore = true);
    } else if (isSilent) {
      setState(() => isSilentRefreshing = true);
      offset = 0;
    } else {
      setState(() {
        isLoading = true;
        offset = 0;
        tableData.clear();
        hasMore = true;
      });
    }

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    String selectedCheckbox = checkboxStates.entries
        .firstWhere(
          (entry) => entry.value == true,
          orElse: () => const MapEntry("", false),
        )
        .key;

    final url = Uri.parse(
      '${AppConfig.baseUrl}/resultadmin/api/premium-monitor/?'
      'game_time_id=${widget.gameTimeId}&'
      'date=$formattedDate&'
      'search=${_searchController.text.trim()}&'
      'selected_type=$selectedType&'
      'selected_ticket=$selectedCheckbox&'
      'sort_customer=$sortCustomer&'
      'hide_zero=$hideZeroCount&'
      'offset=$offset&'
      'limit=$limit',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${MySession.token}'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final dynamic results = data['results'];

        if (results is List) {
          setState(() {
            if (!isLoadMore) tableData.clear();
            tableData.addAll(List<Map<String, dynamic>>.from(results));
            offset = data['next_offset'] ?? offset;
            hasMore = data['next_offset'] != null;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isFetchingMore = false;
          isSilentRefreshing = false;
        });
      }
    }
  }

  Future<void> _clearAllLimits() async {
    final targets = tableData
        .where((row) => (double.tryParse(row['limit'].toString()) ?? 0) > 0)
        .toList();
    if (targets.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear All Limits?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("This will clear limits for ${targets.length} item(s)."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isSilentRefreshing = true);
    try {
      for (var row in targets) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/resultadmin/api/clear-monitor/'),
          headers: {
            'Authorization': 'Bearer ${MySession.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'game_time_id': widget.gameTimeId,
            'date': DateFormat('yyyy-MM-dd').format(selectedDate),
            'ticket': row['ticket'],
            'number': row['number'],
            'amount_to_clear': row['limit'],
          }),
        );
      }
      await fetchMonitorData(isSilent: true);
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isSilentRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "Monitor",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.gameTimeLabel,
              style: TextStyle(
                color: widget.themeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isSilentRefreshing)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                  ),
                ),
              ),
            ),
          // Padding(
          //   padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
          //   child: ElevatedButton.icon(
          //     onPressed: () => Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => SetMonitor(themeColor: widget.themeColor, gameTimeId: widget.gameTimeId,
          //         gameTimeLabel: widget.gameTimeLabel,)),
          //     ),
          //     icon: const Icon(Icons.settings, size: 14),
          //     label: const Text("Set Monitor", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: widget.themeColor,
          //       foregroundColor: Colors.white,
          //       elevation: 0,
          //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                              ),
                            )
                          : tableData.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No monitor records found",
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: tableData.length + (hasMore ? 1 : 0),
                                  separatorBuilder: (context, index) => const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == tableData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildDataRow(tableData[index], index);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Selector Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['ALL', '1', '2', '3'].map((type) {
              bool isSelected = selectedType == type;
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedType = type;
                    checkboxStates.updateAll((key, value) => false);
                  });
                  fetchMonitorData();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.themeColor.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? widget.themeColor : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? widget.themeColor : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedType != 'ALL') ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _getCheckboxesForType()),
            ),
          ],
          const SizedBox(height: 12),
          // Search & Date Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search Number",
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: widget.themeColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: widget.themeColor),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                    fetchMonitorData();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: widget.themeColor),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Actions Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => fetchMonitorData(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Search", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _clearAllLimits,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text("Clear All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Logic Options
          Row(
            children: [
              _buildLogicCheckbox("Sort Customer", sortCustomer, (v) {
                setState(() => sortCustomer = v!);
                fetchMonitorData();
              }),
              _buildLogicCheckbox("Hide Zero Count", hideZeroCount, (v) {
                setState(() => hideZeroCount = v!);
                fetchMonitorData();
              }, showCopy: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogicCheckbox(
    String label,
    bool val,
    Function(bool?) onChange, {
    bool showCopy = false,
  }) {
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: Checkbox(
              value: val,
              onChanged: onChange,
              activeColor: widget.themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          GestureDetector(
            onTap: () => onChange(!val),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
          if (showCopy && val) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _copyTableToClipboard,
              child: const Icon(Icons.copy, size: 16, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _getCheckboxesForType() {
    List<String> options = [];
    if (selectedType == '1') {
      options = ["A", "B", "C"];
    } else if (selectedType == '2') {
      options = ["AB", "BC", "AC"];
    } else if (selectedType == '3') {
      options = ["SUPER", "BOX"];
    }
    return options
        .map(
          (opt) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                width: 28,
                child: Checkbox(
                  value: checkboxStates[opt],
                  activeColor: widget.themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      checkboxStates.updateAll((k, v) => false);
                      checkboxStates[opt] = val!;
                    });
                    fetchMonitorData();
                  },
                ),
              ),
              Text(
                opt,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 12),
            ],
          ),
        )
        .toList();
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: widget.themeColor.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _Cell(text: "Name", flex: 3, isHeader: true, headerColor: widget.themeColor),
          _Cell(text: "Ticket", flex: 4, isHeader: true, headerColor: widget.themeColor),
          _Cell(text: "No", flex: 2, isHeader: true, headerColor: widget.themeColor),
          // _Cell(text: "Cnt", flex: 2, isHeader: true, headerColor: widget.themeColor),
          _Cell(text: "Clr", flex: 2, isHeader: true, headerColor: widget.themeColor),
          _Cell(text: "Lim", flex: 2, isHeader: true, headerColor: widget.themeColor),
          _Cell(text: "#", flex: 3, isHeader: true, headerColor: widget.themeColor),
        ],
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> data, int index) {
    final double limitValue = double.tryParse(data['limit'].toString()) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _Cell(text: data['name'].toString(), flex: 3, isBold: true),
          _Cell(text: data['ticket'].toString(), flex: 4, fontSize: 12),
          _Cell(
            text: data['number'].toString(),
            flex: 2,
            color: widget.themeColor,
            isBold: true,
          ),
          // _Cell(text: data['count'].toString(), flex: 2),
          _Cell(text: data['cleared'].toString(), flex: 2),
          _Cell(text: data['limit'].toString(), flex: 2, color: Colors.black87),
          Expanded(
            flex: 3,
            child: Center(
              child: (limitValue > 0)
                  ? SizedBox(
                      height: 26,
                      width: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final String rowId = data['id'].toString();
                          final String targetTicket = data['ticket'].toString();
                          final String targetNumber = data['number'].toString();
                          final dynamic amountToClear = data['limit'];

                          setState(() {
                            int itemIndex = tableData.indexWhere(
                              (item) => item['id'].toString() == rowId,
                            );

                            if (itemIndex != -1) {
                              var updatedItem = Map<String, dynamic>.from(tableData[itemIndex]);

                              double currentCleared = double.tryParse(updatedItem['cleared'].toString()) ?? 0;
                              double currentLimit = double.tryParse(updatedItem['limit'].toString()) ?? 0;

                              updatedItem['cleared'] = (currentCleared + currentLimit).toInt().toString();
                              updatedItem['limit'] = "0";

                              tableData.removeAt(itemIndex);
                              tableData.add(updatedItem);
                            }
                          });

                          try {
                            final response = await http.post(
                              Uri.parse('${AppConfig.baseUrl}/resultadmin/api/clear-monitor/'),
                              headers: {
                                'Authorization': 'Bearer ${MySession.token}',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({
                                'game_time_id': widget.gameTimeId,
                                'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                                'ticket': targetTicket,
                                'number': targetNumber,
                                'amount_to_clear': amountToClear,
                              }),
                            );

                            if (response.statusCode != 200) {
                              debugPrint("Server failed to clear.");
                            }
                          } catch (e) {
                            debugPrint("Background Network Error: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text(
                          "CLR",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : const Text(
                      "#",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isHeader;
  final bool isBold;
  final Color? color;
  final Color? headerColor;
  final double fontSize;

  const _Cell({
    required this.text,
    required this.flex,
    this.isHeader = false,
    this.isBold = false,
    this.color,
    this.headerColor,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 11 : fontSize,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.w500,
          color: isHeader
              ? (headerColor ?? const Color(0xFF1E293B))
              : (color ?? const Color(0xFF475569)),
        ),
      ),
    );
  }
}