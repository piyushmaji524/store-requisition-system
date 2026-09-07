import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'requisition_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    ApiService.dataChangeNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    ApiService.dataChangeNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadHistory(silent: true);
    }
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent && _historyList.isEmpty) {
      setState(() => _isLoading = true);
    }
    final list = await ApiService.getHistory();
    if (!mounted) return;
    setState(() {
      _historyList = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Requisition History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadHistory),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No previous requisitions recorded', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadHistory(silent: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historyList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rawItem = _historyList[index];
                    if (rawItem is! Map) return const SizedBox.shrink();
                    final item = rawItem;

                    final reqId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                    final reqNo = item['requisition_no']?.toString() ?? '';
                    final reqDate = item['requisition_date']?.toString() ?? '';
                    final status = item['status']?.toString() ?? 'COMPLETED';
                    final totalItems = item['total_items']?.toString() ?? '0';
                    final totalIssuedQty = item['total_issued_qty']?.toString() ?? '0';
                    final pendingCount = int.tryParse(item['pending_count']?.toString() ?? '0') ?? 0;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RequisitionDetailsScreen(
                                requisitionId: reqId,
                                requisitionNo: reqNo,
                                requisitionDate: reqDate,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    reqDate,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.replaceAll('_', ' '),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    reqNo,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF2563EB)),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '$totalItems Items',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '$totalIssuedQty Issued',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(width: 16),
                                    Text(
                                      '$pendingCount Pending',
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706), fontWeight: FontWeight.w700),
                                    ),
                                  ],
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
    );
  }
}
