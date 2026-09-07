import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/onesignal_service.dart';
import '../services/voice_alert_service.dart';
import '../widgets/share_requisition_sheet.dart';
import '../widgets/store_action_sheet.dart';

class StoreFeedScreen extends StatefulWidget {
  const StoreFeedScreen({super.key});

  @override
  State<StoreFeedScreen> createState() => _StoreFeedScreenState();
}

class _StoreFeedScreenState extends State<StoreFeedScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'PENDING';
  int? _selectedLocationId;
  final TextEditingController _searchController = TextEditingController();

  List<StoreItem> _items = [];
  FeedStats? _stats;
  List<LocationItem> _locations = [];
  bool _isLoading = true;

  // Multi-Select Batch Processing
  final Set<int> _selectedItemIds = {};
  bool _isBatchProcessing = false;

  // Auto-polling & real-time sync
  Timer? _pollingTimer;
  Set<int> _knownPendingIds = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _startLivePoller();
    OneSignalNotificationService.onNotificationReceived = () {
      if (mounted) {
        _loadFeed(showLoading: false, isAutoPoll: true);
      }
    };
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (OneSignalNotificationService.onNotificationReceived != null) {
      OneSignalNotificationService.onNotificationReceived = null;
    }
    _searchController.dispose();
    super.dispose();
  }

  void _startLivePoller() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && !_isBatchProcessing) {
        _loadFeed(showLoading: false, isAutoPoll: true);
      }
    });
  }

  Future<void> _loadFeed({bool showLoading = true, bool isAutoPoll = false}) async {
    if (showLoading) setState(() => _isLoading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final res = await ApiService.getFeed(
      date: dateStr,
      locationId: _selectedLocationId,
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final newItems = res['items'] as List<StoreItem>? ?? [];
      final newPendingItems = newItems.where((i) => i.status == 'PENDING').toList();
      final newPendingIds = newPendingItems.map((i) => i.id).toSet();

      // Check if any brand new pending requests arrived in real-time
      if (isAutoPoll && _knownPendingIds.isNotEmpty) {
        final brandNewIds = newPendingIds.difference(_knownPendingIds);
        if (brandNewIds.isNotEmpty) {
          final firstNew = newPendingItems.firstWhere((i) => brandNewIds.contains(i.id));
          HapticFeedback.heavyImpact();
          VoiceAlertService.speak('Dhyan dein! ${firstNew.userName} ne ${firstNew.materialName} ki request bheji hai.');
        }
      }
      _knownPendingIds = newPendingIds;

      setState(() {
        _items = newItems;
        _stats = res['stats'];
        _locations = res['locations'];
        _isLoading = false;
        // Clean up selections not in list
        _selectedItemIds.removeWhere((id) => !_items.any((i) => i.id == id && i.status == 'PENDING'));
      });
    } else {
      if (!isAutoPoll) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to load feed')),
        );
      }
    }
  }

  /// 1-Tap Single Issue (Optimistic UI + Haptics)
  Future<void> _handleSingleIssue(StoreItem item) async {
    HapticFeedback.mediumImpact();

    // Optimistic UI update
    final oldStatus = item.status;
    setState(() {
      item.status = 'ISSUED';
    });

    final res = await ApiService.processItemAction(
      itemId: item.id,
      actionType: 'FULL_ISSUE',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      HapticFeedback.lightImpact();
      _loadFeed(showLoading: false);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        item.status = oldStatus; // Rollback
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Action failed')),
      );
    }
  }

  /// Partial Issue Modal Handler
  Future<void> _handlePartialIssue(StoreItem item) async {
    final result = await StoreActionSheet.showPartialIssue(context: context, item: item);
    if (result != null && mounted) {
      HapticFeedback.mediumImpact();
      final issuedQty = result['issued_quantity'] as double;
      final remark = result['remark'] as String;

      final res = await ApiService.processItemAction(
        itemId: item.id,
        actionType: 'PARTIAL_ISSUE',
        issuedQuantity: issuedQty,
        remark: remark,
      );

      if (mounted) {
        if (res['success'] == true) {
          _loadFeed(showLoading: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Action failed')),
          );
        }
      }
    }
  }

  /// Not Available Modal Handler
  Future<void> _handleNotAvailable(StoreItem item) async {
    final remark = await StoreActionSheet.showNotAvailable(context: context, item: item);
    if (remark != null && mounted) {
      HapticFeedback.mediumImpact();

      final res = await ApiService.processItemAction(
        itemId: item.id,
        actionType: 'NOT_AVAILABLE',
        remark: remark,
      );

      if (mounted) {
        if (res['success'] == true) {
          _loadFeed(showLoading: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Action failed')),
          );
        }
      }
    }
  }

  /// Edit Already Processed Item Handler (Change status/quantity/remarks)
  Future<void> _handleEditItem(StoreItem item) async {
    final result = await StoreActionSheet.showEditProcessedItem(context: context, item: item);
    if (result != null && mounted) {
      HapticFeedback.mediumImpact();
      final actionType = result['action_type'] as String;
      final issuedQty = (result['issued_quantity'] as num?)?.toDouble() ?? 0.0;
      final remark = result['remark'] as String?;

      final res = await ApiService.processItemAction(
        itemId: item.id,
        actionType: actionType,
        issuedQuantity: issuedQty,
        remark: remark,
      );

      if (mounted) {
        if (res['success'] == true) {
          HapticFeedback.lightImpact();
          _loadFeed(showLoading: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Item updated successfully')),
          );
        } else {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Update failed')),
          );
        }
      }
    }
  }

  /// Batch Issue Selected Items
  Future<void> _handleBatchIssue() async {
    if (_selectedItemIds.isEmpty) return;

    HapticFeedback.heavyImpact();
    setState(() => _isBatchProcessing = true);

    final res = await ApiService.batchAction(
      itemIds: _selectedItemIds.toList(),
      actionType: 'FULL_ISSUE',
    );

    if (!mounted) return;

    setState(() {
      _isBatchProcessing = false;
      _selectedItemIds.clear();
    });

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Batch items issued successfully!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadFeed(showLoading: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Batch action failed')),
      );
    }
  }

  /// Toggle Select All Pending
  void _toggleSelectAllPending() {
    HapticFeedback.selectionClick();
    final pendingItems = _items.where((i) => i.status == 'PENDING').toList();
    if (_selectedItemIds.length == pendingItems.length && pendingItems.isNotEmpty) {
      setState(() => _selectedItemIds.clear());
    } else {
      setState(() {
        _selectedItemIds.clear();
        for (var i in pendingItems) {
          _selectedItemIds.add(i.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items.where((i) => i.status == 'PENDING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate Light
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Store Dispatch Feed',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
            ),
            Text(
              DateFormat('EEE, dd MMMM yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 7)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF2563EB),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Color(0xFF0F172A),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadFeed();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 22),
            onPressed: () => _loadFeed(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFeed(showLoading: false),
        child: Column(
          children: [
            // Top KPI Dashboard & Metrics
            _buildKpiHeader(),

            // Filter Tabs & Search Bar
            _buildFiltersAndSearch(),

            // Batch Action Strip (If pending items exist)
            if (pendingCount > 0) _buildBatchHeader(pendingCount),

            // List of Requisition Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _buildItemCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
      // Sticky Batch Issue Floating Bar
      bottomNavigationBar: _selectedItemIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${_selectedItemIds.length} Selected',
                        style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: _isBatchProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                          label: Text(
                            _isBatchProcessing ? 'Dispatching...' : 'Batch Issue (${_selectedItemIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                          ),
                          onPressed: _isBatchProcessing ? null : _handleBatchIssue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildKpiHeader() {
    final pending = _stats?.pendingCount ?? 0;
    final issued = _stats?.issuedCount ?? 0;
    final partial = _stats?.partialCount ?? 0;
    final na = _stats?.notAvailableCount ?? 0;
    final total = _stats?.totalItems ?? 0;
    final amount = _stats?.totalIssuedAmount ?? 0.0;
    final progress = _stats?.dispatchProgress ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'Dispatch Progress: $progress%',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ],
              ),
              Text(
                'Issued Value: ₹${NumberFormat('#,##,##0').format(amount)}',
                style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (issued + partial + na) / total : 0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _kpiPill('Pending', '$pending', const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFCA5A5)),
              _kpiPill('Issued', '$issued', const Color(0xFF16A34A), const Color(0xFFF0FDF4), const Color(0xFF86EFAC)),
              _kpiPill('Partial', '$partial', const Color(0xFFEA580C), const Color(0xFFFFF7ED), const Color(0xFFFDBA74)),
              _kpiPill('N/A', '$na', const Color(0xFF64748B), const Color(0xFFF1F5F9), const Color(0xFFCBD5E1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiPill(String title, String val, Color textCol, Color bgCol, Color borderCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Text('$title: ', style: TextStyle(fontSize: 11, color: textCol.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textCol)),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          // Search & Location Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _loadFeed(showLoading: false),
                    decoration: const InputDecoration(
                      hintText: 'Search Material, Employee...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Location Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedLocationId,
                      isExpanded: true,
                      hint: const Text('All Sites', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Sites', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        ..._locations.map((loc) => DropdownMenuItem<int?>(
                              value: loc.id,
                              child: Text(loc.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedLocationId = val);
                        _loadFeed();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusTab('PENDING', 'Pending (Action Needed)', Icons.pending_actions_rounded),
                const SizedBox(width: 6),
                _statusTab('ALL', 'All Items', Icons.list_alt_rounded),
                const SizedBox(width: 6),
                _statusTab('ISSUED', 'Full Issued', Icons.check_circle_rounded),
                const SizedBox(width: 6),
                _statusTab('PARTIAL_ISSUED', 'Partial', Icons.timelapse_rounded),
                const SizedBox(width: 6),
                _statusTab('NOT_AVAILABLE', 'Not Available', Icons.cancel_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTab(String key, String label, IconData icon) {
    final isSelected = _selectedStatus == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStatus = key);
        _loadFeed();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHeader(int pendingCount) {
    final isAllSelected = _selectedItemIds.length == pendingCount && pendingCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFEFF6FF), // Light Blue
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: isAllSelected,
                activeColor: const Color(0xFF2563EB),
                onChanged: (_) => _toggleSelectAllPending(),
              ),
              Text(
                isAllSelected ? 'Deselect All ($pendingCount)' : 'Select All Pending ($pendingCount)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
          if (_selectedItemIds.isNotEmpty)
            Text(
              '${_selectedItemIds.length} chosen',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(StoreItem item) {
    final isPending = item.status == 'PENDING';
    final isSelected = _selectedItemIds.contains(item.id);
    final cleanReq = (item.requestedQuantity % 1 == 0) ? item.requestedQuantity.toInt().toString() : item.requestedQuantity.toString();
    final cleanIss = (item.issuedQuantity % 1 == 0) ? item.issuedQuantity.toInt().toString() : item.issuedQuantity.toString();
    final cleanStock = (item.currentStock % 1 == 0) ? item.currentStock.toInt().toString() : item.currentStock.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : (item.isEmergency ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.isEmergency ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: item.isEmergency ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isPending)
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF2563EB),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (val == true) {
                              _selectedItemIds.add(item.id);
                            } else {
                              _selectedItemIds.remove(item.id);
                            }
                          });
                        },
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.locationName,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    if (item.isEmergency) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('EMERGENCY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.subRequisitionNo,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Main Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material Name & Stock Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.materialName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${item.materialCode} • Dept: ${item.departmentName}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    // Stock Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.currentStock > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text('Stock', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: item.currentStock > 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C))),
                          Text('$cleanStock ${item.unit}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: item.currentStock > 0 ? const Color(0xFF166534) : const Color(0xFF991B1B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Requester & Quantity Grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              Text(item.employeeCode, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Requested Qty', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              Text(
                                '$cleanReq ${item.unit}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          if (!isPending) ...[
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Issued', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                Text(
                                  '$cleanIss ${item.unit}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (item.remark != null && item.remark!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Note: ${item.remark}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                ],
                const SizedBox(height: 14),

                // ACTION BUTTONS ROW
                if (isPending)
                  Row(
                    children: [
                      // 🟢 Issue Full Button
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            label: const Text('Issue All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            onPressed: () => _handleSingleIssue(item),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 🟠 Partial Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEA580C),
                              side: const BorderSide(color: Color(0xFFFDBA74)),
                              backgroundColor: const Color(0xFFFFF7ED),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _handlePartialIssue(item),
                            child: const Text('Partial', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 🔴 N/A Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _handleNotAvailable(item),
                            child: const Text('N / A', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Status Completed Badge + Edit Action + Share Voucher Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statusBadge(item.status),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              backgroundColor: const Color(0xFFEFF6FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: () => _handleEditItem(item),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF2563EB)),
                            label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            onPressed: () {
                              ShareRequisitionSheet.show(
                                context: context,
                                requisitionNo: item.subRequisitionNo,
                                requisitionDate: item.requisitionDate,
                                requesterName: item.userName,
                                employeeCode: item.employeeCode,
                                departmentName: item.departmentName ?? 'Civil',
                                userMobile: item.userMobile,
                                items: [item],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case 'ISSUED':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        label = 'FULL ISSUED';
        icon = Icons.check_circle_rounded;
        break;
      case 'PARTIAL_ISSUED':
      case 'PARTIALLY_ISSUED':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFEA580C);
        label = 'PARTIAL ISSUED';
        icon = Icons.timelapse_rounded;
        break;
      case 'NOT_AVAILABLE':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        label = 'NOT AVAILABLE';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'PENDING';
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: text)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Requisitions Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'All items for this filter are dispatched or no requests logged.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
