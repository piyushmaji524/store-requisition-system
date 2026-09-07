import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import 'api_service.dart';

class PdfInvoiceService {
  /// Generate and share the PDF via Android Share Sheet
  static Future<void> shareRequisitionPdf(MasterRequisitionModel req) async {
    final bytes = await generateRequisitionPdf(req);
    final filename = 'Requisition_${req.requisitionNo.replaceAll('/', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Print or preview the PDF
  static Future<void> printRequisitionPdf(MasterRequisitionModel req) async {
    final bytes = await generateRequisitionPdf(req);
    final filename = 'Requisition_${req.requisitionNo.replaceAll('/', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: filename,
    );
  }

  /// Build the executive A4 PDF Document
  static Future<Uint8List> generateRequisitionPdf(MasterRequisitionModel req) async {
    final pdf = pw.Document();
    final user = ApiService.currentUser;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Theme Colors
    final navyBlue = PdfColor.fromHex('1E3A8A');
    final darkSlate = PdfColor.fromHex('0F172A');
    final mutedGray = PdfColor.fromHex('64748B');
    final borderGray = PdfColor.fromHex('CBD5E1');
    final cardBg = PdfColor.fromHex('F8FAFC');

    final stats = req.stats;
    final totalItems = stats['total_items'] ?? 0;
    final issuedCount = stats['issued_count'] ?? 0;
    final pendingCount = stats['pending_count'] ?? 0;
    final partialCount = stats['partial_count'] ?? 0;
    final notAvailableCount = stats['not_available_count'] ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Brand Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: pw.BoxDecoration(
                  color: navyBlue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'GUNAYATAN STORE & SITE MANAGEMENT',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'MATERIAL REQUISITION SLIP & ISSUE VOUCHER',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            req.requisitionNo,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue,
                            ),
                          ),
                          pw.Text(
                            'Date: ${req.requisitionDate}',
                            style: pw.TextStyle(fontSize: 8.5, color: darkSlate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Gunayatan ERP v2.0 • Computer Generated Document',
                  style: pw.TextStyle(fontSize: 8, color: mutedGray),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: mutedGray),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Requester & Requisition Info Dual Cards
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Card: Requester Profile
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: cardBg,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REQUESTED BY (EMPLOYEE)',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navyBlue,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _infoLine('Name:', user?.name ?? 'Employee'),
                        _infoLine('Employee Code:', user?.employeeCode ?? 'EMP-101'),
                        _infoLine('Department:', user?.departmentName ?? 'Civil & Maintenance'),
                        _infoLine('Mobile:', user?.mobile ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),

                // Right Card: Requisition Summary
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: cardBg,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REQUISITION METRICS',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navyBlue,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _infoLine('Overall Status:', req.status.replaceAll('_', ' ')),
                        _infoLine('Total Materials:', '$totalItems Items'),
                        _infoLine('Generated At:', dateStr),
                        _infoLine('Tally Export:', 'PENDING / VERIFIED'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // 2. Location-wise Item Tables
            ...req.subRequisitions.map((sub) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Location Header Pill
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EEF2FF'),
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('C7D2FE'), width: 0.8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'LOCATION: ${sub.locationName.toUpperCase()}',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue,
                            ),
                          ),
                          pw.Text(
                            'Sub-Req: ${sub.subRequisitionNo}',
                            style: pw.TextStyle(fontSize: 8.5, color: darkSlate),
                          ),
                        ],
                      ),
                    ),

                    // Items Table
                    pw.TableHelper.fromTextArray(
                      border: pw.TableBorder.all(color: borderGray, width: 0.5),
                      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkSlate),
                      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
                      cellStyle: const pw.TextStyle(fontSize: 8.5),
                      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      cellAlignments: {
                        0: pw.Alignment.center,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.centerRight,
                        3: pw.Alignment.centerRight,
                        4: pw.Alignment.center,
                        5: pw.Alignment.center,
                        6: pw.Alignment.centerLeft,
                      },
                      headers: ['#', 'Material Description', 'Req. Qty', 'Issued', 'Unit', 'Status', 'Purpose / Note'],
                      data: List<List<dynamic>>.generate(sub.items.length, (index) {
                        final it = sub.items[index];
                        return [
                          '${index + 1}',
                          it.materialName,
                          it.requestedQuantity.toStringAsFixed(it.requestedQuantity.truncateToDouble() == it.requestedQuantity ? 0 : 2),
                          it.issuedQuantity.toStringAsFixed(it.issuedQuantity.truncateToDouble() == it.issuedQuantity ? 0 : 2),
                          it.unit,
                          _buildPdfStatusText(it.status),
                          it.remark ?? '--',
                        ];
                      }),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 10),

            // 3. Metric KPI Summary Bar
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderGray, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _metricBox('TOTAL ITEMS', '$totalItems', darkSlate),
                  _metricBox('FULLY ISSUED', '$issuedCount', PdfColor.fromHex('16A34A')),
                  _metricBox('PENDING', '$pendingCount', navyBlue),
                  _metricBox('PARTIAL', '$partialCount', PdfColor.fromHex('D97706')),
                  _metricBox('NOT AVAILABLE', '$notAvailableCount', PdfColor.fromHex('DC2626')),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // 4. Signatures / Authorization Section
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: darkSlate),
                      pw.SizedBox(height: 4),
                      pw.Text('Site Supervisor Signature', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Requested By: ${user?.name ?? ""}', style: pw.TextStyle(fontSize: 7.5, color: mutedGray)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: darkSlate),
                      pw.SizedBox(height: 4),
                      pw.Text('Store Keeper Signature', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Material Issued & Handed Over', style: pw.TextStyle(fontSize: 7.5, color: mutedGray)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: darkSlate),
                      pw.SizedBox(height: 4),
                      pw.Text('Project / Site In-Charge', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Final Verification & Approval', style: pw.TextStyle(fontSize: 7.5, color: mutedGray)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('64748B'))),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
        ],
      ),
    );
  }

  static pw.Widget _metricBox(String title, String val, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(val, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('64748B'))),
      ],
    );
  }

  static String _buildPdfStatusText(String status) {
    if (status == 'ISSUED') return 'ISSUED';
    if (status == 'PARTIALLY_ISSUED') return 'PARTIAL';
    if (status == 'NOT_AVAILABLE') return 'N/A';
    return 'PENDING';
  }
}
