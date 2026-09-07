import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PdfInvoiceService {
  /// Generate A4 Requisition Dispatch Voucher PDF (Single / Sub-Requisition)
  static Future<Uint8List> generateRequisitionPdf({
    required String requisitionNo,
    required String requisitionDate,
    required String requesterName,
    required String employeeCode,
    required String departmentName,
    required String? userMobile,
    required List<StoreItem> items,
  }) async {
    final pdf = pw.Document();

    final primaryNavy = PdfColor.fromHex('#1E3A8A');
    final darkSlate = PdfColor.fromHex('#0F172A');
    final subtleGray = PdfColor.fromHex('#F8FAFC');
    final borderGray = PdfColor.fromHex('#CBD5E1');
    final textMuted = PdfColor.fromHex('#64748B');

    // Group items by Location
    final Map<String, List<StoreItem>> locationGroups = {};
    for (var item in items) {
      locationGroups.putIfAbsent(item.locationName, () => []).add(item);
    }

    final totalItems = items.length;
    final issuedItems = items.where((i) => i.status == 'ISSUED').length;
    final partialItems = items.where((i) => i.isPartial).length;
    final naItems = items.where((i) => i.status == 'NOT_AVAILABLE').length;
    final pendingItems = items.where((i) => i.status == 'PENDING').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Corporate Header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: pw.BoxDecoration(
                color: primaryNavy,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GUNAYATAN STORE DISPATCH VOUCHER',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Material Requisition & Warehouse Movement Record',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FFFFFF'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'OFFICIAL SLIP',
                      style: pw.TextStyle(
                        color: primaryNavy,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Metadata Dual Cards
            pw.Row(
              children: [
                // Requester Card
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: subtleGray,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REQUESTER DETAILS', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text(requesterName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                        pw.SizedBox(height: 2),
                        pw.Text('Code: $employeeCode | Dept: $departmentName', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                        if (userMobile != null && userMobile.isNotEmpty)
                          pw.Text('Phone: $userMobile', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Requisition Card
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: subtleGray,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REQUISITION METADATA', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text('Slip No: $requisitionNo', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                        pw.SizedBox(height: 2),
                        pw.Text('Date: $requisitionDate', style: pw.TextStyle(fontSize: 8, color: darkSlate)),
                        pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: pw.TextStyle(fontSize: 7.5, color: textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Summary Metric Pills
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGray, width: 0.6),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _metricBlock('TOTAL ITEMS', '$totalItems', primaryNavy),
                  _metricBlock('FULL ISSUED', '$issuedItems', PdfColor.fromHex('#16A34A')),
                  _metricBlock('PARTIAL', '$partialItems', PdfColor.fromHex('#EA580C')),
                  _metricBlock('NOT AVAILABLE', '$naItems', PdfColor.fromHex('#DC2626')),
                  _metricBlock('PENDING', '$pendingItems', PdfColor.fromHex('#64748B')),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Location Grouped Tables
            ...locationGroups.entries.map((entry) {
              final locName = entry.key;
              final locItems = entry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Location Header
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#EEF2FF'),
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE'), width: 0.6),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'LOCATION: ${locName.toUpperCase()}',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                          ),
                          pw.Text(
                            '${locItems.length} Material(s)',
                            style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    // Table
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGray, width: 0.5),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(0.6),
                        1: pw.FlexColumnWidth(3.5),
                        2: pw.FlexColumnWidth(1.2),
                        3: pw.FlexColumnWidth(1.2),
                        4: pw.FlexColumnWidth(1.4),
                        5: pw.FlexColumnWidth(2.0),
                      },
                      children: [
                        // Header Row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                          children: [
                            _tableCell('#', isHeader: true),
                            _tableCell('MATERIAL NAME', isHeader: true),
                            _tableCell('REQ QTY', isHeader: true, align: pw.TextAlign.right),
                            _tableCell('ISS QTY', isHeader: true, align: pw.TextAlign.right),
                            _tableCell('STATUS', isHeader: true, align: pw.TextAlign.center),
                            _tableCell('STORE REMARK', isHeader: true),
                          ],
                        ),
                        // Data Rows
                        ...locItems.asMap().entries.map((e) {
                          final idx = e.key + 1;
                          final item = e.value;
                          final cleanReq = (item.requestedQuantity % 1 == 0) ? item.requestedQuantity.toInt().toString() : item.requestedQuantity.toString();
                          final cleanIss = (item.issuedQuantity % 1 == 0) ? item.issuedQuantity.toInt().toString() : item.issuedQuantity.toString();
                          final note = item.storeRemark?.trim().isNotEmpty == true ? item.storeRemark! : (item.remark?.trim().isNotEmpty == true ? item.remark! : '-');

                          return pw.TableRow(
                            children: [
                              _tableCell('$idx', align: pw.TextAlign.center),
                              _tableCell('${item.materialName} (${item.unit})'),
                              _tableCell('$cleanReq ${item.unit}', align: pw.TextAlign.right),
                              _tableCell('$cleanIss ${item.unit}', align: pw.TextAlign.right),
                              _statusCell(item.status),
                              _tableCell(note),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 20),

            // Signature & Authorization Block
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('Requested By (Supervisor)'),
                  _signatureBox('Verified By (In-Charge)'),
                  _signatureBox('Issued By (Store Keeper)'),
                  _signatureBox('Received By (Handover)'),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate A4 Store History Statement / Dispatch Register Report
  static Future<Uint8List> generateHistoryReportPdf({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String statusFilter,
    String? searchQuery,
    required List<StoreItem> items,
  }) async {
    final pdf = pw.Document();

    final primaryNavy = PdfColor.fromHex('#1E3A8A');
    final darkSlate = PdfColor.fromHex('#0F172A');
    final subtleGray = PdfColor.fromHex('#F8FAFC');
    final borderGray = PdfColor.fromHex('#CBD5E1');
    final textMuted = PdfColor.fromHex('#64748B');

    final totalItems = items.length;
    final issuedItems = items.where((i) => i.status == 'ISSUED').length;
    final partialItems = items.where((i) => i.isPartial).length;
    final naItems = items.where((i) => i.status == 'NOT_AVAILABLE').length;
    final totalAmount = items.fold(0.0, (sum, i) => sum + i.amount);

    final fromStr = DateFormat('dd MMM yyyy').format(dateFrom);
    final toStr = DateFormat('dd MMM yyyy').format(dateTo);
    final dateRangeLabel = dateFrom.year == dateTo.year && dateFrom.month == dateTo.month && dateFrom.day == dateTo.day
        ? fromStr
        : '$fromStr to $toStr';

    String filterLabel = statusFilter == 'ALL' ? 'All Statuses' : statusFilter.replaceAll('_', ' ');
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filterLabel += ' • Query: "$searchQuery"';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: pw.BoxDecoration(
                color: primaryNavy,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GUNAYATAN STORE DISPATCH STATEMENT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: $dateRangeLabel',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FFFFFF'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'DISPATCH REGISTER',
                      style: pw.TextStyle(
                        color: primaryNavy,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Metadata & KPI Bar
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: subtleGray,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REPORT METADATA', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textMuted)),
                        pw.SizedBox(height: 3),
                        pw.Text('Filter: $filterLabel', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                        pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: pw.TextStyle(fontSize: 7.5, color: textMuted)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  flex: 7,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: subtleGray,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _metricBlock('TOTAL ENTRIES', '$totalItems', primaryNavy),
                        _metricBlock('FULL ISSUED', '$issuedItems', PdfColor.fromHex('#16A34A')),
                        _metricBlock('PARTIAL', '$partialItems', PdfColor.fromHex('#EA580C')),
                        _metricBlock('NOT AVAIL', '$naItems', PdfColor.fromHex('#DC2626')),
                        _metricBlock('TOTAL VALUE', 'Rs. ${totalAmount.toStringAsFixed(0)}', darkSlate),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // History Register Table
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(2.6),
                5: pw.FlexColumnWidth(1.0),
                6: pw.FlexColumnWidth(1.0),
                7: pw.FlexColumnWidth(1.1),
                8: pw.FlexColumnWidth(1.6),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                  children: [
                    _tableCell('#', isHeader: true),
                    _tableCell('DATE', isHeader: true),
                    _tableCell('RECIPIENT / EMP', isHeader: true),
                    _tableCell('LOCATION', isHeader: true),
                    _tableCell('MATERIAL DESCRIPTION', isHeader: true),
                    _tableCell('REQ QTY', isHeader: true, align: pw.TextAlign.right),
                    _tableCell('ISS QTY', isHeader: true, align: pw.TextAlign.right),
                    _tableCell('STATUS', isHeader: true, align: pw.TextAlign.center),
                    _tableCell('REMARK / NOTE', isHeader: true),
                  ],
                ),
                // Data Rows
                ...items.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final itm = e.value;
                  final cleanReq = (itm.requestedQuantity % 1 == 0) ? itm.requestedQuantity.toInt().toString() : itm.requestedQuantity.toString();
                  final cleanIss = (itm.issuedQuantity % 1 == 0) ? itm.issuedQuantity.toInt().toString() : itm.issuedQuantity.toString();
                  final note = itm.storeRemark?.trim().isNotEmpty == true ? itm.storeRemark! : (itm.remark?.trim().isNotEmpty == true ? itm.remark! : '-');

                  return pw.TableRow(
                    children: [
                      _tableCell('$idx', align: pw.TextAlign.center),
                      _tableCell(itm.requisitionDate.isNotEmpty ? itm.requisitionDate : '-'),
                      _tableCell('${itm.userName} (${itm.employeeCode})'),
                      _tableCell(itm.locationName),
                      _tableCell('${itm.materialName} [${itm.unit}]'),
                      _tableCell(cleanReq, align: pw.TextAlign.right),
                      _tableCell(cleanIss, align: pw.TextAlign.right),
                      _statusCell(itm.status),
                      _tableCell(note),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Signatures Section
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('Generated By (Store Operator)'),
                  _signatureBox('Verified By (Store In-Charge)'),
                  _signatureBox('Audited By (Accounts Department)'),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _metricBlock(String title, String val, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#64748B'))),
        pw.SizedBox(height: 1),
        pw.Text(val, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 6.5 : 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColor.fromHex('#0F172A') : PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  static pw.Widget _statusCell(String status) {
    PdfColor color;
    String label;

    switch (status) {
      case 'ISSUED':
        color = PdfColor.fromHex('#16A34A');
        label = 'ISSUED';
        break;
      case 'PARTIAL_ISSUED':
      case 'PARTIALLY_ISSUED':
        color = PdfColor.fromHex('#EA580C');
        label = 'PARTIAL';
        break;
      case 'NOT_AVAILABLE':
        color = PdfColor.fromHex('#DC2626');
        label = 'NOT AVAIL';
        break;
      default:
        color = PdfColor.fromHex('#64748B');
        label = 'PENDING';
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
      child: pw.Center(
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ),
    );
  }

  static pw.Widget _signatureBox(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
      ],
    );
  }

  /// Print or Share Single Requisition PDF directly
  static Future<void> printOrSharePdf({
    required String requisitionNo,
    required String requisitionDate,
    required String requesterName,
    required String employeeCode,
    required String departmentName,
    required String? userMobile,
    required List<StoreItem> items,
  }) async {
    final pdfBytes = await generateRequisitionPdf(
      requisitionNo: requisitionNo,
      requisitionDate: requisitionDate,
      requesterName: requesterName,
      employeeCode: employeeCode,
      departmentName: departmentName,
      userMobile: userMobile,
      items: items,
    );

    final safeFilename = 'Requisition_${requisitionNo.replaceAll(RegExp(r'[^\w\.-]'), '_')}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: safeFilename);
  }

  /// Print or Preview Single Requisition PDF
  static Future<void> printOrPreviewPdf({
    required String requisitionNo,
    required String requisitionDate,
    required String requesterName,
    required String employeeCode,
    required String departmentName,
    required String? userMobile,
    required List<StoreItem> items,
  }) async {
    final pdfBytes = await generateRequisitionPdf(
      requisitionNo: requisitionNo,
      requisitionDate: requisitionDate,
      requesterName: requesterName,
      employeeCode: employeeCode,
      departmentName: departmentName,
      userMobile: userMobile,
      items: items,
    );

    final safeFilename = 'Requisition_${requisitionNo.replaceAll(RegExp(r'[^\w\.-]'), '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: safeFilename,
    );
  }

  /// Share Store History Statement PDF
  static Future<void> shareHistoryReportPdf({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String statusFilter,
    String? searchQuery,
    required List<StoreItem> items,
  }) async {
    final pdfBytes = await generateHistoryReportPdf(
      dateFrom: dateFrom,
      dateTo: dateTo,
      statusFilter: statusFilter,
      searchQuery: searchQuery,
      items: items,
    );

    final fromStr = DateFormat('yyyyMMdd').format(dateFrom);
    final toStr = DateFormat('yyyyMMdd').format(dateTo);
    final filename = 'Store_Dispatch_Statement_${fromStr}_$toStr.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  /// Print or Preview Store History Statement PDF
  static Future<void> printOrPreviewHistoryPdf({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String statusFilter,
    String? searchQuery,
    required List<StoreItem> items,
  }) async {
    final pdfBytes = await generateHistoryReportPdf(
      dateFrom: dateFrom,
      dateTo: dateTo,
      statusFilter: statusFilter,
      searchQuery: searchQuery,
      items: items,
    );

    final fromStr = DateFormat('yyyyMMdd').format(dateFrom);
    final toStr = DateFormat('yyyyMMdd').format(dateTo);
    final filename = 'Store_Dispatch_Statement_${fromStr}_$toStr.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }
}
