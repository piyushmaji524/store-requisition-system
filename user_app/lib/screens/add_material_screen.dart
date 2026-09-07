import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'select_material_screen.dart';

class QueuedRequisitionItem {
  final MaterialItem material;
  final double quantity;
  final LocationItem location;
  final String? remark;

  QueuedRequisitionItem({
    required this.material,
    required this.quantity,
    required this.location,
    this.remark,
  });
}

class AddMaterialScreen extends StatefulWidget {
  final VoidCallback? onItemAdded;
  const AddMaterialScreen({super.key, this.onItemAdded});

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  static int? _cachedLocationId;

  MaterialItem? _selectedMaterial;
  LocationItem? _selectedLocation;
  final _quantityController = TextEditingController();
  final _remarkController = TextEditingController();

  List<LocationItem> _locations = [];
  bool _isLoadingLocations = true;
  bool _isSubmitting = false;

  // Bulk Add / Cart Mode State
  bool _isBulkMode = false;
  final List<QueuedRequisitionItem> _queuedItems = [];

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndLocations();
  }

  Future<void> _loadPreferencesAndLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final bulkPref = prefs.getBool('bulk_add_mode_enabled') ?? false;

    final list = await ApiService.getLocations();
    if (!mounted) return;

    _cachedLocationId ??= prefs.getInt('last_location_id');

    LocationItem? defaultLocation;
    if (_cachedLocationId != null) {
      for (final loc in list) {
        if (loc.id == _cachedLocationId) {
          defaultLocation = loc;
          break;
        }
      }
    }

    if (defaultLocation == null && list.isNotEmpty) {
      defaultLocation = list.first;
    }

    setState(() {
      _isBulkMode = bulkPref;
      _locations = list;
      _selectedLocation = defaultLocation;
      _isLoadingLocations = false;
    });
  }

  void _toggleMode(bool bulk) async {
    setState(() => _isBulkMode = bulk);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bulk_add_mode_enabled', bulk);
  }

  void _onLocationSelected(LocationItem? loc) {
    if (loc == null) return;
    setState(() => _selectedLocation = loc);
    _cachedLocationId = loc.id;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('last_location_id', loc.id));
  }

  Future<void> _pickMaterial() async {
    final picked = await Navigator.push<MaterialItem>(
      context,
      MaterialPageRoute(builder: (_) => const SelectMaterialScreen()),
    );
    if (picked != null) {
      setState(() => _selectedMaterial = picked);
    }
  }

  // Add Item to Local Queue (Bulk Mode)
  void _addCurrentItemToQueue() {
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material first')),
      );
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    final remark = _remarkController.text.trim().isNotEmpty ? _remarkController.text.trim() : null;

    setState(() {
      _queuedItems.add(QueuedRequisitionItem(
        material: _selectedMaterial!,
        quantity: qty,
        location: _selectedLocation!,
        remark: remark,
      ));

      // Reset material & quantity fields for next item
      _selectedMaterial = null;
      _quantityController.clear();
      _remarkController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item added to list! (${_queuedItems.length} total)'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Submit All Queued Items
  Future<void> _submitAllQueuedItems() async {
    if (_queuedItems.isEmpty) return;

    setState(() => _isSubmitting = true);

    final payload = _queuedItems.map((item) => {
      'material_id': item.material.id,
      'quantity': item.quantity,
      'location_id': item.location.id,
      'remark': item.remark,
    }).toList();

    final res = await ApiService.addBulkItems(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_queuedItems.length} materials submitted successfully!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      widget.onItemAdded?.call();
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to submit bulk items.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // Submit Single Item (Single Mode)
  Future<void> _submitSingleItem() async {
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material')),
      );
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await ApiService.addItem(
      materialId: _selectedMaterial!.id,
      quantity: qty,
      locationId: _selectedLocation!.id,
      remark: _remarkController.text.trim().isNotEmpty ? _remarkController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedMaterial!.name} added to today\'s Requisition!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      widget.onItemAdded?.call();
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to add item.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isBulkMode ? 'Bulk Add Materials' : 'Add Material',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          // Instant Mode Switcher Chip
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                _isBulkMode ? Icons.playlist_add_check_rounded : Icons.looks_one_outlined,
                size: 16,
                color: _isBulkMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              label: Text(
                _isBulkMode ? 'Bulk Mode' : 'Single Mode',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _isBulkMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
              backgroundColor: _isBulkMode ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              side: BorderSide(
                color: _isBulkMode ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
              ),
              onPressed: () => _toggleMode(!_isBulkMode),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isBulkMode && _queuedItems.isNotEmpty
          ? _buildBulkBottomBar()
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Banner (Informative)
            if (_isBulkMode)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bulk Mode Active: Add materials to the list below and submit all at once.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Location Dropdown (Pre-filled with last used)
            const Text('Requisition Location / Site *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            _isLoadingLocations
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LocationItem>(
                        value: _selectedLocation,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: _locations.map((loc) {
                          return DropdownMenuItem<LocationItem>(
                            value: loc,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onLocationSelected,
                      ),
                    ),
                  ),
            const SizedBox(height: 18),

            // Material Selection
            const Text('Material *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickMaterial,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: _selectedMaterial != null ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedMaterial?.name ?? 'Search and select material...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedMaterial != null ? FontWeight.w600 : FontWeight.w400,
                          color: _selectedMaterial != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Quantity
            const Text('Quantity *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g. 10',
                suffixText: _selectedMaterial?.unit ?? 'Units',
                suffixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 18),

            // Purpose / Remark
            const Text('Purpose / Remark (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            TextField(
              controller: _remarkController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. For 2nd floor wall plastering...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Main Action Button (Mode Dependent)
            if (_isBulkMode) ...[
              ElevatedButton.icon(
                onPressed: _addCurrentItemToQueue,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('+ Add Material to List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),

              // Queued Items List
              _buildQueuedItemsSection(),
            ] else ...[
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSingleItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit Material to Store',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueuedItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items Ready to Submit (${_queuedItems.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            if (_queuedItems.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _queuedItems.clear()),
                child: const Text('Clear All', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_queuedItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No items in queue yet',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select a material above and tap "+ Add Material to List"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _queuedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _queuedItems[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.material.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${item.quantity} ${item.material.unit}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${item.location.name}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          if (item.remark != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Note: ${item.remark}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      onPressed: () => setState(() => _queuedItems.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBulkBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total in List',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_queuedItems.length} Materials',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAllQueuedItems,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Submit All (${_queuedItems.length})',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
