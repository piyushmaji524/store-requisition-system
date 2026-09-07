import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Overrides state
  List<DateOverrideItem> _overrides = [];
  bool _isLoadingOverrides = true;

  // Settings state
  Map<String, dynamic>? _settingsMap;
  bool _isLoadingSettings = true;
  final _userStartCtrl = TextEditingController();
  final _userEndCtrl = TextEditingController();
  final _storeStartCtrl = TextEditingController();
  final _storeEndCtrl = TextEditingController();
  final _overrideHoursCtrl = TextEditingController();
  final _tallyLedgerCtrl = TextEditingController();

  // Activity logs state
  List<ActivityLogItem> _logs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOverrides();
    _loadSettings();
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userStartCtrl.dispose();
    _userEndCtrl.dispose();
    _storeStartCtrl.dispose();
    _storeEndCtrl.dispose();
    _overrideHoursCtrl.dispose();
    _tallyLedgerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverrides() async {
    setState(() => _isLoadingOverrides = true);
    final res = await ApiService.getDateOverrides();
    if (mounted) setState(() { _overrides = res; _isLoadingOverrides = false; });
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    final res = await ApiService.getSettings();
    if (mounted) {
      setState(() {
        if (res != null) {
          _settingsMap = res;
          _userStartCtrl.text = res['USER_REQUEST_START']?['value'] ?? '06:00';
          _userEndCtrl.text = res['USER_REQUEST_END']?['value'] ?? '20:00';
          _storeStartCtrl.text = res['STORE_EDIT_START']?['value'] ?? '06:00';
          _storeEndCtrl.text = res['STORE_EDIT_END']?['value'] ?? '21:00';
          _overrideHoursCtrl.text = res['ADMIN_OVERRIDE_HOURS']?['value'] ?? '2';
          _tallyLedgerCtrl.text = res['TALLY_SALES_LEDGER']?['value'] ?? 'Store Consumption';
        } else {
          if (_userStartCtrl.text.isEmpty) _userStartCtrl.text = '06:00';
          if (_userEndCtrl.text.isEmpty) _userEndCtrl.text = '20:00';
          if (_storeStartCtrl.text.isEmpty) _storeStartCtrl.text = '06:00';
          if (_storeEndCtrl.text.isEmpty) _storeEndCtrl.text = '21:00';
          if (_overrideHoursCtrl.text.isEmpty) _overrideHoursCtrl.text = '2';
          if (_tallyLedgerCtrl.text.isEmpty) _tallyLedgerCtrl.text = 'Store Consumption';
        }
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    final res = await ApiService.getActivityLogs();
    if (mounted) setState(() { _logs = res; _isLoadingLogs = false; });
  }

  Future<void> _saveSettings() async {
    final payload = <String, String>{
      'USER_REQUEST_START': _userStartCtrl.text.trim(),
      'USER_REQUEST_END': _userEndCtrl.text.trim(),
      'STORE_EDIT_START': _storeStartCtrl.text.trim(),
      'STORE_EDIT_END': _storeEndCtrl.text.trim(),
      'ADMIN_OVERRIDE_HOURS': _overrideHoursCtrl.text.trim(),
      'TALLY_SALES_LEDGER': _tallyLedgerCtrl.text.trim(),
    };

    final res = await ApiService.saveSettings(payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Settings updated.'),
          backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
        ),
      );
      _loadSettings();
    }
  }

  Future<void> _showNewOverrideDialog() async {
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));
    int durationHours = int.tryParse(_overrideHoursCtrl.text) ?? 3;
    final reasonController = TextEditingController();

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
                  const Text('🔓 Create Temporary Override', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPearl,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppTheme.primaryGold),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Duration dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgPearl,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duration Hours', style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<int>(
                      value: durationHours,
                      underline: const SizedBox(),
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
              const SizedBox(height: 12),

              // Reason
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason for Override *', hintText: 'e.g. Voucher edit requested...'),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason.')));
                      return;
                    }
                    Navigator.pop(ctx);
                    final res = await ApiService.createDateOverride(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      reasonController.text.trim(),
                      durationHours,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? 'Override created.'),
                          backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                        ),
                      );
                      _loadOverrides();
                    }
                  },
                  child: Text('🔓 Open $durationHours-Hour Window'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from the Admin App?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(116),
        child: Column(
          children: [
            GunayatanHeader(
              title: 'Controls & Configuration',
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
                  tooltip: 'Sign Out',
                  onPressed: _handleLogout,
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
                  Tab(text: 'Date Overrides'),
                  Tab(text: 'System Settings'),
                  Tab(text: 'Activity Logs'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Date Overrides
          _buildOverridesTab(),

          // 2. System Settings
          _buildSettingsTab(),

          // 3. Activity Logs
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildOverridesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.surfaceWhite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Past Date Overrides', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Open Date'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _showNewOverrideDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingOverrides
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
              : _overrides.isEmpty
                  ? const EmptyStateWidget(title: 'No Overrides', message: 'No date override records found.')
                  : RefreshIndicator(
                      color: AppTheme.primaryGold,
                      onRefresh: _loadOverrides,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _overrides.length,
                        itemBuilder: (context, idx) {
                          final ov = _overrides[idx];
                          final isOpen = ov.liveStatus == 'OPEN';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isOpen ? AppTheme.primaryGold : AppTheme.borderSubtle, width: isOpen ? 1.5 : 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target Date: ${ov.overrideDate}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                    ),
                                    StatusChip(status: ov.liveStatus),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Reason: ${ov.reason}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text('Opened By: ${ov.openedByName}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                Text('Expires: ${ov.expiresAt}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                if (isOpen) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.lock, size: 16, color: AppTheme.dangerRed),
                                      label: const Text('Force Close Window', style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w700)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppTheme.dangerRed),
                                      ),
                                      onPressed: () async {
                                        await ApiService.closeDateOverride(ov.id);
                                        _loadOverrides();
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
    }

    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _loadSettings,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              const Text('Business Window Timings (IST)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 14),

              // User Request Window
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userStartCtrl,
                      decoration: const InputDecoration(labelText: 'User Window Start (HH:MM)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _userEndCtrl,
                      decoration: const InputDecoration(labelText: 'User Window End (HH:MM)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Store Edit Window
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeStartCtrl,
                      decoration: const InputDecoration(labelText: 'Store Edit Start (HH:MM)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _storeEndCtrl,
                      decoration: const InputDecoration(labelText: 'Store Edit Cutoff (HH:MM)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Override duration
              TextField(
                controller: _overrideHoursCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default Admin Override Duration (Hours)'),
              ),
              const SizedBox(height: 14),

              // Tally Sales Ledger
              TextField(
                controller: _tallyLedgerCtrl,
                decoration: const InputDecoration(labelText: 'Tally Sales Ledger Name'),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save & Apply Live Settings'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                  onPressed: _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildLogsTab() {
    return _isLoadingLogs
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
        : _logs.isEmpty
            ? const EmptyStateWidget(title: 'No Activity Logs', message: 'No security logs found.')
            : RefreshIndicator(
                color: AppTheme.primaryGold,
                onRefresh: _loadLogs,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, idx) {
                    final l = _logs[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l.action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark)),
                              Text(l.createdAt, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('By: ${l.userName ?? 'System'} • Role: ${l.userRole ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          if (l.entityType != null)
                            Text('Entity: ${l.entityType} #${l.entityId ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    );
                  },
                ),
              );
  }
}
