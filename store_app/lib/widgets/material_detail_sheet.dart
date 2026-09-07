import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class MaterialDetailSheet extends StatefulWidget {
  final int materialId;
  final VoidCallback? onUpdated;

  const MaterialDetailSheet({
    super.key,
    required this.materialId,
    this.onUpdated,
  });

  static Future<void> show(BuildContext context, int materialId, {VoidCallback? onUpdated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailSheet(
        materialId: materialId,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<MaterialDetailSheet> createState() => _MaterialDetailSheetState();
}

class _MaterialDetailSheetState extends State<MaterialDetailSheet> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final res = await ApiService.getMaterialDetails(widget.materialId);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _data = res['data'];
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      final msg = res['message'] ?? 'Failed to load material details';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  String _formatQty(dynamic val) {
    if (val == null) return '0';
    final d = (val is num) ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
    return (d % 1 == 0) ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  String _formatCurrency(dynamic val) {
    if (val == null) return '0';
    final d = (val is num) ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
    return NumberFormat('#,##,##0.00').format(d);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  // Quick Physical Stock Adjustment Dialog
  void _openStockAdjustmentDialog() {
    if (_data == null) return;
    final mat = _data!['material'] ?? {};
    final currentStock = (mat['current_stock'] is num)
        ? (mat['current_stock'] as num).toDouble()
        : double.tryParse(mat['current_stock']?.toString() ?? '0') ?? 0.0;
    final unit = mat['unit']?.toString() ?? 'Nos';

    final stockCtrl = TextEditingController(text: (currentStock % 1 == 0) ? currentStock.toInt().toString() : currentStock.toString());
    final reasonCtrl = TextEditingController(text: 'Physical stock verification on site');
    double newStockVal = currentStock;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final diff = newStockVal - currentStock;
            final isIncrease = diff > 0;

            void updateVal(double val) {
              final clean = val < 0 ? 0.0 : val;
              setModalState(() {
                newStockVal = clean;
                stockCtrl.text = (clean % 1 == 0) ? clean.toInt().toString() : clean.toString();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Physical Stock Count',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Direct stock adjustment / audit entry',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Material Name Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mat['name']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Code: ${mat['code']} | Unit: $unit',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Current Balance', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              Text(
                                '${_formatQty(currentStock)} $unit',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stock Input with Steppers
                    const Text('Enter Physical Counted Balance:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: () => updateVal(newStockVal - 1),
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixText: unit,
                              suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed != null) {
                                setModalState(() {
                                  newStockVal = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () => updateVal(newStockVal + 1),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Step Buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _quickStepChip('-50', () => updateVal(newStockVal - 50)),
                          _quickStepChip('-10', () => updateVal(newStockVal - 10)),
                          _quickStepChip('-5', () => updateVal(newStockVal - 5)),
                          _quickStepChip('+5', () => updateVal(newStockVal + 5)),
                          _quickStepChip('+10', () => updateVal(newStockVal + 10)),
                          _quickStepChip('+50', () => updateVal(newStockVal + 50)),
                          _quickStepChip('+100', () => updateVal(newStockVal + 100)),
                          _quickStepChip('Set 0', () => updateVal(0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Difference Counter Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: diff == 0
                            ? const Color(0xFFF1F5F9)
                            : isIncrease
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diff == 0
                                ? Icons.check_circle_outline_rounded
                                : isIncrease
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                            size: 16,
                            color: diff == 0
                                ? const Color(0xFF64748B)
                                : isIncrease
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            diff == 0
                                ? 'No change in stock balance'
                                : '${isIncrease ? "+" : ""}${_formatQty(diff)} $unit (${isIncrease ? "Stock Inward / Found" : "Stock Shortage / Adjustment"})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: diff == 0
                                  ? const Color(0xFF475569)
                                  : isIncrease
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Audit Reason Input
                    const Text('Reason / Audit Remark:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Physical stock count, damage write-off, receipt...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text('Update & Save Physical Stock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final scaffold = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final res = await ApiService.updateMaterialStock(
                            materialId: widget.materialId,
                            currentStock: newStockVal,
                            reason: reasonCtrl.text.trim(),
                            updateMaster: false,
                          );

                          if (!mounted) return;
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Stock updated successfully'),
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          );
                          if (res['success'] == true) {
                            _fetchDetails();
                            widget.onUpdated?.call();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickStepChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onPressed: onTap,
      ),
    );
  }

  // Edit Material Master Info Dialog
  void _openEditMasterDialog() {
    if (_data == null) return;
    final mat = _data!['material'] ?? {};
    final categories = (_data!['categories'] as List?) ?? [];

    final nameCtrl = TextEditingController(text: mat['name']?.toString() ?? '');
    final codeCtrl = TextEditingController(text: mat['code']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: mat['unit']?.toString() ?? 'Nos');
    final rateCtrl = TextEditingController(text: (mat['default_rate'] ?? 0).toString());
    int? selectedCatId = mat['category_id'] != null ? int.tryParse(mat['category_id'].toString()) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 24),
                              SizedBox(width: 10),
                              Text('Edit Material Master', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Warning Banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: Make sure Material Name & Code matches with Tally Master to avoid import/export sync mismatch.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Name Field
                      const Text('Material Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. 1.5 MM 2 CORE CABLE',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Code & Unit
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Material Code *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: codeCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'MAT-001',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Unit (UOM) *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: unitCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Nos, MTR, KG, PCS',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Default Rate & Category
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Default Rate (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: rateCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: selectedCatId,
                                      items: [
                                        const DropdownMenuItem<int?>(value: null, child: Text('No Category', style: TextStyle(fontSize: 12))),
                                        ...categories.map((c) => DropdownMenuItem<int?>(
                                              value: c['id'] is int ? c['id'] : int.tryParse(c['id'].toString()),
                                              child: Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                                            )),
                                      ],
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedCatId = val;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Save Master Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: const Text('Save Master Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name and Code are required')),
                              );
                              return;
                            }
                            final scaffold = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final currentStockVal = (mat['current_stock'] is num)
                                ? (mat['current_stock'] as num).toDouble()
                                : double.tryParse(mat['current_stock']?.toString() ?? '0') ?? 0.0;

                            final res = await ApiService.updateMaterialStock(
                              materialId: widget.materialId,
                              currentStock: currentStockVal,
                              name: nameCtrl.text.trim(),
                              code: codeCtrl.text.trim(),
                              unit: unitCtrl.text.trim(),
                              defaultRate: double.tryParse(rateCtrl.text.trim()) ?? 0.0,
                              categoryId: selectedCatId,
                              reason: 'Material master details updated from mobile',
                              updateMaster: true,
                            );

                            if (!mounted) return;
                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Master updated successfully'),
                                backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            );
                            if (res['success'] == true) {
                              _fetchDetails();
                              widget.onUpdated?.call();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mat = _data?['material'] ?? {};
    final summary = _data?['summary'] ?? {};
    final currentStock = (mat['current_stock'] is num)
        ? (mat['current_stock'] as num).toDouble()
        : double.tryParse(mat['current_stock']?.toString() ?? '0') ?? 0.0;
    final hasStock = currentStock > 0;
    final unit = mat['unit']?.toString() ?? 'Nos';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        hasStock ? Icons.inventory_2_rounded : Icons.warning_amber_rounded,
                        color: hasStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mat['name']?.toString() ?? (_isLoading ? 'Loading item...' : 'Material Details'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF0F172A)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${mat['code'] ?? "-"} • Rate: ₹${_formatCurrency(mat['default_rate'])} / $unit',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Action Action Buttons & Stock Bar
                Row(
                  children: [
                    // Live Balance Indicator Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasStock ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasStock ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LIVE BALANCE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                Text(
                                  '${_formatQty(currentStock)} $unit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: hasStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Physical Audit / Quick Edit Stock Button
                    ElevatedButton.icon(
                      onPressed: (_isLoading || _data == null) ? null : _openStockAdjustmentDialog,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Edit Stock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Edit Master Button
                    IconButton(
                      onPressed: (_isLoading || _data == null) ? null : _openEditMasterDialog,
                      icon: const Icon(Icons.settings_rounded, color: Color(0xFF475569)),
                      tooltip: 'Edit Master Details',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Navigation
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              tabs: const [
                Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Summary'),
                Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Recipients'),
                Tab(icon: Icon(Icons.location_on_rounded, size: 18), text: 'Locations'),
                Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Movements'),
                Tab(icon: Icon(Icons.verified_user_rounded, size: 18), text: 'Audit Trail'),
              ],
            ),
          ),

          // Tab Content Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2563EB)),
                        SizedBox(height: 12),
                        Text('Loading 360° Material Details...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFDC2626)),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchDetails,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSummaryTab(mat, summary, unit),
                          _buildRecipientsTab(unit),
                          _buildLocationsTab(unit),
                          _buildMovementsTab(unit),
                          _buildAuditLogsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // 1. Summary & KPIs Tab
  Widget _buildSummaryTab(Map<String, dynamic> mat, Map<String, dynamic> sum, String unit) {
    final issuedQty = (sum['total_issued_qty'] is num) ? (sum['total_issued_qty'] as num).toDouble() : double.tryParse(sum['total_issued_qty']?.toString() ?? '0') ?? 0.0;
    final reqQty = (sum['total_requested_qty'] is num) ? (sum['total_requested_qty'] as num).toDouble() : double.tryParse(sum['total_requested_qty']?.toString() ?? '0') ?? 0.0;
    final issuedAmt = (sum['total_issued_amount'] is num) ? (sum['total_issued_amount'] as num).toDouble() : double.tryParse(sum['total_issued_amount']?.toString() ?? '0') ?? 0.0;
    final stockVal = (sum['current_stock_value'] is num) ? (sum['current_stock_value'] as num).toDouble() : double.tryParse(sum['current_stock_value']?.toString() ?? '0') ?? 0.0;
    final fulfillmentRatio = reqQty > 0 ? (issuedQty / reqQty * 100).clamp(0, 100).toInt() : 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Grid
          Row(
            children: [
              Expanded(child: _kpiCard('Total Issued', '${_formatQty(issuedQty)} $unit', '₹${_formatCurrency(issuedAmt)}', const Color(0xFF16A34A), Icons.output_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard('Live Stock Value', '₹${_formatCurrency(stockVal)}', 'Balance: ${_formatQty(mat['current_stock'])} $unit', const Color(0xFF2563EB), Icons.account_balance_wallet_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _kpiCard('Total Requested', '${_formatQty(reqQty)} $unit', '$fulfillmentRatio% Fulfilled', const Color(0xFFD97706), Icons.input_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard('Activity Reach', '${sum['total_unique_users'] ?? sum['unique_users_count'] ?? 0} Users', '${sum['total_unique_locations'] ?? sum['unique_locations_count'] ?? 0} Locations', const Color(0xFF7C3AED), Icons.share_location_rounded)),
            ],
          ),
          const SizedBox(height: 16),

          // Material Specification Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text('Master Specifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
                  ],
                ),
                const Divider(height: 20),
                _specRow('Item Full Name', mat['name']?.toString() ?? '-'),
                _specRow('Item Code', mat['code']?.toString() ?? '-'),
                _specRow('Category', mat['category_name']?.toString() ?? 'Uncategorized'),
                _specRow('Unit of Measurement', unit),
                _specRow('Default Unit Rate', '₹ ${_formatCurrency(mat['default_rate'])}'),
                _specRow('Created At', _formatDate(mat['created_at'])),
                _specRow('Last Updated', _formatDate(mat['updated_at'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String val, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Recipients Tab (Who took this item)
  Widget _buildRecipientsTab(String unit) {
    final users = (_data?['user_breakdown'] as List?) ?? [];
    if (users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No requisition history found for any recipient.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final qty = (u['total_issued_qty'] is num) ? (u['total_issued_qty'] as num).toDouble() : double.tryParse(u['total_issued_qty']?.toString() ?? '0') ?? 0.0;
        final amount = (u['total_amount'] is num) ? (u['total_amount'] as num).toDouble() : double.tryParse(u['total_amount']?.toString() ?? '0') ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  (u['name'] != null && u['name'].toString().isNotEmpty)
                      ? u['name'].toString()[0].toUpperCase()
                      : ((u['user_name'] != null && u['user_name'].toString().isNotEmpty) ? u['user_name'].toString()[0].toUpperCase() : 'U'),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u['name']?.toString() ?? u['user_name']?.toString() ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${u['employee_code'] ?? ""} • ${u['department_name'] ?? "General"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Last Taken: ${_formatDate(u['last_issued_at'] ?? u['last_requisition_date'])}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatQty(qty)} $unit',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF16A34A)),
                  ),
                  Text(
                    '₹${_formatCurrency(amount)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '${u['requisition_count'] ?? 1} Requests',
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Locations Tab (Where it went)
  Widget _buildLocationsTab(String unit) {
    final locations = (_data?['location_breakdown'] as List?) ?? [];
    if (locations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No location dispatch records found.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final qty = (loc['total_issued_qty'] is num) ? (loc['total_issued_qty'] as num).toDouble() : double.tryParse(loc['total_issued_qty']?.toString() ?? '0') ?? 0.0;
        final amount = (loc['total_amount'] is num) ? (loc['total_amount'] as num).toDouble() : double.tryParse(loc['total_amount']?.toString() ?? '0') ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_city_rounded, color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc['name']?.toString() ?? loc['location_name']?.toString() ?? 'Site Location',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${loc['code'] ?? loc['location_code'] ?? "-"} • ${loc['requisition_count'] ?? 1} requisitions',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Last Dispatched: ${_formatDate(loc['last_issued_at'] ?? loc['last_requisition_date'])}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatQty(qty)} $unit',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF7C3AED)),
                  ),
                  Text(
                    '₹${_formatCurrency(amount)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Movement Transactions Tab
  Widget _buildMovementsTab(String unit) {
    final movements = (_data?['movement_log'] as List?) ?? [];
    if (movements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No dispatch movement transactions yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final m = movements[index];
        final status = m['status']?.toString() ?? m['item_status']?.toString() ?? 'ISSUED';
        final isIssued = status == 'ISSUED';
        final isPartial = status == 'PARTIAL_ISSUED' || status == 'PARTIALLY_ISSUED';
        final isNotAvailable = status == 'NOT_AVAILABLE';

        final statusColor = isIssued
            ? const Color(0xFF16A34A)
            : isPartial
                ? const Color(0xFFD97706)
                : isNotAvailable
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m['sub_requisition_no']?.toString() ?? 'REQ',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF2563EB)),
                        ),
                      ),
                      if (m['is_emergency'] == 1 || m['is_emergency'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('EMERGENCY', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issued To: ${m['user_name']} (${m['employee_code'] ?? "-"})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Location: ${m['location_name'] ?? "-"}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        if (m['store_action_by_name'] != null)
                          Text(
                            'Store Keeper: ${m['store_action_by_name']}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Req: ${_formatQty(m['requested_quantity'])} $unit',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Issued: ${_formatQty(m['issued_quantity'])} $unit',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: statusColor),
                      ),
                      Text(
                        '₹${_formatCurrency(m['amount'])}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              if (m['store_remark'] != null && m['store_remark'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Remark: ${m['store_remark']}',
                    style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDate(m['store_action_at'] ?? m['created_at']),
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. Audit Trail & Log Tab
  Widget _buildAuditLogsTab() {
    final auditLogs = (_data?['audit_logs'] as List?) ?? [];
    if (auditLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No audit trail records logged yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: auditLogs.length,
      itemBuilder: (context, index) {
        final log = auditLogs[index];
        final action = log['action']?.toString() ?? 'UPDATE';
        final isStockAdjust = action == 'PHYSICAL_STOCK_ADJUSTMENT';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isStockAdjust ? Icons.inventory_rounded : Icons.edit_rounded,
                        size: 16,
                        color: isStockAdjust ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        action.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(log['created_at']),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (log['actor_name'] != null || log['user_name'] != null)
                Text(
                  'Action By: ${log['actor_name'] ?? log['user_name']} ${log['employee_code'] != null ? "(${log['employee_code']})" : ""}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              const SizedBox(height: 4),
              if (log['new_data'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log['new_data'].toString(),
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF334155)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
