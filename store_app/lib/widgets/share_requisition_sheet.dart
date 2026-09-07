import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/pdf_invoice_service.dart';

class ShareRequisitionSheet {
  /// Open multi-option sharing modal
  static void show({
    required BuildContext context,
    required String requisitionNo,
    required String requisitionDate,
    required String requesterName,
    required String employeeCode,
    required String departmentName,
    required String? userMobile,
    required List<StoreItem> items,
  }) {
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
                    child: const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Store Requisition',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$requisitionNo • $requesterName',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                title: 'Share as PDF Document',
                subtitle: 'Send official executive A4 dispatch voucher via WhatsApp / Drive',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _executePdfAction(
                    context: context,
                    actionName: 'Sharing PDF Voucher...',
                    action: () => PdfInvoiceService.printOrSharePdf(
                      requisitionNo: requisitionNo,
                      requisitionDate: requisitionDate,
                      requesterName: requesterName,
                      employeeCode: employeeCode,
                      departmentName: departmentName,
                      userMobile: userMobile,
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
                title: 'Print / Preview PDF Voucher',
                subtitle: 'Directly view or print A4 voucher on connected printer',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _executePdfAction(
                    context: context,
                    actionName: 'Opening Print Preview...',
                    action: () => PdfInvoiceService.printOrPreviewPdf(
                      requisitionNo: requisitionNo,
                      requisitionDate: requisitionDate,
                      requesterName: requesterName,
                      employeeCode: employeeCode,
                      departmentName: departmentName,
                      userMobile: userMobile,
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
                subtitle: 'Instant WhatsApp text message with items and dispatch status',
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _shareWhatsAppText(
                    requisitionNo: requisitionNo,
                    requisitionDate: requisitionDate,
                    requesterName: requesterName,
                    departmentName: departmentName,
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
        duration: const Duration(seconds: 2),
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
            content: Text('Failed to generate PDF: ${e.toString()}'),
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
    required String requisitionNo,
    required String requisitionDate,
    required String requesterName,
    required String departmentName,
    required List<StoreItem> items,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('📋 *GUNAYATAN STORE DISPATCH SLIP*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Slip No: *$requisitionNo*');
    buffer.writeln('Date: $requisitionDate');
    buffer.writeln('Requester: *$requesterName* ($departmentName)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 *MATERIALS DISPATCH:*');

    // Group items by location
    final Map<String, List<StoreItem>> groups = {};
    for (var item in items) {
      groups.putIfAbsent(item.locationName, () => []).add(item);
    }

    for (var entry in groups.entries) {
      buffer.writeln('\n📍 *${entry.key}:*');
      for (var i = 0; i < entry.value.length; i++) {
        final itm = entry.value[i];
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

        buffer.writeln('${i + 1}. $icon *${itm.materialName}* - Req: $cleanReq ${itm.unit} | Issued: $cleanIss ${itm.unit} [${itm.status}]');
        if (itm.storeRemark != null && itm.storeRemark!.isNotEmpty) {
          buffer.writeln('    _Store Note: ${itm.storeRemark}_');
        } else if (itm.remark != null && itm.remark!.isNotEmpty) {
          buffer.writeln('    _Note: ${itm.remark}_');
        }
      }
    }

    buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Verified & Issued by Gunayatan Store Team');

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
