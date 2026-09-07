import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/notifications_sheet.dart';
import 'add_material_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int index, {String? filter}) onNavigateTab;
  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dashboardData;
  int _notificationCount = 0;
  bool _isLoading = true;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();

    // 1. Instant cross-screen event listener
    ApiService.dataChangeNotifier.addListener(_onDataChanged);

    // 2. Real-time background periodic sync (every 4 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchDashboard(silent: true);
      }
    });
  }

  @override
  void dispose() {
    ApiService.dataChangeNotifier.removeListener(_onDataChanged);
    _syncTimer?.cancel();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _fetchDashboard(silent: true);
    }
  }

  Future<void> _fetchDashboard({bool silent = false}) async {
    if (!silent && _dashboardData == null) {
      setState(() => _isLoading = true);
    }

    final data = await ApiService.getDashboard();
    final notifs = await ApiService.getNotifications();
    if (!mounted) return;
    setState(() {
      _dashboardData = data;
      _notificationCount = notifs.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final todayReq = _dashboardData?['today_requisition'];
    final stats = (todayReq?['stats'] as Map<String, dynamic>?) ?? {};
    final hasRequisition = todayReq != null;

    final totalItems = stats['total_items'] ?? 0;
    final pending = stats['pending_count'] ?? 0;
    final issued = stats['issued_count'] ?? 0;
    final partial = stats['partial_count'] ?? 0;
    final notAvailable = stats['not_available_count'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Good Day,', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Text(
                  '${user?.name ?? "User"} 👋',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _fetchDashboard,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
                onPressed: () async {
                  await NotificationsSheet.show(context);
                  _fetchDashboard(silent: true);
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _notificationCount > 9 ? '9+' : '$_notificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today's Requisition Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Today's Requisition",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasRequisition ? (todayReq['requisition_date'] ?? 'Today') : 'No items yet',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (hasRequisition) ...[
                            Text(
                              'Req No: ${todayReq['requisition_no']}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Window: 06:00 AM - 08:00 PM (IST)',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                            ),
                          ] else ...[
                            Text(
                              'Window Open: 06:00 AM - 08:00 PM',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Mini Stat Grid
                          Row(
                            children: [
                              _statChip('Total', '$totalItems', const Color(0xFFEFF6FF), onTap: () => widget.onNavigateTab(1, filter: 'ALL')),
                              const SizedBox(width: 6),
                              _statChip('Pending', '$pending', const Color(0xFFFEF3C7), onTap: () => widget.onNavigateTab(1, filter: 'PENDING')),
                              const SizedBox(width: 6),
                              _statChip('Issued', '$issued', const Color(0xFFDCFCE7), onTap: () => widget.onNavigateTab(1, filter: 'ISSUED')),
                              const SizedBox(width: 6),
                              _statChip('Partial', '$partial', const Color(0xFFFFEDD5), onTap: () => widget.onNavigateTab(1, filter: 'PARTIAL')),
                              const SizedBox(width: 6),
                              _statChip('N/A', '$notAvailable', const Color(0xFFFEE2E2), onTap: () => widget.onNavigateTab(1, filter: 'NA')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Action Button (+ ADD MATERIAL)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
                        );
                        if (res == true) _fetchDashboard();
                      },
                      icon: const Icon(Icons.add_circle_rounded, size: 22),
                      label: const Text('+ ADD MATERIAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Items Summary Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigateTab(1, filter: 'ALL'),
                          child: const Text('View All >', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _summaryCard(
                      icon: Icons.hourglass_top_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Pending Approval / Store Issue',
                      count: pending,
                      onTap: () => widget.onNavigateTab(1, filter: 'PENDING'),
                    ),
                    const SizedBox(height: 10),
                    _summaryCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF16A34A),
                      iconBg: const Color(0xFFDCFCE7),
                      title: 'Issued (Full)',
                      count: issued,
                      onTap: () => widget.onNavigateTab(1, filter: 'ISSUED'),
                    ),
                    const SizedBox(height: 10),
                    _summaryCard(
                      icon: Icons.pie_chart_outline_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFEDD5),
                      title: 'Partially Issued',
                      count: partial,
                      onTap: () => widget.onNavigateTab(1, filter: 'PARTIAL'),
                    ),
                    const SizedBox(height: 10),
                    _summaryCard(
                      icon: Icons.highlight_off_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEE2E2),
                      title: 'Not Available in Store',
                      count: notAvailable,
                      onTap: () => widget.onNavigateTab(1, filter: 'NA'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statChip(String label, String value, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
