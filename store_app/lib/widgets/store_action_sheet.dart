import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

class StoreActionSheet {
  /// Show Partial Issue Action Modal
  static Future<Map<String, dynamic>?> showPartialIssue({
    required BuildContext context,
    required StoreItem item,
  }) {
    double qty = (item.requestedQuantity / 2).ceilToDouble();
    if (qty <= 0) qty = 1;
    if (qty > item.requestedQuantity) qty = item.requestedQuantity;

    final qtyController = TextEditingController(
      text: qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
    );
    final remarkController = TextEditingController();

    final quickChips = [
      'Baki kal subah aayega',
      'Warehouse stock short hai',
      'Gaadi un-load ho rahi hai',
      'Market purchase order laga diya',
    ];

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateQty(double newQty) {
              if (newQty < 0.01) newQty = 0.01;
              if (newQty > item.requestedQuantity) newQty = item.requestedQuantity;
              qty = newQty;
              qtyController.text = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
              qtyController.selection = TextSelection.fromPosition(
                TextPosition(offset: qtyController.text.length),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
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
                          color: const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.timelapse_rounded, color: Color(0xFFEA580C), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Partial Material Issue',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.materialName} (${item.unit})',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Requested vs Available comparison
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricCol('Required', '${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)} ${item.unit}', const Color(0xFF0F172A)),
                        Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                        _metricCol('Current Stock', '${item.currentStock.toStringAsFixed(item.currentStock % 1 == 0 ? 0 : 2)} ${item.unit}', item.currentStock > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Issued Quantity (Type or use +/-):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      Text(
                        'Max: ${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)} ${item.unit}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEA580C)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Interactive Quantity Stepper with Direct Number Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        // Decrement Button (-)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              double current = double.tryParse(qtyController.text.trim()) ?? qty;
                              if (current > 1) {
                                HapticFeedback.lightImpact();
                                setState(() => updateQty(current - 1));
                              } else if (current > 0.1) {
                                HapticFeedback.lightImpact();
                                setState(() => updateQty(current - 0.1));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Icon(Icons.remove_rounded, size: 24, color: Color(0xFFEA580C)),
                            ),
                          ),
                        ),

                        // Middle Editable Number Input
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: TextField(
                                    controller: qtyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFC2410C),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed != null) {
                                        setState(() => qty = parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.unit,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Increment Button (+)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              double current = double.tryParse(qtyController.text.trim()) ?? qty;
                              if (current < item.requestedQuantity) {
                                HapticFeedback.lightImpact();
                                setState(() => updateQty(current + 1));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Icon(Icons.add_rounded, size: 24, color: Color(0xFFEA580C)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Percentage Presets (25%, 50%, 75%, Max)
                  Row(
                    children: [
                      _quickPercentButton('25%', 0.25, item, (v) => setState(() => updateQty(v))),
                      const SizedBox(width: 6),
                      _quickPercentButton('50%', 0.50, item, (v) => setState(() => updateQty(v))),
                      const SizedBox(width: 6),
                      _quickPercentButton('75%', 0.75, item, (v) => setState(() => updateQty(v))),
                      const SizedBox(width: 6),
                      _quickPercentButton('Max (${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)})', 1.0, item, (v) => setState(() => updateQty(v))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Quick Remark (1-Tap):',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickChips.map((chip) {
                      final isSelected = remarkController.text == chip;
                      return ChoiceChip(
                        label: Text(chip, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155))),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEA580C),
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onSelected: (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            remarkController.text = selected ? chip : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      hintText: 'Custom remark (Optional)',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final enteredVal = double.tryParse(qtyController.text.trim());
                        if (enteredVal == null || enteredVal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kripya valid quantity enter karein (0 se jyada).'),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }
                        if (enteredVal > item.requestedQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Issued quantity requested quantity (${item.requestedQuantity} ${item.unit}) se jyada nahi ho sakti.'),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx, {
                          'issued_quantity': enteredVal,
                          'remark': remarkController.text.trim().isEmpty ? 'Partial issue' : remarkController.text.trim(),
                        });
                      },
                      child: const Text(
                        'Confirm Partial Issue',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show Not Available Action Modal
  static Future<String?> showNotAvailable({
    required BuildContext context,
    required StoreItem item,
  }) {
    final remarkController = TextEditingController(text: 'Not available in store');

    final quickChips = [
      'Not available in store',
      'Stock zero / Out of stock',
      'Market PO laga diya hai',
      'Damaged batch quarantined',
    ];

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
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
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mark as Not Available',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.materialName} (${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)} ${item.unit})',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Select Reason / Remark:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickChips.map((chip) {
                      final isSelected = remarkController.text == chip;
                      return ChoiceChip(
                        label: Text(chip, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155))),
                        selected: isSelected,
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onSelected: (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            remarkController.text = chip;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      hintText: 'Custom Reason',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx, remarkController.text.trim().isEmpty ? 'Not available in store' : remarkController.text.trim());
                      },
                      child: const Text(
                        'Mark Not Available',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show Full Edit Modal for Processed Items (Change Full / Partial / N/A, Qty, and Remark)
  static Future<Map<String, dynamic>?> showEditProcessedItem({
    required BuildContext context,
    required StoreItem item,
  }) {
    String currentAction = item.status == 'ISSUED'
        ? 'FULL_ISSUE'
        : item.isPartial
            ? 'PARTIAL_ISSUE'
            : item.status == 'NOT_AVAILABLE'
                ? 'NOT_AVAILABLE'
                : 'FULL_ISSUE';

    double qty = item.issuedQuantity > 0 ? item.issuedQuantity : item.requestedQuantity;
    if (currentAction == 'FULL_ISSUE') qty = item.requestedQuantity;
    if (currentAction == 'NOT_AVAILABLE') qty = 0;

    final qtyController = TextEditingController(
      text: (qty > 0 ? qty : (item.requestedQuantity / 2).ceilToDouble()).toStringAsFixed((qty > 0 ? qty : (item.requestedQuantity / 2).ceilToDouble()) % 1 == 0 ? 0 : 2),
    );
    final remarkController = TextEditingController(text: item.storeRemark ?? '');

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateQty(double newQty) {
              if (newQty < 0.01) newQty = 0.01;
              if (newQty > item.requestedQuantity) newQty = item.requestedQuantity;
              qty = newQty;
              qtyController.text = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
              qtyController.selection = TextSelection.fromPosition(
                TextPosition(offset: qtyController.text.length),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
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
                        child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Item Status / Quantity',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.materialName} (Req: ${item.requestedQuantity} ${item.unit})',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Select Status:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),

                  // Action Selector Chips
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              currentAction = 'FULL_ISSUE';
                              qty = item.requestedQuantity;
                              qtyController.text = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: currentAction == 'FULL_ISSUE' ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: currentAction == 'FULL_ISSUE' ? const Color(0xFF15803D) : const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Text(
                                'Full Issue',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: currentAction == 'FULL_ISSUE' ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              currentAction = 'PARTIAL_ISSUE';
                              if (qty >= item.requestedQuantity || qty <= 0) {
                                qty = (item.requestedQuantity / 2).ceilToDouble();
                              }
                              qtyController.text = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: currentAction == 'PARTIAL_ISSUE' ? const Color(0xFFEA580C) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: currentAction == 'PARTIAL_ISSUE' ? const Color(0xFFC2410C) : const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Text(
                                'Partial',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: currentAction == 'PARTIAL_ISSUE' ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              currentAction = 'NOT_AVAILABLE';
                              qty = 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: currentAction == 'NOT_AVAILABLE' ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: currentAction == 'NOT_AVAILABLE' ? const Color(0xFFB91C1C) : const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Text(
                                'Not Available',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: currentAction == 'NOT_AVAILABLE' ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity Stepper (if Partial Issue)
                  if (currentAction == 'PARTIAL_ISSUE') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Adjust Issued Quantity:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        Text(
                          'Max: ${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)} ${item.unit}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          // Decrement Button (-)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                double current = double.tryParse(qtyController.text.trim()) ?? qty;
                                if (current > 1) {
                                  HapticFeedback.lightImpact();
                                  setState(() => updateQty(current - 1));
                                } else if (current > 0.1) {
                                  HapticFeedback.lightImpact();
                                  setState(() => updateQty(current - 0.1));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: const Icon(Icons.remove_rounded, size: 24, color: Color(0xFFEA580C)),
                              ),
                            ),
                          ),

                          // Middle Editable Number Input
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFC2410C),
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val.trim());
                                        if (parsed != null) {
                                          setState(() => qty = parsed);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.unit,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Increment Button (+)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                double current = double.tryParse(qtyController.text.trim()) ?? qty;
                                if (current < item.requestedQuantity) {
                                  HapticFeedback.lightImpact();
                                  setState(() => updateQty(current + 1));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 24, color: Color(0xFFEA580C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Percentage Presets
                    Row(
                      children: [
                        _quickPercentButton('25%', 0.25, item, (v) => setState(() => updateQty(v))),
                        const SizedBox(width: 6),
                        _quickPercentButton('50%', 0.50, item, (v) => setState(() => updateQty(v))),
                        const SizedBox(width: 6),
                        _quickPercentButton('75%', 0.75, item, (v) => setState(() => updateQty(v))),
                        const SizedBox(width: 6),
                        _quickPercentButton('Max (${item.requestedQuantity.toStringAsFixed(item.requestedQuantity % 1 == 0 ? 0 : 2)})', 1.0, item, (v) => setState(() => updateQty(v))),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Store Remark / Note:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      hintText: 'Enter reason or remark (Optional)',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        double finalQty = qty;
                        if (currentAction == 'PARTIAL_ISSUE') {
                          final enteredVal = double.tryParse(qtyController.text.trim());
                          if (enteredVal == null || enteredVal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kripya valid quantity enter karein (0 se jyada).'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          if (enteredVal > item.requestedQuantity) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Issued quantity requested quantity (${item.requestedQuantity} ${item.unit}) se jyada nahi ho sakti.'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          finalQty = enteredVal;
                        }

                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx, {
                          'action_type': currentAction,
                          'issued_quantity': finalQty,
                          'remark': remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                        });
                      },
                      child: const Text(
                        'Update Issue Record',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _quickPercentButton(String label, double ratio, StoreItem item, Function(double) onApply) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          double calculated = (item.requestedQuantity * ratio);
          if (calculated < 1 && calculated > 0) {
            calculated = (calculated * 100).round() / 100;
          } else {
            calculated = calculated.roundToDouble();
          }
          if (calculated <= 0) calculated = 1;
          if (calculated > item.requestedQuantity) calculated = item.requestedQuantity;
          onApply(calculated);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _metricCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
