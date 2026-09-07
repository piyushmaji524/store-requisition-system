import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/share_requisition_sheet.dart';

class RequisitionDetailsScreen extends StatefulWidget {
  final int requisitionId;
  final String requisitionNo;
  final String requisitionDate;

  const RequisitionDetailsScreen({
    super.key,
    required this.requisitionId,
    required this.requisitionNo,
    required this.requisitionDate,
  });

  @override
  State<RequisitionDetailsScreen> createState() => _RequisitionDetailsScreenState();
}

class _RequisitionDetailsScreenState extends State<RequisitionDetailsScreen> {
  MasterRequisitionModel? _requisition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final req = await ApiService.getRequisitionDetails(widget.requisitionId);
    if (!mounted) return;
    setState(() {
      _requisition = req;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.requisitionNo,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_requisition != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
              tooltip: 'Share Requisition Slip (PDF / WhatsApp)',
              onPressed: () => ShareRequisitionSheet.show(context, _requisition!),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requisition == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load requisition details',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetails,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 16),

                      // Metrics Summary
                      _buildMetricsRow(),
                      const SizedBox(height: 20),

                      // Sub Requisitions / Locations Breakdown
                      const Text(
                        'Requisition Items by Location',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),

                      ..._requisition!.subRequisitions.map((sub) => _buildSubRequisitionCard(sub)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requisition No:',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _requisition!.status.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _requisition!.requisitionNo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Requisition Date', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      _requisition!.requisitionDate,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Locations (Sites)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      '${_requisition!.subRequisitions.length} Location(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    final stats = _requisition!.stats;
    final totalItems = stats['total_items'] ?? 0;
    final issuedCount = stats['issued_count'] ?? 0;
    final partialCount = stats['partial_count'] ?? 0;
    final notAvailableCount = stats['not_available_count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _metricPill('Total Items', '$totalItems', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricPill('Issued', '$issuedCount', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricPill('Partial', '$partialCount', const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricPill('N/A', '$notAvailableCount', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
        ),
      ],
    );
  }

  Widget _metricPill(String title, String val, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSubRequisitionCard(SubRequisitionModel sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub Req Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      sub.locationName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Text(
                  sub.subRequisitionNo,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: sub.items.length,
            separatorBuilder: (ctx, idx) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final item = sub.items[index];
              return _buildItemRow(index + 1, item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, RequisitionItemModel item) {
    Color badgeBg = const Color(0xFFF1F5F9);
    Color badgeText = const Color(0xFF475569);

    if (item.status == 'ISSUED') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF15803D);
    } else if (item.status == 'PARTIALLY_ISSUED') {
      badgeBg = const Color(0xFFFFEDD5);
      badgeText = const Color(0xFFC2410C);
    } else if (item.status == 'NOT_AVAILABLE') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFB91C1C);
    } else if (item.status == 'PENDING') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFB45309);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item Name & Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$index. ${item.materialName}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
              child: Text(
                item.status.replaceAll('_', ' '),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: badgeText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quantities
        Row(
          children: [
            Text(
              'Requested: ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            Text(
              '${item.requestedQuantity} ${item.unit}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 20),
            Text(
              'Issued: ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            Text(
              '${item.issuedQuantity} ${item.unit}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: item.issuedQuantity > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        // Remarks
        if (item.remark != null && item.remark!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Remark: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Expanded(
                child: Text(
                  item.remark!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ],

        if (item.storeRemark != null && item.storeRemark!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, size: 12, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Store Note: ${item.storeRemark}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
