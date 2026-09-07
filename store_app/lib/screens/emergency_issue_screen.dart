import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class EmergencyDraftItem {
  final StockMaterial material;
  double quantity;
  String? remark;

  EmergencyDraftItem({
    required this.material,
    required this.quantity,
    this.remark,
  });

  double get totalAmount => quantity * material.defaultRate;
}

class EmergencyIssueScreen extends StatefulWidget {
  const EmergencyIssueScreen({super.key});

  @override
  State<EmergencyIssueScreen> createState() => _EmergencyIssueScreenState();
}

class _EmergencyIssueScreenState extends State<EmergencyIssueScreen> {
  List<TargetUser> _users = [];
  List<LocationItem> _locations = [];
  List<StockMaterial> _materials = [];

  TargetUser? _selectedUser;
  LocationItem? _selectedLocation;
  final List<EmergencyDraftItem> _draftItems = [];

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _globalRemarkController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<String> _quickReasons = [
    'Urgent Site Repair',
    'Machine Breakdown',
    'Water Pipe Leakage',
    'Electrical Hazard',
    'Concrete Pouring Urgent',
    'Safety Requirement',
  ];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final res = await ApiService.getEmergencyOptions();
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _users = res['users'];
        _locations = res['locations'];
        _materials = res['materials'];
        _isLoading = false;
        if (_locations.isNotEmpty) _selectedLocation = _locations.first;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to load options')),
      );
    }
  }

  double get _totalEstimatedAmount {
    return _draftItems.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  /// Open Searchable Material Picker Bottom Sheet (Supports 1400+ items smoothly)
  void _openMaterialSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _MaterialSearchSheet(
          materials: _materials,
          alreadyAddedIds: _draftItems.map((e) => e.material.id).toSet(),
          onMaterialSelected: (material) {
            Navigator.pop(ctx);
            _promptQuantityAndAdd(material);
          },
        );
      },
    );
  }

  /// Quantity Prompt for adding/editing material
  void _promptQuantityAndAdd(StockMaterial material, {EmergencyDraftItem? existingItem}) {
    double initialQty = existingItem != null ? existingItem.quantity : 1.0;
    final qtyController = TextEditingController(
      text: initialQty.toStringAsFixed(initialQty % 1 == 0 ? 0 : 2),
    );
    final remarkController = TextEditingController(text: existingItem?.remark ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setQty(double newQty) {
              if (newQty <= 0) newQty = 1;
              qtyController.text = newQty.toStringAsFixed(newQty % 1 == 0 ? 0 : 2);
              qtyController.selection = TextSelection.fromPosition(
                TextPosition(offset: qtyController.text.length),
              );
              setSheetState(() {});
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
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFE11D48), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: ${material.code} • Stock: ${material.currentStock.toStringAsFixed(material.currentStock % 1 == 0 ? 0 : 2)} ${material.unit} • Rate: ₹${material.defaultRate.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Dispatch Quantity (Type or use +/-):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),

                  // Quantity Stepper & Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        // Minus Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              double current = double.tryParse(qtyController.text.trim()) ?? 1.0;
                              if (current > 1) {
                                HapticFeedback.lightImpact();
                                setQty(current - 1);
                              } else if (current > 0.1) {
                                HapticFeedback.lightImpact();
                                setQty(current - 0.1);
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

                        // Editable input
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                    ),
                                    onChanged: (val) {
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  material.unit,
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

                        // Plus Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              double current = double.tryParse(qtyController.text.trim()) ?? 1.0;
                              HapticFeedback.lightImpact();
                              setQty(current + 1);
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

                  // Quick Quantity Presets
                  Row(
                    children: [
                      _quickQtyChip('1', 1.0, setQty),
                      const SizedBox(width: 6),
                      _quickQtyChip('5', 5.0, setQty),
                      const SizedBox(width: 6),
                      _quickQtyChip('10', 10.0, setQty),
                      const SizedBox(width: 6),
                      _quickQtyChip('25', 25.0, setQty),
                      const SizedBox(width: 6),
                      _quickQtyChip('50', 50.0, setQty),
                      const SizedBox(width: 6),
                      _quickQtyChip('100', 100.0, setQty),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      hintText: 'Item specific note (Optional)',
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
                        backgroundColor: const Color(0xFFE11D48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final enteredQty = double.tryParse(qtyController.text.trim());
                        if (enteredQty == null || enteredQty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid quantity (> 0)')),
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();
                        setState(() {
                          if (existingItem != null) {
                            existingItem.quantity = enteredQty;
                            existingItem.remark = remarkController.text.trim().isEmpty ? null : remarkController.text.trim();
                          } else {
                            _draftItems.add(EmergencyDraftItem(
                              material: material,
                              quantity: enteredQty,
                              remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                            ));
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        existingItem != null ? 'Update Quantity' : '✓ Add to Emergency Dispatch List',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
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

  Widget _quickQtyChip(String label, double val, Function(double) onApply) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onApply(val);
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  /// Open Searchable Employee Selector
  void _openUserSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUsers = _users.where((u) {
              final q = searchQuery.toLowerCase();
              return u.name.toLowerCase().contains(q) ||
                  u.employeeCode.toLowerCase().contains(q) ||
                  (u.departmentName ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Recipient Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search employee name or code...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(child: Text('No employee found', style: TextStyle(color: Color(0xFF94A3B8))))
                        : ListView.separated(
                            itemCount: filteredUsers.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final u = filteredUsers[index];
                              final isSelected = _selectedUser?.id == u.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? const Color(0xFFE11D48) : const Color(0xFFEFF6FF),
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                subtitle: Text('${u.employeeCode} • ${u.departmentName ?? 'General'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE11D48)) : null,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedUser = u);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
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

  /// Submit Multi-Item Emergency Issue
  Future<void> _submitEmergencyIssue() async {
    if (_selectedUser == null) {
      _showToast('Please select recipient employee');
      return;
    }
    if (_selectedLocation == null) {
      _showToast('Please select site location');
      return;
    }
    if (_draftItems.isEmpty) {
      _showToast('Please add at least one material to emergency dispatch list');
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showToast('Emergency reason is mandatory');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final payloadItems = _draftItems.map((item) {
      return {
        'material_id': item.material.id,
        'quantity': item.quantity,
        'remark': item.remark,
      };
    }).toList();

    final res = await ApiService.createBulkEmergencyIssue(
      userId: _selectedUser!.id,
      locationId: _selectedLocation!.id,
      reason: reason,
      remark: _globalRemarkController.text.trim().isEmpty ? null : _globalRemarkController.text.trim(),
      items: payloadItems,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      HapticFeedback.heavyImpact();
      final data = res['data'] ?? {};
      _showSuccessDialog(data);
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Emergency issue failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final int itemsCount = data['items_count'] ?? _draftItems.length;
    final String subReqNo = data['sub_requisition_no'] ?? data['sub_req_no'] ?? '-';
    final double totalAmount = (data['total_amount'] is num) ? (data['total_amount'] as num).toDouble() : _totalEstimatedAmount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 10),
            Text('Emergency Dispatched!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$itemsCount material(s) successfully issued on the spot to ${_selectedUser?.name}.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Voucher:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(subReqNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Location:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(_selectedLocation?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Value:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('₹ ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF16A34A))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: const Text('Done / New Issue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _draftItems.clear();
      _reasonController.clear();
      _globalRemarkController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '⚡ Emergency Material Dispatch',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFFE11D48), size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant Multi-Material Spot Issue',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF9F1239)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Issue single or multiple materials to employee on the spot. Requisition will be auto-generated and tracked in Tally.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFBE123C)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Recipient Employee
                  const Text('1. Recipient Employee *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _openUserSearchDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: _selectedUser != null ? const Color(0xFF2563EB) : const Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _selectedUser == null
                                ? const Text('Tap to search & select employee...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))
                                : Text('${_selectedUser!.name} (${_selectedUser!.employeeCode}) - ${_selectedUser!.departmentName ?? 'General'}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Location
                  const Text('2. Site Location *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LocationItem>(
                        value: _selectedLocation,
                        isExpanded: true,
                        items: _locations.map((loc) {
                          return DropdownMenuItem(
                            value: loc,
                            child: Text(loc.name, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedLocation = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Multi-Item Dispatch List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3. Materials to Dispatch (${_draftItems.length}) *',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('+ Search Material', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        onPressed: _openMaterialSearchSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Draft Items Container
                  if (_draftItems.isEmpty)
                    InkWell(
                      onTap: _openMaterialSearchSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(50)),
                              child: const Icon(Icons.search_rounded, size: 28, color: Color(0xFFE11D48)),
                            ),
                            const SizedBox(height: 10),
                            const Text('No materials added yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF334155))),
                            const SizedBox(height: 4),
                            const Text('Tap here to search from 1400+ materials and add items', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ..._draftItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
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
                                  radius: 14,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.material.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Code: ${item.material.code} • Rate: ₹${item.material.defaultRate.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                      if (item.remark != null && item.remark!.isNotEmpty)
                                        Text('Note: ${item.remark}', style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C))),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _promptQuantityAndAdd(item.material, existingItem: item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFED7AA)),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.material.unit}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFC2410C)),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFEA580C)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _draftItems.removeAt(idx));
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        // Add More Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE11D48),
                              side: const BorderSide(color: Color(0xFFFECDD3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: const Text('+ Add Another Material', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: _openMaterialSearchSheet,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),

                  // 4. Emergency Reason
                  const Text('4. Emergency Reason (Mandatory) *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickReasons.map((r) {
                      final isSelected = _reasonController.text == r;
                      return ChoiceChip(
                        label: Text(r, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : const Color(0xFF334155))),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE11D48),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _reasonController.text = val ? r : '');
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      hintText: 'Or type custom emergency reason...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Remarks
                  const Text('5. Additional Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _globalRemarkController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Approved over phone by Project Head',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Total & Summary Bar
                  if (_draftItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Items Selected', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              Text('${_draftItems.length} Materials', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Estimated Value', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              Text('₹ ${_totalEstimatedAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                      label: Text(
                        _isSubmitting
                            ? 'Recording Dispatch...'
                            : _draftItems.isNotEmpty
                                ? 'Authorize Emergency Issue (${_draftItems.length} Items)'
                                : 'Authorize Emergency Issue',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                      ),
                      onPressed: _isSubmitting ? null : _submitEmergencyIssue,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

/// Dedicated Search Sheet for fast searching 1400+ materials
class _MaterialSearchSheet extends StatefulWidget {
  final List<StockMaterial> materials;
  final Set<int> alreadyAddedIds;
  final ValueChanged<StockMaterial> onMaterialSelected;

  const _MaterialSearchSheet({
    required this.materials,
    required this.alreadyAddedIds,
    required this.onMaterialSelected,
  });

  @override
  State<_MaterialSearchSheet> createState() => _MaterialSearchSheetState();
}

class _MaterialSearchSheetState extends State<_MaterialSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  List<StockMaterial> _filtered = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.materials;
    final catSet = <String>{};
    for (var m in widget.materials) {
      if (m.category != null && m.category!.trim().isNotEmpty) {
        catSet.add(m.category!.trim());
      }
    }
    _categories = ['ALL', ...catSet.toList()..sort()];
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = widget.materials.where((m) {
        final matchesCat = (_selectedCategory == 'ALL' || (m.category != null && m.category == _selectedCategory));
        final matchesQuery = q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            m.code.toLowerCase().contains(q) ||
            (m.category ?? '').toLowerCase().contains(q);
        return matchesCat && matchesQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '🔍 Search & Select Material',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                Text(
                  '${_filtered.length} found',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search 1400+ items (e.g. cable, cement, MAT-0021)...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE11D48)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                ),
              ),
              onChanged: (_) => _filter(),
            ),
          ),

          // Category Chips
          if (_categories.length > 1)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155))),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE11D48),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        _selectedCategory = cat;
                        _filter();
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // High Performance Item List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No matching material found.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemExtent: 72,
                    itemBuilder: (context, index) {
                      final m = _filtered[index];
                      final isAdded = widget.alreadyAddedIds.contains(m.id);
                      final bool inStock = m.currentStock > 0;

                      return ListTile(
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: isAdded ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              m.code,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: inStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Stock: ${m.currentStock.toStringAsFixed(m.currentStock % 1 == 0 ? 0 : 2)} ${m.unit}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: inStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${m.defaultRate.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        trailing: isAdded
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Added', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                              )
                            : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFE11D48), size: 22),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onMaterialSelected(m);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
