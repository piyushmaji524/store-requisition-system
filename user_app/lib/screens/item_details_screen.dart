import 'package:flutter/material.dart';
import '../models/models.dart';

class ItemDetailsScreen extends StatelessWidget {
  final RequisitionItemModel item;
  const ItemDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Item Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.materialName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location: ${item.locationName ?? "-"}',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.replaceAll('_', ' '),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: badgeText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Details Table Card
            const Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _detailRow('Requested Quantity', '${item.requestedQuantity} ${item.unit}'),
                  const Divider(height: 20),
                  _detailRow(
                    'Issued Quantity',
                    '${item.issuedQuantity} ${item.unit}',
                    isHighlight: true,
                    highlightColor: isIssued ? const Color(0xFF16A34A) : (isPartial ? const Color(0xFFEA580C) : null),
                  ),
                  const Divider(height: 20),
                  _detailRow('Location', item.locationName ?? '-'),
                  const Divider(height: 20),
                  _detailRow('Your Remark', item.remark ?? '-'),
                  if (item.storeRemark != null && item.storeRemark!.isNotEmpty) ...[
                    const Divider(height: 20),
                    _detailRow(
                      'Store Note / Reason',
                      item.storeRemark!,
                      isHighlight: true,
                      highlightColor: const Color(0xFF2563EB),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Timeline / Lock Status Stepper
            const Text('Status Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _stepperItem(
                    title: 'Added by you',
                    subtitle: 'Item submitted to daily requisition',
                    isDone: true,
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                  _stepperLine(isDone: item.isLocked),
                  _stepperItem(
                    title: item.isLocked ? 'Action taken by Store' : 'Awaiting Store Action',
                    subtitle: item.isLocked
                        ? 'Store action recorded by ${item.storeActionByName ?? "Store Incharge"}'
                        : 'Store fulfillment pending',
                    isDone: item.isLocked,
                    icon: item.isLocked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: item.isLocked ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  ),
                  _stepperLine(isDone: item.isLocked),
                  _stepperItem(
                    title: item.isLocked ? 'Item Locked' : 'Editable',
                    subtitle: item.isLocked
                        ? 'Item is locked because store action has already been taken.'
                        : 'You can still edit or delete this pending item.',
                    isDone: item.isLocked,
                    icon: item.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: item.isLocked ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: highlightColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _stepperItem({required String title, required String subtitle, required bool isDone, required IconData icon, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperLine({required bool isDone}) {
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      width: 2,
      height: 24,
      color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
    );
  }
}
