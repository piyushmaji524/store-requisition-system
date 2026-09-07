import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class RequisitionsTab extends StatefulWidget {
  const RequisitionsTab({super.key});

  @override
  State<RequisitionsTab> createState() => _RequisitionsTabState();
}

class _RequisitionsTabState extends State<RequisitionsTab> {
  List<AdminRequisition> _requisitions = [];
  bool _isLoading = true;
  String _selectedDateRangePreset = 'This Month';
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyPreset('This Month');
  }

  void _applyPreset(String preset) {
    _selectedDateRangePreset = preset;
    final now = DateTime.now();
    switch (preset) {
      case 'Today':
        _startDate = now;
        _endDate = now;
        break;
      case 'Yesterday':
        _startDate = now.subtract(const Duration(days: 1));
        _endDate = now.subtract(const Duration(days: 1));
        break;
      case 'Last 7 Days':
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
        break;
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'All':
        _startDate = DateTime(2025, 1, 1);
        _endDate = now.add(const Duration(days: 30));
        break;
    }
    _loadRequisitions();
  }

  Future<void> _loadRequisitions() async {
    setState(() => _isLoading = true);
    final fromStr = _selectedDateRangePreset == 'All' ? '' : DateFormat('yyyy-MM-dd').format(_startDate);
    final toStr = _selectedDateRangePreset == 'All' ? '' : DateFormat('yyyy-MM-dd').format(_endDate);

    final res = await ApiService.getRequisitions(
      dateFrom: fromStr,
      dateTo: toStr,
      status: _selectedStatus,
      search: _searchQuery,
      limit: 50,
    );

    if (mounted) {
      setState(() {
        _requisitions = (res['requisitions'] as List<AdminRequisition>?) ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetailsModal(AdminRequisition req) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequisitionDetailModal(req: req),
    );
  }

  Future<void> _printPdfSlip(AdminRequisition req, Map<String, dynamic> details) async {
    final doc = pw.Document();
    final subReqs = details['sub_requisitions'] as List? ?? [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('GUNAYATAN STORE REQUISITION SLIP',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.amber800),
              pw.SizedBox(height: 8),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Requisition #: ${req.requisitionNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${req.requisitionDate}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Requested By: ${req.userName} (${req.employeeCode})'),
                  pw.Text('Status: ${req.status}'),
                ],
              ),
              pw.SizedBox(height: 12),

              ...subReqs.map((sub) {
                final items = sub['items'] as List? ?? [];
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: PdfColors.grey200,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Location: ${sub['location_name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text(sub['sub_requisition_number'] ?? ''),
                          ],
                        ),
                      ),
                      pw.TableHelper.fromTextArray(
                        headers: ['Item Name', 'Code', 'Req Qty', 'Issued Qty', 'Unit', 'Rate', 'Valuation', 'Status'],
                        data: items.map((it) {
                          final issued = double.tryParse(it['issued_quantity']?.toString() ?? '0') ?? 0;
                          final rate = double.tryParse(it['rate']?.toString() ?? '0') ?? 0;
                          return [
                            it['material_name'] ?? '',
                            it['material_code'] ?? '',
                            it['requested_quantity']?.toString() ?? '',
                            it['issued_quantity']?.toString() ?? '0',
                            it['unit'] ?? '',
                            rate.toStringAsFixed(2),
                            (issued * rate).toStringAsFixed(2),
                            it['status'] ?? '',
                          ];
                        }).toList(),
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                        cellStyle: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorised Admin Signature', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Store Keeper Signature', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Receiver Signature', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Requisition_${req.requisitionNumber}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GunayatanHeader(
        title: 'Requisitions Explorer',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _loadRequisitions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Date preset bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surfaceWhite,
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Requisition #, Name, Employee Code...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadRequisitions();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                    _loadRequisitions();
                  },
                ),
                const SizedBox(height: 10),

                // Date Presets Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Today', 'Yesterday', 'Last 7 Days', 'This Month', 'All'].map((preset) {
                      final isSelected = _selectedDateRangePreset == preset;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGold,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                          onSelected: (_) => _applyPreset(preset),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Requisitions Feed List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : _requisitions.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Requisitions Found',
                        message: 'No requisitions match the selected filters or date range.',
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        onRefresh: _loadRequisitions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requisitions.length,
                          itemBuilder: (context, idx) {
                            final req = _requisitions[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderSubtle, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openDetailsModal(req),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              req.requisitionNumber,
                                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                            ),
                                            StatusChip(status: req.status),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${req.userName} (${req.employeeCode})',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '📅 ${req.requisitionDate} • ${req.totalItems} Items',
                                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                            ),
                                            const Row(
                                              children: [
                                                Text(
                                                  'Details',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGoldDark),
                                                ),
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
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _RequisitionDetailModal extends StatefulWidget {
  final AdminRequisition req;
  const _RequisitionDetailModal({required this.req});

  @override
  State<_RequisitionDetailModal> createState() => _RequisitionDetailModalState();
}

class _RequisitionDetailModalState extends State<_RequisitionDetailModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.getRequisitionDetails(widget.req.id);
    if (mounted) {
      setState(() {
        _details = res;
        _isLoading = false;
        if (res == null) {
          _error = 'Failed to load full requisition details.';
        }
      });
    }
  }

  Future<void> _printPdfSlip() async {
    if (_details == null) return;
    final doc = pw.Document();
    final subReqs = _details!['sub_requisitions'] as List? ?? [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'GUNAYATAN STORE REQUISITION SLIP',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.amber800),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Requisition #: ${widget.req.requisitionNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${widget.req.requisitionDate}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Requested By: ${widget.req.userName} (${widget.req.employeeCode})'),
                  pw.Text('Status: ${widget.req.status}'),
                ],
              ),
              pw.SizedBox(height: 12),
              ...subReqs.map((sub) {
                final items = sub['items'] as List? ?? [];
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: PdfColors.grey200,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Location: ${sub['location_name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text(sub['sub_requisition_number'] ?? ''),
                          ],
                        ),
                      ),
                      pw.TableHelper.fromTextArray(
                        headers: ['Item Name', 'Code', 'Req Qty', 'Issued Qty', 'Unit', 'Rate', 'Valuation', 'Status'],
                        data: items.map((it) {
                          final issued = double.tryParse(it['issued_quantity']?.toString() ?? '0') ?? 0;
                          final rate = double.tryParse(it['rate']?.toString() ?? '0') ?? 0;
                          return [
                            it['material_name'] ?? '',
                            it['material_code'] ?? '',
                            it['requested_quantity']?.toString() ?? '',
                            it['issued_quantity']?.toString() ?? '0',
                            it['unit'] ?? '',
                            rate.toStringAsFixed(2),
                            (issued * rate).toStringAsFixed(2),
                            it['status'] ?? '',
                          ];
                        }).toList(),
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                        cellStyle: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }),
              pw.Spacer(),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorised Admin Signature', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Store Keeper Signature', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Receiver Signature', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Requisition_${widget.req.requisitionNumber}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final subReqs = (_details?['sub_requisitions'] as List?) ?? [];
    final totalItems = (_details?['total_items'] as num?)?.toInt() ?? widget.req.totalItems;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primaryGold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.req.requisitionNumber,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(status: widget.req.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requested by: ${widget.req.userName} (${widget.req.employeeCode})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Quick Summary Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.bgPearl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Date', widget.req.requisitionDate, Icons.calendar_today_outlined),
                Container(width: 1, height: 28, color: AppTheme.borderSubtle),
                _buildMetricColumn('Total Items', totalItems.toString(), Icons.inventory_2_outlined),
                Container(width: 1, height: 28, color: AppTheme.borderSubtle),
                _buildMetricColumn('Status', widget.req.status, Icons.check_circle_outline, isHighlight: true),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryGold),
                        SizedBox(height: 14),
                        Text('Fetching requisition details...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchDetails,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : subReqs.isEmpty
                        ? const Center(
                            child: Text('No item records found in this requisition.', style: TextStyle(color: AppTheme.textMuted)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: subReqs.length,
                            itemBuilder: (ctx, sIdx) {
                              final sub = subReqs[sIdx];
                              final items = (sub['items'] as List?) ?? [];
                              final locName = sub['location_name'] ?? 'General Location';
                              final subNo = sub['sub_requisition_number'] ?? '';
                              final subStatus = sub['status'] ?? 'PENDING';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Location Sub-Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGold.withOpacity(0.08),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 16, color: AppTheme.primaryGold),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    locName,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (subNo.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '($subNo)',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          StatusChip(status: subStatus),
                                        ],
                                      ),
                                    ),

                                    // Items List in this location
                                    ...items.map((it) {
                                      final matName = it['material_name'] ?? 'Unknown Item';
                                      final matCode = it['material_code'] ?? '';
                                      final reqQty = it['requested_quantity']?.toString() ?? '0';
                                      final issQty = it['issued_quantity']?.toString() ?? '0';
                                      final unit = it['unit'] ?? '';
                                      final itemStatus = it['status'] ?? 'PENDING';
                                      final remark = it['remark'];
                                      final storeRemark = it['store_remark'];
                                      final isEmergency = it['is_emergency'] == 1 || it['is_emergency'] == true || it['is_emergency'] == '1';

                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.8)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              matName,
                                                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                                            ),
                                                          ),
                                                          if (isEmergency) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.red.shade50,
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: Colors.red.shade200),
                                                              ),
                                                              child: const Text('EMERGENCY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if (matCode.isNotEmpty) ...[
                                                        const SizedBox(height: 2),
                                                        Text('Code: $matCode', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                StatusChip(status: itemStatus),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // Quantities badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.bgPearl,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildQtyMetric('Requested Qty', '$reqQty $unit', Colors.blueGrey, isBold: true),
                                                  _buildQtyMetric('Issued Qty', '$issQty $unit', AppTheme.primaryGoldDark, isBold: true),
                                                ],
                                              ),
                                            ),

                                            // Remarks if any
                                            if (remark != null && remark.toString().trim().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text('Note: $remark', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                                            ],
                                            if (storeRemark != null && storeRemark.toString().trim().isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('Store Remark: $storeRemark', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange)),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),

                                    // Subtotal Footer for this location
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.surfaceWhite,
                                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${items.length} items for $locName', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                                          Text(
                                            'Status: $subStatus',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGoldDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // Bottom Action Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                    label: const Text('Close', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Share PDF Slip', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: _details != null ? _printPdfSlip : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isHighlight ? AppTheme.primaryGoldDark : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: isHighlight ? AppTheme.primaryGoldDark : AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isHighlight ? AppTheme.primaryGoldDark : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildQtyMetric(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
