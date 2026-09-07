import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReportsTallyTab extends StatefulWidget {
  const ReportsTallyTab({super.key});

  @override
  State<ReportsTallyTab> createState() => _ReportsTallyTabState();
}

class _ReportsTallyTabState extends State<ReportsTallyTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tally state
  DateTime _tallyFrom = DateTime.now();
  DateTime _tallyTo = DateTime.now();
  String _tallyPreset = 'Today';
  Map<String, dynamic>? _tallyPreview;
  bool _isLoadingTally = false;
  bool _isGeneratingExport = false;

  // Reports state & Multi-Filters
  DateTime _reportFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _reportTo = DateTime.now();
  String _reportPreset = 'This Month';
  int? _selectedUserId;
  int? _selectedLocationId;
  int? _selectedMaterialId;
  String _selectedStatus = 'ALL';

  // Cached Master Lists for Dropdowns
  List<UserItem> _allUsers = [];
  List<LocationItem> _allLocations = [];
  List<MaterialItem> _allMaterials = [];

  Map<String, dynamic>? _reportData;
  bool _isLoadingReports = false;

  // Sub-view: 0 = By Location, 1 = By Item, 2 = By User, 3 = Matrix Templates
  int _activeReportView = 0;
  // Matrix template: 1 = User -> Location -> Item, 2 = Item -> User -> Location, 3 = Location -> Item
  int _activeMatrixTemplate = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _applyTallyPreset('Today');
    _loadMasterFilterData();
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterFilterData() async {
    final results = await Future.wait([
      ApiService.getUsers(),
      ApiService.getLocations(),
      ApiService.getMaterials(),
    ]);
    if (mounted) {
      setState(() {
        _allUsers = results[0] as List<UserItem>;
        _allLocations = results[1] as List<LocationItem>;
        _allMaterials = results[2] as List<MaterialItem>;
      });
    }
  }

  // --- Tally Logic ---
  void _applyTallyPreset(String preset) {
    _tallyPreset = preset;
    final now = DateTime.now();
    switch (preset) {
      case 'Today':
        _tallyFrom = now;
        _tallyTo = now;
        break;
      case 'Yesterday':
        _tallyFrom = now.subtract(const Duration(days: 1));
        _tallyTo = now.subtract(const Duration(days: 1));
        break;
      case 'Last 7 Days':
        _tallyFrom = now.subtract(const Duration(days: 6));
        _tallyTo = now;
        break;
      case 'This Month':
        _tallyFrom = DateTime(now.year, now.month, 1);
        _tallyTo = now;
        break;
    }
    _loadTallyPreview();
  }

  Future<void> _loadTallyPreview() async {
    setState(() => _isLoadingTally = true);
    final fromStr = DateFormat('yyyy-MM-dd').format(_tallyFrom);
    final toStr = DateFormat('yyyy-MM-dd').format(_tallyTo);

    final data = await ApiService.getTallyPreview(dateFrom: fromStr, dateTo: toStr);
    if (mounted) {
      setState(() {
        _tallyPreview = data;
        _isLoadingTally = false;
      });
    }
  }

  Future<void> _generateTallyExport() async {
    if (_tallyPreview == null) return;
    final subs = _tallyPreview!['sub_requisitions'] as List? ?? [];
    if (subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vouchers available to export for selected dates.')),
      );
      return;
    }

    setState(() => _isGeneratingExport = true);
    final fromStr = DateFormat('yyyy-MM-dd').format(_tallyFrom);
    final toStr = DateFormat('yyyy-MM-dd').format(_tallyTo);
    final subIds = subs.map<int>((s) => int.parse(s['id'].toString())).toList();

    final res = await ApiService.generateTallyExport(
      dateFrom: fromStr,
      dateTo: toStr,
      subRequisitionIds: subIds,
    );

    setState(() => _isGeneratingExport = false);

    if (mounted) {
      if (res['success'] == true) {
        final downloadUrl = res['data']?['download_url'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Tally export file generated!'),
            backgroundColor: AppTheme.successGreen,
            action: downloadUrl != null
                ? SnackBarAction(
                    label: 'Download',
                    textColor: Colors.white,
                    onPressed: () {
                      launchUrl(Uri.parse('${ApiService.baseUrl}$downloadUrl'), mode: LaunchMode.externalApplication);
                    },
                  )
                : null,
          ),
        );
        _loadTallyPreview();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Export failed.'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  // --- Reports Logic ---
  void _applyReportPreset(String preset) {
    _reportPreset = preset;
    final now = DateTime.now();
    switch (preset) {
      case 'Today':
        _reportFrom = now;
        _reportTo = now;
        break;
      case 'Yesterday':
        _reportFrom = now.subtract(const Duration(days: 1));
        _reportTo = now.subtract(const Duration(days: 1));
        break;
      case 'Last 7 Days':
        _reportFrom = now.subtract(const Duration(days: 6));
        _reportTo = now;
        break;
      case 'This Month':
        _reportFrom = DateTime(now.year, now.month, 1);
        _reportTo = now;
        break;
      case 'Last Month':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        _reportFrom = prevMonth;
        _reportTo = DateTime(now.year, now.month, 0);
        break;
      case 'All':
        _reportFrom = DateTime(2025, 1, 1);
        _reportTo = now;
        break;
    }
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    final fromStr = DateFormat('yyyy-MM-dd').format(_reportFrom);
    final toStr = DateFormat('yyyy-MM-dd').format(_reportTo);

    final data = await ApiService.getReports(
      dateFrom: fromStr,
      dateTo: toStr,
      userId: _selectedUserId,
      locationId: _selectedLocationId,
      materialId: _selectedMaterialId,
      status: _selectedStatus,
    );
    if (mounted) {
      setState(() {
        _reportData = data;
        _isLoadingReports = false;
      });
    }
  }

  void _resetAllFilters() {
    setState(() {
      _selectedUserId = null;
      _selectedLocationId = null;
      _selectedMaterialId = null;
      _selectedStatus = 'ALL';
    });
    _loadReports();
  }

  // --- Drilldown Modals (Issued Quantity as Primary Focus) ---

  // 1. Location Drilldown Modal
  void _showLocationDrilldown(Map<String, dynamic> loc) {
    final locId = int.tryParse(loc['location_id']?.toString() ?? '0') ?? 0;
    final locName = loc['location_name'] ?? 'Location';
    final locCode = loc['code'] ?? loc['location_code'] ?? '';
    final totalIssuedQty = loc['total_issued_qty']?.toString() ?? '0.00';

    final rawRecords = (_reportData?['raw_records'] as List? ?? [])
        .where((r) => int.tryParse(r['location_id']?.toString() ?? '0') == locId)
        .toList();

    // Group records by user and item
    final userMap = <String, List<Map<String, dynamic>>>{};
    for (var r in rawRecords) {
      final uName = '${r['user_name']} (${r['employee_code']})';
      userMap.putIfAbsent(uName, () => []).add(r);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.primaryGoldSoft, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.location_on, color: AppTheme.primaryGoldDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(locName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('Code: $locCode • ${rawRecords.length} Item Transactions', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Hero Highlight: Total Issued Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.bgPearl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, size: 18, color: AppTheme.primaryGoldDark),
                      const SizedBox(width: 8),
                      Text(
                        'Total Issued Quantity: $totalIssuedQty Units',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                      ),
                    ],
                  ),
                  Text('${userMap.length} Requesters', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: userMap.isEmpty
                  ? const Center(child: Text('No item transactions found for this location.', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: userMap.entries.map((entry) {
                        final uName = entry.key;
                        final items = entry.value;
                        final userIssuedTotal = items.fold<double>(0.0, (acc, it) => acc + (double.tryParse(it['issued_quantity']?.toString() ?? '0') ?? 0.0));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AppTheme.navyAccent.withOpacity(0.06),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: AppTheme.navyAccent),
                                        const SizedBox(width: 6),
                                        Text(uName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                    Text('Issued: ${userIssuedTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.navyAccent)),
                                  ],
                                ),
                              ),
                              ...items.map((it) {
                                final issQty = it['issued_quantity']?.toString() ?? '0.00';
                                final reqQty = it['requested_quantity']?.toString() ?? '0.00';
                                final unit = it['unit'] ?? 'Units';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(it['material_name'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                            const SizedBox(height: 2),
                                            Text('Requested: $reqQty $unit • #${it['sub_requisition_no'] ?? it['requisition_number']}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                            Text('📅 ${it['requisition_date']}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$issQty $unit',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                                          ),
                                          const SizedBox(height: 3),
                                          StatusChip(status: it['status'] ?? 'ISSUED'),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Material Drilldown Modal
  void _showMaterialDrilldown(Map<String, dynamic> mat) {
    final matName = mat['item_name'] ?? 'Material';
    final totalIssuedQty = mat['total_issued_qty']?.toString() ?? '0.00';
    final unit = mat['unit'] ?? 'Units';

    final rawRecords = (_reportData?['raw_records'] as List? ?? [])
        .where((r) => r['material_name'] == matName || (mat['material_id'] != null && r['material_id'] == mat['material_id']))
        .toList();

    // Group by Location
    final locMap = <String, List<Map<String, dynamic>>>{};
    for (var r in rawRecords) {
      final locName = r['location_name'] ?? 'General Location';
      locMap.putIfAbsent(locName, () => []).add(r);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.primaryGoldSoft, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2, color: AppTheme.primaryGoldDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(matName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('Code: ${mat['item_code'] ?? ''} • ${rawRecords.length} Requisition Demands', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Hero Highlight: Total Issued Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.bgPearl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primaryGoldDark),
                      const SizedBox(width: 8),
                      Text(
                        'Total Issued: $totalIssuedQty $unit',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                      ),
                    ],
                  ),
                  Text('${locMap.length} Locations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: locMap.isEmpty
                  ? const Center(child: Text('No distribution records found.', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: locMap.entries.map((entry) {
                        final locTitle = entry.key;
                        final items = entry.value;
                        final locTotalIssued = items.fold<double>(0.0, (acc, it) => acc + (double.tryParse(it['issued_quantity']?.toString() ?? '0') ?? 0.0));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold.withOpacity(0.08),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: AppTheme.primaryGold),
                                        const SizedBox(width: 6),
                                        Text(locTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                    Text('Issued: ${locTotalIssued.toStringAsFixed(2)} $unit', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark)),
                                  ],
                                ),
                              ),
                              ...items.map((it) {
                                final issQty = it['issued_quantity']?.toString() ?? '0.00';
                                final reqQty = it['requested_quantity']?.toString() ?? '0.00';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${it['user_name']} (${it['employee_code']})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                            Text('Requested: $reqQty $unit • 📅 ${it['requisition_date']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$issQty $unit',
                                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                                          ),
                                          const SizedBox(height: 2),
                                          StatusChip(status: it['status'] ?? 'ISSUED'),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. User Drilldown Modal
  void _showUserDrilldown(Map<String, dynamic> user) {
    final userId = int.tryParse(user['user_id']?.toString() ?? '0') ?? 0;
    final userName = user['user_name'] ?? 'User';
    final empCode = user['employee_code'] ?? '';
    final dept = user['department_name'] ?? '';
    final totalIssuedQty = user['total_issued_qty']?.toString() ?? '0.00';

    final rawRecords = (_reportData?['raw_records'] as List? ?? [])
        .where((r) => int.tryParse(r['user_id']?.toString() ?? '0') == userId)
        .toList();

    // Group by Location
    final locMap = <String, List<Map<String, dynamic>>>{};
    for (var r in rawRecords) {
      final locName = r['location_name'] ?? 'General Location';
      locMap.putIfAbsent(locName, () => []).add(r);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGoldSoft,
                    radius: 20,
                    child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('Code: $empCode ${dept.isNotEmpty ? "• Dept: $dept" : ""} • ${rawRecords.length} Requests', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Hero Highlight: Total Issued Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.bgPearl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, size: 18, color: AppTheme.primaryGoldDark),
                      const SizedBox(width: 8),
                      Text(
                        'Total Issued: $totalIssuedQty Units',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                      ),
                    ],
                  ),
                  Text('${locMap.length} Locations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: locMap.isEmpty
                  ? const Center(child: Text('No requisitions recorded for this user.', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: locMap.entries.map((entry) {
                        final locName = entry.key;
                        final items = entry.value;
                        final locIssuedTotal = items.fold<double>(0.0, (acc, it) => acc + (double.tryParse(it['issued_quantity']?.toString() ?? '0') ?? 0.0));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGoldSoft,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: AppTheme.primaryGoldDark),
                                        const SizedBox(width: 6),
                                        Text('Location: $locName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                    Text('Issued: ${locIssuedTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark)),
                                  ],
                                ),
                              ),
                              ...items.map((it) {
                                final issQty = it['issued_quantity']?.toString() ?? '0.00';
                                final reqQty = it['requested_quantity']?.toString() ?? '0.00';
                                final unit = it['unit'] ?? 'Units';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(it['material_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                            Text('Requested: $reqQty $unit • 📅 ${it['requisition_date']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$issQty $unit',
                                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                                          ),
                                          const SizedBox(height: 2),
                                          StatusChip(status: it['status'] ?? 'ISSUED'),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PDF Export Logic ---
  Future<void> _exportPdfReport() async {
    if (_reportData == null) return;
    final doc = pw.Document();
    final rawRecords = (_reportData!['raw_records'] as List? ?? []);
    final summary = _reportData!['summary'] as Map<String, dynamic>? ?? {};

    final fromStr = DateFormat('dd MMM yyyy').format(_reportFrom);
    final toStr = DateFormat('dd MMM yyyy').format(_reportTo);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GUNAYATAN STORE REQUISITION & CONSUMPTION REPORT',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                      pw.Text('Date Range: $fromStr to $toStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Issued Qty: ${summary['total_issued_qty'] ?? 0} Units',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                      pw.Text('Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Req #', 'Requester', 'Department', 'Location', 'Material', 'Req Qty', 'Issued Qty', 'Unit', 'Status'],
              data: rawRecords.take(200).map((r) {
                return [
                  r['requisition_date'] ?? '',
                  r['sub_requisition_no'] ?? r['requisition_number'] ?? '',
                  '${r['user_name']}\n(${r['employee_code']})',
                  r['department_name'] ?? '',
                  r['location_name'] ?? '',
                  r['material_name'] ?? '',
                  r['requested_quantity']?.toString() ?? '',
                  r['issued_quantity']?.toString() ?? '',
                  r['unit'] ?? '',
                  r['status'] ?? '',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Gunayatan_Report_${DateFormat('yyyyMMdd').format(_reportFrom)}_${DateFormat('yyyyMMdd').format(_reportTo)}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(116),
        child: Column(
          children: [
            GunayatanHeader(
              title: 'Tally & Analytics Hub',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                  onPressed: () {
                    _loadTallyPreview();
                    _loadReports();
                  },
                ),
              ],
            ),
            Container(
              color: AppTheme.surfaceWhite,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGold,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryGoldDark,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(text: 'Tally Export'),
                  Tab(text: 'Enterprise Reports'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tally Export
          _buildTallyExportTab(),

          // Tab 2: Advanced Enterprise Reports
          _buildAdvancedReportsTab(),
        ],
      ),
    );
  }

  Widget _buildTallyExportTab() {
    final subs = _tallyPreview?['sub_requisitions'] as List? ?? [];
    final totalSubsCount = subs.length;
    final totalAmount = subs.fold<double>(0.0, (acc, s) => acc + (double.tryParse(s['total_amount']?.toString() ?? '0') ?? 0.0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Preset Date Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Today', 'Yesterday', 'Last 7 Days', 'This Month'].map((preset) {
              final isSelected = _tallyPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  onSelected: (_) => _applyTallyPreset(preset),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.softGoldCardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ready for Tally Export', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(
                        '$totalSubsCount Sales Vouchers',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Valuation', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(
                        '₹ ${NumberFormat('#,##,###.00').format(totalAmount)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Export Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isGeneratingExport
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.file_download, size: 20),
                  label: Text(_isGeneratingExport ? 'Generating Excel...' : 'Generate & Download Tally Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isGeneratingExport ? null : _generateTallyExport,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Vouchers in Selected Range', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),

        if (_isLoadingTally)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primaryGold)))
        else if (subs.isEmpty)
          const EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: 'No Pending Vouchers',
            message: 'All requisitions in this date range are either exported or have 0 issued items.',
          )
        else
          ...subs.map((sub) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub['sub_requisition_number'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text('Location: ${sub['location_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text('Party: ${sub['user_name']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹ ${NumberFormat('#,##,###.00').format(double.tryParse(sub['total_amount']?.toString() ?? '0') ?? 0)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(status: sub['tally_export_status'] ?? 'NOT_EXPORTED'),
                  ],
                ),
              ],
            ),
          )),
      ],
    );
  }

  // --- Advanced Enterprise Reports Tab (Issued Quantity Primary) ---
  Widget _buildAdvancedReportsTab() {
    final summary = _reportData?['summary'] as Map<String, dynamic>? ?? {};
    final locConsumption = _reportData?['loc_consumption'] as List? ?? [];
    final itemConsumption = _reportData?['item_consumption'] as List? ?? [];
    final userConsumption = _reportData?['user_consumption'] as List? ?? [];
    final rawRecords = _reportData?['raw_records'] as List? ?? [];

    final hasActiveFilter = _selectedUserId != null || _selectedLocationId != null || _selectedMaterialId != null || _selectedStatus != 'ALL';

    return Column(
      children: [
        // Top Multi-Filter Header
        Container(
          color: AppTheme.surfaceWhite,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Presets & Custom Picker
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Today', 'Yesterday', 'Last 7 Days', 'This Month', 'Last Month', 'All'].map((preset) {
                          final isSelected = _reportPreset == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(preset),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryGold,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                              ),
                              onSelected: (_) => _applyReportPreset(preset),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.date_range, color: AppTheme.primaryGoldDark, size: 20),
                    tooltip: 'Pick Custom Date Range',
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(start: _reportFrom, end: _reportTo),
                      );
                      if (range != null) {
                        setState(() {
                          _reportPreset = 'Custom';
                          _reportFrom = range.start;
                          _reportTo = range.end;
                        });
                        _loadReports();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Dropdowns Row: Location, User, Material, Status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: _selectedLocationId == null
                          ? 'All Locations'
                          : _allLocations.firstWhere((l) => l.id == _selectedLocationId, orElse: () => LocationItem(id: 0, name: 'Loc', code: '', status: '')).name,
                      isActive: _selectedLocationId != null,
                      icon: Icons.location_on_outlined,
                      onTap: () => _showFilterSelectionDialog(
                        title: 'Select Location',
                        items: [
                          {'id': null, 'name': 'All Locations'},
                          ..._allLocations.map((l) => {'id': l.id, 'name': l.name}),
                        ],
                        selectedId: _selectedLocationId,
                        onSelect: (id) {
                          setState(() => _selectedLocationId = id);
                          _loadReports();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    _buildFilterChip(
                      label: _selectedUserId == null
                          ? 'All Users'
                          : _allUsers.firstWhere((u) => u.id == _selectedUserId, orElse: () => UserItem(id: 0, name: 'User', employeeCode: '', role: '', status: '')).name,
                      isActive: _selectedUserId != null,
                      icon: Icons.person_outline,
                      onTap: () => _showFilterSelectionDialog(
                        title: 'Select User',
                        items: [
                          {'id': null, 'name': 'All Users'},
                          ..._allUsers.map((u) => {'id': u.id, 'name': '${u.name} (${u.employeeCode})'}),
                        ],
                        selectedId: _selectedUserId,
                        onSelect: (id) {
                          setState(() => _selectedUserId = id);
                          _loadReports();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    _buildFilterChip(
                      label: _selectedMaterialId == null
                          ? 'All Materials'
                          : _allMaterials.firstWhere((m) => m.id == _selectedMaterialId, orElse: () => MaterialItem(id: 0, name: 'Mat', code: '', unit: '', defaultRate: 0, currentStock: 0, status: '')).name,
                      isActive: _selectedMaterialId != null,
                      icon: Icons.inventory_2_outlined,
                      onTap: () => _showFilterSelectionDialog(
                        title: 'Select Material',
                        items: [
                          {'id': null, 'name': 'All Materials'},
                          ..._allMaterials.map((m) => {'id': m.id, 'name': '${m.name} (${m.code})'}),
                        ],
                        selectedId: _selectedMaterialId,
                        onSelect: (id) {
                          setState(() => _selectedMaterialId = id);
                          _loadReports();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    _buildFilterChip(
                      label: _selectedStatus == 'ALL' ? 'All Statuses' : _selectedStatus,
                      isActive: _selectedStatus != 'ALL',
                      icon: Icons.filter_alt_outlined,
                      onTap: () => _showFilterSelectionDialog(
                        title: 'Select Status',
                        items: [
                          {'id': 'ALL', 'name': 'All Statuses'},
                          {'id': 'ISSUED', 'name': 'ISSUED'},
                          {'id': 'PARTIALLY_ISSUED', 'name': 'PARTIALLY_ISSUED'},
                          {'id': 'PENDING', 'name': 'PENDING'},
                          {'id': 'NOT_AVAILABLE', 'name': 'NOT_AVAILABLE'},
                        ],
                        selectedId: _selectedStatus,
                        onSelect: (val) {
                          setState(() => _selectedStatus = val.toString());
                          _loadReports();
                        },
                      ),
                    ),

                    if (hasActiveFilter) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Reset Filters', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        onPressed: _resetAllFilters,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.borderSubtle),

        // KPI Summary Bar (Hero: Total Issued Qty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.bgPearl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKpiMini('Requisitions', summary['total_requisitions']?.toString() ?? '0'),
              _buildKpiMini('Item Lines', summary['total_items_count']?.toString() ?? '0'),
              _buildKpiMini('Requested Qty', summary['total_requested_qty']?.toString() ?? '0'),
              _buildKpiMini('Total Issued Qty', '${summary['total_issued_qty'] ?? 0}', isHighlight: true),
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.borderSubtle),

        // Sub-View Selector (Locations, Materials, Users, Matrix)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceWhite,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildViewChoiceChip(0, '🏢 Locations (${locConsumption.length})'),
                      const SizedBox(width: 6),
                      _buildViewChoiceChip(1, '📦 Materials (${itemConsumption.length})'),
                      const SizedBox(width: 6),
                      _buildViewChoiceChip(2, '👤 Users (${userConsumption.length})'),
                      const SizedBox(width: 6),
                      _buildViewChoiceChip(3, '📑 Tabular Matrix'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryGold, size: 22),
                tooltip: 'Share / Print PDF Report',
                onPressed: _exportPdfReport,
              ),
            ],
          ),
        ),

        // Main Report Body Content
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
              : _buildActiveSubViewContent(locConsumption, itemConsumption, userConsumption, rawRecords),
        ),
      ],
    );
  }

  Widget _buildActiveSubViewContent(List locConsumption, List itemConsumption, List userConsumption, List rawRecords) {
    if (rawRecords.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: 'No Data for Selected Filters',
        message: 'No requisition or consumption transactions match the active criteria.',
      );
    }

    switch (_activeReportView) {
      case 0: // Location-wise Explorer (Issued Qty as Hero)
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: locConsumption.length,
          itemBuilder: (ctx, idx) {
            final loc = locConsumption[idx];
            final issuedQty = loc['total_issued_qty']?.toString() ?? '0.00';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showLocationDrilldown(loc),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.primaryGoldSoft, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.location_on, color: AppTheme.primaryGoldDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc['location_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Code: ${loc['location_code'] ?? ''} • ${loc['total_items'] ?? 0} Items • ${loc['total_requisitions'] ?? 0} Reqs',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$issuedQty Units',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Text('Issued Qty', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 14, color: AppTheme.navyAccent),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case 1: // Material-wise Explorer (Issued Qty as Hero)
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemConsumption.length,
          itemBuilder: (ctx, idx) {
            final it = itemConsumption[idx];
            final issuedQty = it['total_issued_qty']?.toString() ?? '0.00';
            final unit = it['unit'] ?? 'Units';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showMaterialDrilldown(it),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.navyAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.inventory_2, color: AppTheme.navyAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it['item_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Code: ${it['item_code'] ?? ''} • ${it['total_requests'] ?? 0} Requisitions',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$issuedQty $unit',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Text('Total Issued', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 14, color: AppTheme.primaryGoldDark),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case 2: // User-wise Explorer (Issued Qty as Hero)
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userConsumption.length,
          itemBuilder: (ctx, idx) {
            final u = userConsumption[idx];
            final uName = u['user_name'] ?? 'User';
            final issuedQty = u['total_issued_qty']?.toString() ?? '0.00';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showUserDrilldown(u),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryGoldSoft,
                          radius: 18,
                          child: Text(uName.isNotEmpty ? uName[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(uName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Code: ${u['employee_code']} • ${u['total_requisitions']} Reqs • ${u['total_items']} Items',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$issuedQty Units',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Text('Total Issued', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 14, color: AppTheme.navyAccent),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case 3: // Matrix Templates View (Issued Qty as Hero)
      default:
        return _buildMatrixTemplatesView(rawRecords);
    }
  }

  Widget _buildMatrixTemplatesView(List rawRecords) {
    return Column(
      children: [
        // Matrix Template Switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.bgPearl,
          child: Row(
            children: [
              const Text('Template:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  value: _activeMatrixTemplate,
                  isExpanded: true,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1. User ➔ Location ➔ Material Matrix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DropdownMenuItem(value: 2, child: Text('2. Material ➔ User ➔ Location Matrix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DropdownMenuItem(value: 3, child: Text('3. Location ➔ Material Consumption Matrix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _activeMatrixTemplate = val);
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_activeMatrixTemplate == 1) ..._buildUserLocationMaterialMatrix(rawRecords),
              if (_activeMatrixTemplate == 2) ..._buildMaterialUserLocationMatrix(rawRecords),
              if (_activeMatrixTemplate == 3) ..._buildLocationMaterialMatrix(rawRecords),
            ],
          ),
        ),
      ],
    );
  }

  // --- Template 1: User -> Location -> Material Matrix (Issued Qty as Hero) ---
  List<Widget> _buildUserLocationMaterialMatrix(List rawRecords) {
    final userGroups = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (var r in rawRecords) {
      final uName = '${r['user_name']} (${r['employee_code']})';
      final lName = r['location_name'] ?? 'General Location';
      userGroups.putIfAbsent(uName, () => {});
      userGroups[uName]!.putIfAbsent(lName, () => []).add(r);
    }

    return userGroups.entries.map((uEntry) {
      final uName = uEntry.key;
      final locs = uEntry.value;
      double userIssuedTotal = 0;
      for (var list in locs.values) {
        for (var item in list) {
          userIssuedTotal += double.tryParse(item['issued_quantity']?.toString() ?? '0') ?? 0;
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: const CircleAvatar(
            backgroundColor: AppTheme.primaryGoldSoft,
            radius: 16,
            child: Icon(Icons.person, size: 18, color: AppTheme.primaryGoldDark),
          ),
          title: Text(uName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          subtitle: Text('${locs.length} Target Locations Requested', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          trailing: Text('${userIssuedTotal.toStringAsFixed(2)} Issued', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark)),
          children: locs.entries.map((lEntry) {
            final locName = lEntry.key;
            final items = lEntry.value;

            return Container(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgPearl,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppTheme.navyAccent),
                      const SizedBox(width: 4),
                      Text(locName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.navyAccent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${it['material_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Issued: ${it['issued_quantity']} ${it['unit']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark)),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  // --- Template 2: Material -> User -> Location Matrix (Issued Qty as Hero) ---
  List<Widget> _buildMaterialUserLocationMatrix(List rawRecords) {
    final matGroups = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (var r in rawRecords) {
      final matName = r['material_name'] ?? 'Material';
      final uName = '${r['user_name']} (${r['employee_code']})';
      matGroups.putIfAbsent(matName, () => {});
      matGroups[matName]!.putIfAbsent(uName, () => []).add(r);
    }

    return matGroups.entries.map((mEntry) {
      final matName = mEntry.key;
      final users = mEntry.value;
      double totalQty = 0;
      String unit = '';

      for (var list in users.values) {
        for (var item in list) {
          totalQty += double.tryParse(item['issued_quantity']?.toString() ?? '0') ?? 0;
          unit = item['unit'] ?? '';
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: const CircleAvatar(
            backgroundColor: AppTheme.navyAccent,
            radius: 16,
            child: Icon(Icons.inventory_2, size: 16, color: Colors.white),
          ),
          title: Text(matName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          subtitle: Text('Demanded by ${users.length} Users across locations', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          trailing: Text('${totalQty.toStringAsFixed(2)} $unit', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark)),
          children: users.entries.map((uEntry) {
            final uName = uEntry.key;
            final items = uEntry.value;

            return Container(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgPearl,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: AppTheme.primaryGoldDark),
                      const SizedBox(width: 4),
                      Text(uName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📍 Location: ${it['location_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Issued: ${it['issued_quantity']} ${it['unit']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark)),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  // --- Template 3: Location -> Material Matrix (Issued Qty as Hero) ---
  List<Widget> _buildLocationMaterialMatrix(List rawRecords) {
    final locGroups = <String, Map<String, double>>{};
    final locTotals = <String, double>{};

    for (var r in rawRecords) {
      final locName = r['location_name'] ?? 'Location';
      final matName = '${r['material_name']} (${r['unit']})';
      final qty = double.tryParse(r['issued_quantity']?.toString() ?? '0') ?? 0;

      locGroups.putIfAbsent(locName, () => {});
      locGroups[locName]![matName] = (locGroups[locName]![matName] ?? 0) + qty;
      locTotals[locName] = (locTotals[locName] ?? 0) + qty;
    }

    return locGroups.entries.map((lEntry) {
      final locName = lEntry.key;
      final mats = lEntry.value;
      final locTotal = locTotals[locName] ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: const CircleAvatar(
            backgroundColor: AppTheme.primaryGoldSoft,
            radius: 16,
            child: Icon(Icons.location_on, size: 16, color: AppTheme.primaryGoldDark),
          ),
          title: Text(locName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          subtitle: Text('${mats.length} Unique Materials Consumed', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          trailing: Text('${locTotal.toStringAsFixed(2)} Units Issued', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.primaryGoldDark)),
          children: mats.entries.map((m) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('• ${m.key}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text('${m.value.toStringAsFixed(2)} Issued', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.navyAccent)),
              ],
            ),
          )).toList(),
        ),
      );
    }).toList();
  }

  // Helper Widgets
  Widget _buildFilterChip({required String label, required bool isActive, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryGoldSoft : AppTheme.bgPearl,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.primaryGold : AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppTheme.primaryGoldDark : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppTheme.primaryGoldDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: isActive ? AppTheme.primaryGoldDark : AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildViewChoiceChip(int viewIndex, String label) {
    final isSelected = _activeReportView == viewIndex;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryGold,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: isSelected ? Colors.white : AppTheme.textSecondary,
      ),
      onSelected: (_) => setState(() => _activeReportView = viewIndex),
    );
  }

  Widget _buildKpiMini(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12.5,
            fontWeight: FontWeight.w900,
            color: isHighlight ? AppTheme.primaryGoldDark : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _showFilterSelectionDialog({
    required String title,
    required List<Map<String, dynamic>> items,
    required dynamic selectedId,
    required Function(dynamic) onSelect,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.70),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final it = items[idx];
                  final isSelected = it['id'] == selectedId;
                  return ListTile(
                    title: Text(
                      it['name'],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryGoldDark : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGold) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(it['id']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
