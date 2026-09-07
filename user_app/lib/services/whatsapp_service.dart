import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'api_service.dart';

class WhatsAppService {
  static Future<void> shareMasterRequisition(MasterRequisitionModel req) async {
    final buffer = StringBuffer();
    final user = ApiService.currentUser;

    buffer.writeln('📋 *STORE REQUISITION SLIP*');
    buffer.writeln('*Requisition No:* ${req.requisitionNo}');
    buffer.writeln('*Date:* ${req.requisitionDate}');
    if (user != null) {
      buffer.writeln('*Requested By:* ${user.name} (${user.employeeCode})');
      buffer.writeln('*Department:* ${user.departmentName}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    for (final sub in req.subRequisitions) {
      buffer.writeln('📍 *Location:* ${sub.locationName}');
      for (int i = 0; i < sub.items.length; i++) {
        final it = sub.items[i];
        String statusIcon = '⏳';
        String statusLabel = 'PENDING';

        if (it.status == 'ISSUED') {
          statusIcon = '✅';
          statusLabel = 'ISSUED (${it.issuedQuantity} ${it.unit})';
        } else if (it.status == 'PARTIALLY_ISSUED') {
          statusIcon = '⚡';
          statusLabel = 'PARTIAL (${it.issuedQuantity} / ${it.requestedQuantity} ${it.unit})';
        } else if (it.status == 'NOT_AVAILABLE') {
          statusIcon = '❌';
          statusLabel = 'NOT AVAILABLE';
        }

        buffer.writeln('${i + 1}. ${it.materialName} — ${it.requestedQuantity} ${it.unit}  [$statusIcon $statusLabel]');
        if (it.remark != null && it.remark!.isNotEmpty) {
          buffer.writeln('    _Note: ${it.remark}_');
        }
      }
      buffer.writeln('');
    }

    final stats = req.stats;
    final totalItems = stats['total_items'] ?? 0;
    final issuedCount = stats['issued_count'] ?? 0;
    final pendingCount = stats['pending_count'] ?? 0;
    final partialCount = stats['partial_count'] ?? 0;
    final notAvailableCount = stats['not_available_count'] ?? 0;

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 *STATUS SUMMARY:*');
    buffer.writeln('• Total Items: $totalItems');
    buffer.writeln('• ✅ Full Issued: $issuedCount');
    buffer.writeln('• ⏳ Pending Action: $pendingCount');
    buffer.writeln('• ⚡ Partially Issued: $partialCount');
    buffer.writeln('• ❌ Not Available: $notAvailableCount');
    buffer.writeln('');
    buffer.writeln('_Gunayatan Store Requisition System_');

    final encodedText = Uri.encodeComponent(buffer.toString());
    final whatsappIntentUri = Uri.parse('whatsapp://send?text=$encodedText');
    final webFallbackUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');

    try {
      if (await canLaunchUrl(whatsappIntentUri)) {
        await launchUrl(whatsappIntentUri);
      } else {
        await launchUrl(webFallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webFallbackUri, mode: LaunchMode.externalApplication);
    }
  }
}
