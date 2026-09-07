import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardTab extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  const DashboardTab({super.key, this.onNavigateTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DashboardMetrics? _metrics;
  Map<String, dynamic>? _timingStatus;
  List<DateOverrideItem> _overrides = [];
  bool _isLoading = true;

  String _selectedPreset = 'Today';
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _applyPreset('Today');
  }

  void _applyPreset(String preset) {
    _selectedPreset = preset;
    final now = DateTime.now();
    switch (preset) {
      case 'Today':
        _dateFrom = now;
        _dateTo = now;
        break;
      case 'Yesterday':
        _dateFrom = now.subtract(const Duration(days: 1));
        _dateTo = now.subtract(const Duration(days: 1));
        break;
      case 'Last 7 Days':
        _dateFrom = now.subtract(const Duration(days: 6));
        _dateTo = now;
        break;
      case 'This Month':
        _dateFrom = DateTime(now.year, now.month, 1);
        _dateTo = now;
        break;
      case 'Last Month':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        _dateFrom = prevMonth;
        _dateTo = DateTime(now.year, now.month, 0);
        break;
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
    final toStr = DateFormat('yyyy-MM-dd').format(_dateTo);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final results = await Future.wait([
      ApiService.getDashboardMetrics(dateFrom: fromStr, dateTo: toStr),
      ApiService.getTimingStatus(todayStr),
      ApiService.getDateOverrides(),
    ]);

    if (mounted) {
      setState(() {
        _metrics = results[0] as DashboardMetrics?;
        _timingStatus = results[1] as Map<String, dynamic>?;
        _overrides = results[2] as List<DateOverrideItem>;
        _isLoading = false;
      });
    }
  }

  // --- Quick Date Override Dialog ---
  Future<void> _showQuickOverrideDialog() async {
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));
    int durationHours = 3;
    final reasonController = TextEditingController(text: 'Store correction by Admin Mobile App');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🛡️ Open Date Override Window',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Temporarily open store editing for past requisitions with full audit trail.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),

              // Target Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPearl,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppTheme.primaryGold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Past Date', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            Text(
                              DateFormat('dd MMMM yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGoldDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Duration Slider / Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgPearl,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duration Window', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    DropdownButton<int>(
                      value: durationHours,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(12),
                      items: List.generate(24, (i) => i + 1).map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h Hour${h > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryGoldDark)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => durationHours = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Reason field
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Audit Reason *',
                  hintText: 'e.g. Updating late physical store issue',
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('ACTIVATE OVERRIDE WINDOW', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an audit reason.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                    final res = await ApiService.createDateOverride(
                      formattedDate,
                      reasonController.text.trim(),
                      durationHours,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? 'Override activated'),
                          backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                        ),
                      );
                      _loadDashboardData();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Create Material Dialog ---
  Future<void> _showQuickAddMaterialDialog() async {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '0.00');
    final stockCtrl = TextEditingController(text: '0.00');
    String unit = 'NOS';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('✨ Quick Add Material', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Material Name *', hintText: 'e.g. Mustard Oil'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Rate (₹)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Opening Stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Material', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                      return;
                    }
                    Navigator.pop(ctx);
                    final res = await ApiService.saveMaterial({
                      'name': nameCtrl.text.trim(),
                      'unit': unit,
                      'default_rate': double.tryParse(rateCtrl.text.trim()) ?? 0.0,
                      'current_stock': double.tryParse(stockCtrl.text.trim()) ?? 0.0,
                      'status': 'ACTIVE',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? 'Saved'),
                        backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                      ));
                      _loadDashboardData();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Create User Dialog ---
  Future<void> _showQuickAddUserDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'REQUISITION_USER';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👤 Quick Add User', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Suresh Kumar'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Employee Code *', hintText: 'EMP-105'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Number'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password / PIN *', hintText: 'Min 4 characters'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create User', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty || passCtrl.text.trim().length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Code, and 4-digit Password are required')));
                      return;
                    }
                    Navigator.pop(ctx);
                    final res = await ApiService.saveUser({
                      'name': nameCtrl.text.trim(),
                      'employee_code': codeCtrl.text.trim(),
                      'mobile': mobileCtrl.text.trim(),
                      'password': passCtrl.text.trim(),
                      'role': role,
                      'status': 'ACTIVE',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? 'User created'),
                        backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                      ));
                      _loadDashboardData();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GunayatanHeader(
        title: 'Admin Command Center',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // --- 1. Date Range Filter & Presets Row ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['Today', 'Yesterday', 'Last 7 Days', 'This Month', 'Last Month'].map((preset) {
                                final isSelected = _selectedPreset == preset;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(preset),
                                    selected: isSelected,
                                    selectedColor: AppTheme.primaryGold,
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                    onSelected: (_) => _applyPreset(preset),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.date_range_outlined, color: AppTheme.primaryGold, size: 20),
                          tooltip: 'Custom Date Range',
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025),
                              lastDate: DateTime.now(),
                              initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
                            );
                            if (range != null) {
                              setState(() {
                                _selectedPreset = 'Custom';
                                _dateFrom = range.start;
                                _dateTo = range.end;
                              });
                              _loadDashboardData();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- 2. Overview Section Header with Range Title & Override Shortcut ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_selectedPreset Overview',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '${DateFormat('dd MMM').format(_dateFrom)} - ${DateFormat('dd MMM yyyy').format(_dateTo)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _showQuickOverrideDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGoldSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open_rounded, size: 13, color: AppTheme.primaryGoldDark),
                              SizedBox(width: 4),
                              Text(
                                'Date Override',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGoldDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- 3. Compact & Rich KPI Metrics Grid (8 High-Density Cards) ---
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.62,
                    children: [
                      _buildCompactKpiCard(
                        title: 'Total Requisitions',
                        value: (_metrics?.totalMasterReqs ?? 0).toString(),
                        subtitle: '${_metrics?.totalSubReqs ?? 0} Sub-vouchers',
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.primaryGoldDark,
                        bgColor: AppTheme.primaryGoldSoft,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildCompactKpiCard(
                        title: 'Issued Items',
                        value: (_metrics?.issuedItems ?? 0).toString(),
                        subtitle: '${_metrics?.totalIssuedQty.toStringAsFixed(1)} units issued',
                        icon: Icons.check_circle_rounded,
                        color: AppTheme.successGreen,
                        bgColor: AppTheme.successGreenSoft,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildCompactKpiCard(
                        title: 'Pending Items',
                        value: (_metrics?.pendingItems ?? 0).toString(),
                        subtitle: 'Awaiting store dispatch',
                        icon: Icons.hourglass_top_rounded,
                        color: AppTheme.saffron,
                        bgColor: AppTheme.saffronSoft,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildCompactKpiCard(
                        title: 'Total Valuation',
                        value: '₹ ${NumberFormat('#,##,###').format(_metrics?.totalValuation ?? 0)}',
                        subtitle: '${_metrics?.totalItems ?? 0} total items',
                        icon: Icons.currency_rupee,
                        color: AppTheme.primaryGold,
                        bgColor: AppTheme.primaryGoldSoft,
                        onTap: () => widget.onNavigateTab?.call(3),
                        isValuation: true,
                      ),
                      _buildCompactKpiCard(
                        title: 'Partial Issues',
                        value: (_metrics?.partialItems ?? 0).toString(),
                        subtitle: 'Partially fulfilled lines',
                        icon: Icons.pie_chart_outline_rounded,
                        color: AppTheme.warningOrange,
                        bgColor: const Color(0xFFFEF3C7),
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildCompactKpiCard(
                        title: 'Not Available',
                        value: (_metrics?.notAvailableItems ?? 0).toString(),
                        subtitle: 'Out of stock / Rejected',
                        icon: Icons.cancel_outlined,
                        color: AppTheme.dangerRed,
                        bgColor: AppTheme.dangerRedSoft,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildCompactKpiCard(
                        title: 'Tally Exported',
                        value: (_metrics?.tallyExportedSubs ?? 0).toString(),
                        subtitle: 'Ready for accounting',
                        icon: Icons.cloud_done_rounded,
                        color: AppTheme.navyAccent,
                        bgColor: AppTheme.infoBlueSoft,
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                      _buildCompactKpiCard(
                        title: 'Date Overrides',
                        value: (_metrics?.activeOverridesCount ?? 0).toString(),
                        subtitle: _metrics?.activeOverridesCount != null && _metrics!.activeOverridesCount > 0 ? 'Window is OPEN' : 'All windows standard',
                        icon: Icons.security_rounded,
                        color: AppTheme.royalNavy,
                        bgColor: AppTheme.bgPearl,
                        onTap: _showQuickOverrideDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- 4. Enhanced Quick Administration Hub (8 Direct Actions Grid) ---
                  const Text(
                    'Quick Administration Hub',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.95,
                    children: [
                      _buildActionShortcut(
                        icon: Icons.receipt_long,
                        label: 'Requisitions',
                        color: AppTheme.primaryGold,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildActionShortcut(
                        icon: Icons.inventory_2,
                        label: 'Live Stock',
                        color: AppTheme.navyAccent,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                      _buildActionShortcut(
                        icon: Icons.add_box,
                        label: '+ Material',
                        color: Colors.teal,
                        onTap: _showQuickAddMaterialDialog,
                      ),
                      _buildActionShortcut(
                        icon: Icons.person_add,
                        label: '+ User',
                        color: Colors.indigo,
                        onTap: _showQuickAddUserDialog,
                      ),
                      _buildActionShortcut(
                        icon: Icons.file_download,
                        label: 'Tally Export',
                        color: AppTheme.saffron,
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                      _buildActionShortcut(
                        icon: Icons.analytics,
                        label: 'Reports',
                        color: AppTheme.primaryGoldDark,
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                      _buildActionShortcut(
                        icon: Icons.lock_clock,
                        label: 'Override',
                        color: Colors.deepOrange,
                        onTap: _showQuickOverrideDialog,
                      ),
                      _buildActionShortcut(
                        icon: Icons.tune,
                        label: 'Settings',
                        color: AppTheme.royalNavy,
                        onTap: () => widget.onNavigateTab?.call(4),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- 5. System Timing Status Card ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Live Business Hours & Windows',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            Icon(Icons.schedule, size: 18, color: AppTheme.primaryGold),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TimingRow(
                          title: 'User Request Window',
                          timeRange: _timingStatus?['user_window']?['display'] ?? _timingStatus?['user_window']?['timing_display'] ?? '06:00 AM - 08:00 PM IST',
                          isOpen: _timingStatus?['user_window']?['is_open'] == true || _timingStatus?['is_user_window_open'] == true,
                        ),
                        const Divider(height: 16),
                        _TimingRow(
                          title: 'Store Dispatch Window',
                          timeRange: _timingStatus?['store_window']?['display'] ?? _timingStatus?['store_window']?['timing_display'] ?? '06:00 AM - 09:00 PM IST',
                          isOpen: _timingStatus?['store_window']?['is_open'] == true || _timingStatus?['is_store_edit_allowed'] == true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- 6. Active Date Overrides List Card ---
                  if (_overrides.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Active Date Overrides', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                              Text('${_overrides.length} logged', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ..._overrides.take(4).map((ov) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPearl,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('📅 Date: ${ov.overrideDate}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    Text('Expires: ${ov.expiresAt}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                                  ],
                                ),
                                StatusChip(status: ov.status),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

  // --- Helper Widget: Compact KPI Card ---
  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    bool isValuation = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isValuation ? 15 : 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widget: Action Shortcut Button ---
  Widget _buildActionShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final String title;
  final String timeRange;
  final bool isOpen;

  const _TimingRow({
    required this.title,
    required this.timeRange,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(timeRange, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen ? AppTheme.successGreenSoft : AppTheme.dangerRedSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOpen ? AppTheme.successGreen.withOpacity(0.5) : AppTheme.dangerRed.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOpen ? AppTheme.successGreen : AppTheme.dangerRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isOpen ? 'OPEN' : 'CLOSED',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isOpen ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
