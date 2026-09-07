import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/material_detail_sheet.dart';

class StockInspectorScreen extends StatefulWidget {
  const StockInspectorScreen({super.key});

  @override
  State<StockInspectorScreen> createState() => _StockInspectorScreenState();
}

class _StockInspectorScreenState extends State<StockInspectorScreen> {
  List<StockMaterial> _materials = [];
  List<String> _categories = [];
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    final res = await ApiService.getStock(
      search: _searchController.text.trim(),
      category: _selectedCategory,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _materials = res['materials'];
        _categories = res['categories'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to load stock')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Warehouse Live Stock',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: () => _loadStock(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _loadStock(showLoading: false),
                    decoration: const InputDecoration(
                      hintText: 'Search Material Name, Code...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _categoryChip(null, 'All Categories'),
                        ..._categories.map((c) => _categoryChip(c, c)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Total Items Indicator & Quick Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFE2E8F0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_materials.length} Materials (Tap to edit stock/details)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF334155)),
                ),
                Row(
                  children: [
                    _legendDot(const Color(0xFF16A34A), 'In Stock'),
                    const SizedBox(width: 8),
                    _legendDot(const Color(0xFFDC2626), 'Zero Stock'),
                  ],
                ),
              ],
            ),
          ),

          // Stock List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _materials.isEmpty
                    ? const Center(child: Text('No materials found in inventory'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: _materials.length,
                        itemBuilder: (context, index) {
                          final mat = _materials[index];
                          final hasStock = mat.currentStock > 0;
                          final cleanStock = (mat.currentStock % 1 == 0) ? mat.currentStock.toInt().toString() : mat.currentStock.toString();

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                MaterialDetailSheet.show(
                                  context,
                                  mat.id,
                                  onUpdated: () => _loadStock(showLoading: false),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
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
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mat.name,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Code: ${mat.code} • Rate: ₹${NumberFormat('#,##,##0').format(mat.defaultRate)} / ${mat.unit}',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                          if (mat.category != null && mat.category!.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                mat.category!,
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Balance', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                        Text(
                                          '$cleanStock ${mat.unit}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: hasStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Row(
                                          children: [
                                            Text(
                                              'Details',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                            ),
                                            Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String? cat, String label) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155))),
        selected: isSelected,
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: const Color(0xFFF1F5F9),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = cat);
          _loadStock();
        },
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
