import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/share_history_sheet.dart';

class StoreHistoryScreen extends StatefulWidget {
  const StoreHistoryScreen({super.key});

  @override
  State<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends State<StoreHistoryScreen> {
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dateTo = DateTime.now();
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  List<StoreItem> _items = [];
  bool _isLoading = true;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({int page = 1}) async {
    setState(() => _isLoading = true);

    final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
    final toStr = DateFormat('yyyy-MM-dd').format(_dateTo);
    final search = _searchController.text.trim();

    final res = await ApiService.getHistory(
      dateFrom: fromStr,
      dateTo: toStr,
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      search: search.isEmpty ? null : search,
      page: page,
      limit: 50,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _items = res['items'] ?? [];
        _totalCount = res['total_count'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to load history')),
      );
    }
  }

  Future<void> _openShareHistory() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available to share for the selected filter.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    List<StoreItem> exportItems = _items;
    if (_totalCount > _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching full history records for report...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
      final toStr = DateFormat('yyyy-MM-dd').format(_dateTo);
      final search = _searchController.text.trim();

      final res = await ApiService.getHistory(
        dateFrom: fromStr,
        dateTo: toStr,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        search: search.isEmpty ? null : search,
        page: 1,
        limit: 1000,
      );

      if (res['success'] == true && res['items'] != null && (res['items'] as List).isNotEmpty) {
        exportItems = List<StoreItem>.from(res['items']);
      }
    }

    if (!mounted) return;

    ShareHistorySheet.show(
      context: context,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      statusFilter: _selectedStatus,
      searchQuery: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      items: exportItems,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
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
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromText = DateFormat('dd MMM').format(_dateFrom);
    final toText = DateFormat('dd MMM yyyy').format(_dateTo);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean Light Slate
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Store Issue History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Share Report',
            onPressed: _openShareHistory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Refresh',
            onPressed: () => _loadHistory(page: 1),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                // Date Range Button & Search Row
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$fromText - $toText',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search material, staff...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadHistory();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _loadHistory(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Status Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('ALL', 'All Items ($_totalCount)'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('ISSUED', 'Issued'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('PARTIALLY_ISSUED', 'Partially Issued'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('NOT_AVAILABLE', 'Not Available'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Report Summary Bar with 1-Tap Share
          if (!_isLoading && _items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_totalCount > _items.length ? '$_totalCount total items (showing ${_items.length})' : '${_items.length} records'} • ₹${_items.fold(0.0, (sum, i) => sum + i.amount).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedStatus == 'ALL' ? 'All Records' : _selectedStatus.replaceAll('_', ' ')} • $fromText - $toText',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: _openShareHistory,
                  ),
                ],
              ),
            ),

          // Items List / Loading State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 56, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No Issue Records Found',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try adjusting the date range or filters.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadHistory(page: 1),
                        color: const Color(0xFF2563EB),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _buildHistoryCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String key, String label) {
    final isSelected = _selectedStatus == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStatus = key);
        _loadHistory();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(StoreItem item) {
    Color statusBg;
    Color statusBorder;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (item.status == 'ISSUED') {
      statusBg = const Color(0xFFDCFCE7);
      statusBorder = const Color(0xFF86EFAC);
      statusColor = const Color(0xFF15803D);
      statusText = 'FULL ISSUED';
      statusIcon = Icons.check_circle_rounded;
    } else if (item.isPartial) {
      statusBg = const Color(0xFFFFEDD5);
      statusBorder = const Color(0xFFFDBA74);
      statusColor = const Color(0xFFC2410C);
      statusText = 'PARTIAL ISSUED';
      statusIcon = Icons.timelapse_rounded;
    } else if (item.status == 'NOT_AVAILABLE') {
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFFCA5A5);
      statusColor = const Color(0xFFB91C1C);
      statusText = 'NOT AVAILABLE';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBg = const Color(0xFFF1F5F9);
      statusBorder = const Color(0xFFCBD5E1);
      statusColor = const Color(0xFF64748B);
      statusText = item.status;
      statusIcon = Icons.info_outline_rounded;
    }

    final actionByStr = item.storeActionByName != null ? ' by ${item.storeActionByName}' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Sub-Requisition No & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  item.subRequisitionNo.isNotEmpty ? item.subRequisitionNo : item.masterRequisitionNo,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Material Name & Qty
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.materialName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                textAlign: TextAlign.end,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${item.issuedQuantity > 0 ? item.issuedQuantity : item.requestedQuantity} ',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: item.unit,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // User, Location, Department Metadata
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${item.userName} (${item.employeeCode}) • ${item.locationName}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (item.storeActionAt != null && item.storeActionAt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  'Action At: ${item.storeActionAt}$actionByStr',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ],

          if (item.storeRemark != null && item.storeRemark!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Note: ${item.storeRemark}',
                style: const TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
