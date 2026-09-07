import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/share_requisition_sheet.dart';
import 'add_material_screen.dart';
import 'edit_item_screen.dart';
import 'item_details_screen.dart';

class MyRequisitionScreen extends StatefulWidget {
  static final ValueNotifier<String> activeFilterNotifier = ValueNotifier<String>('ALL');

  static void setFilter(String filter) {
    activeFilterNotifier.value = filter;
  }

  const MyRequisitionScreen({super.key});

  @override
  State<MyRequisitionScreen> createState() => _MyRequisitionScreenState();
}

class _MyRequisitionScreenState extends State<MyRequisitionScreen> {
  MasterRequisitionModel? _masterRequisition;
  bool _isLoading = true;
  String _activeFilter = 'ALL'; // ALL, PENDING, ISSUED, PARTIAL, NA
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _activeFilter = MyRequisitionScreen.activeFilterNotifier.value;
    _loadRequisition();

    // 1. Filter changes from HomeScreen or other tabs
    MyRequisitionScreen.activeFilterNotifier.addListener(_onFilterNotifierChanged);

    // 2. Instant cross-screen event listener
    ApiService.dataChangeNotifier.addListener(_onDataChanged);

    // 3. Real-time background periodic sync (every 4 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadRequisition(silent: true);
      }
    });
  }

  @override
  void dispose() {
    MyRequisitionScreen.activeFilterNotifier.removeListener(_onFilterNotifierChanged);
    ApiService.dataChangeNotifier.removeListener(_onDataChanged);
    _syncTimer?.cancel();
    super.dispose();
  }

  void _onFilterNotifierChanged() {
    if (mounted && _activeFilter != MyRequisitionScreen.activeFilterNotifier.value) {
      setState(() {
        _activeFilter = MyRequisitionScreen.activeFilterNotifier.value;
      });
    }
  }

  void _onDataChanged() {
    if (mounted) {
      _loadRequisition(silent: true);
    }
  }

  Future<void> _loadRequisition({bool silent = false}) async {
    if (!silent && _masterRequisition == null) {
      setState(() => _isLoading = true);
    }

    final req = await ApiService.getTodayRequisition();
    if (!mounted) return;
    setState(() {
      _masterRequisition = req;
      _isLoading = false;
    });
  }

  List<RequisitionItemModel> _getFilteredItems() {
    if (_masterRequisition == null) return [];
    final allItems = <RequisitionItemModel>[];
    for (final sub in _masterRequisition!.subRequisitions) {
      allItems.addAll(sub.items);
    }
    allItems.sort((a, b) => b.id.compareTo(a.id));

    if (_activeFilter == 'PENDING') {
      return allItems.where((i) => i.status == 'PENDING').toList();
    } else if (_activeFilter == 'ISSUED') {
      return allItems.where((i) => i.status == 'ISSUED').toList();
    } else if (_activeFilter == 'PARTIAL') {
      return allItems.where((i) => i.status == 'PARTIALLY_ISSUED').toList();
    } else if (_activeFilter == 'NA') {
      return allItems.where((i) => i.status == 'NOT_AVAILABLE').toList();
    }
    return allItems;
  }

  Map<int, int> _getItemSequenceMap() {
    final map = <int, int>{};
    if (_masterRequisition == null) return map;
    final all = <RequisitionItemModel>[];
    for (final sub in _masterRequisition!.subRequisitions) {
      all.addAll(sub.items);
    }
    all.sort((a, b) => a.id.compareTo(b.id));
    for (int i = 0; i < all.length; i++) {
      map[all[i].id] = i + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final seqMap = _getItemSequenceMap();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Requisition', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_masterRequisition != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
              tooltip: 'Share Requisition Slip (PDF / WhatsApp)',
              onPressed: () => ShareRequisitionSheet.show(context, _masterRequisition!),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRequisition,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _masterRequisition == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No Items Requested Today',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your daily master requisition will be automatically created when you add your first material.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
                            );
                            if (res == true) _loadRequisition();
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Material'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header Summary Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Requisition No.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Row(
                                    children: [
                                      Text(
                                        _masterRequisition!.requisitionNo,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2563EB)),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: _masterRequisition!.requisitionNo));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Requisition No. copied!'), duration: Duration(seconds: 1)),
                                          );
                                        },
                                        child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OPEN',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Window: 06:00 AM - 08:00 PM (IST)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(height: 14),

                          // Filter Tabs
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('All (${_masterRequisition!.allItems.length})', 'ALL'),
                                const SizedBox(width: 8),
                                _filterChip('Pending (${_masterRequisition!.stats["pending_count"] ?? 0})', 'PENDING'),
                                const SizedBox(width: 8),
                                _filterChip('Issued (${_masterRequisition!.stats["issued_count"] ?? 0})', 'ISSUED'),
                                const SizedBox(width: 8),
                                _filterChip('Partial (${_masterRequisition!.stats["partial_count"] ?? 0})', 'PARTIAL'),
                                const SizedBox(width: 8),
                                _filterChip('N/A (${_masterRequisition!.stats["not_available_count"] ?? 0})', 'NA'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                'No items in "$_activeFilter" category',
                                style: const TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredItems.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final seqNo = seqMap[item.id] ?? (filteredItems.length - index);
                                return _buildItemCard(item, seqNo);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _filterChip(String title, String key) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = key);
        MyRequisitionScreen.activeFilterNotifier.value = key;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(RequisitionItemModel item, int seqNo) {
    final isPending = item.status == 'PENDING';
    final isIssued = item.status == 'ISSUED';
    final isPartial = item.status == 'PARTIALLY_ISSUED';
    final isNa = item.status == 'NOT_AVAILABLE';

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeText = const Color(0xFFB45309);

    if (isIssued) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF15803D);
    } else if (isPartial) {
      badgeBg = const Color(0xFFFFEDD5);
      badgeText = const Color(0xFFC2410C);
    } else if (isNa) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFB91C1C);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$seqNo. ${item.materialName}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    item.status.replaceAll('_', ' '),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5, color: badgeText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quantities & Location
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Requested', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text('${item.requestedQuantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                if (!isPending)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Issued', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '${item.issuedQuantity} ${item.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(
                        item.locationName ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (item.remark != null && item.remark!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Remark: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  Expanded(
                    child: Text(
                      item.remark!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],

            if (item.storeRemark != null && item.storeRemark!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.store_rounded, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Store Note: ${item.storeRemark}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 20),

            // Actions or Lock Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.isLocked)
                  const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('Locked (Store Action Taken)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.lock_open_rounded, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('Pending (Editable)', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    ],
                  ),

                if (isPending)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditItemScreen(item: item, currentLocationId: 1),
                            ),
                          );
                          if (res == true) _loadRequisition();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 13),
                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
