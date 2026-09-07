import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/pdf_invoice_service.dart';

class ShareHistorySheet {
  /// Open multi-option sharing modal for Store History Report
  static void show({
    required BuildContext context,
    required DateTime dateFrom,
    required DateTime dateTo,
    required String statusFilter,
    String? searchQuery,
    required List<StoreItem> items,
  }) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available to share for the selected filter.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fromText = DateFormat('dd MMM').format(dateFrom);
    final toText = DateFormat('dd MMM yyyy').format(dateTo);
    final dateRangeLabel = dateFrom.year == dateTo.year && dateFrom.month == dateTo.month && dateFrom.day == dateTo.day
        ? DateFormat('dd MMM yyyy').format(dateFrom)
        : '$fromText - $toText';

    final totalAmount = items.fold(0.0, (sum, i) => sum + i.amount);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assessment_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Store History Report',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateRangeLabel • ${items.length} item(s) • ₹${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1: PDF Document Share
              _shareTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                title: 'Share PDF Statement Report',
                subtitle: 'Official executive A4 statement with itemized table & audit signatures',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _executePdfAction(
                    context: context,
                    actionName: 'Generating History Statement PDF...',
                    action: () => PdfInvoiceService.shareHistoryReportPdf(
                      dateFrom: dateFrom,
                      dateTo: dateTo,
                      statusFilter: statusFilter,
                      searchQuery: searchQuery,
                      items: items,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Print & Preview PDF
              _shareTile(
                icon: Icons.print_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                title: 'Print / Preview PDF Statement',
                subtitle: 'Directly view or print A4 register on connected thermal/office printer',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _executePdfAction(
                    context: context,
                    actionName: 'Opening Print Preview...',
                    action: () => PdfInvoiceService.printOrPreviewHistoryPdf(
                      dateFrom: dateFrom,
                      dateTo: dateTo,
                      statusFilter: statusFilter,
                      searchQuery: searchQuery,
                      items: items,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Share via WhatsApp Text
              _shareTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                title: 'Share via WhatsApp (Text Summary)',
                subtitle: 'Send formatted dispatch summary and counts on WhatsApp',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _shareWhatsAppText(
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    statusFilter: statusFilter,
                    items: items,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _executePdfAction({
    required BuildContext context,
    required String actionName,
    required Future<void> Function() action,
  }) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(actionName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate statement: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Widget _shareTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  static Future<void> _shareWhatsAppText({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String statusFilter,
    required List<StoreItem> items,
  }) async {
    final fromText = DateFormat('dd MMM yyyy').format(dateFrom);
    final toText = DateFormat('dd MMM yyyy').format(dateTo);
    final dateRangeLabel = dateFrom.year == dateTo.year && dateFrom.month == dateTo.month && dateFrom.day == dateTo.day
        ? fromText
        : '$fromText to $toText';

    final issuedCount = items.where((i) => i.status == 'ISSUED').length;
    final partialCount = items.where((i) => i.isPartial).length;
    final naCount = items.where((i) => i.status == 'NOT_AVAILABLE').length;
    final totalAmount = items.fold(0.0, (sum, i) => sum + i.amount);

    final buffer = StringBuffer();
    buffer.writeln('📊 *GUNAYATAN STORE - DISPATCH REPORT*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📅 Period: *$dateRangeLabel*');
    buffer.writeln('🔍 Filter: *${statusFilter == 'ALL' ? 'All Records' : statusFilter}*');
    buffer.writeln('📦 Total Items: *${items.length}*');
    buffer.writeln('✅ Full Issued: *$issuedCount* | ⚡ Partial: *$partialCount* | ❌ N/A: *$naCount*');
    buffer.writeln('💰 Total Value: *₹${totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *DISPATCH BREAKDOWN:*');

    // Limit first 30 items for WhatsApp text to avoid url length limits
    final displayItems = items.take(30).toList();
    for (var i = 0; i < displayItems.length; i++) {
      final itm = displayItems[i];
      final cleanReq = (itm.requestedQuantity % 1 == 0) ? itm.requestedQuantity.toInt().toString() : itm.requestedQuantity.toString();
      final cleanIss = (itm.issuedQuantity % 1 == 0) ? itm.issuedQuantity.toInt().toString() : itm.issuedQuantity.toString();
      
      String icon = '⚪';
      if (itm.status == 'ISSUED') {
        icon = '✅';
      } else if (itm.isPartial) {
        icon = '⚡';
      } else if (itm.status == 'NOT_AVAILABLE') {
        icon = '❌';
      }

      buffer.writeln('${i + 1}. $icon *${itm.materialName}* - Req: $cleanReq ${itm.unit} | Issued: $cleanIss ${itm.unit}');
      buffer.writeln('    👤 ${itm.userName} (${itm.employeeCode}) • 📍 ${itm.locationName} [${itm.requisitionDate}]');
      if (itm.storeRemark != null && itm.storeRemark!.isNotEmpty) {
        buffer.writeln('    _Store Note: ${itm.storeRemark}_');
      }
    }

    if (items.length > 30) {
      buffer.writeln('\n_...and ${items.length - 30} more item(s). Download PDF for full register._');
    }

    buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Generated via Gunayatan Store App');

    final encoded = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('whatsapp://send?text=$encoded');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        final webUrl = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
