import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await ApiService.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });

    // Mark as viewed
    if (list.isNotEmpty) {
      final firstId = list.first['id'];
      if (firstId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_viewed_notification_id', int.tryParse(firstId.toString()) ?? 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Store Action Alerts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_off_outlined, size: 36, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Store Alerts Yet',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'When the store keeper issues or updates any of your requested materials, live notifications will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          itemCount: _notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _notifications[index];
                            return _buildNotificationCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic item) {
    final status = item['status'] ?? 'PENDING';
    final materialName = item['material_name'] ?? 'Material';
    final reqQty = item['requested_quantity'] ?? 0;
    final issQty = item['issued_quantity'] ?? 0;
    final unit = item['unit_snapshot'] ?? '';
    final locName = item['location_name'] ?? 'Location';
    final storeUser = item['store_user_name'] ?? 'Store';
    final storeRemark = item['store_remark'];
    final actionAt = item['store_action_at'] ?? '';

    Color bg;
    Color border;
    Color iconColor;
    IconData icon;
    String title;
    String statusBadge;

    if (status == 'ISSUED') {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      title = 'Material Issued Fully';
      statusBadge = 'ISSUED ($issQty $unit)';
    } else if (status == 'PARTIALLY_ISSUED') {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      iconColor = const Color(0xFFD97706);
      icon = Icons.electric_bolt_rounded;
      title = 'Material Partially Issued';
      statusBadge = 'PARTIAL ($issQty / $reqQty $unit)';
    } else if (status == 'NOT_AVAILABLE') {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      title = 'Material Not Available';
      statusBadge = 'NOT AVAILABLE';
    } else {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF2563EB);
      icon = Icons.info_outline_rounded;
      title = 'Material Updated';
      statusBadge = status;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: iconColor),
                    ),
                    if (actionAt.toString().isNotEmpty)
                      Text(
                        _formatTimestamp(actionAt.toString()),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  materialName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        statusBadge,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📍 $locName',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (storeRemark != null && storeRemark.toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Store Remark: "$storeRemark" (By $storeUser)',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return raw;
    }
  }
}
